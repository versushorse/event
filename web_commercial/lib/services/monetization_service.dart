// 商用版：サブスク（Free/Premium）・AdMob広告枠・アフィリエイト連携・検索回数クォータ管理サービス
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/shift_jis_encoder.dart';

/// アフィリエイトASP設定（審査通過後にご自身のID・計測URLを設定するだけで本番稼働します）
class AffiliateConfig {
  /// じゃらん（バリューコマース / A8.net等の計測URLプレフィックス。空なら公式検索へ遷移）
  static const String jalanAffiliatePrefix =
      'https://px.a8.net/svt/ejp?a8mat=4BGQGS+FEAKZ6+14CS+656YP&a8ejpredirect=';

  /// 楽天トラベル / 楽天市場（楽天アフィリエイトID例: '12345678.abcdefgh'）
  static const String rakutenAffiliateId = '59c88939.7092cc7f';

  /// アソビュー！（体験・割引チケットのASP計測URLプレフィックス）
  static const String asoviewAffiliatePrefix = '';

  /// Amazonアソシエイト トラッキングID（例: 'weekendouting-22'）
  static const String amazonAssociateTag = 'weekendouting-22';
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

  /// 宿泊・温泉検索向けに複合地名や公園名・しおりタイトルをじゃらん/楽天がヒットする地名・温泉名へ正規化する
  static String normalizeTravelKeyword(String raw) {
    final clean = raw
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return '温泉';

    // 1. 「〇〇温泉」が含まれていれば最優先で抽出
    final onsenMatch =
        RegExp(r'[一-龠ぁ-んァ-ヶー]{2,6}温泉').firstMatch(clean);
    if (onsenMatch != null) {
      return onsenMatch.group(0)!;
    }

    final hasOnsenWord = clean.contains('温泉');

    // 2. すでに短い「地名（＋温泉）」形式なら不要語（家族等）のみ除いてそのまま使う
    if (!clean.contains('・') &&
        !clean.contains('エリア') &&
        !clean.contains('コース') &&
        !clean.contains('しおり')) {
      final stripped = clean
          .replaceAll(RegExp(r'\s*家族\s*'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final tokens = stripped.split(' ').where((t) => t.isNotEmpty).toList();
      if (stripped.length <= 12 && tokens.length <= 2 && tokens.isNotEmpty) {
        return stripped;
      }
    }

    // 3. 住所等から都道府県名・市区町村名を抽出
    final prefMatch =
        RegExp(r'(北海道|東京都|大阪府|京都府|[一-龠]{2,3}県)').firstMatch(clean);
    final pref = prefMatch?.group(1);

    String citySearchTarget = clean;
    if (prefMatch != null) {
      citySearchTarget = clean.substring(prefMatch.end);
    }
    // 「〇〇郡」をスキップしてから最初の「市区町村」を取得
    citySearchTarget =
        citySearchTarget.replaceFirst(RegExp(r'^[一-龠ぁ-んァ-ヶー]{1,5}郡'), '');
    final cityMatch =
        RegExp(r'([一-龠ぁ-んァ-ヶー]{1,6}[市区町村])').firstMatch(citySearchTarget);
    final city = (pref != null && cityMatch != null) ? cityMatch.group(1) : null;

    if (pref != null && city != null) {
      return hasOnsenWord ? '$pref $city 温泉' : '$pref $city';
    }
    if (pref != null) {
      return hasOnsenWord ? '$pref 温泉' : pref;
    }

    // 4. GPSエリア名（「宮城・仙台・泉エリア」等）や旅のしおりタイトルから主要地名・観光地を抽出
    const areaKeywords = <String, String>{
      '仙台': '仙台',
      '松島': '松島',
      '蔵王': '蔵王',
      '那須': '那須',
      '日光': '日光',
      '箱根': '箱根',
      '鎌倉': '鎌倉',
      '横浜': '横浜',
      '東京': '東京',
      '名古屋': '名古屋',
      '京都': '京都',
      '大阪': '大阪',
      '神戸': '神戸',
      '広島': '広島',
      '福岡': '福岡',
      '札幌': '札幌',
      '那覇': '那覇',
      '北海道': '北海道',
      '宮城': '宮城県',
      '青森': '青森県',
      '岩手': '岩手県',
      '秋田': '秋田県',
      '山形': '山形県',
      '福島': '福島県',
      '沖縄': '沖縄県',
    };
    for (final entry in areaKeywords.entries) {
      if (clean.contains(entry.key)) {
        return hasOnsenWord ? '${entry.value} 温泉' : entry.value;
      }
    }

    return clean;
  }

  /// じゃらんnetで周辺宿泊・日帰り温泉プランを検索するURL（PR）
  /// ※じゃらんnetのキーワード検索仕様に合わせてShift_JIS（CP932）でエンコードする
  static String buildJalanUrl(String keyword) {
    final normalized = normalizeTravelKeyword(keyword);
    final encodedKeyword = ShiftJisEncoder.encodeUriComponent(normalized);
    final target =
        'https://www.jalan.net/uw/uwp2011/uww2011init.do?keyword=$encodedKeyword';
    if (AffiliateConfig.jalanAffiliatePrefix.isNotEmpty) {
      return '${AffiliateConfig.jalanAffiliatePrefix}${Uri.encodeComponent(target)}';
    }
    return target;
  }

  /// 楽天トラベルで宿・温泉プランを検索するURL（PR）
  static String buildRakutenTravelUrl(String keyword) {
    final normalized = normalizeTravelKeyword(keyword);
    final target =
        'https://search.travel.rakuten.co.jp/ds/undirected/search?f_query=${Uri.encodeComponent(normalized)}';
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

  /// 公開プライバシーポリシー・免責事項URL
  static const String privacyPolicyUrl =
      'https://odekake-navi-5f6b3.web.app/privacy.html';

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
