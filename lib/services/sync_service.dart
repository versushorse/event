// 夫婦間のリアルタイム共有・同期サービス
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_keys.local.dart';
import '../models/outing_spot.dart';

class CoupleSyncService {
  static const String _prefRoomKey = 'couple_room_code';
  static const String _prefFavoritesKey = 'couple_favorites_json';
  static const String _prefLastSyncKey = 'couple_last_sync_time';

  /// 無料KVS（設定不要のキーバリューストア）のAppKey
  static const String _fallbackKvsAppKey = '2pbg4ppa';

  /// ローカルに保存された家族合言葉を取得する
  static Future<String> getRoomCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefRoomKey) ?? 'family-weekend';
  }

  /// 家族合言葉を保存する
  static Future<void> saveRoomCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRoomKey, code);
  }

  /// 夫婦のお気に入りリストをローカルストレージに永続保存する
  static Future<void> saveLocalFavorites(List<OutingSpot> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favorites.map((s) => s.toJson()).toList();
    await prefs.setString(_prefFavoritesKey, jsonEncode(jsonList));
  }

  /// ローカルストレージから夫婦のお気に入りリストを復元する
  static Future<List<OutingSpot>> loadLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefFavoritesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => OutingSpot.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('お気に入り読み込みエラー: $e');
      return [];
    }
  }

  /// クラウド同期（同じ家族合言葉を持つ夫婦端末間でリアルタイム同期）
  /// 1. Firebase Realtime Database（設定されている場合）
  /// 2. 高速CDNトピック（ntfy.sh）＋ オープンKVS による確実な即時同期
  static Future<List<OutingSpot>?> syncWithCloud({
    required String roomCode,
    required List<OutingSpot> localFavorites,
  }) async {
    final sanitizedCode =
        roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return null;

    final firebaseBaseUrl = AppApiKeys.firebaseRealtimeDbUrl.trim();
    if (firebaseBaseUrl.isNotEmpty) {
      return _syncWithFirebase(
        baseUrl: firebaseBaseUrl,
        roomCode: sanitizedCode,
        localFavorites: localFavorites,
      );
    } else {
      return _syncWithFastCdnAndKvs(
        roomCode: sanitizedCode,
        localFavorites: localFavorites,
      );
    }
  }

  /// 1. Firebase Realtime Database による高速・永続同期
  static Future<List<OutingSpot>?> _syncWithFirebase({
    required String baseUrl,
    required String roomCode,
    required List<OutingSpot> localFavorites,
  }) async {
    try {
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final endpoint = Uri.parse('$cleanBaseUrl/rooms/$roomCode.json');

      final getRes =
          await http.get(endpoint).timeout(const Duration(seconds: 10));
      List<OutingSpot> cloudList = [];
      if (getRes.statusCode == 200 &&
          getRes.body.isNotEmpty &&
          getRes.body != 'null') {
        try {
          final decoded = jsonDecode(getRes.body);
          if (decoded is List) {
            cloudList = decoded
                .map(
                    (item) => OutingSpot.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          debugPrint('Firebaseパースエラー: $e');
        }
      }

      final mergedMap = <String, OutingSpot>{};
      for (final spot in cloudList) {
        mergedMap[spot.id] = spot;
      }
      for (final spot in localFavorites) {
        mergedMap[spot.id] = spot;
      }

      final mergedList = mergedMap.values.toList();

      final postBody = jsonEncode(mergedList.map((s) => s.toJson()).toList());
      await http
          .put(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: postBody,
          )
          .timeout(const Duration(seconds: 10));

      await saveLocalFavorites(mergedList);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastSyncKey, DateTime.now().toIso8601String());

      return mergedList;
    } catch (e) {
      debugPrint('Firebase同期エラー: $e');
      return null;
    }
  }

  /// 2. 高速CDN即時通信 ＋ オープンKVS による即座の同期
  static Future<List<OutingSpot>?> _syncWithFastCdnAndKvs({
    required String roomCode,
    required List<OutingSpot> localFavorites,
  }) async {
    final mergedMap = <String, OutingSpot>{};
    for (final spot in localFavorites) {
      mergedMap[spot.id] = spot;
    }

    final cdnTopic = 'weekend_outing_couple_$roomCode';
    final cdnPollUrl = Uri.parse('https://ntfy.sh/$cdnTopic/json?poll=1');

    // A. 高速CDNから最新メッセージ（ハート候補）をフェッチ
    try {
      final cdnRes =
          await http.get(cdnPollUrl).timeout(const Duration(seconds: 4));
      if (cdnRes.statusCode == 200 && cdnRes.body.isNotEmpty) {
        final lines = cdnRes.body.split('\n');
        for (final line in lines.reversed) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final obj = jsonDecode(trimmed) as Map<String, dynamic>;
            if (obj['event'] == 'message' && obj['message'] != null) {
              final msgStr = obj['message'] as String;
              final spotListRaw = jsonDecode(msgStr) as List<dynamic>;
              for (final raw in spotListRaw) {
                final spot = OutingSpot.fromJson(raw as Map<String, dynamic>);
                mergedMap[spot.id] = spot;
              }
              break; // 最新の1件でOK
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('CDNフェッチ注意: $e');
    }

    // B. オープンKVSからもフェッチ（タイムアウト10秒に緩和）
    try {
      final kvsKey = 'room_$roomCode';
      final getUrl = Uri.parse(
          'https://keyvalue.immanuel.co/api/KeyVal/GetValue/$_fallbackKvsAppKey/$kvsKey');
      final getRes =
          await http.get(getUrl).timeout(const Duration(seconds: 8));
      if (getRes.statusCode == 200 && getRes.body.isNotEmpty) {
        final rawVal = getRes.body.trim().replaceAll('"', '');
        if (rawVal.isNotEmpty && rawVal != 'null') {
          try {
            final jsonStr = _decodeBase64Url(rawVal);
            final decoded = jsonDecode(jsonStr) as List<dynamic>;
            for (final item in decoded) {
              final spot =
                  _fromCompactJson(item as Map<String, dynamic>);
              if (!mergedMap.containsKey(spot.id)) {
                mergedMap[spot.id] = spot;
              }
            }
          } catch (e) {
            debugPrint('オープンKVSデコードエラー: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('オープンKVS取得注意: $e');
    }

    final mergedList = mergedMap.values.toList();

    // C. 高速CDNに最新のお気に入りリストを配信（相手のスマホへ即座にプッシュ）
    try {
      final cdnPostUrl = Uri.parse('https://ntfy.sh/$cdnTopic');
      final cdnBody =
          jsonEncode(mergedList.map((s) => s.toJson()).toList());
      await http
          .post(
            cdnPostUrl,
            headers: {'Title': 'CoupleFavoritesSync'},
            body: cdnBody,
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('CDN送信注意: $e');
    }

    // D. オープンKVSへも非同期で保存
    try {
      final kvsKey = 'room_$roomCode';
      final compactList = mergedList
          .take(20)
          .map((s) => _toCompactJson(s))
          .toList();
      final compactJsonStr = jsonEncode(compactList);
      final b64 = _encodeBase64Url(compactJsonStr);

      final updateUrl = Uri.parse(
          'https://keyvalue.immanuel.co/api/KeyVal/UpdateValue/$_fallbackKvsAppKey/$kvsKey/$b64');
      await http.post(
        updateUrl,
        headers: {'Content-Length': '0'},
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('オープンKVS保存注意: $e');
    }

    await saveLocalFavorites(mergedList);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastSyncKey, DateTime.now().toIso8601String());

    return mergedList;
  }

  /// Base64Url エンコード
  static String _encodeBase64Url(String input) {
    final bytes = utf8.encode(input);
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Base64Url デコード
  static String _decodeBase64Url(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final mod4 = normalized.length % 4;
    if (mod4 == 2) normalized += '==';
    if (mod4 == 3) normalized += '=';
    final bytes = base64.decode(normalized);
    return utf8.decode(bytes);
  }

  /// 軽量JSONへの変換（文字数圧縮用）
  static Map<String, dynamic> _toCompactJson(OutingSpot spot) {
    return {
      'i': spot.id,
      't': spot.title,
      'a': spot.address,
      'lt': spot.latitude,
      'lg': spot.longitude,
      'c': spot.category.name,
      'p': spot.pickedBy?.index ?? 2,
      'n': spot.coupleNote,
      'd': spot.driveMinutes,
      'km': spot.distanceKm,
    };
  }

  /// 軽量JSONからの復元
  static OutingSpot _fromCompactJson(Map<String, dynamic> json) {
    final catName = json['c'] as String? ?? 'onsen';
    final cat = SpotCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => SpotCategory.onsen,
    );
    final pickIdx = json['p'] as int? ?? 2;
    final pick = (pickIdx >= 0 && pickIdx < PartnerPick.values.length)
        ? PartnerPick.values[pickIdx]
        : PartnerPick.both;

    return OutingSpot(
      id: json['i'] as String? ?? '',
      title: json['t'] as String? ?? '',
      subtitle: json['sub'] as String? ?? '夫婦の共有スポット',
      category: cat,
      tags: const [SpotTag.kids, SpotTag.food],
      driveMinutes: json['d'] as int? ?? 0,
      distanceKm: (json['km'] as num?)?.toDouble() ?? 0.0,
      scheduleText: '通年営業',
      parkingInfo: '駐車場情報あり',
      recommendPoints: const ['家族・夫婦で楽しめるおすすめスポット'],
      aiTip: '週末のドライブや立ち寄りに最適です',
      address: json['a'] as String? ?? '',
      latitude: (json['lt'] as num?)?.toDouble() ?? 38.2682,
      longitude: (json['lg'] as num?)?.toDouble() ?? 140.8694,
      isFavorite: true,
      pickedBy: pick,
      coupleNote: json['n'] as String? ?? '',
    );
  }

  /// 夫婦のお気に入りをLINEやメールで共有するためのテキストを作成
  static String exportFavoritesShareText(
      List<OutingSpot> favorites, String roomCode) {
    if (favorites.isEmpty) {
      return '【週末お出かけナビ】まだ行きたいスポットが登録されていません。\n合言葉: $roomCode';
    }

    final buffer = StringBuffer();
    buffer.writeln('💑 週末どこ行く？夫婦の行きたいスポット一覧');
    buffer.writeln('🔑 家族合言葉: $roomCode\n');

    for (var i = 0; i < favorites.length; i++) {
      final spot = favorites[i];
      final pickLabel = spot.pickedBy?.label ?? '2人とも';
      buffer.writeln('${i + 1}. ${spot.title}');
      buffer.writeln('   📍 ${spot.address}');
      buffer.writeln('   🙋 担当: $pickLabel');
      if (spot.coupleNote.isNotEmpty) {
        buffer.writeln('   💬 メモ: ${spot.coupleNote}');
      }
      buffer.writeln(
          '   🗺️ 地図: https://maps.google.com/?q=${spot.latitude},${spot.longitude}');
      buffer.writeln();
    }

    buffer.writeln('アプリの「夫婦の行きたい！」画面で合言葉「$roomCode」を入力すると同期できます！');
    return buffer.toString();
  }

  /// 最終同期日時のフォーマット文字列を取得
  static Future<String> getLastSyncLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_prefLastSyncKey);
    if (timeStr == null) return '未同期';

    final dt = DateTime.tryParse(timeStr);
    if (dt == null) return '未同期';

    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}
