// 商用版UIウィジェット：バナー広告枠・インフィードネイティブPR枠・リワード動画回復・プレミアムプランシート
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/monetization_service.dart';

/// 画面下部のバナー広告枠（プレミアム会員時は非表示）
/// ※ 本番公開時は google_mobile_ads の AdWidget(ad: bannerAd) に差し替えてご利用ください
class AdBannerBar extends StatelessWidget {
  final VoidCallback onOpenPremium;
  final ValueChanged<String> onOpenAffiliateUrl;

  const AdBannerBar({
    super.key,
    required this.onOpenPremium,
    required this.onOpenAffiliateUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'PR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => onOpenAffiliateUrl(
                AffiliateLinkBuilder.buildAsoviewUrl('家族 レジャー 割引'),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🎟️ アソビュー！週末レジャー・温泉の前売り最大50%OFF',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00695C),
                    ),
                  ),
                  Text(
                    '広告枠（AdMob Banner: ${AdMobConfig.androidBannerUnitId}）',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onOpenPremium,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '広告非表示',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// スポット一覧の合間に自然に差し込むネイティブPRカード（フリープラン時のみ表示）
class InFeedNativeAdCard extends StatelessWidget {
  final int slotIndex;
  final String regionLabel;
  final ValueChanged<String> onOpenAffiliateUrl;
  final VoidCallback onOpenPremium;

  const InFeedNativeAdCard({
    super.key,
    required this.slotIndex,
    required this.regionLabel,
    required this.onOpenAffiliateUrl,
    required this.onOpenPremium,
  });

  @override
  Widget build(BuildContext context) {
    final isFirstVariant = slotIndex.isEven;
    final title = isFirstVariant
        ? '🏨 【$regionLabel】子連れ歓迎の温泉宿・日帰りプランを探す'
        : '🎟️ 【アソビュー！】近くの遊園地・水族館・体験をお得に予約';
    final subtitle = isFirstVariant
        ? 'じゃらんnetのファミリープラン＆クチコミ人気宿をまとめてチェック！'
        : 'スマホで事前チケット購入なら当日の窓口行列も回避できてスマート。';
    final ctaLabel = isFirstVariant ? 'じゃらんで見る (PR)' : 'アソビューで見る (PR)';
    final targetUrl = isFirstVariant
        ? AffiliateLinkBuilder.buildJalanUrl('$regionLabel 家族 温泉')
        : AffiliateLinkBuilder.buildAsoviewUrl('$regionLabel 子ども 体験');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0.5,
      color: const Color(0xFFFFFBF2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PR / スポンサー',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onOpenPremium,
                  child: Text(
                    'プレミアムで広告OFF 👑',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.brown.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.brown.shade800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => onOpenAffiliateUrl(targetUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade200,
                  foregroundColor: Colors.brown.shade900,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  ctaLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 無料検索回数を使い切った際のリワード動画回復 / プレミアム案内ダイアログ
Future<void> showSearchQuotaExceededDialog(
  BuildContext context, {
  required VoidCallback onRewardCompleted,
  required VoidCallback onOpenPremium,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      bool isWatchingAd = false;
      int countdown = 3;
      Timer? timer;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          void startSimulatedRewardAd() {
            // 本番移行時はここで google_mobile_ads の RewardedAd.show() を呼び出します
            setDialogState(() {
              isWatchingAd = true;
              countdown = 3;
            });
            timer?.cancel();
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (!context.mounted) {
                t.cancel();
                return;
              }
              if (countdown <= 1) {
                t.cancel();
                Navigator.of(dialogCtx).pop();
                onRewardCompleted();
              } else {
                setDialogState(() => countdown--);
              }
            });
          }

          return AlertDialog(
            title: const Row(
              children: [
                Text('🔍 ', style: TextStyle(fontSize: 22)),
                Expanded(
                  child: Text(
                    '本日の無料検索枠を使い切りました',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: isWatchingAd
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        '🎬 動画広告を再生中... あと $countdown 秒',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '（本番ビルドでは AdMob RewardedAd が表示されます）',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'フリープランでは1日${MonetizationService.freeDailySearchLimit}回までGoogle最新スポット＆AI検索をご利用いただけます。',
                        style: TextStyle(fontSize: 13, height: 1.45),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '• 🎬 短い動画広告を見ると +${MonetizationService.rewardRecoveryAmount}回 すぐ回復！\n'
                        '• 👑 ファミリープレミアムなら検索無制限＆広告なし',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
            actions: isWatchingAd
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('閉じる'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        onOpenPremium();
                      },
                      icon: const Icon(Icons.workspace_premium, size: 18),
                      label: const Text('プレミアムを見る'),
                    ),
                    FilledButton.icon(
                      onPressed: startSimulatedRewardAd,
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text(
                        '広告で+${MonetizationService.rewardRecoveryAmount}回回復',
                      ),
                    ),
                  ],
          );
        },
      );
    },
  );
}

/// ファミリープレミアム（サブスク）案内 ＆ テスト用プレビュー切替シート
Future<void> showPremiumPlanSheet(
  BuildContext context, {
  required bool isPremium,
  required int remainingSearches,
  required ValueChanged<bool> onTogglePremium,
  required VoidCallback onResetQuota,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      bool localPremium = isPremium;
      int localRemaining = remainingSearches;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('👑 ', style: TextStyle(fontSize: 26)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ファミリープレミアムプラン',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              localPremium
                                  ? '現在の状態: プレミアム会員（無制限・広告OFF）'
                                  : '現在の状態: フリープラン（本日残り検索 $localRemaining回）',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: localPremium
                                    ? Colors.amber.shade900
                                    : Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 料金プランカード
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade50,
                          Colors.orange.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💑 1契約で夫婦・家族2台のスマホで使えます',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _PriceOptionBox(
                                title: '月額プラン',
                                price: '¥480 / 月',
                                note: 'いつでも解約OK',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _PriceOptionBox(
                                title: '年額プラン (お得)',
                                price: '¥3,600 / 年',
                                note: '月あたり¥300 (4ヶ月分無料)',
                                highlight: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    '✨ プレミアムで解放される機能',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const _BenefitRow(
                    icon: '🚫',
                    title: 'アプリ内広告の完全非表示',
                    desc: 'バナー・リスト内PRカードがすべて消えて快適に検索',
                  ),
                  const _BenefitRow(
                    icon: '🔍',
                    title: 'Googleスポット＆Gemini AI検索 無制限',
                    desc: '無料枠（1日${MonetizationService.freeDailySearchLimit}回）を気にせず何度でも検索・再提案',
                  ),
                  const _BenefitRow(
                    icon: '❤️',
                    title: '夫婦お気に入り＆思い出スタンプ 無制限',
                    desc: '無料枠（${MonetizationService.freeMaxFavorites}件）を超えて家族の思い出をずっと保存',
                  ),
                  const _BenefitRow(
                    icon: '📒',
                    title: '旅のしおり 複数作成・AI自動プランニング',
                    desc: '大阪/名古屋/北海道など旅行ごとに何冊でも作成可能',
                  ),

                  const Divider(height: 24),

                  // オーナーテスト・プレビュー用の切替セクション
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
                          '🛠️ 動作プレビュー切替（開発・確認用）',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004D40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'プレミアム会員モードをONにする',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'OFFにすると広告表示・検索制限ありのフリープラン挙動を確認できます',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: localPremium,
                          onChanged: (val) {
                            setSheetState(() => localPremium = val);
                            onTogglePremium(val);
                          },
                        ),
                        if (!localPremium)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                onResetQuota();
                                setSheetState(() {
                                  localRemaining =
                                      MonetizationService.freeDailySearchLimit;
                                });
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text(
                                '本日の無料検索回数を5回にリセット',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: const Text('閉じる'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _PriceOptionBox extends StatelessWidget {
  final String title;
  final String price;
  final String note;
  final bool highlight;

  const _PriceOptionBox({
    required this.title,
    required this.price,
    required this.note,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? Colors.deepOrange.shade400 : Colors.amber.shade200,
          width: highlight ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.deepOrange.shade800 : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
