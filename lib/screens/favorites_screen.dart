// 夫婦間で共有する「ここ行きたい！」＆「💮 行ったよ！思い出スタンプ帳」画面
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/outing_spot.dart';
import '../services/monetization_service.dart';
import '../services/sync_service.dart';

class FavoritesScreen extends StatefulWidget {
  final List<OutingSpot> favoriteSpots;
  final String coupleRoomCode;
  final ValueChanged<String> onRoomCodeChanged;
  final void Function(OutingSpot spot, PartnerPick pickedBy, String note)
      onUpdateFavorite;
  final ValueChanged<OutingSpot>? onUpdateVisitedSpot;
  final ValueChanged<OutingSpot> onRemoveFavorite;
  final ValueChanged<OutingSpot> onOpenSpotDetail;
  final VoidCallback onTriggerSync;
  final String syncStatusLabel;
  final PartnerPick myRole;
  final ValueChanged<PartnerPick>? onChangeMyRole;
  final bool isPremium;
  final VoidCallback? onOpenPremium;

  const FavoritesScreen({
    super.key,
    required this.favoriteSpots,
    required this.coupleRoomCode,
    required this.onRoomCodeChanged,
    required this.onUpdateFavorite,
    this.onUpdateVisitedSpot,
    required this.onRemoveFavorite,
    required this.onOpenSpotDetail,
    required this.onTriggerSync,
    required this.syncStatusLabel,
    this.myRole = PartnerPick.husband,
    this.onChangeMyRole,
    this.isPremium = false,
    this.onOpenPremium,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  SpotCategory? _selectedCategoryFilter;
  bool _onlyVisitedFilter = false;
  bool _onlyFavoritesFilter = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visitedCount =
        widget.favoriteSpots.where((s) => s.isVisited).length;
    final favoritesCount =
        widget.favoriteSpots.where((s) => !s.isVisited).length;

    final filteredSpots = widget.favoriteSpots.where((s) {
      if (_onlyVisitedFilter && !s.isVisited) return false;
      if (_onlyFavoritesFilter && s.isVisited) return false;
      if (_selectedCategoryFilter != null &&
          s.category != _selectedCategoryFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 夫婦のリアルタイム共有ルーム情報ヘッダー
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.9),
                colorScheme.secondaryContainer.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💖', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '行きたい！リスト ＆ 思い出スタンプ帳',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '合言葉: ${widget.coupleRoomCode}（同期: ${widget.syncStatusLabel}）',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.favoriteSpots.isNotEmpty)
                    IconButton.filledTonal(
                      tooltip: '🎰 行きたい候補からルーレット抽選！',
                      onPressed: () => _showFavoritesRouletteDialog(context),
                      icon: const Text('🎰', style: TextStyle(fontSize: 16)),
                    ),
                  IconButton.filledTonal(
                    tooltip: '今すぐ同期',
                    onPressed: widget.onTriggerSync,
                    icon: const Icon(Icons.sync, size: 18),
                  ),
                  IconButton(
                    tooltip: 'LINE等で共有',
                    onPressed: () {
                      final shareText =
                          CoupleSyncService.exportFavoritesShareText(
                        widget.favoriteSpots,
                        widget.coupleRoomCode,
                      );
                      Clipboard.setData(ClipboardData(text: shareText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '📋 お気に入り＆思い出一覧をコピーしました！LINEに貼り付けて共有できます',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                  ),
                  IconButton(
                    tooltip: '合言葉を変更',
                    onPressed: () => _showRoomCodeDialog(context),
                    icon: const Icon(Icons.key, size: 18),
                  ),
                ],
              ),
              if (!widget.isPremium) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: widget.onOpenPremium,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('👑 ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(
                            'フリー保存枠: ${widget.favoriteSpots.length} / ${MonetizationService.freeMaxFavorites}件',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '無制限にする ➔',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 1段目：お気に入り・💮行ったよ！スタンプ帳の絞り込みチップ
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text('すべて (${widget.favoriteSpots.length})'),
                selected: !_onlyFavoritesFilter && !_onlyVisitedFilter,
                onSelected: (_) => setState(() {
                  _onlyFavoritesFilter = false;
                  _onlyVisitedFilter = false;
                }),
              ),
              const SizedBox(width: 8),
              FilterChip(
                visualDensity: VisualDensity.compact,
                avatar: const Text('❤️'),
                label: Text('行きたい！ ($favoritesCount)'),
                selected: _onlyFavoritesFilter,
                selectedColor: Colors.pink.shade100,
                onSelected: (val) => setState(() {
                  _onlyFavoritesFilter = val;
                  if (val) _onlyVisitedFilter = false;
                }),
              ),
              const SizedBox(width: 8),
              FilterChip(
                visualDensity: VisualDensity.compact,
                avatar: const Text('💮'),
                label: Text('行ったよ！思い出 ($visitedCount)'),
                selected: _onlyVisitedFilter,
                selectedColor: Colors.orange.shade100,
                onSelected: (val) => setState(() {
                  _onlyVisitedFilter = val;
                  if (val) _onlyFavoritesFilter = false;
                }),
              ),
            ],
          ),
        ),

        // 2段目：ジャンル別フィルターボタン（食事処・観光地・温泉・公園など）
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Row(
            children: [
              FilterChip(
                visualDensity: VisualDensity.compact,
                label: const Text('📂 全ジャンル'),
                selected: _selectedCategoryFilter == null,
                selectedColor: colorScheme.primaryContainer,
                onSelected: (_) => setState(() {
                  _selectedCategoryFilter = null;
                }),
              ),
              const SizedBox(width: 6),
              ...SpotCategory.values.where((cat) => cat != SpotCategory.gourmet).map((cat) {
                final count = widget.favoriteSpots
                    .where((s) => s.category == cat)
                    .length;
                final isSelected = _selectedCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Text(cat.icon),
                    label: Text('${cat.label} ($count)'),
                    selected: isSelected,
                    selectedColor: colorScheme.primaryContainer,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategoryFilter = isSelected ? null : cat;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        // お気に入りカード一覧
        Expanded(
          child: filteredSpots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _onlyVisitedFilter
                              ? Icons.verified_outlined
                              : Icons.favorite_border,
                          size: 56,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _onlyVisitedFilter
                              ? 'まだ「💮 行ったよ！」スタンプがありません'
                              : 'まだ「行きたい！」スポットがありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _onlyVisitedFilter
                              ? '実際にお出かけしたスポットの「💮 行ったよ！」ボタンを押すと、家族の思い出スタンプ帳として記録されます！'
                              : '奥様または旦那様がハートボタンを押すと、自動的に2人のスマホに候補が同期されます！',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filteredSpots.length,
                  itemBuilder: (context, index) {
                    final spot = filteredSpots[index];
                    return _buildFavoriteCard(context, spot);
                  },
                ),
        ),
      ],
    );
  }

  /// お気に入りスポット1件分のカードUI
  Widget _buildFavoriteCard(BuildContext context, OutingSpot spot) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpenSpotDetail(spot),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 夫婦ステータスバッジ ＆ 💮行ったよバッジ ＆ 削除ボタン
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (spot.isVisited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.deepOrange.shade300),
                            ),
                            child: Text(
                              '💮 行ったよ！ ${spot.visitedDate} (${"★" * spot.visitedRating})',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade900,
                              ),
                            ),
                          ),
                        if (!spot.isVisited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.pink.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.pink.shade200),
                            ),
                            child: const Text(
                              '❤️ 行きたい！',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC2185B),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${spot.category.icon} ${spot.category.label}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '候補から外す',
                    onPressed: () => widget.onRemoveFavorite(spot),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // タイトル・開催場所住所・所要時間
              Text(
                spot.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '📍 ${spot.address}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${spot.driveTimeLabel}（約${spot.distanceKm.toStringAsFixed(0)}km）',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    spot.weatherText.split(' ').first,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 💮 行ったよ！思い出メモ（記録済みの場合に表示）
              if (spot.isVisited) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text('💮', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          spot.visitedMemory.isEmpty
                              ? '家族でお出かけ達成！（${spot.visitedDate}）'
                              : '思い出（${spot.visitedDate}）: ${spot.visitedMemory}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepOrange.shade900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _showVisitedStampDialog(context, spot),
                        child: const Text('編集'),
                      ),
                    ],
                  ),
                ),
              ],

              // 💬 Googleマップのレビュー・評価枠（ある場合は別枠で表示）
              if (spot.hasGoogleReviewData) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('💬 ', style: TextStyle(fontSize: 14)),
                          Text(
                            'Googleマップのレビュー',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          if (spot.googleRatingBadgeText.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                spot.googleRatingBadgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (spot.googleReviews.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...spot.googleReviews.take(2).map(
                              (rev) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '・$rev',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ],

              // 夫婦のひとことメモ欄
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 18, color: Colors.brown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        spot.coupleNote.isEmpty
                            ? 'メモを追加（例：土曜の午前中に出発しよう！）'
                            : spot.coupleNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: spot.coupleNote.isEmpty
                              ? Colors.brown.shade400
                              : Colors.brown.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showEditFavoriteDialog(context, spot),
                      child: const Text('編集'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 公式サイト・元記事リンクボタン
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(spot.officialWebUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
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

              // 💮行ったよスタンプ ＆ メモ編集 ＆ LINE共有ボタン
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showVisitedStampDialog(context, spot),
                      icon: const Text('💮', style: TextStyle(fontSize: 14)),
                      label: Text(
                        spot.isVisited ? '思い出編集' : '行ったよ！',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditFavoriteDialog(context, spot),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label:
                          const Text('メモ編集', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: spot.toShareText()),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '📋 LINE等で送れる紹介テキスト＆マップURLをコピーしました！',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, size: 16),
                      label:
                          const Text('LINE共有', style: TextStyle(fontSize: 12)),
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

  /// 💮 行ったよ！思い出スタンプ登録・編集ダイアログ（案C）
  void _showVisitedStampDialog(BuildContext context, OutingSpot spot) {
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
              title: Text('💮「${spot.title}」行ったよスタンプ'),
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'お出かけした日',
                        hintText: '例: 2026/11/08',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: memoryCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '家族の思い出ひとことメモ',
                        hintText: '例：アスレチックが最高！帰りに寄った温泉も気持ちよかった♨️',
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
                    if (widget.onUpdateVisitedSpot != null) {
                      widget.onUpdateVisitedSpot!(updated);
                    }
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('スタンプを保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 🎰 お気に入り候補の中からおみくじルーレット抽選（案D）
  void _showFavoritesRouletteDialog(BuildContext context) {
    final candidates =
        widget.favoriteSpots.where((s) => !s.isVisited).toList();
    final pool = candidates.isNotEmpty ? candidates : widget.favoriteSpots;
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
                  Expanded(child: Text('週末どこ行く？ルーレット！')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '行きたい候補から選ばれた今週末の行き先は…',
                    style: TextStyle(fontSize: 12.5),
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
                            style: const TextStyle(fontSize: 36)),
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
                          '📍 ${picked.address}（${picked.driveTimeLabel}）',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
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
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    widget.onOpenSpotDetail(picked);
                  },
                  child: const Text('詳細を見る'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditFavoriteDialog(BuildContext context, OutingSpot spot) {
    final noteController = TextEditingController(text: spot.coupleNote);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('「${spot.title}」のメモ設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ひとことメモ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '例：土曜のお昼に行きたい！レジャーシート持参で',
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
                    widget.onUpdateFavorite(
                      spot,
                      spot.pickedBy ?? PartnerPick.me,
                      noteController.text.trim(),
                    );
                    Navigator.of(dialogContext).pop();
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

  void _showRoomCodeDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.coupleRoomCode);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('👥 共有合言葉の設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '家族やパートナーのスマホと同じ「合言葉」を設定すると、追加した候補や旅のしおり・思い出スタンプが自動でリアルタイム共有されます。（1人で使う場合はこのままでOK）',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '共有ルーム合言葉',
                  hintText: '例: family-weekend',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_outlined,
                        size: 20, color: Colors.blue.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'クラウド自動同期エンジンが稼働中です。相手のスマホでも同じ合言葉を入力して「今すぐ同期」を押してください。',
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
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
                  widget.onRoomCodeChanged(controller.text.trim());
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('設定＆同期'),
            ),
          ],
        );
      },
    );
  }
}
