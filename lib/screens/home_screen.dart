// ホーム画面（東北6県タブ・期間指定イベント検索・Google Maps周辺立ち寄り検索・天気予報連携・夫婦リアルタイム同期・GPS連携）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/outing_spot.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../services/weather_service.dart';
import 'favorites_screen.dart';

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

  /// ドライブ地図下部のスポット一覧カードの表示・非表示フラグ
  bool _isMapListExpanded = true;

  /// AI検索中フラグ
  bool _isSearchingAi = false;

  /// AIからの要約コメント
  String _aiSummaryComment = '';

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
    _mapController?.dispose();
    super.dispose();
  }

  /// 夫婦間のローカル保存およびクラウド同期の初期化
  Future<void> _initCoupleSync() async {
    final code = await CoupleSyncService.getRoomCode();
    var savedFavs = await CoupleSyncService.loadLocalFavorites();

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
        final favIds = savedFavs.map((s) => s.id).toSet();
        _allSpots = _allSpots.map((spot) {
          if (favIds.contains(spot.id)) {
            final saved = savedFavs.firstWhere((s) => s.id == spot.id);
            return spot.copyWith(
              isFavorite: true,
              pickedBy: saved.pickedBy,
              coupleNote: saved.coupleNote,
            );
          }
          return spot;
        }).toList();
        for (final saved in savedFavs) {
          if (!_allSpots.any((s) => s.id == saved.id)) {
            _allSpots.add(saved.copyWith(isFavorite: true));
          }
        }
      }
    });

    _triggerCloudSync();
  }

  /// クラウド同期を実行する
  Future<void> _triggerCloudSync() async {
    setState(() => _syncStatusLabel = '同期中...');
    final localFavs = _favoriteSpots;
    final merged = await CoupleSyncService.syncWithCloud(
      roomCode: _coupleRoomCode,
      localFavorites: localFavs,
    );

    if (!mounted) return;
    if (merged != null) {
      final mergedIds = merged.map((s) => s.id).toSet();
      setState(() {
        _allSpots = _allSpots.map((spot) {
          if (mergedIds.contains(spot.id)) {
            final cloudSpot = merged.firstWhere((s) => s.id == spot.id);
            return spot.copyWith(
              isFavorite: true,
              pickedBy: cloudSpot.pickedBy,
              coupleNote: cloudSpot.coupleNote,
            );
          } else {
            return spot.copyWith(isFavorite: false);
          }
        }).toList();
        for (final cloudSpot in merged) {
          if (!_allSpots.any((s) => s.id == cloudSpot.id)) {
            _allSpots.add(cloudSpot.copyWith(isFavorite: true));
          }
        }
      });
    }

    final lastSync = await CoupleSyncService.getLastSyncLabel();
    if (!mounted) return;
    setState(() {
      _syncStatusLabel = lastSync;
    });
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
      if (_selectedTag != null && !spot.tags.contains(_selectedTag)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// お気に入り登録済みスポット一覧
  List<OutingSpot> get _favoriteSpots =>
      _allSpots.where((s) => s.isFavorite).toList();

  /// ジャンルボタンをタップしたときの検索
  Future<void> _selectGenreAndSearch(SpotCategory? category) async {
    setState(() {
      _selectedCategory = category;
      _selectedTag = null;
      _anchorSpot = null;
    });
    await _runAiSearch(null, category);
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

  /// お気に入りON/OFF切り替え
  Future<void> _toggleFavorite(OutingSpot target) async {
    setState(() {
      _allSpots = _allSpots.map((spot) {
        if (spot.id != target.id) return spot;
        final nextFav = !spot.isFavorite;
        return spot.copyWith(
          isFavorite: nextFav,
          pickedBy: nextFav ? (spot.pickedBy ?? PartnerPick.both) : spot.pickedBy,
        );
      }).toList();
      if (_selectedMapSpot?.id == target.id) {
        _selectedMapSpot = _allSpots.firstWhere((s) => s.id == target.id);
      }
      if (_anchorSpot?.id == target.id) {
        _anchorSpot = _allSpots.firstWhere((s) => s.id == target.id);
      }
    });

    await CoupleSyncService.saveLocalFavorites(_favoriteSpots);
    _triggerCloudSync();

    final updated = _allSpots.firstWhere((s) => s.id == target.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isFavorite
              ? '❤️ 「${updated.title}」を夫婦の行きたい！に追加しました'
              : '「${updated.title}」を行きたい！リストから外しました',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

    await CoupleSyncService.saveLocalFavorites(_favoriteSpots);
    _triggerCloudSync();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateLabel = GeminiOutingService.formatDateRange(_targetDateRange);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        title: Row(
          children: [
            const Text('🚗 ', style: TextStyle(fontSize: 22)),
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
          _buildExploreTab(context),
          _buildGoogleMapTab(context),
          FavoritesScreen(
            favoriteSpots: _favoriteSpots,
            coupleRoomCode: _coupleRoomCode,
            syncStatusLabel: _syncStatusLabel,
            onTriggerSync: _triggerCloudSync,
            onRoomCodeChanged: (code) async {
              setState(() => _coupleRoomCode = code);
              await CoupleSyncService.saveRoomCode(code);
              _triggerCloudSync();
            },
            onUpdateFavorite: _updateFavoriteDetail,
            onRemoveFavorite: _toggleFavorite,
            onOpenSpotDetail: (spot) => _showSpotDetailSheet(context, spot),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() => _currentTabIndex = index);
          if (index == 1 && _selectedMapSpot != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(_selectedMapSpot!.latitude, _selectedMapSpot!.longitude),
              ),
            );
          }
        },
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
            label: '夫婦の行きたい！',
          ),
        ],
      ),
    );
  }

  /// タブ1：東北6県タブ・期間指定・天気予報・ジャンル別スポット検索画面
  Widget _buildExploreTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = _filteredSpots;
    final dateRangeStr = GeminiOutingService.formatDateRange(_targetDateRange);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. フリーワード検索ボックス（全国・県外地名もそのまま検索可能）
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _runAiSearch(),
                  decoration: InputDecoration(
                    hintText: 'キーワードや県外地名で検索（例：那須 温泉、天童 公園）',
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
                          child: ChoiceChip(
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
                      ...SpotCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
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
                      ChoiceChip(
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
                      ActionChip(
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
                      FilterChip(
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
                      FilterChip(
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: '夫婦の行きたい！に追加',
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
                          ? '🌐 公式・元記事を見る（外部ブラウザ）'
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

              // 3段目：「この地図エリア周辺」ワンタップジャンル検索チップ
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMapGenreChip(SpotCategory.onsen, '♨️ 周辺の温泉・銭湯'),
                    _buildMapGenreChip(SpotCategory.sightseeing, '⛩️ 周辺の神社仏閣'),
                    _buildMapGenreChip(SpotCategory.park, '🏃 周辺の大きな公園'),
                    _buildMapGenreChip(SpotCategory.smallPark, '🌳 周辺の小さな公園'),
                    _buildMapGenreChip(SpotCategory.indoor, '🏛️ 周辺の屋内施設'),
                    _buildMapGenreChip(SpotCategory.gourmet, '🍠 周辺のグルメ・道の駅'),
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
                            '🚗 ${spot.driveTimeLabel} ｜ 📍 ${spot.address}',
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

  /// ドライブ地図上部のジャンルチップ1個分
  Widget _buildMapGenreChip(SpotCategory category, String label) {
    final isSelected = _mapAreaCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          label,
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
        ),
        visualDensity: VisualDensity.compact,
        onPressed: _isSearchingAi
            ? null
            : () => _runMapAreaSearch(category: category),
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
                      Chip(
                        avatar: Text(spot.category.icon),
                        label: Text(spot.category.label),
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
                        .map((t) => Chip(
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
                            ActionChip(
                              label: const Text('♨️ 近くの温泉・銭湯',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.onsen);
                              },
                            ),
                            ActionChip(
                              label: const Text('⛩️ 近くの神社仏閣',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.sightseeing);
                              },
                            ),
                            ActionChip(
                              label: const Text('🏃 近くの大きな公園',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.park);
                              },
                            ),
                            ActionChip(
                              label: const Text('🍠 近くのグルメ・道の駅',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _jumpToMapAndSearchNearby(
                                    spot, SpotCategory.gourmet);
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
                            ? '🌐 公式サイト・元記事を開く（外部ブラウザ）'
                            : '🔍 Webで最新情報を検索',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
