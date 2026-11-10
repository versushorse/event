// ホーム画面（東北6県タブ・期間指定イベント検索・Google Maps周辺立ち寄り検索・天気予報連携・夫婦リアルタイム同期・GPS連携）
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_keys.local.dart';
import '../models/outing_spot.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../services/weather_service.dart';
import '../widgets/safe_chips.dart';
import 'dart:math';
import 'favorites_screen.dart';
import 'trip_planner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 全スポットデータ
  late List<OutingSpot> _allSpots;

  /// 現在のボトムナビタブ番号（0: 探す, 1: ドライブ地図, 2: 夫婦の行きたい）
  int _currentTabIndex = 0;

  /// 雨の日・寒い日安心モード（案B：天候連動スイッチ）
  bool _isRainOrColdMode = false;

  /// 家族の旅のしおり一覧（案A：大阪・名古屋旅行＆週末ドライブ）
  List<TripPlan> _tripPlans = [TripPlan.createOsakaNagoyaStarter()];
  int _selectedTripIndex = 0;

  /// 出発エリア名
  String _departureArea = '現在地を取得中...';

  /// 現在地の位置情報（GPS）
  LocationResult? _currentLocation;

  /// 現在地取得中フラグ
  bool _isLocating = false;

  /// 選択中の東北地域タブ（デフォルト：宮城県）
  TohokuRegion _selectedRegion = TohokuRegion.miyagi;

  /// 選択中地域の週末天気予報
  AreaWeatherSummary? _currentRegionWeather;

  /// イベント検索の対象期間（デフォルト：直近の週末 土曜〜日曜）
  late DateTimeRange _targetDateRange;

  /// 期間選択の状態ラベル（'直近の週末', '来週末', '期間指定'）
  String _dateRangePresetLabel = '直近の週末';

  /// 選択中の種別フィルタ
  SpotCategory? _selectedCategory;

  /// 選択中のタイプタグフィルタ
  SpotTag? _selectedTag;

  /// AI検索バーの入力コントローラ
  final TextEditingController _searchController = TextEditingController();

  /// ドライブ地図タブ内の検索バー入力コントローラ
  final TextEditingController _mapSearchController = TextEditingController();

  /// ドライブ地図下部のスポット一覧スクロールコントローラ
  final ScrollController _mapSpotListScrollController = ScrollController();

  /// メイン探索タブ（AI提案・検索）のスクロールコントローラ
  final ScrollController _exploreScrollController = ScrollController();

  /// トップに戻るボタンの表示フラグ
  bool _showBackToTop = false;

  /// ドライブ地図下部のスポット一覧カードの表示・非表示フラグ
  bool _isMapListExpanded = true;

  /// AI検索中フラグ
  bool _isSearchingAi = false;

  /// AIからの要約コメント
  String _aiSummaryComment = '';

  /// 夫婦の好み分析AI（Gemini 3.5 Flash-Lite）のインサイト
  CouplePreferenceAiInsight? _coupleAiInsight;
  bool _isLoadingAiInsight = false;

  /// マップ画面で選択中のスポット
  OutingSpot? _selectedMapSpot;

  /// 「この周辺で立ち寄り先を探す」の基準となっているスポット（イベント会場など）
  OutingSpot? _anchorSpot;

  /// ドライブ地図の現在のカメラ中心座標
  LatLng _mapCenterLatLng = LatLng(
    TohokuRegion.miyagi.centerLat,
    TohokuRegion.miyagi.centerLng,
  );

  /// ドライブ地図上で選択中の周辺検索カテゴリ
  SpotCategory? _mapAreaCategory;

  /// 夫婦共有ルームの合言葉
  String _coupleRoomCode = 'family-weekend';

  /// このスマホの使用者（Web版はme、Android版は夫 or 妻）
  PartnerPick _myRole = kIsWeb ? PartnerPick.me : PartnerPick.husband;
  bool _hasSelectedMyRole = kIsWeb;

  /// 夫婦同期のステータス文字列
  String _syncStatusLabel = '確認中...';

  /// Googleマップコントローラ
  GoogleMapController? _mapController;

  /// Googleマップの表示タイプ（通常 or 航空写真）
  MapType _currentMapType = MapType.normal;

  /// マップカメラを初期現在地に移動完了したかどうかのフラグ
  bool _hasMovedMapToUserLocation = false;

  /// 初回起動時の自動取得完了フラグ
  bool _hasAutoFetchedSpots = false;

  /// ドライブ持ち物チェックリストの状態
  final Map<String, bool> _packingList = {
    'エコバッグ・保冷バッグ（マルシェ・道の駅用）': true,
    'お風呂・温泉セット（タオル・着替え）': true,
    'ボール・バドミントン・外遊び道具': true,
    '子どもの着替え・動きやすい靴': true,
    '水筒・飲み物・おやつ': true,
    '汗拭きタオル・ウェットティッシュ': true,
    'モバイルバッテリー・充電ケーブル': true,
    '羽織る上着・レジャーシート': false,
  };

  @override
  void initState() {
    super.initState();
    _targetDateRange = GeminiOutingService.getUpcomingWeekendRange();
    _allSpots = GeminiOutingService.getInitialSpots();
    _selectedMapSpot = _allSpots.first;
    final dateText = GeminiOutingService.formatDateRange(_targetDateRange);
    _aiSummaryComment =
        '🎪 【${_selectedRegion.label}】直近の週末（$dateText）開催イベントや、定番お出かけスポットを表示しています！';
    _initCoupleSync();

    // スクロール位置を監視して「トップに戻るボタン」の表示/非表示を切り替え
    _exploreScrollController.addListener(() {
      final show = _exploreScrollController.hasClients &&
          _exploreScrollController.offset > 300;
      if (show != _showBackToTop && mounted) {
        setState(() => _showBackToTop = show);
      }
    });

    // 地域の週末天気を取得
    _fetchRegionWeather(_selectedRegion);

    // 1. 端末の直近キャッシュ位置（Last Known Location）を即座に反映
    LocationService.getLastKnownLocation().then((cachedLoc) {
      if (cachedLoc != null && mounted && _currentLocation == null) {
        setState(() {
          _currentLocation = cachedLoc;
          _departureArea = cachedLoc.label;
          _mapCenterLatLng = LatLng(cachedLoc.latitude, cachedLoc.longitude);
          _recalculateSpotDistances(cachedLoc.latitude, cachedLoc.longitude);
        });
        _autoFetchInitialSpotsOnce(cachedLoc);
      }
    });

    // 2. 続けて最新の高精度GPSを取得
    _fetchCurrentLocation(autoFetch: true, moveMap: false).then((_) {
      if (_currentLocation != null) {
        _autoFetchInitialSpotsOnce(_currentLocation!);
      } else {
        _autoFetchInitialSpotsOnce(null);
      }
    });
  }

  /// 選択地域の週末天気を取得
  Future<void> _fetchRegionWeather(TohokuRegion region, [DateTimeRange? dateRange]) async {
    final range = dateRange ?? _targetDateRange;
    final weather = await WeatherService.fetchWeekendWeather(
      lat: region.centerLat,
      lng: region.centerLng,
      areaName: region.label,
      targetSaturday: range.start,
    );
    if (!mounted) return;
    setState(() {
      _currentRegionWeather = weather;
    });
  }

  /// 初回起動時に選択地域（宮城県）の直近週末イベント＆代表スポットを自動取得
  Future<void> _autoFetchInitialSpotsOnce(LocationResult? loc) async {
    if (_hasAutoFetchedSpots) return;
    _hasAutoFetchedSpots = true;

    final result = await GeminiOutingService.searchWithAi(
      query: '',
      departureArea: loc?.label ?? _departureArea,
      currentSpots: _allSpots,
      userLat: loc?.latitude,
      userLng: loc?.longitude,
      selectedRegion: _selectedRegion,
      targetDateRange: _targetDateRange,
      targetCategory: null,
    );
    if (!mounted) return;
    if (result.spots.isNotEmpty) {
      setState(() {
        final favMap = {for (final f in _favoriteSpots) f.id: f};
        _allSpots = result.spots.map((s) {
          if (favMap.containsKey(s.id)) {
            final fav = favMap[s.id]!;
            return s.copyWith(
              isFavorite: true,
              pickedBy: fav.pickedBy,
              coupleNote: fav.coupleNote,
            );
          }
          return s;
        }).toList();
        for (final fav in favMap.values) {
          if (!_allSpots.any((s) => s.id == fav.id)) {
            _allSpots.add(fav);
          }
        }
        _aiSummaryComment = result.aiSummaryComment;
        if (_filteredSpots.isNotEmpty) {
          _selectedMapSpot = _filteredSpots.first;
        }
      });
      _fetchCoupleAiInsight();
    }
  }

  /// GPS現在地を取得し、各スポットまでの距離・所要時間を自動再計算
  Future<void> _fetchCurrentLocation({
    bool autoFetch = false,
    bool moveMap = false,
  }) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    final loc = await LocationService.getCurrentLocation();
    if (!mounted) return;

    if (loc != null) {
      setState(() {
        _isLocating = false;
        _currentLocation = loc;
        _departureArea = loc.label;
        _recalculateSpotDistances(loc.latitude, loc.longitude);
      });

      final shouldMoveMap = moveMap || !_hasMovedMapToUserLocation;
      if (shouldMoveMap && _mapController != null) {
        _hasMovedMapToUserLocation = true;
        _mapCenterLatLng = LatLng(loc.latitude, loc.longitude);
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(loc.latitude, loc.longitude),
              zoom: 12.0,
            ),
          ),
        );
      }

      if (!autoFetch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 現在地（${loc.label}）を取得しました！距離・所要時間を更新しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _isLocating = false;
        if (_departureArea == '現在地を取得中...') {
          _departureArea = '宮城・仙台エリア';
        }
      });

      if (!autoFetch) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ 現在地を取得できませんでした。端末の位置情報（GPS）をONにしてください'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 現在地からの実距離（km）とおおよそのドライブ所要時間をスポットに反映
  void _recalculateSpotDistances(double userLat, double userLng) {
    _allSpots = _allSpots.map<OutingSpot>((spot) {
      final distKm = LocationService.calculateDistanceKm(
        startLat: userLat,
        startLng: userLng,
        endLat: spot.latitude,
        endLng: spot.longitude,
      );
      final driveMin = LocationService.estimateDriveMinutes(distKm);

      return spot.copyWith(
        driveMinutes: driveMin,
        distanceKm: distKm,
      );
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapSearchController.dispose();
    _mapSpotListScrollController.dispose();
    _exploreScrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// 夫婦間のローカル保存およびクラウド同期の初期化
  Future<void> _initCoupleSync() async {
    final code = await CoupleSyncService.getRoomCode();
    final savedRole = await CoupleSyncService.getMyRole();
    var savedFavs = await CoupleSyncService.loadLocalFavorites();
    final savedTrips = await CoupleSyncService.loadLocalTrips();
    if (mounted) {
      setState(() {
        _tripPlans = savedTrips;
        if (kIsWeb) {
          _myRole = PartnerPick.me;
          _hasSelectedMyRole = true;
        } else if (savedRole != null && savedRole != PartnerPick.me) {
          _myRole = savedRole;
          _hasSelectedMyRole = true;
        }
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final hasClearedDefault = prefs.getBool('cleared_default_favs_v3') ?? false;
    if (!hasClearedDefault) {
      await prefs.setBool('cleared_default_favs_v3', true);
      final isOnlyDummy = savedFavs.every((s) =>
          s.id == 'event_jogi_stamprally_2026' ||
          s.id == 'event_pokemon_kogei_2026' ||
          s.id == 'gourmet_more_tohoku_marche' ||
          s.id == 'autumn_harvest_marche_2026' ||
          s.id == 'lake_park_dino_2026' ||
          s.id == 'science_museum_tokubetsu');
      if (isOnlyDummy) {
        await CoupleSyncService.saveLocalFavorites([]);
        savedFavs = [];
      }
    }

    setState(() {
      _coupleRoomCode = code;
      if (savedFavs.isNotEmpty) {
        _applySyncedFavoritesToSpots(savedFavs, replaceMissingWithFalse: false);
      }
    });

    _triggerCloudSync();
  }

  /// 同期済みお気に入りリストを _allSpots へ反映する共通ヘルパー
  void _applySyncedFavoritesToSpots(
    List<OutingSpot> syncedFavs, {
    bool replaceMissingWithFalse = true,
  }) {
    final favMap = <String, OutingSpot>{for (final s in syncedFavs) s.id: s};
    _allSpots = _allSpots.map((spot) {
      final synced = favMap[spot.id];
      if (synced != null) {
        return spot.copyWith(
          isFavorite: true,
          pickedBy: synced.pickedBy,
          coupleNote: synced.coupleNote,
          isVisited: synced.isVisited,
          visitedDate: synced.visitedDate,
          visitedRating: synced.visitedRating,
          visitedMemory: synced.visitedMemory,
        );
      } else if (replaceMissingWithFalse) {
        return spot.copyWith(isFavorite: false);
      }
      return spot;
    }).toList();
    for (final synced in syncedFavs) {
      if (!_allSpots.any((s) => s.id == synced.id)) {
        _allSpots.add(synced.copyWith(isFavorite: true));
      }
    }
    if (_selectedMapSpot != null) {
      _selectedMapSpot = _allSpots.firstWhere(
        (s) => s.id == _selectedMapSpot!.id,
        orElse: () => _selectedMapSpot!,
      );
    }
    if (_anchorSpot != null) {
      _anchorSpot = _allSpots.firstWhere(
        (s) => s.id == _anchorSpot!.id,
        orElse: () => _anchorSpot!,
      );
    }
  }

  /// クラウド同期を実行する（相手の最新変更を受信・安全マージ）
  Future<void> _triggerCloudSync() async {
    setState(() => _syncStatusLabel = '同期中...');
    final localFavs = _favoriteSpots;
    final pulled = await CoupleSyncService.pullFromCloud(
      roomCode: _coupleRoomCode,
      currentLocal: localFavs,
    );

    if (!mounted) return;
    if (pulled != null) {
      setState(() {
        _applySyncedFavoritesToSpots(pulled, replaceMissingWithFalse: true);
      });
    }

    final lastSync = await CoupleSyncService.getLastSyncLabel();
    if (!mounted) return;
    setState(() {
      _syncStatusLabel = lastSync;
    });

    // 旅のしおりもクラウド同期
    final syncedTrips = await CoupleSyncService.pullTripsFromCloud(
      roomCode: _coupleRoomCode,
      currentLocal: _tripPlans,
    );
    if (mounted) {
      setState(() => _tripPlans = syncedTrips);
    }

    // クラウド受信後に夫婦の好みを再分析
    _fetchCoupleAiInsight();
  }

  /// 夫婦の好み分析AI（Gemini 3.5 Flash-Lite）の分析・提案を取得
  Future<void> _fetchCoupleAiInsight({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingAiInsight = true);
    try {
      final insight = await GeminiOutingService.generatePersonalizedInsight(
        favorites: _favoriteSpots,
        currentRegion: _selectedRegion,
        currentSpots: _allSpots,
        dateRange: _targetDateRange,
      );
      if (mounted) {
        setState(() {
          _coupleAiInsight = insight;
          _isLoadingAiInsight = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAiInsight = false);
      }
    }
  }

  /// 直近の検索結果に含まれるスポットIDセット
  Set<String>? _activeSearchResultIds;

  /// フィルタ条件に合致するスポット一覧（選択地域や検索結果をそのまま表示）
  List<OutingSpot> get _filteredSpots {
    return _allSpots.where((spot) {
      if (_activeSearchResultIds != null &&
          !_activeSearchResultIds!.contains(spot.id)) {
        return false;
      }
      if (_selectedCategory != null &&
          spot.category != _selectedCategory &&
          spot.id != _anchorSpot?.id) {
        return false;
      }
      if (_isRainOrColdMode && !spot.isRainOrColdFriendly) {
        return false;
      }
      if (_selectedTag != null && !spot.tags.contains(_selectedTag)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// お気に入り登録済みスポット一覧
  List<OutingSpot> get _favoriteSpots =>
      _allSpots.where((s) => s.isFavorite).toList();

  /// ジャンルボタンをタップしたときの検索（検索窓に「山寺」等の目的地が入力されていれば掛け合わせ検索！）
  Future<void> _selectGenreAndSearch(SpotCategory? category) async {
    final currentInput = _searchController.text.trim();
    setState(() {
      _selectedCategory = category;
      _selectedTag = null;
      _anchorSpot = null;
    });
    await _runAiSearch(currentInput.isNotEmpty ? currentInput : null, category);
  }

  /// 地域タブ（東北6県）をタップしたときの検索
  Future<void> _selectRegionAndSearch(TohokuRegion region) async {
    setState(() {
      _selectedRegion = region;
      _anchorSpot = null;
      _mapCenterLatLng = LatLng(region.centerLat, region.centerLng);
    });
    _fetchRegionWeather(region);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_mapCenterLatLng, 10.5),
    );
    await _runAiSearch(null, _selectedCategory);
    _fetchCoupleAiInsight();
  }

  /// 期間指定ダイアログ・カレンダーピッカーを開く
  Future<void> _showDateRangeSelectorSheet(BuildContext context) async {
    final upcoming = GeminiOutingService.getUpcomingWeekendRange();
    final following = GeminiOutingService.getFollowingWeekendRange();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('📅 ', style: TextStyle(fontSize: 20)),
                    Text(
                      'イベントの開催期間を指定',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '指定した週末や日付範囲に開催されている期間限定イベント・マルシェを検索します。',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const Divider(height: 20),
                ListTile(
                  leading: const Icon(Icons.weekend_outlined),
                  title: Text(
                    '直近の週末（${GeminiOutingService.formatDateRange(upcoming)}）',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('今度の土曜日・日曜日に開催中のイベント'),
                  trailing: _dateRangePresetLabel == '直近の週末'
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : null,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    setState(() {
                      _targetDateRange = upcoming;
                      _dateRangePresetLabel = '直近の週末';
                    });
                    _fetchRegionWeather(_selectedRegion, upcoming);
                    _runAiSearch(null, _selectedCategory);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(
                    '来週末（${GeminiOutingService.formatDateRange(following)}）',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('次の週の土曜日・日曜日に開催されるイベント'),
                  trailing: _dateRangePresetLabel == '来週末'
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : null,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    setState(() {
                      _targetDateRange = following;
                      _dateRangePresetLabel = '来週末';
                    });
                    _fetchRegionWeather(_selectedRegion, following);
                    _runAiSearch(null, _selectedCategory);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text(
                    'カレンダーから期間を自由に指定...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('三連休や特定の日付を指定して調べる'),
                  trailing: _dateRangePresetLabel == '期間指定'
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year, now.month, 1),
                      lastDate: DateTime(now.year + 1, 12, 31),
                      initialDateRange: _targetDateRange,
                      helpText: 'イベントを調べる期間（開始日〜終了日）を選択',
                      saveText: 'この期間で検索',
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _targetDateRange = picked;
                        _dateRangePresetLabel = '期間指定';
                      });
                      _fetchRegionWeather(_selectedRegion, picked);
                      _runAiSearch(null, _selectedCategory);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 通常検索（地域タブ＋期間指定＋フリーワード）を実行する
  Future<void> _runAiSearch([
    String? presetQuery,
    SpotCategory? explicitCategory,
  ]) async {
    if (presetQuery != null) {
      _searchController.text = presetQuery;
      if (explicitCategory == null) {
        _selectedCategory = null;
      }
    }

    setState(() {
      _isSearchingAi = true;
    });

    final currentFavs = List<OutingSpot>.from(_favoriteSpots);
    final targetCat = explicitCategory ?? _selectedCategory;

    final result = await GeminiOutingService.searchWithAi(
      query: _searchController.text,
      departureArea: _departureArea,
      currentSpots: _allSpots,
      userLat: _currentLocation?.latitude,
      userLng: _currentLocation?.longitude,
      targetCategory: targetCat,
      selectedRegion: _selectedRegion,
      targetDateRange: _targetDateRange,
    );

    if (!mounted) return;
    _applySearchResultToState(result, currentFavs, keepAnchorSpot: false);
  }

  /// ドライブ地図（タブ2）で「この地図エリア周辺」の立ち寄りスポット（温泉・神社・公園等）を検索する
  Future<void> _runMapAreaSearch({
    SpotCategory? category,
    String? customQuery,
    OutingSpot? centerOnSpot,
  }) async {
    final targetCenter = centerOnSpot != null
        ? LatLng(centerOnSpot.latitude, centerOnSpot.longitude)
        : _mapCenterLatLng;

    final String? centerLabel = centerOnSpot != null
        ? '「${centerOnSpot.title}」周辺'
        : null;

    setState(() {
      _isSearchingAi = true;
      _mapAreaCategory = category;
      _selectedCategory = null; // 基準スポットも周辺スポットも両方地図に表示するためフィルタ解除
      _isMapListExpanded = true; // 検索結果リストを自動展開
      if (centerOnSpot != null) {
        _anchorSpot = centerOnSpot;
        _mapCenterLatLng = targetCenter;
      }
    });

    if (centerOnSpot != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(targetCenter, 12.2),
      );
    }

    final currentFavs = List<OutingSpot>.from(_favoriteSpots);
    final queryText = customQuery ?? _mapSearchController.text.trim();

    final result = await GeminiOutingService.searchWithAi(
      query: queryText,
      departureArea: _departureArea,
      currentSpots: _allSpots,
      userLat: _currentLocation?.latitude,
      userLng: _currentLocation?.longitude,
      targetCategory: category,
      selectedRegion: _selectedRegion,
      targetDateRange: _targetDateRange,
      searchCenterLat: targetCenter.latitude,
      searchCenterLng: targetCenter.longitude,
      mapCenterLabel: centerLabel,
    );

    if (!mounted) return;
    _applySearchResultToState(result, currentFavs, keepAnchorSpot: true);

    if (mounted) {
      final label = category?.label ?? (queryText.isNotEmpty ? queryText : 'スポット');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🗺️ 周辺の【$label】が ${result.spots.length}件 見つかりました！下部リストやピンから確認・登録できます',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 検索結果をStateに反映し、お気に入り状態や基準スポットを保持する
  void _applySearchResultToState(
    AiSearchResult result,
    List<OutingSpot> currentFavs, {
    required bool keepAnchorSpot,
  }) {
    setState(() {
      _isSearchingAi = false;
      _aiSummaryComment = result.aiSummaryComment;
      if (result.isLiveAi) {
        final favMap = {for (final f in currentFavs) f.id: f};
        final mergedSpots = <OutingSpot>[];
        final addedIds = <String>{};
        final searchResultIds = <String>{};

        // 地図周辺検索時は、基準となったイベント/スポットも先頭に残して地図上で比較できるようにする
        if (keepAnchorSpot && _anchorSpot != null) {
          final anchor = favMap.containsKey(_anchorSpot!.id)
              ? _anchorSpot!.copyWith(isFavorite: true)
              : _anchorSpot!;
          mergedSpots.add(anchor);
          addedIds.add(anchor.id);
          searchResultIds.add(anchor.id);
        }

        for (final s in result.spots) {
          if (addedIds.contains(s.id)) continue;
          addedIds.add(s.id);
          searchResultIds.add(s.id);
          if (favMap.containsKey(s.id)) {
            final old = favMap[s.id]!;
            mergedSpots.add(
              s.copyWith(
                isFavorite: true,
                pickedBy: old.pickedBy,
                coupleNote: old.coupleNote,
              ),
            );
          } else {
            mergedSpots.add(s);
          }
        }

        for (final fav in currentFavs) {
          if (!addedIds.contains(fav.id)) {
            mergedSpots.add(fav);
          }
        }

        _activeSearchResultIds = searchResultIds;
        _allSpots = mergedSpots;

        if (_currentLocation != null) {
          _recalculateSpotDistances(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
          );
        }
      }
      if (_filteredSpots.isNotEmpty) {
        if (keepAnchorSpot && _filteredSpots.length > 1) {
          _selectedMapSpot = _filteredSpots[1];
        } else {
          _selectedMapSpot = _filteredSpots.first;
        }
        _scrollToSpotInList(_selectedMapSpot!);
      }
    });
  }

  /// ドライブ地図下部のスポット一覧カードを該当位置へスムーズに横スクロール
  void _scrollToSpotInList(OutingSpot spot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapSpotListScrollController.hasClients) return;
      final spots = _filteredSpots;
      final index = spots.indexWhere((s) => s.id == spot.id);
      if (index != -1) {
        final targetOffset = index * 290.0;
        _mapSpotListScrollController.animateTo(
          targetOffset.clamp(
            0.0,
            _mapSpotListScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// イベントやスポットを地図の中心に据えて、周辺の立ち寄り先（温泉・神社等）を探すモードへ移行
  void _jumpToMapAndSearchNearby(OutingSpot baseSpot, [SpotCategory? initialNearbyCategory]) {
    setState(() {
      _anchorSpot = baseSpot;
      _selectedMapSpot = baseSpot;
      _mapCenterLatLng = LatLng(baseSpot.latitude, baseSpot.longitude);
      _currentTabIndex = 1;
      _isMapListExpanded = true;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(baseSpot.latitude, baseSpot.longitude),
        12.5,
      ),
    );
    if (initialNearbyCategory != null) {
      _runMapAreaSearch(
        category: initialNearbyCategory,
        centerOnSpot: baseSpot,
      );
    }
  }

  /// ドライブ地図の周辺ジャンル絞り込みをOFF（クリア）に戻す
  void _clearMapAreaCategory() {
    setState(() {
      _mapAreaCategory = null;
      _anchorSpot = null;
      _activeSearchResultIds = null;
    });
    _runAiSearch(null, _selectedCategory);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 周辺ジャンルの絞り込みをOFF（クリア）にしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// この端末の使用者を設定して保存する
  Future<void> _setMyRole(PartnerPick role) async {
    setState(() {
      _myRole = role;
      _hasSelectedMyRole = true;
    });
    await CoupleSyncService.saveMyRole(role);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final roleName = role == PartnerPick.me
        ? '自分用（❤️）'
        : (role == PartnerPick.wife ? '妻（ママ）' : '夫（パパ）');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? '📱 この端末を「${role.icon} $roleName」に設定しました！'
              : '📱 このスマホを「${role.icon} $roleName」に設定しました！ハートを押すと自動で識別されます',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Android版：初回ハート押下時に1回だけ「このスマホは夫 / 妻どちらですか？」を確認するダイアログ
  Future<PartnerPick?> _promptMyRoleFirstTime() async {
    return showDialog<PartnerPick>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Text('📱 ', style: TextStyle(fontSize: 22)),
              Expanded(child: Text('このスマホはどちらですか？')),
            ],
          ),
          content: const Text(
            '1回選ぶだけで、今後はハート❤️を押した時点で自動的に「夫が気になる」「妻が気になる」として識別されます！\n（※画面右上からいつでも変更できます）',
            style: TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(dialogCtx).pop(PartnerPick.husband),
              icon: const Text('🙋‍♂️', style: TextStyle(fontSize: 18)),
              label: const Text('夫（パパ）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(PartnerPick.wife),
              icon: const Text('🙋‍♀️', style: TextStyle(fontSize: 18)),
              label: const Text('妻（ママ）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// お気に入りをクラウドとマージ・同期し、最新状態をUIへ反映する共通ヘルパー
  Future<void> _pushAndSyncFavorites() async {
    final synced = await CoupleSyncService.pushToCloud(
      roomCode: _coupleRoomCode,
      favorites: _favoriteSpots,
    );
    final lastSync = await CoupleSyncService.getLastSyncLabel();
    if (!mounted) return;
    setState(() {
      _applySyncedFavoritesToSpots(synced, replaceMissingWithFalse: true);
      _syncStatusLabel = lastSync;
    });
  }

  /// お気に入りON/OFF切り替え
  Future<void> _toggleFavorite(OutingSpot target) async {
    if (!kIsWeb && !target.isFavorite && !_hasSelectedMyRole) {
      final chosen = await _promptMyRoleFirstTime();
      if (chosen != null) {
        await _setMyRole(chosen);
      } else {
        _hasSelectedMyRole = true;
        await CoupleSyncService.saveMyRole(_myRole);
      }
    }

    bool upgradedToBoth = false;
    bool downgradedToPartner = false;
    PartnerPick? remainingPartnerPick;
    bool wasRemovedCompletely = false;

    setState(() {
      _allSpots = _allSpots.map((spot) {
        if (spot.id != target.id) return spot;
        if (!spot.isFavorite) {
          return spot.copyWith(
            isFavorite: true,
            pickedBy: kIsWeb ? PartnerPick.me : _myRole,
          );
        } else if (!kIsWeb &&
            spot.pickedBy != null &&
            spot.pickedBy != _myRole &&
            spot.pickedBy != PartnerPick.both &&
            spot.pickedBy != PartnerPick.me) {
          // 相手が付けていたスポットに自分もハートを押したら「💑 2人とも行きたい！」に昇格
          upgradedToBoth = true;
          return spot.copyWith(
            isFavorite: true,
            pickedBy: PartnerPick.both,
          );
        } else if (!kIsWeb && spot.pickedBy == PartnerPick.both) {
          // 「2人とも」状態から自分のハートを外す場合は、相手の候補まで消さないよう相手分だけ残す
          downgradedToPartner = true;
          remainingPartnerPick = _myRole == PartnerPick.husband
              ? PartnerPick.wife
              : PartnerPick.husband;
          return spot.copyWith(
            isFavorite: true,
            pickedBy: remainingPartnerPick,
          );
        } else {
          wasRemovedCompletely = true;
          return spot.copyWith(
            isFavorite: false,
            coupleNote: '',
          );
        }
      }).toList();
      if (_selectedMapSpot?.id == target.id) {
        _selectedMapSpot = _allSpots.firstWhere((s) => s.id == target.id);
      }
      if (_anchorSpot?.id == target.id) {
        _anchorSpot = _allSpots.firstWhere((s) => s.id == target.id);
      }
    });

    if (wasRemovedCompletely) {
      await CoupleSyncService.recordSpotDeletion(target.id);
    } else {
      await CoupleSyncService.recordSpotChange(target.id);
    }

    await _pushAndSyncFavorites();

    final updated = _allSpots.firstWhere(
      (s) => s.id == target.id,
      orElse: () => target,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final pickBadge = updated.pickedBy ?? _myRole;
    final String msg;
    if (upgradedToBoth) {
      msg = '💑 「${updated.title}」が『2人とも行きたい！』になりました！';
    } else if (downgradedToPartner && remainingPartnerPick != null) {
      msg =
          '自分の行きたいを解除しました（${remainingPartnerPick!.icon} ${remainingPartnerPick!.label} として残ります）';
    } else if (updated.isFavorite) {
      msg = kIsWeb
          ? '❤️ 「${updated.title}」を行きたい！リストに追加しました'
          : '❤️ 「${updated.title}」を【${pickBadge.icon} ${pickBadge.label}】として追加しました！';
    } else {
      msg = '「${updated.title}」を行きたい！リストから外しました';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );

    // お気に入り変更に伴い夫婦の好みを再分析
    _fetchCoupleAiInsight();
  }

  /// お気に入り画面の削除ボタンからスポットを完全に外す
  Future<void> _removeFavoriteCompletely(OutingSpot target) async {
    setState(() {
      _allSpots = _allSpots.map((spot) {
        if (spot.id != target.id) return spot;
        return spot.copyWith(
          isFavorite: false,
          coupleNote: '',
        );
      }).toList();
    });
    await CoupleSyncService.recordSpotDeletion(target.id);
    await _pushAndSyncFavorites();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${target.title}」を行きたい！リストから削除しました'),
        duration: const Duration(seconds: 2),
      ),
    );
    _fetchCoupleAiInsight();
  }

  /// 夫婦のお気に入りステータスやメモを更新する
  Future<void> _updateFavoriteDetail(
      OutingSpot target, PartnerPick pickedBy, String note) async {
    setState(() {
      _allSpots = _allSpots.map((spot) {
        if (spot.id != target.id) return spot;
        return spot.copyWith(
          isFavorite: true,
          pickedBy: pickedBy,
          coupleNote: note,
        );
      }).toList();
    });

    await CoupleSyncService.recordSpotChange(target.id);
    await _pushAndSyncFavorites();

    // メモや担当者更新に伴い夫婦の好みを再分析
    _fetchCoupleAiInsight();
  }

  /// 💮 行ったよ！思い出スタンプを更新してクラウドへ保存する（案C）
  Future<void> _updateVisitedSpot(OutingSpot updated) async {
    setState(() {
      _allSpots = _allSpots.map((spot) {
        if (spot.id != updated.id) return spot;
        return updated.copyWith(
          isFavorite: true,
          pickedBy: updated.pickedBy ??
              (kIsWeb ? PartnerPick.me : PartnerPick.both),
        );
      }).toList();
    });

    await CoupleSyncService.recordSpotChange(updated.id);
    await _pushAndSyncFavorites();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isVisited
                ? '💮「${updated.title}」に『行ったよ！』スタンプを押しました！'
                : '「${updated.title}」のスタンプを解除しました',
          ),
        ),
      );
    }
    _fetchCoupleAiInsight();
  }

  /// 旅のしおりリストを更新してクラウド同期する（案A）
  Future<void> _updateTripPlans(List<TripPlan> updatedTrips) async {
    setState(() {
      _tripPlans = updatedTrips;
      if (_selectedTripIndex >= _tripPlans.length) {
        _selectedTripIndex = (_tripPlans.length - 1).clamp(0, 99);
      }
    });
    await CoupleSyncService.pushTripsToCloud(
      roomCode: _coupleRoomCode,
      trips: updatedTrips,
    );
  }

  /// 選んだスポットを軸に「1日ドライブコースしおり」を自動作成してしおりタブを開く（案A）
  void _createDayDrivePlanFromSpot(OutingSpot spot) {
    final plan = GeminiOutingService.buildDayDrivePlanFromSpot(
      mainSpot: spot,
      regionalSpots: _allSpots,
    );
    final updated = List<TripPlan>.from(_tripPlans)..insert(0, plan);
    _updateTripPlans(updated);
    setState(() {
      _selectedTripIndex = 0;
      _currentTabIndex = 3;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🚗「${spot.title}」の1日ドライブコースしおりを作成しました！自由に編集できます',
        ),
      ),
    );
  }

  /// 現在の旅のしおりにスポットを1件追加する（案A）
  void _addSpotToCurrentTripPlan(OutingSpot spot) {
    final current = _tripPlans.isNotEmpty
        ? _tripPlans[_selectedTripIndex.clamp(0, _tripPlans.length - 1)]
        : TripPlan.createOsakaNagoyaStarter();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final newItem = TripScheduleItem(
      id: 'spot_${nowMs}_${spot.id}',
      dayNumber: 1,
      timeText: '11:00',
      title: spot.title,
      type: spot.category == SpotCategory.dining ||
              spot.category == SpotCategory.gourmet
          ? TripItemType.food
          : spot.category == SpotCategory.onsen
              ? TripItemType.hotel
              : TripItemType.sightseeing,
      location: spot.address,
      memo: spot.subtitle,
      url: spot.url,
    );
    final updatedPlan = current.copyWith(
      items: [...current.items, newItem],
    );
    final list = List<TripPlan>.from(_tripPlans);
    if (list.isEmpty) {
      list.add(updatedPlan);
    } else {
      list[_selectedTripIndex.clamp(0, list.length - 1)] = updatedPlan;
    }
    _updateTripPlans(list);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📒「${current.title}」に「${spot.title}」を追加しました！'),
        action: SnackBarAction(
          label: 'しおりを見る',
          onPressed: () => setState(() => _currentTabIndex = 3),
        ),
      ),
    );
  }

  /// 🎰 迷ったときの「週末どこ行く？おみくじルーレット」ダイアログ（案D）
  void _showExploreRouletteDialog(BuildContext context) {
    final pool = _filteredSpots.isNotEmpty ? _filteredSpots : _allSpots;
    if (pool.isEmpty) return;
    final rng = Random();
    OutingSpot picked = pool[rng.nextInt(pool.length)];

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Text('🎰 ', style: TextStyle(fontSize: 24)),
                  Expanded(child: Text('週末どこ行く？おみくじルーレット')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '現在の候補（${pool.length}件）から抽選されたおすすめスポットは…',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade50,
                          Colors.amber.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(picked.category.icon,
                            style: const TextStyle(fontSize: 38)),
                        const SizedBox(height: 6),
                        Text(
                          picked.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          picked.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '🚗 ${picked.driveTimeLabel} ｜ 📍 ${picked.address}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      picked = pool[rng.nextInt(pool.length)];
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('もう一度回す！'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _showSpotDetailSheet(this.context, picked);
                  },
                  icon: const Icon(Icons.celebration, size: 18),
                  label: const Text('ここを詳しく見る'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 🌲 スポット単体の TimeTree ＆ Googleカレンダー連携シート（案E）
  void _showSpotCalendarAndTimeTreeSheet(
    BuildContext context,
    OutingSpot spot,
  ) {
    DateTime selectedDate = _targetDateRange.start;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dateStr =
                '${selectedDate.year}/${selectedDate.month}/${selectedDate.day}';
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🌲「${spot.title}」をTimeTree・カレンダーへ登録',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text('お出かけ予定日: $dateStr',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 7)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('日付変更'),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Text('🌲', style: TextStyle(fontSize: 20)),
                    ),
                    title: const Text(
                      '① TimeTree用に予定メモをコピー',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      '場所・所要時間・駐車場・URLを綺麗にコピーし、TimeTreeにそのままペーストできます',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: spot.toTimeTreeCopyText()));
                        Navigator.of(sheetCtx).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '🌲 TimeTree用にコピーしました！TimeTreeアプリにそのまま貼り付けできます'),
                          ),
                        );
                      },
                      child: const Text('コピー'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Text('📅', style: TextStyle(fontSize: 20)),
                    ),
                    title: const Text(
                      '② Googleカレンダーに登録（TimeTree連携対応）',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'TimeTreeの「OSカレンダーを表示」をONにしていれば、登録するとTimeTreeにも自動表示されます！',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: FilledButton(
                      onPressed: () {
                        final calUrl = spot.toGoogleCalendarUrl(selectedDate);
                        Navigator.of(sheetCtx).pop();
                        _launchWebUrl(calUrl);
                      },
                      child: const Text('登録する'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 💮 ホーム・詳細シートからワンタップで「行ったよ！」スタンプを押すダイアログ（案C）
  void _showQuickVisitedDialog(BuildContext context, OutingSpot spot) {
    final now = DateTime.now();
    final defaultDate = spot.visitedDate.isNotEmpty
        ? spot.visitedDate
        : '${now.year}/${now.month}/${now.day}';
    final dateCtrl = TextEditingController(text: defaultDate);
    final memoryCtrl = TextEditingController(text: spot.visitedMemory);
    int rating = spot.visitedRating.clamp(1, 5);
    bool isVisited = true;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('💮「${spot.title}」行ったよ記録'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('💮 行ったよ！スタンプを押す',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isVisited,
                      onChanged: (v) => setDialogState(() => isVisited = v),
                    ),
                    TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(
                        labelText: '行った日',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('家族の満足度:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (idx) {
                        final starVal = idx + 1;
                        return IconButton(
                          onPressed: () =>
                              setDialogState(() => rating = starVal),
                          icon: Icon(
                            starVal <= rating ? Icons.star : Icons.star_border,
                            color: Colors.amber.shade700,
                            size: 30,
                          ),
                        );
                      }),
                    ),
                    TextField(
                      controller: memoryCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '思い出ひとことメモ（任意）',
                        hintText: '例: 子どもがすごく楽しそうだった！また来年も行きたい',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final updated = spot.copyWith(
                      isVisited: isVisited,
                      visitedDate: isVisited ? dateCtrl.text.trim() : '',
                      visitedRating: rating,
                      visitedMemory: isVisited ? memoryCtrl.text.trim() : '',
                    );
                    _updateVisitedSpot(updated);
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('保存する'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 外部Googleマップアプリを起動してナビを開始する
  Future<void> _launchGoogleMaps(OutingSpot spot) async {
    final uri = Uri.parse(spot.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: spot.googleMapsUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗺️ GoogleマップのURLをコピーしました！')),
      );
    }
  }

  /// 公式Webサイトまたは元記事リンクを外部ブラウザで開く
  Future<void> _launchWebUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🌐 リンクのURLをコピーしました！')),
      );
    }
  }

  /// ボトムナビのメインタブ（0:AI検索, 1:ドライブ地図, 2:夫婦の行きたい！, 3:旅のしおり）を切り替える
  void _selectBottomTab(int index) {
    final target = index.clamp(0, 3);
    if (target == _currentTabIndex) return;
    setState(() => _currentTabIndex = target);
    if (target == 1 && _selectedMapSpot != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_selectedMapSpot!.latitude, _selectedMapSpot!.longitude),
        ),
      );
    } else if (target == 2 || target == 3) {
      _triggerCloudSync();
    }
  }

  /// 左右スワイプでメインタブ（AI提案・検索 ⇄ ドライブ地図 ⇄ 夫婦の行きたい！ ⇄ 旅のしおり）を移動する
  void _handleHorizontalTabSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity.abs() < 260) return;
    if (velocity < 0 && _currentTabIndex < 3) {
      // 左へスワイプ ➔ 次のタブへ
      _selectBottomTab(_currentTabIndex + 1);
    } else if (velocity > 0 && _currentTabIndex > 0) {
      // 右へスワイプ ➔ 前のタブへ
      _selectBottomTab(_currentTabIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateLabel = GeminiOutingService.formatDateRange(_targetDateRange);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Text('🚗 ', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '週末どこ行く？AIナビ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '地域: ${_selectedRegion.label} ｜ 期間: $dateLabel（$_dateRangePresetLabel）',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!kIsWeb)
            // このスマホの使用者（夫 / 妻）ワンタップ切替バッジ（Android版のみ）
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Tooltip(
                message: 'タップで「夫 / 妻」を切替（ハート押下時に自動識別）',
                child: SafeActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Text(
                    _myRole.icon,
                    style: const TextStyle(fontSize: 13),
                  ),
                  label: Text(
                    _myRole == PartnerPick.wife ? '妻' : '夫',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    final nextRole = _myRole == PartnerPick.husband
                        ? PartnerPick.wife
                        : PartnerPick.husband;
                    _setMyRole(nextRole);
                  },
                ),
              ),
            ),
          IconButton(
            tooltip: '📅 イベント期間指定',
            onPressed: () => _showDateRangeSelectorSheet(context),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: '🎒 持ち物チェック',
            onPressed: () => _showPackingListSheet(context),
            icon: const Icon(Icons.backpack_outlined),
          ),
          IconButton(
            tooltip: '出発エリアの設定',
            onPressed: () => _showDepartureAreaDialog(context),
            icon: const Icon(Icons.edit_location_alt_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleHorizontalTabSwipe,
            child: _buildExploreTab(context),
          ),
          _buildGoogleMapTab(context),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleHorizontalTabSwipe,
            child: FavoritesScreen(
              favoriteSpots: _favoriteSpots,
              coupleRoomCode: _coupleRoomCode,
              syncStatusLabel: _syncStatusLabel,
              myRole: _myRole,
              onChangeMyRole: _setMyRole,
              onTriggerSync: _triggerCloudSync,
              onRoomCodeChanged: (code) async {
                setState(() => _coupleRoomCode = code);
                await CoupleSyncService.saveRoomCode(code);
                _triggerCloudSync();
              },
              onUpdateFavorite: _updateFavoriteDetail,
              onUpdateVisitedSpot: _updateVisitedSpot,
              onRemoveFavorite: _removeFavoriteCompletely,
              onOpenSpotDetail: (spot) => _showSpotDetailSheet(context, spot),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleHorizontalTabSwipe,
            child: TripPlannerScreen(
              tripPlans: _tripPlans,
              selectedTripIndex: _selectedTripIndex,
              onSelectTrip: (idx) => setState(() => _selectedTripIndex = idx),
              onUpdateTrips: _updateTripPlans,
              coupleRoomCode: _coupleRoomCode,
              onTriggerSync: _triggerCloudSync,
            ),
          ),
        ],
      ),
      floatingActionButton: (_currentTabIndex == 0 && _showBackToTop)
          ? FloatingActionButton.small(
              tooltip: 'トップに戻る',
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              onPressed: () {
                _exploreScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Icon(Icons.arrow_upward),
            )
          : null,
      bottomNavigationBar: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _handleHorizontalTabSwipe,
        child: NavigationBar(
          selectedIndex: _currentTabIndex,
          onDestinationSelected: _selectBottomTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'AI提案・検索',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'ドライブ地図',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _favoriteSpots.isNotEmpty,
              label: Text('${_favoriteSpots.length}'),
              child: const Icon(Icons.favorite_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: _favoriteSpots.isNotEmpty,
              label: Text('${_favoriteSpots.length}'),
              child: const Icon(Icons.favorite),
            ),
            label: kIsWeb ? '行きたい！リスト' : '夫婦の行きたい！',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _tripPlans.isNotEmpty,
              label: Text('${_tripPlans.length}'),
              child: const Icon(Icons.event_note_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _tripPlans.isNotEmpty,
              label: Text('${_tripPlans.length}'),
              child: const Icon(Icons.event_note),
            ),
            label: '旅のしおり',
          ),
        ],
      ),
    ),
  );
}

  /// タブ1：東北6県タブ・期間指定・天気予報・ジャンル別スポット検索画面
  Widget _buildExploreTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = _filteredSpots;
    final dateRangeStr = GeminiOutingService.formatDateRange(_targetDateRange);

    return CustomScrollView(
      controller: _exploreScrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. フリーワード検索ボックス（目的地＋下のジャンルボタンで周辺検索も可能）
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _runAiSearch(),
                  decoration: InputDecoration(
                    hintText: '目的地・キーワード（例：山寺、松島）＋下のボタンで周辺検索！',
                    prefixIcon:
                        Icon(Icons.auto_awesome, color: colorScheme.primary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'クリア',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _runAiSearch(null, _selectedCategory);
                            },
                            icon: const Icon(Icons.clear, size: 20),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilledButton(
                            onPressed:
                                _isSearchingAi ? null : () => _runAiSearch(),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              minimumSize: const Size(60, 38),
                            ),
                            child: const Text('検索'),
                          ),
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 2. 東北6県の地域指定タブ
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 17),
                      const SizedBox(width: 4),
                      ...TohokuRegion.values.map((region) {
                        final isSelected = _selectedRegion == region;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SafeChoiceChip(
                            avatar: Text(
                              region.icon,
                              style: const TextStyle(fontSize: 13),
                            ),
                            label: Text(
                              region.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => _selectRegionAndSearch(region),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // 3. その地域の週末天気予報バナー
                if (_currentRegionWeather != null)
                  _buildRegionWeatherCard(context, _currentRegionWeather!),

                const SizedBox(height: 6),

                // 4. メイン7大ジャンル検索チップ
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...SpotCategory.values
                          .where((cat) => cat != SpotCategory.gourmet)
                          .map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SafeChoiceChip(
                            avatar: Text(cat.icon,
                                style: const TextStyle(fontSize: 15)),
                            label: Text(
                              cat.label,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: colorScheme.primaryContainer,
                            onSelected: (_) {
                              if (isSelected) {
                                _selectGenreAndSearch(null);
                              } else {
                                _selectGenreAndSearch(cat);
                              }
                            },
                          ),
                        );
                      }),
                      SafeChoiceChip(
                        label:
                            const Text('すべて', style: TextStyle(fontSize: 12.5)),
                        selected:
                            _selectedCategory == null && _selectedTag == null,
                        onSelected: (_) => _selectGenreAndSearch(null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // 5. イベント期間指定ボタン ＆ 駐車場・入場料フィルタ
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SafeActionChip(
                        avatar: Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          '期間: $dateRangeStr（$_dateRangePresetLabel）',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            colorScheme.primaryContainer.withValues(alpha: 0.4),
                        onPressed: () => _showDateRangeSelectorSheet(context),
                      ),
                      const SizedBox(width: 6),
                      SafeFilterChip(
                        avatar: const Text('☔', style: TextStyle(fontSize: 13)),
                        label: const Text('雨・寒い日安心モード',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: _isRainOrColdMode,
                        selectedColor: Colors.lightBlue.shade100,
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          setState(() => _isRainOrColdMode = val);
                        },
                      ),
                      const SizedBox(width: 6),
                      SafeActionChip(
                        avatar: const Text('🎰', style: TextStyle(fontSize: 13)),
                        label: const Text('おみくじルーレット',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.amber.shade50,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showExploreRouletteDialog(context),
                      ),
                      const SizedBox(width: 6),
                      SafeActionChip(
                        avatar: const Text('📒', style: TextStyle(fontSize: 13)),
                        label: const Text('大阪・名古屋 / 旅のしおり',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.orange.shade50,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _currentTabIndex = 3),
                      ),
                      const SizedBox(width: 6),
                      SafeFilterChip(
                        avatar: Text(SpotTag.freeParking.icon,
                            style: const TextStyle(fontSize: 13)),
                        label: Text(SpotTag.freeParking.label,
                            style: const TextStyle(fontSize: 12)),
                        selected: _selectedTag == SpotTag.freeParking,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() {
                            _selectedTag = _selectedTag == SpotTag.freeParking
                                ? null
                                : SpotTag.freeParking;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      SafeFilterChip(
                        avatar: Text(SpotTag.freeEntry.icon,
                            style: const TextStyle(fontSize: 13)),
                        label: Text(SpotTag.freeEntry.label,
                            style: const TextStyle(fontSize: 12)),
                        selected: _selectedTag == SpotTag.freeEntry,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() {
                            _selectedTag = _selectedTag == SpotTag.freeEntry
                                ? null
                                : SpotTag.freeEntry;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Gemini AIの要約バナー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isSearchingAi
                            ? Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_selectedRegion.label}のイベント・お出かけスポットを検索中...',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _aiSummaryComment,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.4),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // お出かけ好みAIナビ（Gemini 3.5 Flash-Lite）カード（Web版やAPIキーなし環境では非表示）
                if (!kIsWeb && AppApiKeys.geminiApiKey.isNotEmpty) ...[
                  _buildCoupleAiInsightCard(context),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),

        // 提案スポットカード一覧
        if (spots.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off,
                        size: 48, color: colorScheme.outline),
                    const SizedBox(height: 8),
                    const Text('条件に合うスポットが見つかりませんでした'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                          _selectedTag = null;
                          _activeSearchResultIds = null;
                          _searchController.clear();
                        });
                        _selectGenreAndSearch(null);
                      },
                      child: const Text('条件をリセットする'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSpotCard(context, spots[index]),
                childCount: spots.length,
              ),
            ),
          ),
      ],
    );
  }

  /// その地域の週末天気予報カード（タブ1上部表示）
  Widget _buildRegionWeatherCard(BuildContext context, AreaWeatherSummary weather) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200.withValues(alpha: 0.9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌤️ ', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '【${weather.areaName}の週末天気】 ${weather.summaryText}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weather.adviceComment,
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 💑 夫婦の好みAIナビカード（Gemini 3.5 Flash-Lite）
  Widget _buildCoupleAiInsightCard(BuildContext context) {
    final favCount = _favoriteSpots.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.pink.shade50.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.pink.shade200.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル行 ＆ 再分析ボタン
          Row(
            children: [
              const Text('💑 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '夫婦の好みAIナビ',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF880E4F),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Flash-Lite',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFAD1457),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      favCount > 0
                          ? '夫婦のお気に入り（$favCount件）から好みをAI分析'
                          : '気になるスポットの❤️を押すと好みをAI分析',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.pink.shade800.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingAiInsight)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: '夫婦の好みを再分析',
                  visualDensity: VisualDensity.compact,
                  color: Colors.pink.shade700,
                  onPressed: () => _fetchCoupleAiInsight(forceRefresh: true),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // 本文コンテンツ
          if (_coupleAiInsight != null) ...[
            // 夫婦の好みキャッチコピー ＆ キーワードタグ
            if (_coupleAiInsight!.preferenceSummary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_alt_outlined,
                        size: 15, color: Color(0xFFC2185B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _coupleAiInsight!.preferenceSummary,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF880E4F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // キーワードバッジ
            if (_coupleAiInsight!.favoriteKeywords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _coupleAiInsight!.favoriteKeywords.map((tag) {
                    final displayTag = tag.startsWith('#') ? tag : '#$tag';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.pink.shade200,
                        ),
                      ),
                      child: Text(
                        displayTag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC2185B),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // AI提案テキスト（Gemini 3.5 Flash-Lite）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _coupleAiInsight!.recommendationText,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF37474F),
                ),
              ),
            ),
          ] else if (_isLoadingAiInsight) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'お気に入りから好みを分析しています...',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'お気に入り（❤️）を増やすと、Gemini 3.5 Flash-Lite が好みを学習して、ぴったりなお出かけスポットを提案します！',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 情報ソースに応じたテーマカラー
  Color _getSourceBadgeColor(OutingSpot spot) {
    if (spot.sourceInfo.contains('いこーよ') ||
        spot.id.startsWith('ikoyo_') ||
        spot.url.contains('iko-yo.net')) {
      return Colors.orange.shade800;
    }
    if (spot.sourceInfo.contains('せんだい旅日和') ||
        spot.url.contains('sendai-tabibiyori.info')) {
      return Colors.teal.shade700;
    }
    if (spot.sourceInfo.contains('仙台つーしん') ||
        spot.url.contains('sendai-tushin.jp')) {
      return Colors.indigo.shade600;
    }
    if (spot.sourceInfo.contains('Walkerplus') ||
        spot.url.contains('walkerplus.com')) {
      return Colors.blue.shade700;
    }
    if (spot.sourceInfo.contains('Google') || spot.id.startsWith('places_')) {
      return Colors.red.shade700;
    }
    return Colors.blueGrey.shade700;
  }

  /// スポット提案カード1件分
  Widget _buildSpotCard(BuildContext context, OutingSpot spot) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEvent = spot.category == SpotCategory.event ||
        spot.category == SpotCategory.gourmet;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showSpotDetailSheet(context, spot),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 最上部：種別バッジ ＋ 所要時間 ＋ ハートボタン
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isEvent
                                ? Colors.deepOrange.shade50
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isEvent
                                  ? Colors.deepOrange.shade200
                                  : Colors.teal.shade200,
                            ),
                          ),
                          child: Text(
                            '${spot.category.icon} ${spot.category.label}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isEvent
                                  ? Colors.deepOrange.shade800
                                  : Colors.teal.shade800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car,
                                  size: 14,
                                  color: colorScheme.onPrimaryContainer),
                              const SizedBox(width: 4),
                              Text(
                                spot.driveTimeLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getSourceBadgeColor(spot)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getSourceBadgeColor(spot)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(spot.sourceBadgeIcon,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                spot.sourceBadgeLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _getSourceBadgeColor(spot),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (spot.isFavorite && spot.pickedBy != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.pink.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.pink.shade200),
                            ),
                            child: Text(
                              '${spot.pickedBy!.icon} ${spot.pickedBy!.label}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade800,
                              ),
                            ),
                          ),
                        if (spot.isVisited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.deepOrange.shade300),
                            ),
                            child: Text(
                              '💮 行ったよ！(${"★" * spot.visitedRating})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: '行きたい！リストに追加',
                    onPressed: () => _toggleFavorite(spot),
                    icon: Icon(
                      spot.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: spot.isFavorite ? Colors.pink : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // タイトル・サブタイトル
              Text(
                spot.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                spot.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),

              // タグ一覧
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: spot.tags.map((tag) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tag.icon} ${tag.label}',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 開催場所住所・日時・駐車場情報ボックス
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📍 ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(
                            spot.address,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📅 ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(
                            spot.scheduleText,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🅿️ ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(
                            spot.parkingInfo,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // おすすめポイント
              const Text(
                '✨ おすすめポイント',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...spot.recommendPoints.map((point) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary)),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),

              // 💬 Googleマップのレビュー・クチコミ（おすすめポイントとは別枠で表示！）
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💬 ', style: TextStyle(fontSize: 14)),
                        Text(
                          'Googleマップのレビュー・評価',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        if (spot.googleRatingBadgeText.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              spot.googleRatingBadgeText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade900,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        InkWell(
                          onTap: () => _launchGoogleMaps(spot),
                          child: Text(
                            'クチコミを見る ➔',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (spot.googleReviews.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...spot.googleReviews.take(2).map(
                            (rev) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '• $rev',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                          ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        '📍「${spot.title}」の最新クチコミ・写真をGoogleマップで確認できます',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 公式サイト・元記事リンクボタン
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchWebUrl(spot.officialWebUrl),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(
                      spot.url.isNotEmpty
                          ? '🌐 ${spot.sourceBadgeLabel}の元記事・公式を見る'
                          : '🔍 Webで最新情報を検索',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              // 立ち寄り先（近隣の温泉・神社等）を地図で探すショートカットボタン
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        _jumpToMapAndSearchNearby(spot, SpotCategory.onsen),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.travel_explore, size: 17),
                    label: const Text(
                      '♨️⛩️ この周辺の温泉・神社・立ち寄り先を地図で探す',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              // 便利アクションチップ（1日しおり作成 / しおり追加 / TimeTree・カレンダー / 行ったよ！）
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SafeActionChip(
                      avatar: const Text('🚗', style: TextStyle(fontSize: 12)),
                      label: const Text('1日ドライブしおり作成',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.orange.shade50,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _createDayDrivePlanFromSpot(spot),
                    ),
                    SafeActionChip(
                      avatar: const Text('📋', style: TextStyle(fontSize: 12)),
                      label: const Text('しおりに追加',
                          style: TextStyle(fontSize: 11.5)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _addSpotToCurrentTripPlan(spot),
                    ),
                    SafeActionChip(
                      avatar: const Text('🌲', style: TextStyle(fontSize: 12)),
                      label: const Text('TimeTree・カレンダー',
                          style: TextStyle(fontSize: 11.5)),
                      backgroundColor: Colors.teal.shade50,
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _showSpotCalendarAndTimeTreeSheet(context, spot),
                    ),
                    SafeActionChip(
                      avatar: const Text('💮', style: TextStyle(fontSize: 12)),
                      label: Text(
                        spot.isVisited ? '行ったよ編集' : '行ったよ！記録',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      backgroundColor:
                          spot.isVisited ? Colors.orange.shade100 : null,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showQuickVisitedDialog(context, spot),
                    ),
                  ],
                ),
              ),

              // 下部ボタン（マップへ移動 / 詳細・共有）
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _jumpToMapAndSearchNearby(spot, null),
                      icon: const Icon(Icons.location_on_outlined, size: 18),
                      label: const Text('マップで位置を見る'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _showSpotDetailSheet(context, spot),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('詳細・共有'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// タブ2：ドライブ地図（地図エリア周辺の温泉・神社・公園検索 ＆ 画面下部スポット一覧リスト ＆ その場でお気に入り登録）
  Widget _buildGoogleMapTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = _filteredSpots;
    final activeSpot =
        _selectedMapSpot ?? (spots.isNotEmpty ? spots.first : null);

    // 各スポットのピン（マーカー）を作成
    final markers = <Marker>{};
    for (final spot in spots) {
      final isSelected = activeSpot?.id == spot.id;
      final isAnchor = _anchorSpot?.id == spot.id;
      final isEvent = spot.category == SpotCategory.event ||
          spot.category == SpotCategory.gourmet;

      // お気に入り登録済みはピンク、基準スポットやイベントはオレンジ、通常スポットは水色
      final double hue;
      if (spot.isFavorite) {
        hue = BitmapDescriptor.hueRose;
      } else if (isAnchor || isEvent) {
        hue = BitmapDescriptor.hueOrange;
      } else {
        hue = BitmapDescriptor.hueCyan;
      }

      markers.add(
        Marker(
          markerId: MarkerId(spot.id),
          position: LatLng(spot.latitude, spot.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title:
                '${spot.isFavorite ? "❤️ " : ""}${spot.category.icon} ${spot.title}',
            snippet: '${spot.driveTimeLabel} / 🅿️ ${spot.parkingInfo}',
          ),
          zIndexInt: isSelected ? 3 : (isAnchor ? 2 : 1),
          onTap: () {
            setState(() => _selectedMapSpot = spot);
            _scrollToSpotInList(spot);
          },
        ),
      );
    }

    final initialCenter = activeSpot != null
        ? LatLng(activeSpot.latitude, activeSpot.longitude)
        : _mapCenterLatLng;

    return Stack(
      children: [
        // Google Maps 本体
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialCenter,
            zoom: 11.5,
          ),
          mapType: _currentMapType,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onCameraMove: (pos) {
            _mapCenterLatLng = pos.target;
          },
          onMapCreated: (controller) {
            _mapController = controller;
          },
        ),

        // マップ上部：この地図エリア周辺でスポットを探す検索バー ＆ 天気チップ ＆ ジャンルチップ
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1段目：天気予報サマリーバナー（コンパクト）
              if (_currentRegionWeather != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌤️ ', style: TextStyle(fontSize: 13)),
                      Text(
                        '${_currentRegionWeather!.areaName}の週末天気: ${_currentRegionWeather!.dailyForecasts.map((d) => "${d.weatherIcon} ${d.maxTemp.round()}℃/${d.minTemp.round()}℃").join(" ｜ ")}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              // 2段目：地図周辺フリーワード検索 ＋ 周辺検索ボタン ＋ 航空写真切替
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.travel_explore,
                        size: 20, color: Colors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _mapSearchController,
                          onSubmitted: (val) => _runMapAreaSearch(
                            category: _mapAreaCategory,
                            customQuery: val,
                          ),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: _anchorSpot != null
                                ? '「${_anchorSpot!.title}」周辺で検索...'
                                : 'この地図周辺で検索（例：温泉、神社、公園）',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            border: InputBorder.none,
                            suffixIcon: _mapSearchController.text.isNotEmpty
                                ? IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _mapSearchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _isSearchingAi
                          ? null
                          : () => _runMapAreaSearch(
                                category: _mapAreaCategory,
                                customQuery: _mapSearchController.text,
                              ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(56, 32),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _isSearchingAi
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('周辺検索',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _currentMapType = _currentMapType == MapType.normal
                              ? MapType.hybrid
                              : MapType.normal;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _currentMapType == MapType.normal
                              ? Icons.satellite_alt
                              : Icons.map,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 3段目：「この地図エリア周辺」ワンタップジャンル検索チップ（再タップでOFF/クリア可能！）
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_mapAreaCategory != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SafeActionChip(
                          avatar: const Icon(Icons.close,
                              size: 15, color: Colors.red),
                          label: const Text(
                            'クリア（解除）',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          backgroundColor: Colors.red.shade50,
                          side: BorderSide(color: Colors.red.shade300),
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              _isSearchingAi ? null : _clearMapAreaCategory,
                        ),
                      ),
                    _buildMapGenreChip(SpotCategory.dining, '🍽️ 周辺の食事処・ランチ'),
                    _buildMapGenreChip(SpotCategory.tourism, '📸 周辺の観光地・名所'),
                    _buildMapGenreChip(SpotCategory.onsen, '♨️ 周辺の温泉・銭湯'),
                    _buildMapGenreChip(SpotCategory.sightseeing, '⛩️ 周辺の神社仏閣'),
                    _buildMapGenreChip(SpotCategory.park, '🏃 周辺の大きな公園'),
                    _buildMapGenreChip(SpotCategory.smallPark, '🌳 周辺の小さな公園'),
                    _buildMapGenreChip(SpotCategory.indoor, '🏛️ 周辺の屋内施設'),
                    _buildMapGenreChip(SpotCategory.event, '🎪 周辺のイベント'),
                  ],
                ),
              ),
            ],
          ),
        ),



        // マップ下部：検索結果スポットの横スクロールカード一覧（リスト表示）
        if (spots.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 件数バー ＆ リスト開閉ボタン
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.list_alt,
                                size: 14, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              'スポット一覧（${spots.length}件）',
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            if (_isMapListExpanded) ...[
                              const SizedBox(width: 6),
                              const Text('👈 スワイプで切替 👉',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(
                              () => _isMapListExpanded = !_isMapListExpanded);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 1)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isMapListExpanded
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_up,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              Text(
                                _isMapListExpanded ? 'リストを隠す' : 'リストを表示',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isMapListExpanded) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 168,
                    child: ListView.builder(
                      controller: _mapSpotListScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: spots.length,
                      itemBuilder: (context, index) {
                        final spot = spots[index];
                        final isSelected = activeSpot?.id == spot.id;
                        return _buildMapSpotCarouselCard(
                            context, spot, isSelected);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

        // マップ右側：現在地へ移動ボタン
        Positioned(
          right: 16,
          bottom: _isMapListExpanded && spots.isNotEmpty ? 200 : 20,
          child: FloatingActionButton.small(
            heroTag: 'map_current_location_fab',
            backgroundColor: Colors.white,
            foregroundColor: colorScheme.primary,
            elevation: 4,
            onPressed: () => _fetchCurrentLocation(moveMap: true),
            tooltip: '現在地に移動',
            child: _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  /// ドライブ地図下部の横スクロールスポットカード1枚分
  Widget _buildMapSpotCarouselCard(
    BuildContext context,
    OutingSpot spot,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 285,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Card(
        elevation: isSelected ? 6 : 2.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: colorScheme.primary, width: 2.2)
              : BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() => _selectedMapSpot = spot);
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(spot.latitude, spot.longitude),
                13.0,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 基準スポットがある場合は距離バッジを表示
                if (_anchorSpot != null && _anchorSpot!.id != spot.id) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      '📍 「${_anchorSpot!.title}」から約${LocationService.calculateDistanceKm(startLat: _anchorSpot!.latitude, startLng: _anchorSpot!.longitude, endLat: spot.latitude, endLng: spot.longitude).toStringAsFixed(1)}km',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade800,
                      ),
                    ),
                  ),
                ],

                // タイトル ＆ ハートボタン
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${spot.category.icon} ${spot.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🚗 ${spot.driveTimeLabel} ｜ ${spot.sourceBadgeIcon} ${spot.sourceBadgeLabel} ｜ 📍 ${spot.address}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '🅿️ ${spot.parkingInfo}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '行きたい！に追加',
                      onPressed: () => _toggleFavorite(spot),
                      icon: Icon(
                        spot.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: spot.isFavorite ? Colors.pink : Colors.grey,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // ボタン（詳細 / ナビ開始）
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showSpotDetailSheet(context, spot),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('詳細を見る',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _launchGoogleMaps(spot),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('ナビ開始',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ドライブ地図上部のジャンルチップ1個分（もう一度押すとOFF/クリアになる）
  Widget _buildMapGenreChip(SpotCategory category, String label) {
    final isSelected = _mapAreaCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SafeActionChip(
        label: Text(
          isSelected ? '$label ✕' : label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.teal.shade900 : Colors.black87,
          ),
        ),
        backgroundColor: isSelected
            ? Colors.teal.shade100
            : Colors.white.withValues(alpha: 0.95),
        side: BorderSide(
          color: isSelected ? Colors.teal.shade600 : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1.0,
        ),
        visualDensity: VisualDensity.compact,
        onPressed: _isSearchingAi
            ? null
            : () {
                if (isSelected) {
                  _clearMapAreaCategory();
                } else {
                  _runMapAreaSearch(category: category);
                }
              },
      ),
    );
  }

  /// スポット詳細＆立ち寄り先検索シート
  void _showSpotDetailSheet(BuildContext context, OutingSpot spot) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.84,
          maxChildSize: 0.94,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SafeChip(
                        avatar: Text(spot.category.icon),
                        label: Text(spot.category.label),
                      ),
                      SafeChip(
                        avatar: Text(spot.sourceBadgeIcon),
                        label: Text(spot.sourceBadgeLabel),
                        backgroundColor: _getSourceBadgeColor(spot)
                            .withValues(alpha: 0.12),
                      ),
                      Text(
                        '🚗 ${spot.driveTimeLabel}（約${spot.distanceKm.toStringAsFixed(0)}km）',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spot.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(spot.subtitle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: spot.tags
                        .map((t) => SafeChip(
                              label: Text('${t.icon} ${t.label}'),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('開催場所・住所',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.address),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('開催日程・営業時間',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.scheduleText),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_parking),
                    title: const Text('駐車場・アクセス情報',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.parkingInfo),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.source_outlined),
                    title: const Text('情報ソース・提供元',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${spot.sourceBadgeIcon} ${spot.sourceInfo}',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language),
                    title: const Text('公式・元記事リンク',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      spot.url.isNotEmpty ? spot.url : 'タップしてWebで最新情報を確認',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => _launchWebUrl(spot.officialWebUrl),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✨ おすすめポイント',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...spot.recommendPoints.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✔ ',
                                style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold)),
                            Expanded(child: Text(p)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),

                  // 💬 Googleマップのレビュー・評価枠（おすすめポイントとは別枠で表示）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('💬 ', style: TextStyle(fontSize: 16)),
                            Text(
                              'Googleマップのレビュー・評価',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            if (spot.googleRatingBadgeText.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  spot.googleRatingBadgeText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (spot.googleReviews.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...spot.googleReviews.map(
                            (rev) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '• $rev',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text(
                            'Googleマップで実際の来場者クチコミ・写真を確認できます。',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _launchGoogleMaps(spot),
                            icon: const Icon(Icons.rate_review_outlined,
                                size: 16),
                            label: const Text(
                              'Googleマップでクチコミ・写真をすべて見る',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // このスポット周辺の立ち寄り先をワンタップで地図検索できるボックス
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🗺️ ついでに寄れる！この周辺の立ち寄りスポットを地図で探す',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            SafeActionChip(
                              label: const Text('🍽️ 近くの食事処・ランチ',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.dining);
                              },
                            ),
                            SafeActionChip(
                              label: const Text('📸 近くの観光地・名所',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.tourism);
                              },
                            ),
                            SafeActionChip(
                              label: const Text('♨️ 近くの温泉・銭湯',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.onsen);
                              },
                            ),
                            SafeActionChip(
                              label: const Text('⛩️ 近くの神社仏閣',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.sightseeing);
                              },
                            ),
                            SafeActionChip(
                              label: const Text('🏃 近くの大きな公園',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.park);
                              },
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _launchWebUrl(spot.officialWebUrl),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        spot.url.isNotEmpty
                            ? '🌐 ${spot.sourceBadgeLabel}の元記事・公式を開く'
                            : '🔍 Webで最新情報を検索',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      SafeActionChip(
                        avatar: const Text('🚗'),
                        label: const Text('1日ドライブしおり作成',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.orange.shade50,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _createDayDrivePlanFromSpot(spot);
                        },
                      ),
                      SafeActionChip(
                        avatar: const Text('🌲'),
                        label: const Text('TimeTree・カレンダー連携',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.teal.shade50,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showSpotCalendarAndTimeTreeSheet(
                              this.context, spot);
                        },
                      ),
                      SafeActionChip(
                        avatar: const Text('💮'),
                        label: Text(
                          spot.isVisited ? '行ったよスタンプ編集' : '行ったよ！スタンプ',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showQuickVisitedDialog(this.context, spot);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _jumpToMapAndSearchNearby(spot, null);
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('🗺️ アプリ内のドライブ地図で位置を見る',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _toggleFavorite(spot);
                            Navigator.of(sheetContext).pop();
                          },
                          icon: Icon(
                            spot.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.pink,
                          ),
                          label: Text(
                            spot.isFavorite ? '共有ボード登録中' : '行きたい！に追加',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _launchGoogleMaps(spot);
                          },
                          icon: const Icon(Icons.navigation),
                          label: const Text('ナビ開始'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 🎒 ドライブお出かけ持ち物チェックリストモーダル
  void _showPackingListSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final checkedCount = _packingList.values.where((v) => v).length;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🎒 ', style: TextStyle(fontSize: 22)),
                      Text(
                        'ドライブ持ち物チェック ($checkedCount/${_packingList.length})',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '週末のお出かけ前に車に積んだかチェックしましょう！',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  ..._packingList.keys.map((item) {
                    final isChecked = _packingList[item] ?? false;
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item,
                        style: TextStyle(
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.grey : Colors.black87,
                        ),
                      ),
                      value: isChecked,
                      onChanged: (val) {
                        setState(() => _packingList[item] = val ?? false);
                        setModalState(() {});
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('チェック完了して閉じる'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 出発エリア変更ダイアログ
  void _showDepartureAreaDialog(BuildContext context) {
    final controller = TextEditingController(text: _departureArea);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🚗 出発エリアの設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _fetchCurrentLocation(moveMap: true);
                },
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('📍 現在地（GPS）を自動取得して設定'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                ),
              ),
              const SizedBox(height: 14),
              const Text('または手動でエリアを入力:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '出発地（市区町村や駅名）',
                  hintText: '例: 富谷市 / 仙台市泉区',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() => _departureArea = controller.text.trim());
                  _runAiSearch();
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('変更する'),
            ),
          ],
        );
      },
    );
  }
}
