// 商用版UIウィジェット：バナー広告枠・インフィードネイティブPR枠・リワード動画回復・プレミアムプランシート
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/monetization_service.dart';

/// AdMobネイティブ広告が動作するモバイル実環境か判定する（Web・Widgetテスト時はfalse）
bool _isAdMobSupportedPlatform() {
  final isTestBinding =
      WidgetsBinding.instance.runtimeType.toString().contains('Test');
  if (kIsWeb || isTestBinding) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// 画面下部のバナー広告枠（プレミアム会員時は非表示）
/// モバイル実環境では google_mobile_ads の BannerAd を読み込み、未読込時やWeb/テスト時はPR枠を表示する
class AdBannerBar extends StatefulWidget {
  final VoidCallback onOpenPremium;
  final ValueChanged<String> onOpenAffiliateUrl;

  const AdBannerBar({
    super.key,
    required this.onOpenPremium,
    required this.onOpenAffiliateUrl,
  });

  @override
  State<AdBannerBar> createState() => _AdBannerBarState();
}

class _AdBannerBarState extends State<AdBannerBar> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (!_isAdMobSupportedPlatform()) return;
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AdMobConfig.currentBannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isAdLoaded = false;
            });
          }
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 広告読み込み完了時はAdMobポリシー遵守のため、広告の上にボタンを重ねず純粋にAdWidgetを表示する
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Center(
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      );
    }

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
              onTap: () => widget.onOpenAffiliateUrl(
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
                    'お出かけチケット・宿の割引情報をチェック',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          if (MonetizationService.enablePremiumSubscription) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: widget.onOpenPremium,
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
                if (MonetizationService.enablePremiumSubscription) ...[
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
  Timer? timer;
  bool isDialogClosed = false;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      bool isLoadingAd = false;
      bool isWatchingAd = false;
      int countdown = 3;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          void startSimulatedRewardAd() {
            if (!dialogCtx.mounted || isDialogClosed) return;
            setDialogState(() {
              isLoadingAd = false;
              isWatchingAd = true;
              countdown = 3;
            });
            timer?.cancel();
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (!dialogCtx.mounted || isDialogClosed) {
                t.cancel();
                return;
              }
              if (countdown <= 1) {
                t.cancel();
                onRewardCompleted();
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
              } else {
                setDialogState(() => countdown--);
              }
            });
          }

          void startRewardAd() {
            if (!_isAdMobSupportedPlatform()) {
              startSimulatedRewardAd();
              return;
            }
            setDialogState(() => isLoadingAd = true);
            RewardedAd.load(
              adUnitId: AdMobConfig.currentRewardedUnitId,
              request: const AdRequest(),
              rewardedAdLoadCallback: RewardedAdLoadCallback(
                onAdLoaded: (RewardedAd ad) {
                  if (isDialogClosed || !dialogCtx.mounted) {
                    ad.dispose();
                    return;
                  }
                  bool rewardEarned = false;
                  bool adDismissed = false;
                  bool rewardHandled = false;

                  void finishRewardIfReady() {
                    if (rewardHandled || !rewardEarned || !adDismissed) return;
                    rewardHandled = true;
                    onRewardCompleted();
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                  }

                  ad.fullScreenContentCallback = FullScreenContentCallback(
                    onAdDismissedFullScreenContent: (ad) {
                      ad.dispose();
                      adDismissed = true;
                      if (rewardEarned) {
                        finishRewardIfReady();
                      } else if (dialogCtx.mounted && !isDialogClosed) {
                        setDialogState(() => isLoadingAd = false);
                      }
                    },
                    onAdFailedToShowFullScreenContent: (ad, error) {
                      ad.dispose();
                      if (dialogCtx.mounted && !isDialogClosed) {
                        startSimulatedRewardAd();
                      }
                    },
                  );

                  ad.show(
                    onUserEarnedReward: (_, _) {
                      rewardEarned = true;
                      finishRewardIfReady();
                    },
                  );
                },
                onAdFailedToLoad: (LoadAdError error) {
                  if (!dialogCtx.mounted || isDialogClosed) return;
                  startSimulatedRewardAd();
                },
              ),
            );
          }

          final Widget bodyContent;
          if (isLoadingAd) {
            bodyContent = const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  '🎬 動画広告を読み込み中...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          } else if (isWatchingAd) {
            bodyContent = Column(
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
                  '（再生完了後に検索回数が回復します）',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            );
          } else {
            bodyContent = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MonetizationService.enablePremiumSubscription
                      ? 'フリープランでは1日${MonetizationService.freeDailySearchLimit}回までGoogle最新スポット＆AI検索をご利用いただけます。'
                      : '1日${MonetizationService.freeDailySearchLimit}回までGoogle最新スポット検索をご利用いただけます。',
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 10),
                Text(
                  MonetizationService.enablePremiumSubscription
                      ? '• 🎬 短い動画広告を見ると +${MonetizationService.rewardRecoveryAmount}回 すぐ回復！\n'
                          '• 👑 ファミリープレミアムなら検索無制限＆広告なし'
                      : '• 🎬 短い動画広告を見ると +${MonetizationService.rewardRecoveryAmount}回 すぐ回復！（何度でも無料でご利用いただけます）',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Row(
              children: [
                Text('🔍 ', style: TextStyle(fontSize: 22)),
                Expanded(
                  child: Text(
                    '本日の検索枠を使い切りました',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: bodyContent,
            actions: (isLoadingAd || isWatchingAd)
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('閉じる'),
                    ),
                    if (MonetizationService.enablePremiumSubscription)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          onOpenPremium();
                        },
                        icon: const Icon(Icons.workspace_premium, size: 18),
                        label: const Text('プレミアムを見る'),
                      ),
                    FilledButton.icon(
                      onPressed: startRewardAd,
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
  ).whenComplete(() {
    isDialogClosed = true;
    timer?.cancel();
  });
}

/// ファミリープレミアム（サブスク）案内 ＆ テスト用プレビュー切替シート
Future<void> showPremiumPlanSheet(
  BuildContext context, {
  required bool isPremium,
  required int remainingSearches,
  required ValueChanged<bool> onTogglePremium,
  required VoidCallback onResetQuota,
  VoidCallback? onOpenPrivacyPolicy,
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
                      Text(
                        MonetizationService.enablePremiumSubscription
                            ? '👑 '
                            : '🚗 ',
                        style: const TextStyle(fontSize: 26),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MonetizationService.enablePremiumSubscription
                                  ? 'ファミリープレミアムプラン'
                                  : 'おでかけナビ ご案内',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              MonetizationService.enablePremiumSubscription
                                  ? (localPremium
                                      ? '現在の状態: プレミアム会員（無制限・広告OFF）'
                                      : '現在の状態: フリープラン（本日残り検索 $localRemaining回）')
                                  : '全機能無料（本日の残り検索 $localRemaining回）',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (MonetizationService
                                            .enablePremiumSubscription &&
                                        localPremium)
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

                  if (!MonetizationService.enablePremiumSubscription) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✨ すべての機能を完全無料でご利用いただけます',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF004D40),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• お気に入り保存・思い出スタンプ・旅のしおりは無制限！\n'
                            '• スポット検索は1日${MonetizationService.freeDailySearchLimit}回まで（使い切っても短い動画広告で何度でも+${MonetizationService.rewardRecoveryAmount}回回復します）\n'
                            '• アプリ内広告およびPRリンクにより無料で運営しています',
                            style: TextStyle(fontSize: 12.5, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 料金プランカード（将来のサブスク課金導入用）
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
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const _BenefitRow(
                      icon: '🚫',
                      title: 'アプリ内広告の完全非表示',
                      desc: 'バナー・リスト内PRカードがすべて消えて快適に検索',
                    ),
                    const _BenefitRow(
                      icon: '🔍',
                      title: 'Googleスポット＆AI検索 無制限',
                      desc:
                          '無料枠（1日${MonetizationService.freeDailySearchLimit}回）を気にせず何度でも検索・再提案',
                    ),
                    const _BenefitRow(
                      icon: '❤️',
                      title: '夫婦お気に入り＆思い出スタンプ 無制限',
                      desc:
                          '無料枠（${MonetizationService.freeMaxFavorites}件）を超えて家族の思い出をずっと保存',
                    ),
                    const _BenefitRow(
                      icon: '📒',
                      title: '旅のしおり 複数作成・AI自動プランニング',
                      desc: '大阪/名古屋/北海道など旅行ごとに何冊でも作成可能',
                    ),
                  ],

                  // オーナーテスト・プレビュー用の切替セクション（リリースビルド時は自動非表示）
                  if (kDebugMode) ...[
                    const Divider(height: 24),
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
                          if (MonetizationService.enablePremiumSubscription)
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
                          if (!localPremium ||
                              !MonetizationService.enablePremiumSubscription)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  onResetQuota();
                                  setSheetState(() {
                                    localRemaining = MonetizationService
                                        .freeDailySearchLimit;
                                  });
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text(
                                  '本日の検索回数を${MonetizationService.freeDailySearchLimit}回にリセット',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (onOpenPrivacyPolicy != null) ...[
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onOpenPrivacyPolicy,
                        icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                        label: const Text(
                          'プライバシーポリシー・免責事項・お問い合わせ',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
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
