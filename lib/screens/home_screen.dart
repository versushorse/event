// ホーム画面（AI提案検索・年齢別フィルタ・持ち物チェック・Google Maps・夫婦リアルタイム同期・GPS現在地連携）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/outing_spot.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 全スポットデータ
  late List<OutingSpot> _allSpots;

  /// 現在のボトムナビタブ番号（0: 探す, 1: マップ, 2: 夫婦の行きたい）
  int _currentTabIndex = 0;

  /// 出発エリア名
  String _departureArea = '現在地を取得中...';

  /// 現在地の位置情報（GPS）
  LocationResult? _currentLocation;

  /// 現在地取得中フラグ
  bool _isLocating = false;

  /// 車での最大移動時間（60分 or 120分）
  int _maxDriveMinutes = 120;

  /// 選択中の種別フィルタ
  SpotCategory? _selectedCategory;

  /// 選択中のタイプタグフィルタ
  SpotTag? _selectedTag;

  /// AI検索バーの入力コントローラ
  final TextEditingController _searchController = TextEditingController();

  /// AI検索中フラグ
  bool _isSearchingAi = false;

  /// AIからの要約コメント
  String _aiSummaryComment = '';

  /// マップ画面で選択中のスポット
  OutingSpot? _selectedMapSpot;

  /// 夫婦共有ルームの合言葉
  String _coupleRoomCode = 'family-weekend';

  /// 夫婦同期のステータス文字列
  String _syncStatusLabel = '確認中...';

  /// Googleマップコントローラ
  GoogleMapController? _mapController;

  /// Googleマップの表示タイプ（通常 or 航空写真）
  MapType _currentMapType = MapType.normal;

  /// ドライブ持ち物チェックリストの状態
  final Map<String, bool> _packingList = {
    'レジャーシート・ミニテント': true,
    '子供の着替え（1〜2回分）': true,
    'オムツ・おしりふき（乳幼児）': false,
    '水筒・飲み物・おやつ': true,
    'ビニール袋（ゴミ・濡れ物用）': true,
    'タオル・ウェットティッシュ': true,
    '羽織る上着・防寒着': false,
    '虫除け・日焼け止め': false,
  };

  @override
  void initState() {
    super.initState();
    _allSpots = GeminiOutingService.getInitialSpots();
    _selectedMapSpot = _allSpots.first;
    _aiSummaryComment =
        '📍 現在地から車で1〜2時間圏内で行ける、今週末（${GeminiOutingService.getThisWeekendDates()}）の最新催し物・大型公園を提案しています。';
    _initCoupleSync();
    _fetchCurrentLocation(autoFetch: true);
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

      // マップカメラを現在地にフォーカス
      if (moveMap && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(loc.latitude, loc.longitude),
              zoom: 11.5,
            ),
          ),
        );
      }

      if (!autoFetch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 現在地（${loc.label}）を取得しました！お出かけ時間を更新しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _isLocating = false;
        if (_departureArea == '現在地を取得中...') {
          _departureArea = '現在地（東京・神奈川・埼玉・千葉）';
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

    // 距離が近い順に並び替え
    _allSpots.sort((a, b) => a.driveMinutes.compareTo(b.driveMinutes));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// 夫婦間のローカル保存およびクラウド同期の初期化
  Future<void> _initCoupleSync() async {
    final code = await CoupleSyncService.getRoomCode();
    final savedFavs = await CoupleSyncService.loadLocalFavorites();

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
      }
    });

    // バックグラウンドでクラウド最新データを取得
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
      });
    }

    final lastSync = await CoupleSyncService.getLastSyncLabel();
    if (!mounted) return;
    setState(() {
      _syncStatusLabel = lastSync;
    });
  }

  /// フィルタ条件に合致するスポット一覧
  List<OutingSpot> get _filteredSpots {
    final withinTime = _allSpots.where((spot) {
      if (_selectedCategory != null && spot.category != _selectedCategory) {
        return false;
      }
      if (_selectedTag != null && !spot.tags.contains(_selectedTag)) {
        return false;
      }
      // Google Places API等のライブ検索結果が含まれている場合はAPI側で検索済みのためそのまま通す
      if (spot.id.startsWith('google_place_')) {
        return true;
      }
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        final matchTitle = spot.title.contains(query) ||
            spot.subtitle.contains(query) ||
            spot.recommendPoints.any((p) => p.contains(query));
        final matchFood = (query.contains('食') || query.contains('グルメ') || query.contains('マルシェ')) && spot.tags.contains(SpotTag.food);
        final matchBaby = (query.contains('赤ちゃん') || query.contains('0歳') || query.contains('1歳') || query.contains('2歳')) && spot.tags.contains(SpotTag.baby);
        final matchKids = (query.contains('子供') || query.contains('遊具') || query.contains('アスレチック')) && (spot.tags.contains(SpotTag.kids) || spot.tags.contains(SpotTag.toddler));
        final matchRain = (query.contains('雨') || query.contains('室内')) && spot.tags.contains(SpotTag.indoor);
        if (!matchTitle && !matchFood && !matchBaby && !matchKids && !matchRain) {
          return false;
        }
      }
      return true;
    }).toList();

    final timeFiltered = withinTime.where((s) => s.driveMinutes <= _maxDriveMinutes).toList();
    return timeFiltered.isNotEmpty ? timeFiltered : withinTime;
  }

  /// お気に入り登録済みスポット一覧
  List<OutingSpot> get _favoriteSpots =>
      _allSpots.where((s) => s.isFavorite).toList();

  /// AI検索＆Google APIリアルタイム検索を実行する
  Future<void> _runAiSearch([String? presetQuery]) async {
    if (presetQuery != null) {
      _searchController.text = presetQuery;
    }
    setState(() {
      _isSearchingAi = true;
    });

    final currentFavs = List<OutingSpot>.from(_favoriteSpots);

    final result = await GeminiOutingService.searchWithAi(
      query: _searchController.text,
      departureArea: _departureArea,
      maxDriveMinutes: _maxDriveMinutes,
      currentSpots: _allSpots,
      userLat: _currentLocation?.latitude,
      userLng: _currentLocation?.longitude,
    );

    if (!mounted) return;
    setState(() {
      _isSearchingAi = false;
      _aiSummaryComment = result.aiSummaryComment;
      if (result.isLiveAi) {
        final favMap = {for (final f in currentFavs) f.id: f};
        final mergedSpots = <OutingSpot>[];
        final addedIds = <String>{};

        for (final s in result.spots) {
          addedIds.add(s.id);
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
        // 既存のお気に入りで今回の検索結果に含まれなかったものも保持（夫婦ボードから消えないように）
        for (final fav in currentFavs) {
          if (!addedIds.contains(fav.id)) {
            mergedSpots.add(fav);
          }
        }
        _allSpots = mergedSpots;
      }
      if (_filteredSpots.isNotEmpty) {
        _selectedMapSpot = _filteredSpots.first;
      }
    });
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
    });

    // ローカル保存＆クラウド同期
    await CoupleSyncService.saveLocalFavorites(_favoriteSpots);
    _triggerCloudSync();

    final updated = _allSpots.firstWhere((s) => s.id == target.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isFavorite
              ? '❤️ 「${updated.title}」を夫婦共有ボードに追加しました！'
              : '「${updated.title}」を共有ボードから外しました',
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                    '出発: $_departureArea（車で1〜2時間圏内）',
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

  /// タブ1：AI検索＆おすすめ提案カードリスト画面
  Widget _buildExploreTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = _filteredSpots;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI検索入力ボックス
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _runAiSearch(),
                  decoration: InputDecoration(
                    hintText: 'AIに相談（例：子供が喜ぶ遊具と美味しいもの）',
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
                              _runAiSearch('');
                            },
                            icon: const Icon(Icons.clear, size: 20),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilledButton(
                            onPressed: _isSearchingAi ? null : () => _runAiSearch(),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              minimumSize: const Size(60, 38),
                            ),
                            child: const Text('AI検索'),
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

                // ワンタップAI質問チップ
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickPromptChip('🍔 今週末のグルメ・マルシェ'),
                      _buildQuickPromptChip('👶 0〜2歳の赤ちゃんとお散歩'),
                      _buildQuickPromptChip('🏃 小学生も夢中の巨大アスレチック'),
                      _buildQuickPromptChip('☔ 雨でも安心の屋内スポット'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 移動時間切り替え
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'ドライブ圏内:',
                        style:
                            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('🚗 1時間以内'),
                        selected: _maxDriveMinutes == 60,
                        onSelected: (_) {
                          setState(() => _maxDriveMinutes = 60);
                          _runAiSearch();
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('🚗 1〜2時間圏内'),
                        selected: _maxDriveMinutes == 120,
                        onSelected: (_) {
                          setState(() => _maxDriveMinutes = 120);
                          _runAiSearch();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // カテゴリ＆子供の年齢別・タイプ別タグフィルタ
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('すべて'),
                        selected:
                            _selectedCategory == null && _selectedTag == null,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = null;
                            _selectedTag = null;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ...SpotCategory.values.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Text(cat.icon),
                            label: Text(cat.label),
                            selected: _selectedCategory == cat,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory =
                                    _selectedCategory == cat ? null : cat;
                              });
                            },
                          ),
                        );
                      }),
                      ...SpotTag.values.map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Text(tag.icon),
                            label: Text(tag.label),
                            selected: _selectedTag == tag,
                            onSelected: (_) {
                              setState(() {
                                _selectedTag =
                                    _selectedTag == tag ? null : tag;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

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
                            ? const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Gemini 3.8 Flash がGoogle検索で今週末の最新イベントを調べています...',
                                      style: TextStyle(
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
                          _maxDriveMinutes = 120;
                          _searchController.clear();
                        });
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

  Widget _buildQuickPromptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 12)),
        onPressed: () => _runAiSearch(text.substring(2).trim()),
      ),
    );
  }

  /// スポット提案カード1件分
  Widget _buildSpotCard(BuildContext context, OutingSpot spot) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEvent = spot.category == SpotCategory.event;

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
              // 最上部：種別バッジ ＋ 所要時間 ＋ 天気予報 ＋ ハートボタン
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car,
                            size: 14, color: colorScheme.onPrimaryContainer),
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
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      spot.weatherText.split(' ').first,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: '夫婦共有ボードに追加',
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

              // タイプ別・子供年齢別タグ一覧
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

              // おすすめポイント（3点）
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

              // 下部ボタン（マップへ移動 / 詳細・共有）
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedMapSpot = spot;
                          _currentTabIndex = 1;
                        });
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(spot.latitude, spot.longitude),
                            12.5,
                          ),
                        );
                      },
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

  /// タブ2：Google Maps SDK による本格地図画面
  Widget _buildGoogleMapTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = _filteredSpots;
    final activeSpot = _selectedMapSpot ?? (spots.isNotEmpty ? spots.first : null);

    // 各スポットのピン（マーカー）を作成
    final markers = <Marker>{};
    for (final spot in spots) {
      final isSelected = activeSpot?.id == spot.id;
      final isEvent = spot.category == SpotCategory.event;

      markers.add(
        Marker(
          markerId: MarkerId(spot.id),
          position: LatLng(spot.latitude, spot.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isEvent
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueCyan,
          ),
          infoWindow: InfoWindow(
            title: '${spot.category.icon} ${spot.title}',
            snippet: '${spot.driveTimeLabel} / 🅿️ ${spot.parkingInfo}',
          ),
          zIndexInt: isSelected ? 2 : 1,
          onTap: () {
            setState(() => _selectedMapSpot = spot);
          },
        ),
      );
    }

    final initialCenter = _currentLocation != null
        ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
        : (activeSpot != null
            ? LatLng(activeSpot.latitude, activeSpot.longitude)
            : const LatLng(35.75, 139.65));

    return Stack(
      children: [
        // 本物の Google Maps ウィジェット
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialCenter,
            zoom: 10.0,
          ),
          mapType: _currentMapType,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
          },
        ),

        // マップ上部：凡例 ＆ 地図タイプ（通常/衛星写真）切り替えボタン
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('イベント', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('公園・観光', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentMapType = _currentMapType == MapType.normal
                          ? MapType.hybrid
                          : MapType.normal;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentMapType == MapType.normal ? Icons.satellite_alt : Icons.map,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentMapType == MapType.normal ? '航空写真' : '地図',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // マップ下部：選択中スポットのフロート詳細カード
        if (activeSpot != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${activeSpot.category.icon} ${activeSpot.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          activeSpot.driveTimeLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${activeSpot.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '🅿️ ${activeSpot.parkingInfo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showSpotDetailSheet(context, activeSpot),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text('おすすめ詳細'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _launchGoogleMaps(activeSpot),
                            icon: const Icon(Icons.navigation, size: 16),
                            label: const Text('ナビ開始'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // マップ右側：現在地へ戻るボタン
        Positioned(
          right: 16,
          bottom: activeSpot != null ? 190 : 20,
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

  /// スポット詳細＆AIアドバイスシート
  void _showSpotDetailSheet(BuildContext context, OutingSpot spot) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.94,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        avatar: Text(spot.category.icon),
                        label: Text(spot.category.label),
                      ),
                      const SizedBox(width: 8),
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
                    title: const Text('開催場所・住所', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.address),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('開催日程・営業時間', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.scheduleText),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('今週末の天気予報', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.weatherText),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_parking),
                    title: const Text('駐車場・アクセス情報', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.parkingInfo),
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
                            const Text('✔ ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(p)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 18)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ドライブ＆混雑回避のアドバイス',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(spot.aiTip, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _toggleFavorite(spot);
                            Navigator.of(sheetContext).pop();
                          },
                          icon: Icon(
                            spot.isFavorite ? Icons.favorite : Icons.favorite_border,
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
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                          decoration: isChecked ? TextDecoration.lineThrough : null,
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
                  hintText: '例: さいたま市 / 横浜市 / 世田谷区',
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
