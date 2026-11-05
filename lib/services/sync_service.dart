// 夫婦間のリアルタイム共有・同期サービス
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outing_spot.dart';

class CoupleSyncService {
  static const String _prefRoomKey = 'couple_room_code';
  static const String _prefFavoritesKey = 'couple_favorites_json';
  static const String _prefLastSyncKey = 'couple_last_sync_time';

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
  /// 無料・設定不要のキーバリューストレージエンドポイントを利用し、2人のスマホ間でマージ
  static Future<List<OutingSpot>?> syncWithCloud({
    required String roomCode,
    required List<OutingSpot> localFavorites,
  }) async {
    final sanitizedCode = roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return null;

    final url = Uri.parse('https://kvdb.io/4y9q4u8YvP47kY3zKkX6bV/room_$sanitizedCode');

    try {
      // 1. クラウド側の最新データを取得
      final getRes = await http.get(url).timeout(const Duration(seconds: 4));
      List<OutingSpot> cloudList = [];
      if (getRes.statusCode == 200 && getRes.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(getRes.body) as List<dynamic>;
          cloudList = decoded
              .map((item) => OutingSpot.fromJson(item as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }

      // 2. ローカルとクラウドのデータをマージ（ID単位で統合）
      final mergedMap = <String, OutingSpot>{};
      for (final spot in cloudList) {
        mergedMap[spot.id] = spot;
      }
      for (final spot in localFavorites) {
        // ローカルでの最新編集を優先マージ
        mergedMap[spot.id] = spot;
      }

      final mergedList = mergedMap.values.toList();

      // 3. マージ結果をクラウドに保存（妻/夫のスマホにも即座に届くようにする）
      final postBody = jsonEncode(mergedList.map((s) => s.toJson()).toList());
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: postBody,
      ).timeout(const Duration(seconds: 4));

      // ローカルにも保存
      await saveLocalFavorites(mergedList);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastSyncKey, DateTime.now().toIso8601String());

      return mergedList;
    } catch (e) {
      debugPrint('クラウド同期エラー（ローカル保存のみ適用）: $e');
      return null;
    }
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
