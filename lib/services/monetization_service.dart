// 商用版：サブスク（Free/Premium）・AdMob広告枠・アフィリエイト連携・検索回数クォータ管理サービス
import 'package:shared_preferences/shared_preferences.dart';

/// アフィリエイトASP設定（審査通過後にご自身のID・計測URLを設定するだけで本番稼働します）
class AffiliateConfig {
  /// じゃらん（バリューコマース / A8.net等の計測URLプレフィックス。空なら公式検索へ遷移）
  static const String jalanAffiliatePrefix = '';

  /// 楽天トラベル / 楽天市場（楽天アフィリエイトID例: '12345678.abcdefgh'）
  static const String rakutenAffiliateId = '';

  /// アソビュー！（体験・割引チケットのASP計測URLプレフィックス）
  static const String asoviewAffiliatePrefix = '';

  /// Amazonアソシエイト トラッキングID（例: 'weekendouting-22'）
  static const String amazonAssociateTag = '';
}

/// Google AdMob 本番移行用ユニットID設定（テストIDを初期設定）
class AdMobConfig {
  static const String androidBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String iosBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const String androidRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String iosRewardedUnitId = 'ca-app-pub-3940256099942544/1712485313';
}

/// 提携アフィリエイト・Google検索リンク生成ヘルパー
class AffiliateLinkBuilder {
  /// 週末イベントをGoogle検索（ブラウザ）で安全に調べるURL
  static String buildGoogleEventSearchUrl({
    required String areaName,
    String keyword = '週末 イベント 子ども 家族',
  }) {
    final q = Uri.encodeComponent('$areaName $keyword');
    return 'https://www.google.com/search?q=$q';
  }

  /// じゃらんnetで周辺宿泊・日帰り温泉プランを検索するURL（PR）
  static String buildJalanUrl(String keyword) {
    final clean = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
    final target =
        'https://www.jalan.net/uw/uwp2011/uww2011init.do?keyword=${Uri.encodeComponent(clean)}';
    if (AffiliateConfig.jalanAffiliatePrefix.isNotEmpty) {
      return '${AffiliateConfig.jalanAffiliatePrefix}${Uri.encodeComponent(target)}';
    }
    return target;
  }

  /// 楽天トラベルで宿・温泉プランを検索するURL（PR）
  static String buildRakutenTravelUrl(String keyword) {
    final clean = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
    final target =
        'https://search.travel.rakuten.co.jp/ds/undirected/search?f_query=${Uri.encodeComponent(clean)}';
    if (AffiliateConfig.rakutenAffiliateId.isNotEmpty) {
      return 'https://hb.afl.rakuten.co.jp/hgc/${AffiliateConfig.rakutenAffiliateId}/?pc=${Uri.encodeComponent(target)}';
    }
    return target;
  }

  /// アソビュー！で割引チケット・体験アクティビティを検索するURL（PR）
  static String buildAsoviewUrl(String keyword) {
    final clean = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
    final target =
        'https://www.asoview.com/search/?keyword=${Uri.encodeComponent(clean)}';
    if (AffiliateConfig.asoviewAffiliatePrefix.isNotEmpty) {
      return '${AffiliateConfig.asoviewAffiliatePrefix}${Uri.encodeComponent(target)}';
    }
    return target;
  }

  /// Amazonで持ち物・お出かけグッズを検索するURL（PR）
  static String buildAmazonGoodsUrl(String keyword) {
    final clean = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
    final base = 'https://www.amazon.co.jp/s?k=${Uri.encodeComponent(clean)}';
    if (AffiliateConfig.amazonAssociateTag.isNotEmpty) {
      return '$base&tag=${Uri.encodeComponent(AffiliateConfig.amazonAssociateTag)}';
    }
    return base;
  }
}

/// 無料プラン / ファミリープレミアムプランの仕様・利用枠管理
class MonetizationService {
  static const String _prefIsPremiumKey = 'commercial_is_premium_v1';
  static const String _prefQuotaDateKey = 'commercial_quota_date_v1';
  static const String _prefRemainingSearchKey = 'commercial_remaining_search_v1';

  /// 無料プランの日次検索上限・お気に入り上限・しおり上限
  static const int freeDailySearchLimit = 5;
  static const int rewardRecoveryAmount = 3;
  static const int freeMaxFavorites = 10;
  static const int freeMaxTrips = 1;

  /// 今日の日付キー（YYYY-MM-DD）
  static String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// プレミアム会員（月額480円 / 年額3,600円想定）かどうかを取得
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefIsPremiumKey) ?? false;
  }

  /// プレミアム状態を設定（実ストア課金連携・テストプレビュー切替兼用）
  static Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsPremiumKey, value);
  }

  /// 本日の残り検索回数を取得（日付が変わっていれば自動リセット）
  static Future<int> getRemainingSearches([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(now);
    final savedDate = prefs.getString(_prefQuotaDateKey);

    if (savedDate != today) {
      await prefs.setString(_prefQuotaDateKey, today);
      await prefs.setInt(_prefRemainingSearchKey, freeDailySearchLimit);
      return freeDailySearchLimit;
    }
    return prefs.getInt(_prefRemainingSearchKey) ?? freeDailySearchLimit;
  }

  /// 検索を1回消費する（プレミアムなら無制限でtrue、無料枠0ならfalse）
  static Future<bool> tryConsumeSearch([DateTime? now]) async {
    if (await isPremium()) return true;

    final remaining = await getRemainingSearches(now);
    if (remaining <= 0) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefRemainingSearchKey, remaining - 1);
    return true;
  }

  /// リワード動画広告の視聴完了で検索回数を +3回 回復する
  static Future<int> grantRewardSearchBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getRemainingSearches();
    final updated = current + rewardRecoveryAmount;
    await prefs.setInt(_prefRemainingSearchKey, updated);
    return updated;
  }

  /// テスト用：本日の検索回数を初期値（5回）にリセットする
  static Future<int> resetDailyQuota() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefQuotaDateKey, _todayKey());
    await prefs.setInt(_prefRemainingSearchKey, freeDailySearchLimit);
    return freeDailySearchLimit;
  }
}
