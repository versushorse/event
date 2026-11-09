// 家族の旅のしおり＆スケジュール作成画面（大阪・名古屋などの県外旅行＆週末ドライブ対応）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/outing_spot.dart';
import '../services/gemini_service.dart';

class TripPlannerScreen extends StatefulWidget {
  final List<TripPlan> tripPlans;
  final int selectedTripIndex;
  final ValueChanged<int> onSelectTrip;
  final ValueChanged<List<TripPlan>> onUpdateTrips;
  final String coupleRoomCode;
  final VoidCallback onTriggerSync;

  const TripPlannerScreen({
    super.key,
    required this.tripPlans,
    required this.selectedTripIndex,
    required this.onSelectTrip,
    required this.onUpdateTrips,
    required this.coupleRoomCode,
    required this.onTriggerSync,
  });

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  int _selectedDay = 1;
  bool _isGeneratingAi = false;

  TripPlan get _currentPlan {
    if (widget.tripPlans.isEmpty) {
      return TripPlan.createOsakaNagoyaStarter();
    }
    final idx = widget.selectedTripIndex.clamp(0, widget.tripPlans.length - 1);
    return widget.tripPlans[idx];
  }

  void _saveUpdatedPlan(TripPlan updated) {
    final list = List<TripPlan>.from(widget.tripPlans);
    if (list.isEmpty) {
      list.add(updated);
    } else {
      final idx = widget.selectedTripIndex.clamp(0, list.length - 1);
      list[idx] = updated;
    }
    widget.onUpdateTrips(list);
  }

  Future<void> _launchWebUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🌐 URLをコピーしました！ブラウザに貼り付けて開けます')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plan = _currentPlan;
    final activeDay = _selectedDay.clamp(1, plan.totalDays);
    final dayItems =
        plan.items.where((i) => i.dayNumber == activeDay).toList();

    return Column(
      children: [
        // 上部ヘッダー：しおり選択 ＆ 新規作成・AI作成・共有バー
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade50,
                Colors.amber.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // しおり切り替えドロップダウン ＆ 同期ボタン
              Row(
                children: [
                  const Text('📒', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: widget.selectedTripIndex
                            .clamp(0, (widget.tripPlans.length - 1).clamp(0, 99)),
                        items: List.generate(widget.tripPlans.length, (i) {
                          final p = widget.tripPlans[i];
                          return DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDay = 1);
                            widget.onSelectTrip(val);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'しおりタイトル・日数を編集',
                    onPressed: () => _showEditPlanHeaderDialog(context, plan),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'スマホ間で同期',
                    onPressed: widget.onTriggerSync,
                    icon: const Icon(Icons.sync, size: 20),
                  ),
                ],
              ),
              if (plan.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    plan.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.brown.shade700,
                    ),
                  ),
                ),

              // アクションボタン群（新規しおり / AI自動生成 / LINE共有 / TimeTree・カレンダー）
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('新しいしおり', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showCreateNewPlanDialog(context),
                  ),
                  ActionChip(
                    avatar: _isGeneratingAi
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('🤖'),
                    label: Text(
                      _isGeneratingAi ? 'AI作成中...' : 'AIで旅行プラン作成',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.amber.shade100,
                    onPressed: _isGeneratingAi
                        ? null
                        : () => _showAiGeneratorSheet(context),
                  ),
                  ActionChip(
                    avatar: const Text('🌲'),
                    label: const Text('TimeTree・カレンダー連携',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.teal.shade50,
                    onPressed: () =>
                        _showCalendarAndTimeTreeSheet(context, plan, activeDay),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.share, size: 15),
                    label: const Text('LINE共有コピー',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: plan.toShareText()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '📋 旅のしおり全文をコピーしました！LINEやメモ帳にそのまま貼り付けられます'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Day 1 / Day 2 / Day 3... タブバー ＋ 「＋予定を追加」ボタン
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int d = 1; d <= plan.totalDays; d++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              'Day $d (${plan.items.where((i) => i.dayNumber == d).length})',
                              style: TextStyle(
                                fontWeight: activeDay == d
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: activeDay == d,
                            onSelected: (_) =>
                                setState(() => _selectedDay = d),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 15),
                        label: const Text('日数を追加',
                            style: TextStyle(fontSize: 11.5)),
                        onPressed: () {
                          final newDays = (plan.totalDays + 1).clamp(1, 10);
                          _saveUpdatedPlan(plan.copyWith(totalDays: newDays));
                          setState(() => _selectedDay = newDays);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () =>
                    _showAddOrEditItemDialog(context, plan, activeDay, null),
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('予定を追加', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),

        // タイムライン一覧
        Expanded(
          child: dayItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_outlined,
                            size: 52, color: colorScheme.outline),
                        const SizedBox(height: 10),
                        Text(
                          'Day $activeDay の予定がまだありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '右上の「＋予定を追加」から自由に時間や場所を入れるか、「🤖 AIで旅行プラン作成」から大阪・名古屋などのモデルコースを作れます！',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _showAddOrEditItemDialog(
                              context, plan, activeDay, null),
                          icon: const Icon(Icons.add),
                          label: Text('Day $activeDay に予定を追加する'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  itemCount: dayItems.length,
                  itemBuilder: (context, idx) {
                    final item = dayItems[idx];
                    return _buildTimelineItemCard(
                      context,
                      plan: plan,
                      item: item,
                      indexInDay: idx,
                      totalInDay: dayItems.length,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 1コマ分のタイムライン予定カード
  Widget _buildTimelineItemCard(
    BuildContext context, {
    required TripPlan plan,
    required TripScheduleItem item,
    required int indexInDay,
    required int totalInDay,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            _showAddOrEditItemDialog(context, plan, item.dayNumber, item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側：時刻 ＆ 種別アイコン
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.timeText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.type.icon, style: const TextStyle(fontSize: 24)),
                ],
              ),
              const SizedBox(width: 12),

              // 中央：タイトル・場所・メモ・リンク
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.type.label,
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          final q = Uri.encodeComponent(
                              '${item.title} ${item.location}');
                          _launchWebUrl(
                              'https://www.google.com/maps/search/?api=1&query=$q');
                        },
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 14, color: colorScheme.primary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                item.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (item.memo.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '💬 ${item.memo}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown.shade800,
                          ),
                        ),
                      ),
                    ],
                    if (item.url.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 26),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _launchWebUrl(item.url),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('公式ページを開く',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),

              // 右側：上下並び替え・編集・削除ボタン
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (indexInDay > 0)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '上へ移動',
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      onPressed: () => _moveItem(plan, item, -1),
                    ),
                  if (indexInDay < totalInDay - 1)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '下へ移動',
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      onPressed: () => _moveItem(plan, item, 1),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '削除',
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.grey),
                    onPressed: () {
                      final updatedItems = plan.items
                          .where((e) => e.id != item.id)
                          .toList();
                      _saveUpdatedPlan(plan.copyWith(items: updatedItems));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 同じDayの中で予定の順番を上下に入れ替える
  void _moveItem(TripPlan plan, TripScheduleItem item, int delta) {
    final dayItems =
        plan.items.where((i) => i.dayNumber == item.dayNumber).toList();
    final idx = dayItems.indexWhere((i) => i.id == item.id);
    if (idx < 0) return;
    final newIdx = idx + delta;
    if (newIdx < 0 || newIdx >= dayItems.length) return;

    final swapped = dayItems[newIdx];
    final allItems = List<TripScheduleItem>.from(plan.items);
    final posA = allItems.indexWhere((i) => i.id == item.id);
    final posB = allItems.indexWhere((i) => i.id == swapped.id);
    if (posA >= 0 && posB >= 0) {
      allItems[posA] = swapped;
      allItems[posB] = item;
      _saveUpdatedPlan(plan.copyWith(items: allItems));
    }
  }

  /// 予定の追加・編集ダイアログ
  void _showAddOrEditItemDialog(
    BuildContext context,
    TripPlan plan,
    int defaultDay,
    TripScheduleItem? existing,
  ) {
    final timeCtrl =
        TextEditingController(text: existing?.timeText ?? '10:00');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    TripItemType selectedType = existing?.type ?? TripItemType.sightseeing;
    int selectedDay = existing?.dayNumber ?? defaultDay;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? '✏️ 予定を追加' : '✏️ 予定を編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 何日目の予定か ＆ 時刻
                    Row(
                      children: [
                        DropdownButton<int>(
                          value: selectedDay.clamp(1, plan.totalDays),
                          items: List.generate(plan.totalDays, (i) {
                            final d = i + 1;
                            return DropdownMenuItem(
                              value: d,
                              child: Text('Day $d'),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedDay = val);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: timeCtrl,
                            decoration: InputDecoration(
                              labelText: '時刻（例: 09:30）',
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time, size: 18),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(
                                        hour: 10, minute: 0),
                                  );
                                  if (picked != null) {
                                    final hh = picked.hour
                                        .toString()
                                        .padLeft(2, '0');
                                    final mm = picked.minute
                                        .toString()
                                        .padLeft(2, '0');
                                    timeCtrl.text = '$hh:$mm';
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // アイコン種別選択
                    const Text('ジャンル・移動手段:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: TripItemType.values.map((t) {
                        final isSel = selectedType == t;
                        return ChoiceChip(
                          label: Text('${t.icon} ${t.label}',
                              style: const TextStyle(fontSize: 11.5)),
                          selected: isSel,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setDialogState(() => selectedType = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '予定タイトル（必須）',
                        hintText: '例: ジブリパーク / 新幹線で名古屋へ / たこ焼きランチ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: locCtrl,
                      decoration: const InputDecoration(
                        labelText: '場所・駅・住所（任意・地図連動）',
                        hintText: '例: 名古屋駅 / 大阪市港区 / 道頓堀',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: memoCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ひとことメモ・予約情報（任意）',
                        hintText: '例: 11:00入場予約済み！お土産もここで買う',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(
                        labelText: '参考URL（任意）',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        isDense: true,
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
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;

                    final newItem = TripScheduleItem(
                      id: existing?.id ??
                          'item_${DateTime.now().microsecondsSinceEpoch}',
                      dayNumber: selectedDay,
                      timeText: timeCtrl.text.trim().isEmpty
                          ? '10:00'
                          : timeCtrl.text.trim(),
                      title: title,
                      type: selectedType,
                      location: locCtrl.text.trim(),
                      memo: memoCtrl.text.trim(),
                      url: urlCtrl.text.trim(),
                    );

                    final list = List<TripScheduleItem>.from(plan.items);
                    if (existing != null) {
                      final idx = list.indexWhere((i) => i.id == existing.id);
                      if (idx >= 0) list[idx] = newItem;
                    } else {
                      list.add(newItem);
                      // 時刻順に自動整列
                      list.sort((a, b) {
                        final cmpDay = a.dayNumber.compareTo(b.dayNumber);
                        if (cmpDay != 0) return cmpDay;
                        return a.timeText.compareTo(b.timeText);
                      });
                    }

                    _saveUpdatedPlan(plan.copyWith(items: list));
                    setState(() => _selectedDay = selectedDay);
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

  /// 新しい空のしおりを作成するダイアログ
  void _showCreateNewPlanDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final subCtrl = TextEditingController();
    int days = 2;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('📒 新しい旅のしおりを作成'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'しおりのタイトル',
                      hintText: '例: 🏯 来週の大阪・名古屋旅行 / 🚗 日曜ドライブ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subCtrl,
                    decoration: const InputDecoration(
                      labelText: 'サブタイトル・日程メモ（任意）',
                      hintText: '例: 11/14〜11/16（2泊3日）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('旅行の日数: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: days,
                        items: [1, 2, 3, 4, 5]
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d == 1 ? '日帰り (1日)' : '$d日間'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => days = v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim().isEmpty
                        ? '✈️ 家族のお出かけしおり'
                        : titleCtrl.text.trim();
                    final nowMs = DateTime.now().millisecondsSinceEpoch;
                    final newPlan = TripPlan(
                      id: 'trip_$nowMs',
                      title: title,
                      subtitle: subCtrl.text.trim(),
                      totalDays: days,
                      items: const [],
                      updatedAtMs: nowMs,
                    );
                    final updated = List<TripPlan>.from(widget.tripPlans)
                      ..insert(0, newPlan);
                    widget.onUpdateTrips(updated);
                    widget.onSelectTrip(0);
                    setState(() => _selectedDay = 1);
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('作成する'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// しおりのタイトルや日数を編集・削除するダイアログ
  void _showEditPlanHeaderDialog(BuildContext context, TripPlan plan) {
    final titleCtrl = TextEditingController(text: plan.title);
    final subCtrl = TextEditingController(text: plan.subtitle);
    int days = plan.totalDays;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('📒 しおり情報の編集'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'しおりのタイトル',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subCtrl,
                    decoration: const InputDecoration(
                      labelText: 'サブタイトル・日程メモ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('日数: '),
                      DropdownButton<int>(
                        value: days.clamp(1, 10),
                        items: List.generate(
                          7,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}日間'),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => days = v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                if (widget.tripPlans.length > 1)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      final list = List<TripPlan>.from(widget.tripPlans)
                        ..removeWhere((p) => p.id == plan.id);
                      widget.onUpdateTrips(list);
                      widget.onSelectTrip(0);
                      Navigator.of(dialogCtx).pop();
                    },
                    child: const Text('このしおりを削除'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    _saveUpdatedPlan(
                      plan.copyWith(
                        title: titleCtrl.text.trim().isEmpty
                            ? plan.title
                            : titleCtrl.text.trim(),
                        subtitle: subCtrl.text.trim(),
                        totalDays: days,
                      ),
                    );
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 🤖 AIで旅行プラン（大阪・名古屋や全国どこでも）を自動作成するシート
  void _showAiGeneratorSheet(BuildContext context) {
    final themeCtrl = TextEditingController(
      text: '大阪・名古屋 家族旅行（USJ・海遊館・ジブリパーク・名古屋めし）',
    );
    int days = 3;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🤖 AI旅行しおりメーカー（全国どこでもOK！）',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '行き先や「ここに行きたい・これ食べたい」を入力すると、Geminiがお出かけ・旅行タイムスケジュールを自動作成します（作成後に手動で自由に変更できます！）',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('🏯 大阪＆名古屋 3日間',
                            style: TextStyle(fontSize: 11.5)),
                        onPressed: () {
                          themeCtrl.text =
                              '大阪・名古屋 家族旅行（USJ・海遊館・道頓堀・ジブリパーク・名古屋めし）';
                          setSheetState(() => days = 3);
                        },
                      ),
                      ActionChip(
                        label: const Text('🎡 大阪満喫 2日間（USJ＆海遊館）',
                            style: TextStyle(fontSize: 11.5)),
                        onPressed: () {
                          themeCtrl.text =
                              '大阪家族旅行（USJ・海遊館・道頓堀たこ焼き・串カツ）';
                          setSheetState(() => days = 2);
                        },
                      ),
                      ActionChip(
                        label: const Text('🏰 名古屋満喫 2日間（ジブリ＆レゴランド）',
                            style: TextStyle(fontSize: 11.5)),
                        onPressed: () {
                          themeCtrl.text =
                              '名古屋家族旅行（ジブリパーク・レゴランド・名古屋港水族館・ひつまぶし）';
                          setSheetState(() => days = 2);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: themeCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '行き先・やりたいこと・食べたいもの',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('旅行日数: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: days,
                        items: [1, 2, 3, 4, 5]
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text('$d日間'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => days = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final query = themeCtrl.text.trim();
                        Navigator.of(sheetCtx).pop();
                        setState(() => _isGeneratingAi = true);
                        try {
                          final generated = await GeminiOutingService
                              .generateCustomTripPlanWithAi(
                            destinationAndTheme: query,
                            totalDays: days,
                          );
                          final updated =
                              List<TripPlan>.from(widget.tripPlans)
                                ..insert(0, generated);
                          widget.onUpdateTrips(updated);
                          widget.onSelectTrip(0);
                          if (!mounted) return;
                          setState(() {
                            _selectedDay = 1;
                            _isGeneratingAi = false;
                          });
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✨「${generated.title}」を作成しました！タップして自由に編集できます'),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isGeneratingAi = false);
                          }
                        }
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('この条件で旅のしおりを自動作成！'),
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

  /// 🌲 TimeTree ＆ Googleカレンダー連携シート（案E）
  void _showCalendarAndTimeTreeSheet(
    BuildContext context,
    TripPlan plan,
    int activeDay,
  ) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

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
                  const Text(
                    '🌲 TimeTree ＆ カレンダー連携',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'TimeTreeは外部アプリからの直接書き込みが非公開のため、以下の2つの方法でカンタンに連携できます！',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),

                  // 出発日の指定
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text('Day 1 の日付: $dateStr',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 30)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('日付を変更'),
                      ),
                    ],
                  ),
                  const Divider(),

                  // 方法1：TimeTree用に整形コピー ＆ TimeTreeを開く
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Text('🌲', style: TextStyle(fontSize: 20)),
                    ),
                    title: const Text(
                      '① TimeTree用にスケジュールをコピー',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      '時間・場所・メモを綺麗にコピーします。そのままTimeTreeの予定メモ欄に貼り付けられます！',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: plan.toShareText()));
                        Navigator.of(sheetCtx).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '🌲 TimeTree用にしおりをコピーしました！TimeTreeアプリを開いて貼り付けできます'),
                          ),
                        );
                      },
                      child: const Text('コピー'),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 方法2：Googleカレンダーに登録（TimeTreeのOSカレンダー表示と自動連動）
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Text('📅', style: TextStyle(fontSize: 20)),
                    ),
                    title: Text(
                      '② カレンダーに Day $activeDay の予定を一括登録',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Googleカレンダーに追加します（TimeTreeで「OSカレンダーを表示」をONにしていればTimeTreeにも自動表示されます！）',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: FilledButton(
                      onPressed: () {
                        final calUrl = plan.toGoogleCalendarUrl(
                          selectedDate,
                          dayFilter: activeDay,
                        );
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
}
