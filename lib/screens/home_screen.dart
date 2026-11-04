// ホーム画面（AI検索・タイプ別フィルタ・提案リスト・ドライブ圏内マップ表示）
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/outing_spot.dart';
import '../services/gemini_service.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 全スポットデータ（お気に入り状態を含む）
  late List<OutingSpot> _allSpots;

  /// 現在のボトムナビゲーションのタブ番号（0: 探す, 1: マップ, 2: 夫婦の行きたいリスト）
  int _currentTabIndex = 0;

  /// 出発エリア名
  String _departureArea = '現在地（自宅周辺）';

  /// 車での最大移動時間フィルタ（60分 or 120分）
  int _maxDriveMinutes = 120;

  /// 選択中の種別フィルタ（nullならすべて）
  SpotCategory? _selectedCategory;

  /// 選択中のタイプタグフィルタ（nullならすべて）
  SpotTag? _selectedTag;

  /// AI検索バーの入力コントローラ
  final TextEditingController _searchController = TextEditingController();

  /// AI検索中かどうかのフラグ
  bool _isSearchingAi = false;

  /// AIからの要約コメント
  String _aiSummaryComment =
      '📍 現在地から車で1〜2時間圏内で行ける「今週末の催し物」と「大型公園・観光地」を提案しています（すべて駐車場情報付き）。';

  /// マップ画面で選択中のスポット
  OutingSpot? _selectedMapSpot;

  /// 夫婦共有ルームの合言葉
  String _coupleRoomCode = 'family-weekend';

  @override
  void initState() {
    super.initState();
    _allSpots = GeminiOutingService.getInitialSpots();
    _selectedMapSpot = _allSpots.first;
  }

  @override
  void reassemble() {
    super.reassemble();
    _allSpots = GeminiOutingService.getInitialSpots();
    _selectedMapSpot = _allSpots.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 現在のフィルタ条件に合致するスポット一覧を取得する
  List<OutingSpot> get _filteredSpots {
    return _allSpots.where((spot) {
      if (spot.driveMinutes > _maxDriveMinutes) return false;
      if (_selectedCategory != null && spot.category != _selectedCategory) {
        return false;
      }
      if (_selectedTag != null && !spot.tags.contains(_selectedTag)) {
        return false;
      }
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        final matchTitle = spot.title.contains(query) ||
            spot.subtitle.contains(query) ||
            spot.recommendPoints.any((p) => p.contains(query));
        final matchFood = (query.contains('食') ||
                query.contains('グルメ') ||
                query.contains('マルシェ')) &&
            spot.tags.contains(SpotTag.food);
        final matchKids = (query.contains('子供') ||
                query.contains('遊具') ||
                query.contains('公園')) &&
            spot.tags.contains(SpotTag.kids);
        final matchRain =
            (query.contains('雨') || query.contains('室内')) &&
                spot.tags.contains(SpotTag.indoor);
        if (!matchTitle && !matchFood && !matchKids && !matchRain) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// お気に入り登録済みのスポット一覧を取得する
  List<OutingSpot> get _favoriteSpots =>
      _allSpots.where((s) => s.isFavorite).toList();

  /// Gemini AI検索を実行する
  Future<void> _runAiSearch([String? presetQuery]) async {
    if (presetQuery != null) {
      _searchController.text = presetQuery;
    }
    setState(() {
      _isSearchingAi = true;
    });

    final result = await GeminiOutingService.searchWithAi(
      query: _searchController.text,
      departureArea: _departureArea,
      maxDriveMinutes: _maxDriveMinutes,
      currentSpots: _allSpots,
    );

    if (!mounted) return;
    setState(() {
      _isSearchingAi = false;
      _aiSummaryComment = result.aiSummaryComment;
      if (_filteredSpots.isNotEmpty) {
        _selectedMapSpot = _filteredSpots.first;
      }
    });
  }

  /// お気に入り（夫婦の行きたい！リスト）のON/OFFを切り替える
  void _toggleFavorite(OutingSpot target) {
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

    final updated = _allSpots.firstWhere((s) => s.id == target.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isFavorite
              ? '❤️ 「${updated.title}」を夫婦の行きたいリストに追加しました！'
              : '「${updated.title}」を行きたいリストから外しました',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 夫婦のお気に入りステータスやメモを更新する
  void _updateFavoriteDetail(
      OutingSpot target, PartnerPick pickedBy, String note) {
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
                    '週末どこ行く？AIお出かけナビ',
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
          _buildMapTab(context),
          FavoritesScreen(
            favoriteSpots: _favoriteSpots,
            coupleRoomCode: _coupleRoomCode,
            onRoomCodeChanged: (code) {
              setState(() => _coupleRoomCode = code);
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
                      _buildQuickPromptChip('👨‍👩‍👧‍👦 子供が思いっきり遊べる大型公園'),
                      _buildQuickPromptChip('☔ 雨でも安心の屋内スポット'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 移動時間（車で1時間 or 1〜2時間）切り替え ＆ 種別フィルタ
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

                // カテゴリ（イベント / 大型公園 / 観光・道の駅）＆ タイプ別タグフィルタ
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
                            ? const Text('Gemini AIが今週末のイベント・公園情報を整理しています...')
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

  /// ワンタップでAI検索を実行する質問チップ
  Widget _buildQuickPromptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 12)),
        onPressed: () => _runAiSearch(text.substring(2).trim()),
      ),
    );
  }

  /// スポット・イベントの提案カード1件分
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
              // 最上部：種別バッジ ＋ 車での所要時間 ＋ お気に入りボタン
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
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: '夫婦の行きたい！リストに追加',
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

              // タイプ別タグ一覧（食べる系・子供向けなど）
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

              // 開催場所住所・開催日時・駐車場情報ボックス
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

              // AIおすすめポイント（3点）
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

              // 下部ボタン（地図で確認 / 詳細・共有）
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedMapSpot = spot;
                          _currentTabIndex = 1;
                        });
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
                      label: const Text('詳細・LINE共有'),
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

  /// タブ2：現在地から車で1時間・2時間圏内のインタラクティブ・ドライブマップ画面
  Widget _buildMapTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = _filteredSpots;
    final activeSpot = _selectedMapSpot ?? (spots.isNotEmpty ? spots.first : null);

    return Column(
      children: [
        // マップ上部の凡例バー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              const Icon(Icons.radar, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'ドライブ圏内マップ（内円:1h / 外円:2h）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.deepOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('イベント', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('公園・観光', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),

        // インタラクティブマップキャンバス
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight / 2,
              );
              final maxRadius =
                  math.min(constraints.maxWidth, constraints.maxHeight) * 0.42;

              return Stack(
                children: [
                  // 背景の地図グリッド＆1時間/2時間圏内サークル描画
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _DriveRadarMapPainter(
                      center: center,
                      maxRadius: maxRadius,
                      primaryColor: colorScheme.primary,
                    ),
                  ),

                  // 中央：現在地（自宅）ピン
                  Positioned(
                    left: center.dx - 44,
                    top: center.dy - 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home, size: 15, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '現在地',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 各スポットのピンを所要時間＆方角に応じて配置
                  ...spots.asMap().entries.map((entry) {
                    final index = entry.key;
                    final spot = entry.value;
                    final isSelected = activeSpot?.id == spot.id;
                    final isEvent = spot.category == SpotCategory.event;

                    // 所要時間（120分満点）を半径比率に変換し、方角を分散配置
                    final ratio = (spot.driveMinutes / 120.0).clamp(0.25, 1.0);
                    final angle = (index * (2 * math.pi / spots.length)) -
                        (math.pi / 3);
                    final pinX = center.dx + math.cos(angle) * maxRadius * ratio;
                    final pinY = center.dy + math.sin(angle) * maxRadius * ratio;

                    final maxLeft = math.max(8.0, constraints.maxWidth - 138);
                    final maxTop = math.max(8.0, constraints.maxHeight - 54);
                    return Positioned(
                      left: (pinX - 65).clamp(8.0, maxLeft),
                      top: (pinY - 22).clamp(8.0, maxTop),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedMapSpot = spot);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 10 : 8,
                            vertical: isSelected ? 6 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isEvent
                                    ? Colors.deepOrange.shade700
                                    : Colors.teal.shade700)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isEvent ? Colors.deepOrange : Colors.teal,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isSelected ? 0.28 : 0.12),
                                blurRadius: isSelected ? 8 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(spot.category.icon,
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 95),
                                child: Text(
                                  spot.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),

        // マップ下部の選択中スポット情報カード
        if (activeSpot != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                  '📍 ${activeSpot.address} / 🅿️ ${activeSpot.parkingInfo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showSpotDetailSheet(context, activeSpot),
                        icon: const Icon(Icons.article_outlined, size: 18),
                        label: const Text('おすすめ詳細を見る'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: activeSpot.googleMapsUrl),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🗺️ Googleマップ検索URLをコピーしました: ${activeSpot.title}',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: const Text('GoogleマップURL'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// スポットの詳細・AIワンポイントアドバイス・夫婦共有シートを表示する
  void _showSpotDetailSheet(BuildContext context, OutingSpot spot) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          maxChildSize: 0.92,
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
                  const SizedBox(height: 12),
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
                    title: const Text('開催日時・営業時間',
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
                  const SizedBox(height: 8),
                  const Text(
                    '✨ Gemini AIのおすすめポイント',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...spot.recommendPoints.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✔ ',
                                style: TextStyle(color: Colors.teal)),
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
                                'ドライブ＆混雑回避のワンポイント',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                spot.aiTip,
                                style: const TextStyle(fontSize: 13),
                              ),
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
                            spot.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.pink,
                          ),
                          label: Text(
                            spot.isFavorite
                                ? '夫婦リスト登録済み'
                                : '行きたい！に追加',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: spot.toShareText()),
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '📋 LINEで妻/夫に送れる紹介文＆GoogleマップURLをコピーしました！',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('LINE共有用コピー'),
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

  /// 出発エリア（自宅や現在地）を変更するダイアログ
  void _showDepartureAreaDialog(BuildContext context) {
    final controller = TextEditingController(text: _departureArea);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🚗 出発エリアの設定'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '出発地（市区町村や駅名など）',
              hintText: '例: さいたま市 / 横浜市 / 名古屋市',
              border: OutlineInputBorder(),
            ),
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

/// 1時間圏内・2時間圏内のドライブレーダーマップを描画するCustomPainter
class _DriveRadarMapPainter extends CustomPainter {
  final Offset center;
  final double maxRadius;
  final Color primaryColor;

  _DriveRadarMapPainter({
    required this.center,
    required this.maxRadius,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF3F7F4);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 地図風の道路グリッド線
    final gridPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 外円（車で2時間圏内）
    final outerFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final outerStroke = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, maxRadius, outerFill);
    canvas.drawCircle(center, maxRadius, outerStroke);

    // 内円（車で1時間圏内）
    final innerFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;
    final innerStroke = Paint()
      ..color = primaryColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, maxRadius * 0.5, innerFill);
    canvas.drawCircle(center, maxRadius * 0.5, innerStroke);
  }

  @override
  bool shouldRepaint(covariant _DriveRadarMapPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.maxRadius != maxRadius;
  }
}
