// 夫婦間・パートナー間のリアルタイム共有・同期サービス（お気に入り・行ったよスタンプ・旅のしおり対応）
// ※スポット単位の和集合マージ＋明示的削除記録（Tombstone）方式により、同時・非同期操作でも相手や自分のお気に入りが上書き消滅しない設計
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_keys.local.dart';
import '../models/outing_spot.dart';

class _CloudRoomSnapshot {
  final int timestamp;
  final List<OutingSpot> spots;
  final Map<String, int> updatedMap;
  final Map<String, int> deletedMap;

  const _CloudRoomSnapshot({
    required this.timestamp,
    required this.spots,
    this.updatedMap = const {},
    this.deletedMap = const {},
  });
}

class _MergedFavoritesResult {
  final List<OutingSpot> spots;
  final Map<String, int> updatedMap;
  final Map<String, int> deletedMap;
  final bool cloudNeedsRepairPush;

  const _MergedFavoritesResult({
    required this.spots,
    required this.updatedMap,
    required this.deletedMap,
    required this.cloudNeedsRepairPush,
  });
}

class CoupleSyncService {
  static const String _prefRoomKey = 'couple_room_code';
  static const String _prefMyRoleKey = 'couple_my_role';
  static const String _prefFavoritesKey = 'couple_favorites_json';
  static const String _prefSpotUpdatedMapKey = 'couple_spot_updated_map';
  static const String _prefSpotDeletedMapKey = 'couple_spot_deleted_map';
  static const String _prefTripsKey = 'couple_trips_json';
  static const String _prefTripsUpdatedAtKey = 'couple_trips_updated_at';
  static const String _prefLastSyncKey = 'couple_last_sync_time';
  static const String _prefLocalUpdatedAtKey = 'couple_local_updated_at';

  /// このスマホの使用者（夫 / 妻 / 自分）を取得する（未設定ならnull）
  static Future<PartnerPick?> getMyRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(_prefMyRoleKey);
    if (roleStr == PartnerPick.husband.name) return PartnerPick.husband;
    if (roleStr == PartnerPick.wife.name) return PartnerPick.wife;
    if (roleStr == PartnerPick.me.name) return PartnerPick.me;
    return null;
  }

  /// このスマホの使用者（夫 / 妻 / 自分）を保存する
  static Future<void> saveMyRole(PartnerPick role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMyRoleKey, role.name);
  }

  /// ローカルに保存された共有合言葉を取得する（未設定・旧共通デフォルト時は空文字を返す）
  static Future<String> getRoomCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefRoomKey)?.trim() ?? '';
    if (code.isEmpty || code == 'family-weekend') {
      return '';
    }
    return code;
  }

  /// 商用版向け：推測困難なペア専用合言葉（例: pair-a7k3-m9p2）を自動発行する
  static String generateRandomRoomCode() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rand = math.Random.secure();
    String chunk() =>
        List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'pair-${chunk()}-${chunk()}';
  }

  /// 共有合言葉を保存する
  static Future<void> saveRoomCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRoomKey, code.trim());
  }

  /// スポットの追加・更新時刻をローカルログに記録（削除ログからは除外）
  static Future<void> recordSpotChange(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final updated = _loadTimestampMap(prefs, _prefSpotUpdatedMapKey);
    final deleted = _loadTimestampMap(prefs, _prefSpotDeletedMapKey);
    updated[spotId] = nowMs;
    deleted.remove(spotId);
    await _saveTimestampMap(prefs, _prefSpotUpdatedMapKey, updated);
    await _saveTimestampMap(prefs, _prefSpotDeletedMapKey, deleted);
  }

  /// スポットの意図的な削除時刻をローカルログに記録
  static Future<void> recordSpotDeletion(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final updated = _loadTimestampMap(prefs, _prefSpotUpdatedMapKey);
    final deleted = _loadTimestampMap(prefs, _prefSpotDeletedMapKey);
    deleted[spotId] = nowMs;
    updated.remove(spotId);
    await _saveTimestampMap(prefs, _prefSpotUpdatedMapKey, updated);
    await _saveTimestampMap(prefs, _prefSpotDeletedMapKey, deleted);
  }

  static Map<String, int> _loadTimestampMap(
      SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
        );
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveTimestampMap(
    SharedPreferences prefs,
    String key,
    Map<String, int> map,
  ) async {
    //肥大化防止のため最新300件のみ保持
    if (map.length > 300) {
      final entries = map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final trimmed = Map<String, int>.fromEntries(entries.take(300));
      await prefs.setString(key, jsonEncode(trimmed));
      return;
    }
    await prefs.setString(key, jsonEncode(map));
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

  /// 旅のしおり一覧をローカルから読み込む（初期状態は空リスト）
  static Future<List<TripPlan>> loadLocalTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefTripsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => TripPlan.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('旅のしおり読み込みエラー: $e');
      return [];
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
  }

  /// 旅のしおりをクラウドからプルして最新状態を反映（ID単位で安全マージ）
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

    final firebaseBaseUrl = AppApiKeys.firebaseRealtimeDbUrl.trim();
    if (firebaseBaseUrl.isNotEmpty) {
      try {
        final cleanBaseUrl = firebaseBaseUrl.endsWith('/')
            ? firebaseBaseUrl.substring(0, firebaseBaseUrl.length - 1)
            : firebaseBaseUrl;
        final endpoint = Uri.parse('$cleanBaseUrl/trips/$sanitizedCode.json');
        final res =
            await http.get(endpoint).timeout(const Duration(seconds: 8));
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

    if (cloudTrips == null || cloudTrips.isEmpty) {
      if (currentLocal.isNotEmpty) {
        await pushTripsToCloud(roomCode: roomCode, trips: currentLocal);
      }
      return currentLocal;
    }

    // しおりIDごとにマージ（新しい updatedAtMs の方を採用し、片方にしかないしおりも保持）
    final mergedMap = <String, TripPlan>{};
    for (final t in currentLocal) {
      mergedMap[t.id] = t;
    }
    for (final c in cloudTrips) {
      final existing = mergedMap[c.id];
      if (existing == null || c.updatedAtMs >= existing.updatedAtMs) {
        mergedMap[c.id] = c;
      }
    }
    final mergedList = mergedMap.values.toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

    await saveLocalTrips(mergedList);
    if (cloudTimestamp > localUpdatedAt) {
      await prefs.setInt(_prefTripsUpdatedAtKey, cloudTimestamp);
    }
    if (mergedList.length > cloudTrips.length ||
        localUpdatedAt > cloudTimestamp) {
      await pushTripsToCloud(roomCode: roomCode, trips: mergedList);
    }
    return mergedList;
  }

  /// 自分がハートを追加・削除・編集したときのクラウドプッシュ
  /// 送信前にクラウド最新データを読み取り、マージ（和集合）してから書き戻すことで相手の候補を上書き消滅させない
  static Future<List<OutingSpot>> pushToCloud({
    required String roomCode,
    required List<OutingSpot> favorites,
  }) async {
    final sanitizedCode =
        roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return favorites;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();

    // ローカル状態をまず確定保存
    await prefs.setInt(_prefLocalUpdatedAtKey, nowMs);
    await prefs.setString(_prefLastSyncKey, DateTime.now().toIso8601String());
    await saveLocalFavorites(favorites);

    final localUpdated = _loadTimestampMap(prefs, _prefSpotUpdatedMapKey);
    final localDeleted = _loadTimestampMap(prefs, _prefSpotDeletedMapKey);
    // ローカルにあるスポットでタイムスタンプ未登録のものがあれば記録しておく
    bool updatedMapChanged = false;
    for (final s in favorites) {
      if (!localUpdated.containsKey(s.id)) {
        localUpdated[s.id] = nowMs;
        updatedMapChanged = true;
      }
      if (localDeleted.containsKey(s.id)) {
        localDeleted.remove(s.id);
        updatedMapChanged = true;
      }
    }
    if (updatedMapChanged) {
      await _saveTimestampMap(prefs, _prefSpotUpdatedMapKey, localUpdated);
      await _saveTimestampMap(prefs, _prefSpotDeletedMapKey, localDeleted);
    }

    // Read-Modify-Write: クラウド上の最新データを取り込んで安全マージしてからアップロード
    final cloud = await _fetchCloudSnapshot(sanitizedCode);
    var mergedSpots = favorites;
    var mergedUpdated = Map<String, int>.from(localUpdated);
    var mergedDeleted = Map<String, int>.from(localDeleted);

    if (cloud != null) {
      final merged = _mergeCoupleData(
        localSpots: favorites,
        localUpdated: localUpdated,
        localDeleted: localDeleted,
        cloud: cloud,
      );
      mergedSpots = merged.spots;
      mergedUpdated = merged.updatedMap;
      mergedDeleted = merged.deletedMap;

      await saveLocalFavorites(mergedSpots);
      await _saveTimestampMap(prefs, _prefSpotUpdatedMapKey, mergedUpdated);
      await _saveTimestampMap(prefs, _prefSpotDeletedMapKey, mergedDeleted);
    }

    await _uploadCloudSnapshot(
      sanitizedCode: sanitizedCode,
      nowMs: nowMs,
      spots: mergedSpots,
      updatedMap: mergedUpdated,
      deletedMap: mergedDeleted,
    );

    return mergedSpots;
  }

  /// 相手の最新変更を受信（Pull）してローカルと安全マージ・反映する
  static Future<List<OutingSpot>?> pullFromCloud({
    required String roomCode,
    required List<OutingSpot> currentLocal,
  }) async {
    final sanitizedCode =
        roomCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedCode.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final localUpdated = _loadTimestampMap(prefs, _prefSpotUpdatedMapKey);
    final localDeleted = _loadTimestampMap(prefs, _prefSpotDeletedMapKey);

    final cloud = await _fetchCloudSnapshot(sanitizedCode);
    if (cloud == null ||
        (cloud.spots.isEmpty && cloud.deletedMap.isEmpty)) {
      if (currentLocal.isNotEmpty) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await _uploadCloudSnapshot(
          sanitizedCode: sanitizedCode,
          nowMs: nowMs,
          spots: currentLocal,
          updatedMap: localUpdated,
          deletedMap: localDeleted,
        );
      }
      return currentLocal;
    }

    final merged = _mergeCoupleData(
      localSpots: currentLocal,
      localUpdated: localUpdated,
      localDeleted: localDeleted,
      cloud: cloud,
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await saveLocalFavorites(merged.spots);
    await _saveTimestampMap(prefs, _prefSpotUpdatedMapKey, merged.updatedMap);
    await _saveTimestampMap(prefs, _prefSpotDeletedMapKey, merged.deletedMap);
    await prefs.setInt(_prefLocalUpdatedAtKey,
        math.max(nowMs, cloud.timestamp));
    await prefs.setString(_prefLastSyncKey, DateTime.now().toIso8601String());

    // ローカルにしかない新規スポットや、相手の古い配列から保護されたスポットがあった場合、クラウドにも修復反映
    if (merged.cloudNeedsRepairPush) {
      await _uploadCloudSnapshot(
        sanitizedCode: sanitizedCode,
        nowMs: nowMs,
        spots: merged.spots,
        updatedMap: merged.updatedMap,
        deletedMap: merged.deletedMap,
      );
    }

    return merged.spots;
  }

  /// テスト用：夫婦のお気に入り安全マージロジックを直接検証する
  @visibleForTesting
  static List<OutingSpot> mergeSpotsForTesting({
    required List<OutingSpot> localSpots,
    Map<String, int> localUpdated = const {},
    Map<String, int> localDeleted = const {},
    required List<OutingSpot> cloudSpots,
    int cloudTimestamp = 0,
    Map<String, int> cloudUpdated = const {},
    Map<String, int> cloudDeleted = const {},
  }) {
    return _mergeCoupleData(
      localSpots: localSpots,
      localUpdated: localUpdated,
      localDeleted: localDeleted,
      cloud: _CloudRoomSnapshot(
        timestamp: cloudTimestamp,
        spots: cloudSpots,
        updatedMap: cloudUpdated,
        deletedMap: cloudDeleted,
      ),
    ).spots;
  }

  /// ローカルとクラウドのお気に入りを安全にマージ（和集合＋削除記録尊重＋夫婦の「2人とも！」自動統合）
  static _MergedFavoritesResult _mergeCoupleData({
    required List<OutingSpot> localSpots,
    required Map<String, int> localUpdated,
    required Map<String, int> localDeleted,
    required _CloudRoomSnapshot cloud,
  }) {
    final mergedDeleted = <String, int>{...localDeleted};
    cloud.deletedMap.forEach((id, ts) {
      final cur = mergedDeleted[id] ?? 0;
      if (ts > cur) mergedDeleted[id] = ts;
    });

    final localMap = <String, OutingSpot>{for (final s in localSpots) s.id: s};
    final cloudMap = <String, OutingSpot>{for (final s in cloud.spots) s.id: s};
    final allIds = <String>{...localMap.keys, ...cloudMap.keys};

    final mergedSpots = <OutingSpot>[];
    final mergedUpdated = <String, int>{};
    bool cloudNeedsRepair = false;

    for (final id in allIds) {
      final l = localMap[id];
      final c = cloudMap[id];
      final lTime = localUpdated[id] ?? 0;
      final cTime = cloud.updatedMap[id] ?? cloud.timestamp;
      final delTime = mergedDeleted[id] ?? 0;

      if (l != null && c != null) {
        final latestActive = math.max(lTime, cTime);
        if (delTime > latestActive) {
          // より新しい明示的な削除記録がある
          if (cloud.deletedMap[id] == null || cloud.deletedMap[id]! < delTime) {
            cloudNeedsRepair = true;
          }
          continue;
        }
        // 両方に存在：賢くマージ
        final mergedSpot = _mergeTwoSpots(l, c, lTime, cTime);
        mergedSpots.add(mergedSpot);
        mergedUpdated[id] = latestActive;
        // mergedされた状態（例えばbothへ自動昇格した等）がクラウドと違っていれば修復プッシュ
        if (mergedSpot.pickedBy != c.pickedBy ||
            mergedSpot.isVisited != c.isVisited ||
            mergedSpot.coupleNote != c.coupleNote ||
            mergedSpot.visitedPhotos.length != c.visitedPhotos.length) {
          cloudNeedsRepair = true;
        }
      } else if (l != null && c == null) {
        // ローカルにのみある（相手が明示的に削除していた場合のみ消す。旧端末の全上書き等で欠落しただけなら救済維持！）
        final cloudDelTime = cloud.deletedMap[id] ?? 0;
        if (cloudDelTime > lTime) {
          continue;
        }
        mergedSpots.add(l);
        mergedUpdated[id] = lTime;
        cloudNeedsRepair = true;
      } else if (l == null && c != null) {
        // クラウドにのみある（自分が明示的に削除していた場合のみ取り込まない）
        final localDelTime = localDeleted[id] ?? 0;
        if (localDelTime > cTime) {
          cloudNeedsRepair = true;
          continue;
        }
        mergedSpots.add(c);
        mergedUpdated[id] = cTime;
      }
    }

    // 削除ログ側で復活（再登録）されたものは削除ログから除去
    for (final s in mergedSpots) {
      mergedDeleted.remove(s.id);
    }

    return _MergedFavoritesResult(
      spots: mergedSpots,
      updatedMap: mergedUpdated,
      deletedMap: mergedDeleted,
      cloudNeedsRepairPush: cloudNeedsRepair,
    );
  }

  /// 同一スポットの夫婦データ競合を解決（夫＋妻の衝突は自動で「2人とも行きたい！」に昇格）
  static OutingSpot _mergeTwoSpots(
    OutingSpot local,
    OutingSpot cloud,
    int lTime,
    int cTime,
  ) {
    final preferCloud = cTime > lTime;
    final base = preferCloud ? cloud : local;
    final other = preferCloud ? local : cloud;

    PartnerPick? mergedPick = base.pickedBy ?? other.pickedBy;
    if ((local.pickedBy == PartnerPick.husband &&
            cloud.pickedBy == PartnerPick.wife) ||
        (local.pickedBy == PartnerPick.wife &&
            cloud.pickedBy == PartnerPick.husband)) {
      mergedPick = PartnerPick.both;
    } else if (local.pickedBy == PartnerPick.both ||
        cloud.pickedBy == PartnerPick.both) {
      mergedPick = PartnerPick.both;
    }

    final mergedNote = base.coupleNote.trim().isNotEmpty
        ? base.coupleNote
        : other.coupleNote;

    final mergedVisited = local.isVisited || cloud.isVisited;
    String mergedVisitedDate = base.visitedDate;
    int mergedVisitedRating = base.visitedRating;
    String mergedVisitedMemory = base.visitedMemory;
    if (!base.isVisited && other.isVisited) {
      mergedVisitedDate = other.visitedDate;
      mergedVisitedRating = other.visitedRating;
      mergedVisitedMemory = other.visitedMemory;
    } else if (base.isVisited &&
        other.isVisited &&
        base.visitedMemory.trim().isEmpty &&
        other.visitedMemory.trim().isNotEmpty) {
      mergedVisitedMemory = other.visitedMemory;
    }

    // 思い出写真：より新しい編集側(base)を優先し、旧バージョン由来の欠落等のみ補完保持する
    final List<String> mergedPhotos;
    if (base.visitedPhotos.isNotEmpty) {
      mergedPhotos = base.visitedPhotos;
    } else if (other.visitedPhotos.isNotEmpty &&
        (preferCloud || !base.isVisited)) {
      mergedPhotos = other.visitedPhotos;
    } else {
      mergedPhotos = base.visitedPhotos;
    }

    return base.copyWith(
      isFavorite: true,
      pickedBy: mergedPick,
      coupleNote: mergedNote,
      isVisited: mergedVisited,
      visitedDate: mergedVisitedDate,
      visitedRating: mergedVisitedRating,
      visitedMemory: mergedVisitedMemory,
      visitedPhotos: mergedPhotos,
    );
  }

  /// クラウド（Firebase）から最新スナップショットを取得
  static Future<_CloudRoomSnapshot?> _fetchCloudSnapshot(
      String sanitizedCode) async {
    _CloudRoomSnapshot? parseDecoded(dynamic decoded) {
      if (decoded is Map<String, dynamic>) {
        final ts = (decoded['timestamp'] as num?)?.toInt() ?? 0;
        final rawSpots = decoded['spots'] as List<dynamic>? ?? [];
        final spots = rawSpots
            .map((item) => OutingSpot.fromJson(item as Map<String, dynamic>))
            .toList();
        final upd = <String, int>{};
        if (decoded['updated'] is Map<String, dynamic>) {
          (decoded['updated'] as Map<String, dynamic>).forEach((k, v) {
            upd[k] = (v as num?)?.toInt() ?? 0;
          });
        }
        final del = <String, int>{};
        if (decoded['deleted'] is Map<String, dynamic>) {
          (decoded['deleted'] as Map<String, dynamic>).forEach((k, v) {
            del[k] = (v as num?)?.toInt() ?? 0;
          });
        }
        return _CloudRoomSnapshot(
          timestamp: ts,
          spots: spots,
          updatedMap: upd,
          deletedMap: del,
        );
      } else if (decoded is List) {
        final spots = decoded
            .map((item) => OutingSpot.fromJson(item as Map<String, dynamic>))
            .toList();
        return _CloudRoomSnapshot(timestamp: 0, spots: spots);
      }
      return null;
    }

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
          return parseDecoded(jsonDecode(res.body));
        }
      } catch (e) {
        debugPrint('Firebase取得エラー: $e');
      }
    }
    return null;
  }

  /// クラウド（Firebase）へ最新スナップショットをアップロード
  static Future<void> _uploadCloudSnapshot({
    required String sanitizedCode,
    required int nowMs,
    required List<OutingSpot> spots,
    required Map<String, int> updatedMap,
    required Map<String, int> deletedMap,
  }) async {
    final firebaseBaseUrl = AppApiKeys.firebaseRealtimeDbUrl.trim();
    if (firebaseBaseUrl.isEmpty) return;

    final payload = {
      'v': 2,
      'timestamp': nowMs,
      'spots': spots.map((s) => s.toSyncJson()).toList(),
      if (updatedMap.isNotEmpty) 'updated': updatedMap,
      if (deletedMap.isNotEmpty) 'deleted': deletedMap,
    };
    final jsonStr = jsonEncode(payload);

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
  }

  /// 夫婦・パートナーのお気に入りをLINEやメールで共有するためのテキストを作成
  static String exportFavoritesShareText(
      List<OutingSpot> favorites, String roomCode) {
    if (favorites.isEmpty) {
      return '【おでかけナビ】まだ行きたいスポットが登録されていません。\n合言葉: $roomCode';
    }

    final buffer = StringBuffer();
    buffer.writeln('💑 おでかけナビ 夫婦の行きたいスポット一覧');
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
      if (spot.isVisited && spot.visitedPhotos.isNotEmpty) {
        buffer.writeln('   📸 思い出写真: ${spot.visitedPhotos.length}枚');
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
