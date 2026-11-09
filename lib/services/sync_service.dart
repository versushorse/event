// 夫婦間のリアルタイム共有・同期サービス（お気に入り・行ったよスタンプ・旅のしおり対応）
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_keys.local.dart';
import '../models/outing_spot.dart';

class CoupleSyncService {
  static const String _prefRoomKey = 'couple_room_code';
  static const String _prefMyRoleKey = 'couple_my_role';
  static const String _prefFavoritesKey = 'couple_favorites_json';
  static const String _prefTripsKey = 'couple_trips_json';
  static const String _prefTripsUpdatedAtKey = 'couple_trips_updated_at';
  static const String _prefLastSyncKey = 'couple_last_sync_time';
  static const String _prefLocalUpdatedAtKey = 'couple_local_updated_at';

  /// 無料KVS（設定不要のキーバリューストア）のAppKey
  static const String _fallbackKvsAppKey = '2pbg4ppa';

  /// このスマホの使用者（自分 / 夫 / 妻）を取得する（未設定ならnull）
  static Future<PartnerPick?> getMyRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(_prefMyRoleKey);
    if (roleStr == PartnerPick.me.name) return PartnerPick.me;
    if (roleStr == PartnerPick.husband.name) return PartnerPick.husband;
    if (roleStr == PartnerPick.wife.name) return PartnerPick.wife;
    return null;
  }

  /// このスマホの使用者（自分 / 夫 / 妻）を保存する
  static Future<void> saveMyRole(PartnerPick role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMyRoleKey, role.name);
  }

  /// ローカルに保存された共有合言葉を取得する（未設定なら端末固有のコードを自動生成）
  static Future<String> getRoomCode() async {
    final prefs = await SharedPreferences.getInstance();
    var code = prefs.getString(_prefRoomKey);
    if (code == null || code.trim().isEmpty) {
      // 端末ごとにユニークな個別ルームコードを自動生成（例: spot-k9x2）
      // 誰かと合言葉を共有しない限り、自分専用のプライベートリストとして完全に独立します
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final hash = (timestamp % 1679616).toRadixString(36).padLeft(4, '0');
      code = 'spot-$hash';
      await prefs.setString(_prefRoomKey, code);
    }
    return code;
  }

  /// 共有合言葉を保存する
  static Future<void> saveRoomCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRoomKey, code.trim());
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

  /// 旅のしおり一覧をローカルストレージに保存する
  static Future<void> saveLocalTrips(List<TripPlan> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = trips.map((t) => t.toJson()).toList();
    await prefs.setString(_prefTripsKey, jsonEncode(jsonList));
  }

  /// 旅のしおり一覧をローカルから読み込む（初回は大阪・名古屋家族旅行しおりを自動用意）
  static Future<List<TripPlan>> loadLocalTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefTripsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      final starter = [TripPlan.createOsakaNagoyaStarter()];
      await saveLocalTrips(starter);
      return starter;
    }
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final trips = list
          .map((item) => TripPlan.fromJson(item as Map<String, dynamic>))
          .toList();
      if (trips.isEmpty) {
        return [TripPlan.createOsakaNagoyaStarter()];
      }
      return trips;
    } catch (e) {
      debugPrint('旅のしおり読み込みエラー: $e');
      return [TripPlan.createOsakaNagoyaStarter()];
    }
  }

  /// 旅のしおりをクラウドへプッシュ（夫婦間で同期）
  static Future<void> pushTripsToCloud({
    required String roomCode,
    required List<TripPlan> trips,
  }) async {
    final sanitizedCode =
        roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTripsUpdatedAtKey, nowMs);
    await saveLocalTrips(trips);

    final payload = {
      'v': 1,
      'timestamp': nowMs,
      'trips': trips.map((t) => t.toJson()).toList(),
    };
    final jsonStr = jsonEncode(payload);

    // 1. Firebase Realtime Database に保存
    final firebaseBaseUrl = AppApiKeys.firebaseRealtimeDbUrl.trim();
    if (firebaseBaseUrl.isNotEmpty) {
      try {
        final cleanBaseUrl = firebaseBaseUrl.endsWith('/')
            ? firebaseBaseUrl.substring(0, firebaseBaseUrl.length - 1)
            : firebaseBaseUrl;
        final endpoint = Uri.parse('$cleanBaseUrl/trips/$sanitizedCode.json');
        await http
            .put(
              endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonStr,
            )
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('しおりFirebaseプッシュエラー: $e');
      }
    }

    // 2. ntfy.sh (PubSub) にも即時通知
    final cdnTopic = 'weekend_outing_trips_$sanitizedCode';
    try {
      final cdnPostUrl = Uri.parse('https://ntfy.sh/$cdnTopic');
      await http
          .post(
            cdnPostUrl,
            headers: {'Title': 'CoupleTripsSync'},
            body: jsonStr,
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('しおりCDNプッシュ注意: $e');
    }
  }

  /// 旅のしおりをクラウドからプルして最新状態を反映
  static Future<List<TripPlan>> pullTripsFromCloud({
    required String roomCode,
    required List<TripPlan> currentLocal,
  }) async {
    final sanitizedCode =
        roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return currentLocal;

    final prefs = await SharedPreferences.getInstance();
    final localUpdatedAt = prefs.getInt(_prefTripsUpdatedAtKey) ?? 0;

    int cloudTimestamp = 0;
    List<TripPlan>? cloudTrips;

    // 1. Firebase Realtime Database から最新しおりを取得
    final firebaseBaseUrl = AppApiKeys.firebaseRealtimeDbUrl.trim();
    if (firebaseBaseUrl.isNotEmpty) {
      try {
        final cleanBaseUrl = firebaseBaseUrl.endsWith('/')
            ? firebaseBaseUrl.substring(0, firebaseBaseUrl.length - 1)
            : firebaseBaseUrl;
        final endpoint = Uri.parse('$cleanBaseUrl/trips/$sanitizedCode.json');
        final res = await http.get(endpoint).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            cloudTimestamp = (decoded['timestamp'] as num?)?.toInt() ?? 0;
            final rawTrips = decoded['trips'] as List<dynamic>? ?? [];
            cloudTrips = rawTrips
                .map((item) => TripPlan.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('しおりFirebase取得エラー: $e');
      }
    }

    final cdnTopic = 'weekend_outing_trips_$sanitizedCode';
    final cdnPollUrl = Uri.parse('https://ntfy.sh/$cdnTopic/json?poll=1');
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
              final parsed = jsonDecode(msgStr);
              if (parsed is Map<String, dynamic>) {
                cloudTimestamp = (parsed['timestamp'] as num?)?.toInt() ?? 0;
                final rawTrips = parsed['trips'] as List<dynamic>? ?? [];
                cloudTrips = rawTrips
                    .map((item) =>
                        TripPlan.fromJson(item as Map<String, dynamic>))
                    .toList();
                break;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('しおりCDN取得注意: $e');
    }

    if (cloudTrips == null || cloudTrips.isEmpty) {
      // クラウドが空または12時間経過で消去された場合、ローカルにあれば自動再投入
      if (currentLocal.isNotEmpty) {
        await pushTripsToCloud(roomCode: roomCode, trips: currentLocal);
      }
      return currentLocal;
    }

    if (cloudTimestamp >= localUpdatedAt) {
      await saveLocalTrips(cloudTrips);
      await prefs.setInt(_prefTripsUpdatedAtKey, cloudTimestamp);
      return cloudTrips;
    } else {
      await pushTripsToCloud(roomCode: roomCode, trips: currentLocal);
      return currentLocal;
    }
  }

  /// 自分がハートを追加・削除・編集したときのクラウドプッシュ（上書き）
  /// 古いクラウドデータで復活させないため、現在のリストで完全にクラウドを更新する
  static Future<void> pushToCloud({
    required String roomCode,
    required List<OutingSpot> favorites,
  }) async {
    final sanitizedCode =
        roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLocalUpdatedAtKey, nowMs);
    await prefs.setString(_prefLastSyncKey, DateTime.now().toIso8601String());
    await saveLocalFavorites(favorites);

    final payload = {
      'v': 1,
      'timestamp': nowMs,
      'spots': favorites.map((s) => s.toSyncJson()).toList(),
    };
    final jsonStr = jsonEncode(payload);

    // 1. Firebaseが設定されている場合
    final firebaseBaseUrl = AppApiKeys.firebaseRealtimeDbUrl.trim();
    if (firebaseBaseUrl.isNotEmpty) {
      try {
        final cleanBaseUrl = firebaseBaseUrl.endsWith('/')
            ? firebaseBaseUrl.substring(0, firebaseBaseUrl.length - 1)
            : firebaseBaseUrl;
        final endpoint = Uri.parse('$cleanBaseUrl/rooms/$sanitizedCode.json');
        await http
            .put(
              endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonStr,
            )
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Firebaseプッシュエラー: $e');
      }
      return;
    }

    // 2. 高速CDN（ntfy.sh）へプッシュ（相手のスマホへ即座に送信）
    final cdnTopic = 'weekend_outing_couple_$sanitizedCode';
    try {
      final cdnPostUrl = Uri.parse('https://ntfy.sh/$cdnTopic');
      await http
          .post(
            cdnPostUrl,
            headers: {'Title': 'CoupleFavoritesSync'},
            body: jsonStr,
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('CDNプッシュ注意: $e');
    }

    // 3. オープンKVSへも保存（タイムアウト対策付き）
    try {
      final kvsKey = 'room_$sanitizedCode';
      final compactList =
          favorites.take(20).map((s) => _toCompactJson(s)).toList();
      final compactPayload = {
        'ts': nowMs,
        'sp': compactList,
      };
      final compactJsonStr = jsonEncode(compactPayload);
      final b64 = _encodeBase64Url(compactJsonStr);

      final updateUrl = Uri.parse(
          'https://keyvalue.immanuel.co/api/KeyVal/UpdateValue/$_fallbackKvsAppKey/$kvsKey/$b64');
      await http.post(
        updateUrl,
        headers: {'Content-Length': '0'},
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('オープンKVSプッシュ注意: $e');
    }
  }

  /// 相手の最新変更を受信（Pull）してローカルにマージ・反映する
  static Future<List<OutingSpot>?> pullFromCloud({
    required String roomCode,
    required List<OutingSpot> currentLocal,
  }) async {
    final sanitizedCode =
        roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final localUpdatedAt = prefs.getInt(_prefLocalUpdatedAtKey) ?? 0;

    int cloudTimestamp = 0;
    List<OutingSpot>? cloudSpots;

    // 1. FirebaseからPull
    final firebaseBaseUrl = AppApiKeys.firebaseRealtimeDbUrl.trim();
    if (firebaseBaseUrl.isNotEmpty) {
      try {
        final cleanBaseUrl = firebaseBaseUrl.endsWith('/')
            ? firebaseBaseUrl.substring(0, firebaseBaseUrl.length - 1)
            : firebaseBaseUrl;
        final endpoint = Uri.parse('$cleanBaseUrl/rooms/$sanitizedCode.json');
        final res =
            await http.get(endpoint).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            cloudTimestamp = (decoded['timestamp'] as num?)?.toInt() ?? 0;
            final rawSpots = decoded['spots'] as List<dynamic>? ?? [];
            cloudSpots = rawSpots
                .map((item) =>
                    OutingSpot.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (decoded is List) {
            cloudSpots = decoded
                .map((item) =>
                    OutingSpot.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Firebase取得エラー: $e');
      }
    } else {
      // 2. 高速CDN（ntfy.sh）からPull
      final cdnTopic = 'weekend_outing_couple_$sanitizedCode';
      final cdnPollUrl = Uri.parse('https://ntfy.sh/$cdnTopic/json?poll=1');
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
              if (obj['event'] == 'message') {
                String jsonBody = '';
                // 4KB超えで添付ファイル化された場合はURLから直接ダウンロード
                if (obj['attachment'] != null &&
                    obj['attachment']['url'] != null) {
                  final attachUrl = obj['attachment']['url'] as String;
                  try {
                    final attachRes = await http
                        .get(Uri.parse(attachUrl))
                        .timeout(const Duration(seconds: 4));
                    if (attachRes.statusCode == 200) {
                      jsonBody = attachRes.body;
                    }
                  } catch (_) {}
                }
                if (jsonBody.isEmpty && obj['message'] != null) {
                  jsonBody = obj['message'] as String;
                }
                if (jsonBody.isNotEmpty) {
                  try {
                    final parsed = jsonDecode(jsonBody);
                    if (parsed is Map<String, dynamic>) {
                      cloudTimestamp = (parsed['timestamp'] as num?)?.toInt() ?? 0;
                      final rawSpots = parsed['spots'] as List<dynamic>? ?? [];
                      cloudSpots = rawSpots
                          .map((item) => OutingSpot.fromJson(
                              item as Map<String, dynamic>))
                          .toList();
                      break;
                    } else if (parsed is List) {
                      cloudSpots = parsed
                          .map((item) => OutingSpot.fromJson(
                              item as Map<String, dynamic>))
                          .toList();
                      break;
                    }
                  } catch (e) {
                    debugPrint('JSONパース注意: $e');
                  }
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('CDN取得注意: $e');
      }

      // 3. オープンKVSからも確認（CDNが空だった場合や予備）
      if (cloudSpots == null) {
        try {
          final kvsKey = 'room_$sanitizedCode';
          final getUrl = Uri.parse(
              'https://keyvalue.immanuel.co/api/KeyVal/GetValue/$_fallbackKvsAppKey/$kvsKey');
          final getRes =
              await http.get(getUrl).timeout(const Duration(seconds: 8));
          if (getRes.statusCode == 200 && getRes.body.isNotEmpty) {
            final rawVal = getRes.body.trim().replaceAll('"', '');
            if (rawVal.isNotEmpty && rawVal != 'null') {
              try {
                final jsonStr = _decodeBase64Url(rawVal);
                final decoded = jsonDecode(jsonStr);
                if (decoded is Map<String, dynamic>) {
                  cloudTimestamp = (decoded['ts'] as num?)?.toInt() ?? 0;
                  final rawList = decoded['sp'] as List<dynamic>? ?? [];
                  cloudSpots = rawList
                      .map((item) =>
                          _fromCompactJson(item as Map<String, dynamic>))
                      .toList();
                } else if (decoded is List) {
                  cloudSpots = decoded
                      .map((item) =>
                          _fromCompactJson(item as Map<String, dynamic>))
                      .toList();
                }
              } catch (e) {
                debugPrint('オープンKVSデコードエラー: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('オープンKVS取得注意: $e');
        }
      }
    }

    if (cloudSpots == null || cloudSpots.isEmpty) {
      // クラウドにまだ何もない、または12時間経過で一時消去された場合:
      // ローカルにお気に入りがあれば自動で再プッシュしてクラウドを復活させる！
      if (currentLocal.isNotEmpty) {
        await pushToCloud(roomCode: roomCode, favorites: currentLocal);
      }
      return currentLocal;
    }

    // タイムスタンプ判定:
    // クラウドのほうが新しい、または同等の場合はクラウドの内容を採用（削除も反映される！）
    // ローカルのほうが新しい場合はローカルを優先し、クラウドへ押し戻す
    if (cloudTimestamp >= localUpdatedAt) {
      await saveLocalFavorites(cloudSpots);
      await prefs.setInt(_prefLocalUpdatedAtKey, cloudTimestamp);
      await prefs.setString(
          _prefLastSyncKey, DateTime.now().toIso8601String());
      return cloudSpots;
    } else {
      // ローカルのほうが新しい操作をした状態なので、クラウドへプッシュ
      await pushToCloud(roomCode: roomCode, favorites: currentLocal);
      return currentLocal;
    }
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
      'v': spot.isVisited ? 1 : 0,
      'vd': spot.visitedDate,
      'vr': spot.visitedRating,
      'vm': spot.visitedMemory,
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
      isVisited: (json['v'] as int? ?? 0) == 1,
      visitedDate: json['vd'] as String? ?? '',
      visitedRating: (json['vr'] as int?) ?? 5,
      visitedMemory: json['vm'] as String? ?? '',
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
      final visitedBadge = spot.isVisited ? ' 💮[行ったよ！]' : '';
      buffer.writeln('${i + 1}. ${spot.title}$visitedBadge');
      buffer.writeln('   📍 ${spot.address}');
      buffer.writeln('   🙋 担当: $pickLabel');
      if (spot.coupleNote.isNotEmpty) {
        buffer.writeln('   💬 メモ: ${spot.coupleNote}');
      }
      if (spot.isVisited && spot.visitedMemory.isNotEmpty) {
        buffer.writeln(
            '   💮 思い出(${spot.visitedDate} ★${spot.visitedRating}): ${spot.visitedMemory}');
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
