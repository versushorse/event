// 夫婦間で共有する「ここ行きたい！」リアルタイム同期お気に入りリスト画面
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/outing_spot.dart';
import '../services/sync_service.dart';

class FavoritesScreen extends StatefulWidget {
  final List<OutingSpot> favoriteSpots;
  final String coupleRoomCode;
  final ValueChanged<String> onRoomCodeChanged;
  final void Function(OutingSpot spot, PartnerPick pickedBy, String note)
      onUpdateFavorite;
  final ValueChanged<OutingSpot> onRemoveFavorite;
  final ValueChanged<OutingSpot> onOpenSpotDetail;
  final VoidCallback onTriggerSync;
  final String syncStatusLabel;

  const FavoritesScreen({
    super.key,
    required this.favoriteSpots,
    required this.coupleRoomCode,
    required this.onRoomCodeChanged,
    required this.onUpdateFavorite,
    required this.onRemoveFavorite,
    required this.onOpenSpotDetail,
    required this.onTriggerSync,
    required this.syncStatusLabel,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  PartnerPick? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredSpots = _selectedFilter == null
        ? widget.favoriteSpots
        : widget.favoriteSpots
            .where((s) => s.pickedBy == _selectedFilter)
            .toList();

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
                  const Text('💑', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '夫婦のリアルタイム共有ボード',
                          style: TextStyle(
                            fontSize: 15,
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
                            '📋 お気に入り一覧をコピーしました！LINEやメッセージに貼り付けて共有できます',
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
            ],
          ),
        ),

        // 誰が気になるかの絞り込みチップ
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: Text('すべて (${widget.favoriteSpots.length})'),
                selected: _selectedFilter == null,
                onSelected: (_) => setState(() => _selectedFilter = null),
              ),
              const SizedBox(width: 8),
              ...PartnerPick.values.map((pick) {
                final count = widget.favoriteSpots
                    .where((s) => s.pickedBy == pick)
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Text(pick.icon),
                    label: Text('${pick.label} ($count)'),
                    selected: _selectedFilter == pick,
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter =
                            _selectedFilter == pick ? null : pick;
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
                          Icons.favorite_border,
                          size: 56,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'まだ「行きたい！」スポットがありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '奥様または旦那様がハートボタンを押すと、自動的に2人のスマホに候補が同期されます！',
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

  /// 夫婦のお気に入りスポット1件分のカードUI
  Widget _buildFavoriteCard(BuildContext context, OutingSpot spot) {
    final colorScheme = Theme.of(context).colorScheme;
    final pick = spot.pickedBy ?? PartnerPick.both;

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
              // 夫婦ステータスバッジ ＆ 削除ボタン
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
                            color: pick == PartnerPick.both
                                ? Colors.pink.shade50
                                : colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: pick == PartnerPick.both
                                  ? Colors.pink.shade200
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${pick.icon} ${pick.label}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: pick == PartnerPick.both
                                  ? Colors.pink.shade800
                                  : colorScheme.onSecondaryContainer,
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
                            ? '夫婦メモを追加（例：土曜の午前中に出発しよう！）'
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
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(
                      spot.url.isNotEmpty ? '🌐 公式・元記事を見る（外部ブラウザ）' : '🔍 Webで最新情報を検索',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              // LINE共有＆ステータス変更ボタン
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditFavoriteDialog(context, spot),
                      icon: const Icon(Icons.people_alt_outlined, size: 18),
                      label: const Text('設定・メモ'),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('LINEで共有'),
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

  void _showEditFavoriteDialog(BuildContext context, OutingSpot spot) {
    var selectedPick = spot.pickedBy ?? PartnerPick.both;
    final noteController = TextEditingController(text: spot.coupleNote);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('「${spot.title}」の共有設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '誰の行きたい候補ですか？',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PartnerPick.values.map((pick) {
                      return ChoiceChip(
                        avatar: Text(pick.icon),
                        label: Text(pick.label),
                        selected: selectedPick == pick,
                        onSelected: (_) {
                          setDialogState(() => selectedPick = pick);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '夫婦のひとことメモ',
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
                      selectedPick,
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
          title: const Text('💑 夫婦の共有合言葉の設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ご夫婦の2台のAndroidスマホで同じ「合言葉」を設定すると、どちらかが追加した候補やメモが自動でリアルタイム同期されます。',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '家族ルーム合言葉',
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
