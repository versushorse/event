// Gemini AI / リアルタイムWebイベントスクレイピング / Google Places API (New) 統合検索サービス
import 'dart:convert';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:http/http.dart' as http;
import '../config/api_keys.local.dart';
import '../data/cached_events_data.dart';
import '../models/outing_spot.dart';
import 'location_service.dart';

/// AI検索のレスポンス結果
class AiSearchResult {
  final String aiSummaryComment;
  final List<OutingSpot> spots;
  final bool isLiveAi;

  const AiSearchResult({
    required this.aiSummaryComment,
    required this.spots,
    this.isLiveAi = false,
  });
}

class GeminiOutingService {
  static const List<String> _weekdayNames = ['', '月', '火', '水', '木', '金', '土', '日'];

  /// 基準日（省略時は今日）から見て「直近の週末（土曜日〜日曜日）」の日付範囲を返す
  /// 例: 11/9(月)に調べたら 11/14(土)〜11/15(日) を返す
  static DateTimeRange getUpcomingWeekendRange([DateTime? baseDate]) {
    final now = baseDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    late final DateTime saturday;
    late final DateTime sunday;

    if (today.weekday == DateTime.sunday) {
      // 日曜日に調べた場合は、その週末（前日の土曜〜当日の日曜）を対象とする
      saturday = today.subtract(const Duration(days: 1));
      sunday = today;
    } else {
      // 月〜土曜日に調べた場合は、直近の土曜日と翌日曜日を対象とする
      final daysUntilSat = DateTime.saturday - today.weekday;
      saturday = today.add(Duration(days: daysUntilSat));
      sunday = saturday.add(const Duration(days: 1));
    }

    return DateTimeRange(start: saturday, end: sunday);
  }

  /// 直近の週末の「翌週末（来週末）」の日付範囲を返す
  static DateTimeRange getFollowingWeekendRange([DateTime? baseDate]) {
    final upcoming = getUpcomingWeekendRange(baseDate);
    return DateTimeRange(
      start: upcoming.start.add(const Duration(days: 7)),
      end: upcoming.end.add(const Duration(days: 7)),
    );
  }

  /// 日付範囲を「11/14(土)〜11/15(日)」のような表示用文字列にフォーマットする
  static String formatDateRange(DateTimeRange range) {
    final s = range.start;
    final e = range.end;
    final sw = _weekdayNames[s.weekday];
    final ew = _weekdayNames[e.weekday];
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return '${s.month}/${s.day}($sw)';
    }
    return '${s.month}/${s.day}($sw)〜${e.month}/${e.day}($ew)';
  }

  /// 直近の週末（土曜・日曜）の日付文字列を自動生成する（例: "11/14(土)〜11/15(日)"）
  static String getThisWeekendDates([DateTime? baseDate]) {
    return formatDateRange(getUpcomingWeekendRange(baseDate));
  }

  /// オフライン時・テスト環境用の初期代表スポットデータ（特定イベントへの偏りを排除した東北の定番スポット）
  static List<OutingSpot> getInitialSpots() {
    final weekend = getThisWeekendDates();

    return [
      // 1. 大きな公園（宮城県民の森 フィールドアスレチック）
      OutingSpot(
        id: 'park_kenmin_no_mori_athletic',
        title: '宮城県民の森 フィールドアスレチック＆冒険広場',
        subtitle: '小学生が夢中になる！大自然の起伏を活かした本格木製アスレチックコース25基以上',
        category: SpotCategory.park,
        tags: const [
          SpotTag.kids,
          SpotTag.nature,
          SpotTag.freeParking,
          SpotTag.freeEntry,
        ],
        driveMinutes: 19,
        distanceKm: 11.5,
        scheduleText: '9:00〜16:30（$weekend 営業・入場無料）',
        parkingInfo: '無料大駐車場あり（中央記念館・アスレチック前 計約400台）',
        recommendPoints: const [
          '丸太渡りやターザンロープ、ネット登りなど、小学生の運動能力をフルに使って遊べる本格アスレチック',
          '入園料・アスレチック利用料・駐車場がすべて無料でコスパ最高',
          '中央記念館では木工クラフト体験もでき、家族で1日中遊べる',
        ],
        aiTip: '森の中のアスレチックで土や木の葉がつくことがあるため、動きやすいスニーカーと軍手があるとさらに楽しめます！',
        address: '宮城県宮城郡利府町神谷沢菅野沢41',
        latitude: 38.3214,
        longitude: 140.9386,
        weatherText: '☀️ 晴れ（アスレチック日和）',
        sourceInfo: '宮城県民の森 公式 / Googleマップ高評価',
        url: 'https://kenminforest.jp/',
        isFavorite: false,
        googleRating: 4.3,
        googleRatingCount: 1420,
        googleReviews: const [
          '★5: アスレチックが本格的で小学生の子どもが大興奮！木陰が多く親も気持ちよく見守れます。駐車場無料も助かる。',
          '★4: 自然の中のコースで運動量抜群。軍手とスニーカー持参が正解でした。中央記念館の木工体験も楽しかったです。',
        ],
      ),

      // 2. 大きな公園（国営みちのく杜の湖畔公園）
      OutingSpot(
        id: 'park_michinoku_kohan',
        title: '国営みちのく杜の湖畔公園（わらすこひろば）',
        subtitle: 'ジャンピングドーナツ（巨大トランポリン）や大型遊具・ローラースライダーが揃う国営公園',
        category: SpotCategory.park,
        tags: const [
          SpotTag.kids,
          SpotTag.nature,
          SpotTag.toddler,
        ],
        driveMinutes: 45,
        distanceKm: 34.0,
        scheduleText: '9:30〜17:00（$weekend 営業）',
        parkingInfo: '大型駐車場完備（約1,600台 / 普通車400円）',
        recommendPoints: const [
          '小学生に大人気の「ジャンピングドーナツ」や大型アスレチック、足漕ぎカートが充実',
          '広大な芝生広場でボール遊びやバドミントン、ピクニックが思いっきり楽しめる',
          '季節ごとの花畑や古民家エリア（ふるさと村）での昔遊び体験も魅力',
        ],
        aiTip: '遊具が集まる「わらすこひろば」へ行くなら、南地区の「中央口ゲート」近くの駐車場に停めるのが一番近道です。',
        address: '宮城県柴田郡川崎町小野字二本松53-9',
        latitude: 38.2104,
        longitude: 140.6738,
        weatherText: '☀️ 快晴（ピクニック日和）',
        sourceInfo: 'みちのく公園 公式',
        url: 'https://michinoku-park.info/',
        isFavorite: false,
        googleRating: 4.4,
        googleRatingCount: 3950,
        googleReviews: const [
          '★5: ジャンピングドーナツとローラースライダーで1日中遊べます！芝生が広大でテントを張ってピクニックに最高。',
          '★5: 季節の花がいつも綺麗。足漕ぎカートやボートもあって家族みんな大満足の国営公園です。',
        ],
      ),

      // 3. 温泉・日帰り銭湯（スパメッツァ仙台 竜泉寺の湯）
      OutingSpot(
        id: 'onsen_spametzasendai_ryusenjinoyu',
        title: 'スパメッツァ仙台 竜泉寺の湯',
        subtitle: '東北最大級のスパ＆天然温泉！小学生も入れる多彩な露天風呂・炭酸泉と休憩ラウンジ',
        category: SpotCategory.onsen,
        tags: const [
          SpotTag.onsen,
          SpotTag.kids,
          SpotTag.freeParking,
          SpotTag.food,
        ],
        driveMinutes: 16,
        distanceKm: 8.5,
        scheduleText: '朝6:00〜深夜2:00（$weekend 営業）',
        parkingInfo: '大型無料駐車場完備（約650台）',
        recommendPoints: const [
          '6種の炭酸泉をはじめ全16種のお風呂＆露天風呂があり、家族でゆったりリフレッシュできる',
          '泉インター近くでドライブ帰りにも立ち寄りやすい好アクセス',
          '食事処ではキッズメニューや定食も充実し、お風呂上がりの食事にも便利',
        ],
        aiTip: '夕方17時〜19時は混み合うため、お出かけ帰りの15時台か19時以降の利用がゆったり過ごせます。',
        address: '宮城県仙台市泉区大沢2丁目5-6',
        latitude: 38.3495,
        longitude: 140.8792,
        weatherText: '♨️ 天然温泉・露天風呂',
        sourceInfo: 'スパメッツァ仙台 公式',
        url: 'https://ryusenjinoyu.com/spametzasendai/',
        isFavorite: false,
        googleRating: 4.2,
        googleRatingCount: 3120,
        googleReviews: const [
          '★5: 東北屈指のスパ施設。炭酸泉の種類が多く露天風呂も最高に気持ちいい！施設が清潔で食事処も美味。',
          '★4: 家族連れにも優しい広さ。お風呂上がりの休憩ラウンジも充実していてドライブ帰りの定番です。',
        ],
      ),

      // 4. 温泉・日帰り銭湯（秋保温泉 共同浴場＆日帰り温泉）
      OutingSpot(
        id: 'onsen_akiu_hotspring',
        title: '秋保温泉 共同浴場＆日帰り温泉街',
        subtitle: '開湯1500年の名湯！源泉掛け流しの共同浴場や磊々峡散策・名物おはぎが楽しめる温泉郷',
        category: SpotCategory.onsen,
        tags: const [
          SpotTag.onsen,
          SpotTag.nature,
          SpotTag.food,
          SpotTag.freeParking,
        ],
        driveMinutes: 38,
        distanceKm: 24.5,
        scheduleText: '7:30〜21:30（$weekend 営業）',
        parkingInfo: '秋保・里センターおよび各施設に無料駐車場あり',
        recommendPoints: const [
          '日帰り入浴できる温泉旅館や露天風呂、無料の足湯が温泉街に多数点在',
          'すぐ近くの「主婦の店 さいち」のおはぎや、磊々峡の渓谷散策も一緒に楽しめる',
          '仙台中心部や山形方面へのドライブ途中の立ち寄り湯として最適',
        ],
        aiTip: '家族でゆったり広い露天風呂に入るなら、天守閣自然公園内の「市太郎の湯」や各旅館の日帰り入浴もおすすめです。',
        address: '宮城県仙台市太白区秋保町湯元',
        latitude: 38.2255,
        longitude: 140.7185,
        weatherText: '♨️ 名湯 秋保温泉',
        sourceInfo: '秋保温泉観光案内所 公式',
        url: 'https://akiusato.jp/',
        isFavorite: false,
        googleRating: 4.3,
        googleRatingCount: 2280,
        googleReviews: const [
          '★5: 共同浴場のお湯は熱めで体の芯まで温まります！さいちのおはぎとセットで訪れるのが最高の休日コース。',
          '★4: 磊々峡の遊歩道を散策した後の温泉は最高。無料の足湯もあって気軽に名湯を楽しめます。',
        ],
      ),

      // 5. 屋内スポット（スリーエム仙台市科学館）
      OutingSpot(
        id: 'indoor_sendai_science_museum',
        title: 'スリーエム仙台市科学館',
        subtitle: '小学生の理科・実験好きが夢中になる参加体験型サイエンスミュージアム',
        category: SpotCategory.indoor,
        tags: const [
          SpotTag.kids,
          SpotTag.indoor,
          SpotTag.freeParking,
        ],
        driveMinutes: 20,
        distanceKm: 10.2,
        scheduleText: '9:00〜16:45（最終入館16:00・月曜休館）',
        parkingInfo: '無料専用駐車場あり（約170台）',
        recommendPoints: const [
          '巨大なシャボン玉の中に入る装置や放電実験など、小学生が体で体験できる展示が満載',
          '宮城・東北の自然や化石、恐竜骨格標本エリアも大迫力',
          '隣が「台原森林公園」なので、科学館の後に森の散策もセットで楽しめる',
        ],
        aiTip: '展示室で行われる「サイエンスショー」の実演時間を入口で最初にチェックして回ると満足度が倍増します。',
        address: '宮城県仙台市青葉区台原森林公園4-1',
        latitude: 38.2995,
        longitude: 140.8768,
        weatherText: '🏛️ 屋内施設（雨や寒い日も快適）',
        sourceInfo: '仙台市科学館 公式',
        url: 'http://www.sendai-c.ed.jp/~bousai/',
        isFavorite: false,
        googleRating: 4.2,
        googleRatingCount: 1890,
        googleReviews: const [
          '★5: シャボン玉の中に入れる装置や体験型の科学展示がたくさんあり、小学生が大喜びでした！雨の日のお出かけに最適。',
          '★4: 入館料がリーズナブルなのに見ごたえ十分。台原森林公園直結なので晴れていれば公園遊びも楽しめます。',
        ],
      ),

      // 6. 小さな公園（やまいちサステナパーク七北田公園）
      OutingSpot(
        id: 'smallpark_nanakita_park',
        title: 'やまいちサステナパーク七北田公園',
        subtitle: '泉中央すぐ！芝生広場・木製遊具・池の散策・カフェが揃う心地よい公園',
        category: SpotCategory.smallPark,
        tags: const [
          SpotTag.nature,
          SpotTag.kids,
          SpotTag.freeEntry,
        ],
        driveMinutes: 15,
        distanceKm: 7.5,
        scheduleText: '終日開放（都市緑化ホールは9:00〜17:00）',
        parkingInfo: '七北田公園駐車場あり（約260台・最初の3時間まで100円/時間）',
        recommendPoints: const [
          '広々とした芝生でキャッチボールやバドミントンが気軽に楽しめる',
          '園内のカフェ（NANA+Ichi）でソフトクリームや軽食を買ってベンチで休憩できる',
          '泉中央エリアなのでお買い物やランチのついでに立ち寄りやすい',
        ],
        aiTip: 'スタジアムで試合がある日は周辺駐車場が混雑するため、イベントがない時間帯が快適です。',
        address: '宮城県仙台市泉区七北田柳78',
        latitude: 38.3198,
        longitude: 140.8764,
        weatherText: '☀️ 晴れ',
        sourceInfo: '仙台市公園緑地協会 公式',
        url: 'https://sendai-park.or.jp/shisetsu/nanakita.html',
        isFavorite: false,
        googleRating: 4.2,
        googleRatingCount: 1650,
        googleReviews: const [
          '★5: 芝生が広くて開放感抜群！大型木製遊具「キートス広場」は子どもたちに大人気です。',
          '★4: 池の周りの散策路が綺麗でベビーカーでも歩きやすい。カフェのソフトクリームも美味しいです。',
        ],
      ),

      // 7. 神社仏閣（国宝 大崎八幡宮）
      OutingSpot(
        id: 'shrine_osaki_hachimangu',
        title: '国宝 大崎八幡宮',
        subtitle: '伊達政宗公が創建した絢爛豪華な桃山建築の国宝社殿！境内散策と門前グルメも魅力',
        category: SpotCategory.sightseeing,
        tags: const [
          SpotTag.baby,
          SpotTag.freeParking,
          SpotTag.freeEntry,
        ],
        driveMinutes: 24,
        distanceKm: 12.8,
        scheduleText: '参拝自由（授与所は9:00〜17:00）',
        parkingInfo: '神社専用無料駐車場あり（北参道側・約70台）',
        recommendPoints: const [
          '黒漆塗りに金箔・極彩色が輝く国宝の社殿は、小学生の歴史学習や家族参拝にぴったりの迫力',
          '境内に放し飼いのチャボ（鶏）が歩いており、子どもと一緒に探しながら参道を散策できる',
          '限定の御朱印やだるまみくじなど、家族での参拝記念になる授与品も豊富',
        ],
        aiTip: '表参道の石段は100段近くあるため、車の場合は裏手の「北参道駐車場（無料）」に停めると平坦に本殿へ行けます。',
        address: '宮城県仙台市青葉区八幡4-6-1',
        latitude: 38.2724,
        longitude: 140.8447,
        weatherText: '☀️ 晴れ（参拝日和）',
        sourceInfo: '国宝 大崎八幡宮 公式',
        url: 'http://www.oosaki-hachiman.or.jp/',
        isFavorite: false,
        googleRating: 4.4,
        googleRatingCount: 2840,
        googleReviews: const [
          '★5: 国宝の社殿の黒漆塗りと金箔の装飾が圧巻の美しさ！境内のチャボ（鶏）に子どもも興味津々でした。',
          '★4: 伊達家の歴史を感じられる荘厳な神社。駐車場も無料で参拝しやすいです。',
        ],
      ),

      // 8. 地元グルメ・食事処（定義とうふ店）
      OutingSpot(
        id: 'dining_jogi_tofu',
        title: '定義とうふ店（名物 三角定義あぶらあげ）',
        subtitle: '定義如来の門前で揚げたてアツアツ！外はサクッ中はフワフワの宮城屈指の名物グルメ',
        category: SpotCategory.dining,
        tags: const [
          SpotTag.food,
          SpotTag.freeParking,
          SpotTag.kids,
        ],
        driveMinutes: 45,
        distanceKm: 27.8,
        scheduleText: '営業時間: 9:00〜16:00（年中無休）',
        parkingInfo: '定義如来門前駐車場・大駐車場あり（無料・約300台）',
        recommendPoints: const [
          '揚げたて熱々の油揚げに醤油とにんにく七味をかけて食べる名物は絶品！子どもも大喜び',
          '豆乳や焼きめし、田楽などドライブ途中の小腹満たしやランチに最高のローカル食事処',
          '定義山西方寺の参拝とセットで立ち寄れる定番の家族ドライブコース',
        ],
        aiTip: '休日の昼時は行列ができますが回転が早いです。隣の休憩ベンチで座ってゆっくり食べられます。',
        address: '宮城県仙台市青葉区大倉字下道1-2',
        latitude: 38.3639,
        longitude: 140.6722,
        weatherText: '☀️ ドライブ日和',
        sourceInfo: '定義観光協会・Googleマップ高評価',
        url: 'https://sankaku-tofu.jp/',
        isFavorite: false,
        googleRating: 4.4,
        googleRatingCount: 3820,
        googleReviews: const [
          '★5: 揚げたての三角あぶらあげが外はカリッと中はジューシーで最高！にんにく七味が相性抜群です。',
          '★5: ドライブがてら家族で訪問。回転が早くてすぐ買えました。隣のベンチで熱々を食べられます！',
        ],
      ),

      // 9. 観光地・名所（日本三景 松島海岸・五大堂＆仁王島遊覧）
      OutingSpot(
        id: 'tourism_matsushima_kaigan',
        title: '日本三景 松島海岸（五大堂・福浦橋・遊覧船）',
        subtitle: '260余りの島々が浮かぶ絶景スポット！赤い透かし橋を渡るスリルと食べ歩き散策に大人気',
        category: SpotCategory.tourism,
        tags: const [
          SpotTag.nature,
          SpotTag.food,
          SpotTag.baby,
        ],
        driveMinutes: 32,
        distanceKm: 23.0,
        scheduleText: '終日散策自由（遊覧船・瑞巌寺は9:00〜16:30）',
        parkingInfo: '松島公園駐車場ほか周辺観光駐車場多数あり',
        recommendPoints: const [
          '海の上にかかる「すかし橋」を渡る五大堂や全長252mの福浦橋は小学生もワクワクする観光名所',
          '湾内を巡る大型遊覧船や、焼きたての手焼き笹かま体験・牡蠣カレーパンなど食べ歩きも充実',
          '展望台（西行戻しの松公園など）からの松島湾パノラマ絶景は家族写真のベストスポット',
        ],
        aiTip: '海岸沿いの中心駐車場が満車のときは、高台の「西行戻しの松公園（無料駐車場）」に停めて絶景とカフェを楽しむのも穴場です。',
        address: '宮城県宮城郡松島町松島字町内',
        latitude: 38.3719,
        longitude: 141.0598,
        weatherText: '☀️ 絶景ドライブ日和',
        sourceInfo: '松島観光協会 公式 / Googleマップ高評価',
        url: 'https://www.matsushima-kanko.com/',
        isFavorite: false,
        googleRating: 4.3,
        googleRatingCount: 5410,
        googleReviews: const [
          '★5: 遊覧船からの景色が素晴らしく、小学生の子どもも大喜びでした！笹かまの手焼き体験も楽しいです。',
          '★4: 五大堂の透かし橋がスリル満点。周辺の食事処や食べ歩きグルメも豊富で半日たっぷり遊べます。',
        ],
      ),
    ];
  }

  /// メイン検索エントリ：地域・期間・ジャンル・地図中心座標に応じて最適なリアルタイム検索を実行
  static Future<AiSearchResult> searchWithAi({
    required String query,
    required String departureArea,
    int maxDriveMinutes = 120,
    required List<OutingSpot> currentSpots,
    double? userLat,
    double? userLng,
    SpotCategory? targetCategory,
    TohokuRegion selectedRegion = TohokuRegion.miyagi,
    DateTimeRange? targetDateRange,
    double? searchCenterLat,
    double? searchCenterLng,
    String? mapCenterLabel,
  }) async {
    final apiKey = AppApiKeys.geminiApiKey.trim();
    final mapsKey = AppApiKeys.googleMapsApiKey.trim();
    final cleanQuery = query.replaceAll(RegExp(r'[🎪🍠🍽️📸🏃♨️🏛️🌳⛩️🍔👶👦☔✨📍🚗🍎⛰️🌾🍒🍑]'), '').trim();

    final effectiveDateRange = targetDateRange ?? getUpcomingWeekendRange();
    final dateRangeText = formatDateRange(effectiveDateRange);

    // クエリやターゲットカテゴリから検索ジャンルを判定
    final resolvedCategory = _resolveSearchGenre(cleanQuery, targetCategory);

    // フリーワードに東北以外の都道府県名や具体的な地名が含まれているか判定
    final externalArea = _detectExternalAreaInQuery(cleanQuery);
    final isMapAreaSearch = searchCenterLat != null && searchCenterLng != null;
    final areaDisplayLabel = isMapAreaSearch
        ? (mapCenterLabel ?? _guessPrefectureOrCityName(searchCenterLat, searchCenterLng))
        : (externalArea?.prefName ?? selectedRegion.label);

    // =========================================================================
    // A. 「🎪 期間限定イベント」の場合：
    //    指定期間（デフォルトは直近の週末）に開催されるイベントを取得（Web版CORS対応済み）
    // =========================================================================
    if (resolvedCategory == SpotCategory.event) {
      final liveEvents = await _fetchLiveWebEvents(
        query: cleanQuery,
        targetCategory: SpotCategory.event,
        selectedRegion: selectedRegion,
        externalArea: externalArea,
        targetDateRange: effectiveDateRange,
        userLat: userLat,
        userLng: userLng,
        searchCenterLat: searchCenterLat,
        searchCenterLng: searchCenterLng,
      );

      // Web環境のCORS制約や外部サイト接続切れ時は、厳選イベントコレクションから確実に表示（銭湯等のすり替わりを完全防止）
      final eventSpots = liveEvents.isNotEmpty
          ? liveEvents
          : _getCuratedEventsForRegion(
              selectedRegion: selectedRegion,
              externalArea: externalArea,
              dateRangeText: dateRangeText,
              userLat: userLat,
              userLng: userLng,
            );

      if (eventSpots.isNotEmpty) {
        if (apiKey.isNotEmpty) {
          final enhanced = await _enhanceSpotsWithGeminiAi(
            apiKey: apiKey,
            query: cleanQuery.isEmpty ? '期間限定イベント（$dateRangeText）' : cleanQuery,
            areaLabel: areaDisplayLabel,
            dateRangeLabel: dateRangeText,
            spots: eventSpots,
          );
          if (enhanced != null) return enhanced;
        }

        return AiSearchResult(
          aiSummaryComment:
              '🎪 【$areaDisplayLabel】$dateRangeText に開催される期間限定イベント・催し物を ${eventSpots.length}件 取得しました！',
          spots: eventSpots,
          isLiveAi: true,
        );
      }
    }

    // =========================================================================
    // B. 「🍠 グルメ・マルシェ」の場合：
    //    開催中のグルメイベント・マルシェ ＋ 地域の道の駅・朝市・ご当地グルメスポットを両方取得！
    // =========================================================================
    if (resolvedCategory == SpotCategory.gourmet) {
      final liveGourmetEvents = await _fetchLiveWebEvents(
        query: cleanQuery,
        targetCategory: SpotCategory.gourmet,
        selectedRegion: selectedRegion,
        externalArea: externalArea,
        targetDateRange: effectiveDateRange,
        userLat: userLat,
        userLng: userLng,
        searchCenterLat: searchCenterLat,
        searchCenterLng: searchCenterLng,
      );

      List<OutingSpot> placesGourmetSpots = [];
      if (mapsKey.isNotEmpty) {
        try {
          final placesRes = await _callGooglePlacesLiveSearch(
            mapsApiKey: mapsKey,
            query: cleanQuery,
            selectedRegion: selectedRegion,
            externalArea: externalArea,
            targetDateRange: effectiveDateRange,
            userLat: userLat,
            userLng: userLng,
            searchCenterLat: searchCenterLat,
            searchCenterLng: searchCenterLng,
            mapCenterLabel: mapCenterLabel,
            targetCategory: SpotCategory.gourmet,
          );
          if (placesRes != null) {
            placesGourmetSpots = placesRes.spots;
          }
        } catch (_) {}
      }

      final combinedGourmet = _deduplicateAndAggregateSpots([
        ...( _stripAreaAndGenreWords(cleanQuery).isNotEmpty
            ? liveGourmetEvents.where((s) =>
                '${s.title} ${s.subtitle} ${s.address}'
                    .toLowerCase()
                    .contains(_stripAreaAndGenreWords(cleanQuery).toLowerCase()))
            : liveGourmetEvents),
        ...placesGourmetSpots,
      ]);
      combinedGourmet.sort((a, b) => _compareSpotsForFamily(
            a,
            b,
            centerLat: searchCenterLat,
            centerLng: searchCenterLng,
          ));

      if (combinedGourmet.isNotEmpty) {
        if (apiKey.isNotEmpty) {
          final enhanced = await _enhanceSpotsWithGeminiAi(
            apiKey: apiKey,
            query: cleanQuery.isEmpty ? 'グルメ・マルシェ・道の駅' : cleanQuery,
            areaLabel: areaDisplayLabel,
            dateRangeLabel: dateRangeText,
            spots: combinedGourmet,
          );
          if (enhanced != null) return enhanced;
        }
        return AiSearchResult(
          aiSummaryComment:
              '🍠 【$areaDisplayLabel】のグルメマルシェ・道の駅・ご当地グルメスポットを ${combinedGourmet.length}件 取得しました！',
          spots: combinedGourmet,
          isLiveAi: true,
        );
      }
    }

    // =========================================================================
    // C. 「♨️ 温泉・日帰り銭湯」「🏃 大きな公園」「🏛️ 屋内スポット」「🌳 小さな公園」「⛩️ 神社仏閣」
    //    または一般キーワード検索：
    //    イベントに引っ張られず、純粋な常設スポットとして Google Places API で多数取得！
    // =========================================================================
    if (mapsKey.isNotEmpty) {
      try {
        final placesResult = await _callGooglePlacesLiveSearch(
          mapsApiKey: mapsKey,
          query: cleanQuery,
          selectedRegion: selectedRegion,
          externalArea: externalArea,
          targetDateRange: effectiveDateRange,
          userLat: userLat,
          userLng: userLng,
          searchCenterLat: searchCenterLat,
          searchCenterLng: searchCenterLng,
          mapCenterLabel: mapCenterLabel,
          targetCategory: resolvedCategory,
        );
        if (placesResult != null && placesResult.spots.isNotEmpty) {
          List<OutingSpot> finalSpots = placesResult.spots;

          // 「すべて（ジャンル未選択＆フリーワード空）」かつ通常検索時のみ、直近週末のイベントも先頭にミックス
          if (cleanQuery.isEmpty && targetCategory == null && !isMapAreaSearch) {
            final topEvents = await _fetchLiveWebEvents(
              query: '',
              targetCategory: SpotCategory.event,
              selectedRegion: selectedRegion,
              externalArea: externalArea,
              targetDateRange: effectiveDateRange,
              userLat: userLat,
              userLng: userLng,
              includeBothEventAndGourmet: true,
            );
            if (topEvents.isNotEmpty) {
              finalSpots = _deduplicateAndAggregateSpots([
                ...topEvents.take(6),
                ...placesResult.spots,
              ]);
            }
          }

          if (apiKey.isNotEmpty) {
            final aiEnhanced = await _enhanceSpotsWithGeminiAi(
              apiKey: apiKey,
              query: cleanQuery.isEmpty
                  ? (resolvedCategory?.label ?? '$areaDisplayLabelの週末イベント・お出かけスポット')
                  : cleanQuery,
              areaLabel: areaDisplayLabel,
              dateRangeLabel: dateRangeText,
              spots: finalSpots,
            );
            if (aiEnhanced != null) {
              return aiEnhanced;
            }
          }
          return AiSearchResult(
            aiSummaryComment: placesResult.aiSummaryComment,
            spots: finalSpots,
            isLiveAi: true,
          );
        }
      } catch (_) {}
    }

    // D. フォールバック（オフライン時など）
    return _fallbackCategorySearch(
      query: cleanQuery,
      areaLabel: areaDisplayLabel,
      targetCategory: resolvedCategory,
      userLat: userLat,
      userLng: userLng,
    );
  }

  /// クエリ文字列と選択カテゴリから検索ジャンルを判定
  static SpotCategory? _resolveSearchGenre(String cleanQuery, SpotCategory? explicitCategory) {
    if (explicitCategory != null) return explicitCategory;
    if (cleanQuery.isEmpty) return null;

    if (cleanQuery.contains('温泉') ||
        cleanQuery.contains('銭湯') ||
        cleanQuery.contains('サウナ') ||
        cleanQuery.contains('露天風呂') ||
        cleanQuery.contains('日帰り') ||
        cleanQuery.contains('スーパー銭湯') ||
        cleanQuery.contains('スパ') ||
        cleanQuery.contains('共同浴場') ||
        cleanQuery.contains('竜泉寺') ||
        cleanQuery.contains('スパメッツァ')) {
      return SpotCategory.onsen;
    }
    if (cleanQuery.contains('小さな公園') ||
        cleanQuery.contains('小さい公園') ||
        cleanQuery.contains('近所の公園') ||
        cleanQuery.contains('近くの公園') ||
        cleanQuery.contains('児童公園')) {
      return SpotCategory.smallPark;
    }
    if (cleanQuery.contains('大きな公園') ||
        cleanQuery.contains('大型公園') ||
        cleanQuery.contains('アスレチック') ||
        cleanQuery.contains('思いっきり') ||
        cleanQuery.contains('おもいっきり') ||
        cleanQuery.contains('遊具')) {
      return SpotCategory.park;
    }
    if (cleanQuery.contains('屋内') ||
        cleanQuery.contains('室内') ||
        cleanQuery.contains('雨') ||
        cleanQuery.contains('科学館') ||
        cleanQuery.contains('博物館') ||
        cleanQuery.contains('水族館') ||
        cleanQuery.contains('天文台') ||
        cleanQuery.contains('美術館')) {
      return SpotCategory.indoor;
    }
    if (cleanQuery.contains('観光地') ||
        cleanQuery.contains('名所') ||
        cleanQuery.contains('展望') ||
        cleanQuery.contains('絶景') ||
        cleanQuery.contains('城') ||
        cleanQuery.contains('渓谷') ||
        cleanQuery.contains('滝')) {
      return SpotCategory.tourism;
    }
    if (cleanQuery.contains('神社') ||
        cleanQuery.contains('仏閣') ||
        cleanQuery.contains('寺') ||
        cleanQuery.contains('御朱印') ||
        cleanQuery.contains('参拝') ||
        cleanQuery.contains('八幡宮') ||
        cleanQuery.contains('東照宮') ||
        cleanQuery.contains('稲荷')) {
      return SpotCategory.sightseeing;
    }
    if (cleanQuery.contains('食事') ||
        cleanQuery.contains('ランチ') ||
        cleanQuery.contains('ご飯') ||
        cleanQuery.contains('ごはん') ||
        cleanQuery.contains('定食') ||
        cleanQuery.contains('レストラン') ||
        cleanQuery.contains('食堂') ||
        cleanQuery.contains('ラーメン') ||
        cleanQuery.contains('そば') ||
        cleanQuery.contains('蕎麦') ||
        cleanQuery.contains('うどん') ||
        cleanQuery.contains('カフェ') ||
        cleanQuery.contains('海鮮') ||
        cleanQuery.contains('肉') ||
        cleanQuery.contains('名物料理')) {
      return SpotCategory.dining;
    }
    if (cleanQuery.contains('グルメ') ||
        cleanQuery.contains('おいも') ||
        cleanQuery.contains('パン') ||
        cleanQuery.contains('コーヒー') ||
        cleanQuery.contains('芋煮') ||
        cleanQuery.contains('キッチンカー')) {
      return SpotCategory.dining;
    }
    if (cleanQuery.contains('マルシェ') ||
        cleanQuery.contains('万博') ||
        cleanQuery.contains('道の駅') ||
        cleanQuery.contains('朝市') ||
        cleanQuery.contains('マーケット')) {
      return SpotCategory.tourism;
    }
    if (cleanQuery.contains('期間限定') ||
        cleanQuery.contains('イベント') ||
        cleanQuery.contains('催し') ||
        cleanQuery.contains('スタンプラリー') ||
        cleanQuery.contains('特別展') ||
        cleanQuery.contains('ライトアップ') ||
        cleanQuery.contains('フェス') ||
        cleanQuery.contains('まつり') ||
        cleanQuery.contains('祭り')) {
      return SpotCategory.event;
    }
    return null;
  }

  /// フリーワード内に東北以外の都道府県・主要観光地が含まれているか検出する
  static _WalkerplusAreaTarget? _detectExternalAreaInQuery(String query) {
    if (query.isEmpty) return null;
    const externalAreas = <_WalkerplusAreaTarget>[
      _WalkerplusAreaTarget('ar0101', '北海道', 43.0642, 141.3469, ['北海道', '札幌', '函館', '小樽', '旭川', '富良野']),
      _WalkerplusAreaTarget('ar0308', '茨城県', 36.3418, 140.4468, ['茨城', '水戸', 'つくば', '大洗', 'ひたちなか', '笠間']),
      _WalkerplusAreaTarget('ar0309', '栃木県', 36.5658, 139.8836, ['栃木', '宇都宮', '那須', '日光', '鬼怒川', '佐野', '益子']),
      _WalkerplusAreaTarget('ar0310', '群馬県', 36.3907, 139.0604, ['群馬', '高崎', '前橋', '草津', '伊香保', 'みなかみ', '軽井沢']),
      _WalkerplusAreaTarget('ar0311', '埼玉県', 35.8569, 139.6489, ['埼玉', 'さいたま', '川越', '秩父', '長瀞', '越谷']),
      _WalkerplusAreaTarget('ar0312', '千葉県', 35.6051, 140.1233, ['千葉', '幕張', '浦安', '舞浜', '成田', '木更津', '房総', '銚子']),
      _WalkerplusAreaTarget('ar0313', '東京都', 35.6812, 139.7671, ['東京', '新宿', '渋谷', 'お台場', '浅草', '上野', '池袋', '立川', '八王子']),
      _WalkerplusAreaTarget('ar0314', '神奈川県', 35.4478, 139.6425, ['神奈川', '横浜', '鎌倉', '箱根', '江ノ島', '川崎', '小田原', 'みなとみらい']),
      _WalkerplusAreaTarget('ar0415', '新潟県', 37.9026, 139.0232, ['新潟', '長岡', '越後湯沢', '苗場', '村上', '佐渡', '上越']),
      _WalkerplusAreaTarget('ar0419', '山梨県', 35.6642, 138.5684, ['山梨', '甲府', '河口湖', '富士急', '八ヶ岳', '清里']),
      _WalkerplusAreaTarget('ar0420', '長野県', 36.6513, 138.1810, ['長野', '松本', '上高地', '諏訪', '白馬', '善光寺']),
      _WalkerplusAreaTarget('ar0522', '静岡県', 34.9769, 138.3831, ['静岡', '熱海', '伊豆', '浜松', '御殿場', '富士宮']),
      _WalkerplusAreaTarget('ar0623', '愛知県', 35.1802, 136.9066, ['愛知', '名古屋', 'ジブリパーク', 'レゴランド', '犬山', '岡崎']),
      _WalkerplusAreaTarget('ar0417', '石川県', 36.5947, 136.6256, ['石川', '金沢', '加賀', '能登']),
      _WalkerplusAreaTarget('ar0726', '京都府', 35.0212, 135.7556, ['京都', '嵐山', '祇園', '宇治']),
      _WalkerplusAreaTarget('ar0727', '大阪府', 34.6863, 135.5200, ['大阪', '梅田', '難波', 'USJ', 'ユニバ']),
      _WalkerplusAreaTarget('ar0728', '兵庫県', 34.6913, 135.1830, ['兵庫', '神戸', '有馬', '姫路', '淡路島']),
      _WalkerplusAreaTarget('ar1040', '福岡県', 33.6064, 130.4183, ['福岡', '博多', '天神', '太宰府', '糸島']),
      _WalkerplusAreaTarget('ar1047', '沖縄県', 26.2124, 127.6809, ['沖縄', '那覇', '美ら海', '恩納村', '石垣島', '宮古島']),
    ];

    for (final area in externalAreas) {
      for (final kw in area.keywords) {
        if (query.contains(kw)) {
          return area;
        }
      }
    }
    return null;
  }

  /// フリーワード内に東北の他県名や主要観光地名が含まれている場合、その県を優先する
  static TohokuRegion _resolveEffectiveTohokuRegion(String query, TohokuRegion selectedRegion) {
    if (query.contains('青森') || query.contains('弘前') || query.contains('八戸') || query.contains('十和田') || query.contains('奥入瀬') || query.contains('浅虫') || query.contains('恐山')) {
      return TohokuRegion.aomori;
    }
    if (query.contains('岩手') || query.contains('盛岡') || query.contains('平泉') || query.contains('中尊寺') || query.contains('一関') || query.contains('花巻') || query.contains('北上') || query.contains('厳美渓') || query.contains('猊鼻渓') || query.contains('龍泉洞') || query.contains('浄土ヶ浜') || query.contains('小岩井')) {
      return TohokuRegion.iwate;
    }
    if (query.contains('秋田') || query.contains('横手') || query.contains('角館') || query.contains('田沢湖') || query.contains('男鹿') || query.contains('乳頭温泉') || query.contains('十文字')) {
      return TohokuRegion.akita;
    }
    if (query.contains('山形') || query.contains('山寺') || query.contains('立石寺') || query.contains('天童') || query.contains('東根') || query.contains('上山') || query.contains('かみのやま') || query.contains('米沢') || query.contains('鶴岡') || query.contains('酒田') || query.contains('銀山') || query.contains('寒河江') || query.contains('尾花沢') || query.contains('加茂水族館') || query.contains('羽黒山') || query.contains('蔵王温泉')) {
      return TohokuRegion.yamagata;
    }
    if (query.contains('福島') || query.contains('郡山') || query.contains('会津') || query.contains('大内宿') || query.contains('鶴ヶ城') || query.contains('いわき') || query.contains('猪苗代') || query.contains('裏磐梯') || query.contains('五色沼') || query.contains('飯坂') || query.contains('ハワイアンズ')) {
      return TohokuRegion.fukushima;
    }
    if (query.contains('宮城') || query.contains('仙台') || query.contains('松島') || query.contains('秋保') || query.contains('作並') || query.contains('鳴子') || query.contains('石巻') || query.contains('気仙沼') || query.contains('定義') || query.contains('塩竈') || query.contains('多賀城') || query.contains('白石') || query.contains('女川') || query.contains('南三陸')) {
      return TohokuRegion.miyagi;
    }
    return selectedRegion;
  }

  // ===========================================================================
  // 1. リアルタイム Web イベント取得エンジン（期間フィルタ対応・固定事例バイアスなし）
  // ===========================================================================
  static Future<List<OutingSpot>> _fetchLiveWebEvents({
    required String query,
    required SpotCategory targetCategory,
    required TohokuRegion selectedRegion,
    _WalkerplusAreaTarget? externalArea,
    required DateTimeRange targetDateRange,
    double? userLat,
    double? userLng,
    double? searchCenterLat,
    double? searchCenterLng,
    bool includeBothEventAndGourmet = false,
  }) async {
    final startLat = userLat ?? 38.3866;
    final startLng = userLng ?? 140.8712;
    final effectiveRegion = _resolveEffectiveTohokuRegion(query, selectedRegion);

    // 地図中心検索の場合は、その座標から該当する県を判定
    final targetArea = externalArea ??
        (searchCenterLat != null && searchCenterLng != null
            ? _resolveAreaTargetFromCoords(searchCenterLat, searchCenterLng)
            : _WalkerplusAreaTarget(
                effectiveRegion.walkerplusCode,
                effectiveRegion.label,
                effectiveRegion.centerLat,
                effectiveRegion.centerLng,
              ));

    final isMiyagiSearch = externalArea == null &&
        ((searchCenterLat == null && effectiveRegion == TohokuRegion.miyagi) ||
            targetArea.code == 'ar0204');

    final collected = <OutingSpot>[];

    try {
      final futures = <Future<List<OutingSpot>>>[
        // 宮城県を検索している場合は「せんだい旅日和」と「仙台つーしん」も並列取得
        if (isMiyagiSearch) ...[
          _scrapeSentabiEvents(
            startLat: startLat,
            startLng: startLng,
            targetDateRange: targetDateRange,
          ),
          _scrapeSendaiTushinRssEvents(
            startLat: startLat,
            startLng: startLng,
            isGourmetFocus: targetCategory == SpotCategory.gourmet,
            targetDateRange: targetDateRange,
          ),
        ],
        // Walkerplus から指定地域＆指定期間のイベントを取得
        _scrapeWalkerplusEvents(
          startLat: startLat,
          startLng: startLng,
          areaTarget: targetArea,
          targetDateRange: targetDateRange,
        ),
        // 子どもとお出かけ情報 いこーよ（iko-yo.net）からファミリー向けイベントを取得
        _scrapeIkoyoEvents(
          startLat: startLat,
          startLng: startLng,
          region: effectiveRegion,
          targetDateRange: targetDateRange,
        ),
      ];

      final results = await Future.wait(futures).timeout(const Duration(seconds: 7));
      for (final list in results) {
        for (final item in list) {
          if (!includeBothEventAndGourmet) {
            if (targetCategory == SpotCategory.gourmet && item.category != SpotCategory.gourmet) {
              continue;
            }
            if (targetCategory == SpotCategory.event && item.category != SpotCategory.event) {
              continue;
            }
          }
          collected.add(item);
        }
      }
    } catch (_) {}

    // 名寄せ・重複排除
    var deduplicated = _deduplicateAndAggregateSpots(collected);

    // 検索キーワードが指定されている場合（地域名やジャンル名以外の具体ワード）、一致するものを優先
    final specificKeyword = _stripAreaAndGenreWords(query);
    if (specificKeyword.isNotEmpty) {
      final matched = deduplicated.where((s) {
        final text = '${s.title} ${s.subtitle} ${s.address} ${s.recommendPoints.join(' ')}';
        return text.toLowerCase().contains(specificKeyword.toLowerCase());
      }).toList();
      if (matched.isNotEmpty) {
        deduplicated = matched;
      }
    }

    // ファミリー向け適性スコア（お祭り・フェス・子ども向け・公園等）を最優先し、
    // 同スコア内では現在地（または地図中心）からの所要時間・距離が近い順にソート！
    deduplicated.sort((a, b) => _compareSpotsForFamily(
          a,
          b,
          centerLat: searchCenterLat,
          centerLng: searchCenterLng,
        ));

    return deduplicated;
  }

  /// 小学生連れファミリー、お祭り・フェス、公園・体験を最優先するための適性スコア算出
  static int _calculateFamilyEventScore(OutingSpot spot) {
    int score = 0;
    final text =
        '${spot.title} ${spot.subtitle} ${spot.recommendPoints.join(" ")} ${spot.parkingInfo} ${spot.address}'
            .toLowerCase();

    // 0. 子どもとお出かけ専門「いこーよ」の情報は最優先ブースト（+150点！）
    if (spot.sourceInfo.contains('いこーよ') || spot.id.startsWith('ikoyo_')) {
      score += 150;
    }

    // 1. 子ども・小学生・キャラクター・体験・遊び（最優先: +120点）
    const kidsWords = [
      'ポケモン', 'ピカチュウ', '恐竜', 'ダイナソー', 'アンパンマン', 'アニメ', 'キャラクター',
      '小学生', '子ども', 'こども', 'キッズ', '親子', 'ファミリー',
      'アスレチック', '体験', 'ワークショップ', '工作', 'クラフト', 'スタンプラリー',
      'クイズ', 'おしごと', '実験', 'サイエンス', 'プラネタリウム', '水族館', '動物', 'ふれあい',
      '遊具', 'トランポリン', 'すべり台', 'スライダー'
    ];
    for (final w in kidsWords) {
      if (text.contains(w.toLowerCase())) {
        score += 120;
        break;
      }
    }

    // 2. お祭り・フェス・マルシェ・収穫祭（高得点: +100点）
    const festivalWords = [
      '祭り', 'まつり', 'フェス', 'フェスティバル', 'マルシェ', '収穫祭', 'マーケット',
      '市', 'フリマ', 'バザー', '縁日', '花火', '物産展', 'フェア', '味覚', 'キャンペーン'
    ];
    for (final w in festivalWords) {
      if (text.contains(w.toLowerCase())) {
        score += 100;
        break;
      }
    }

    // 3. 公園・広場・自然（高得点: +80点）
    const parkWords = [
      '公園', '広場', '国営', '県民の森', '森林', '自然公園', '芝生', '緑地',
      'キャンプ', 'アウトドア', '湖畔'
    ];
    for (final w in parkWords) {
      if (text.contains(w.toLowerCase())) {
        score += 80;
        break;
      }
    }

    // 4. 無料駐車場・入場無料（便利度加点: +30点）
    if (spot.tags.contains(SpotTag.freeParking) || text.contains('無料駐車場')) {
      score += 30;
    }
    if (spot.tags.contains(SpotTag.freeEntry) ||
        text.contains('無料') ||
        text.contains('入場無料')) {
      score += 30;
    }

    // 5. ホテル催事・夜間・大人向け・アフタヌーンティー（減点: -150点）
    const adultWords = [
      'ホテル', 'ロイヤルパーク', 'アフタヌーンティー', 'シネマナイト', 'ナイトタイム',
      'ディナー', 'バー', '宿泊', 'ブライダル', '結婚式', '大人'
    ];
    for (final w in adultWords) {
      if (text.contains(w.toLowerCase())) {
        score -= 150;
        break;
      }
    }

    return score;
  }

  /// ファミリー適性スコアと所要時間によるスポット比較（スコア高優先 → 近い順）
  static int _compareSpotsForFamily(
    OutingSpot a,
    OutingSpot b, {
    double? centerLat,
    double? centerLng,
  }) {
    final scoreA = _calculateFamilyEventScore(a);
    final scoreB = _calculateFamilyEventScore(b);

    // スコア差がある場合はスコアが高い方を優先
    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA);
    }

    // スコアが同等の場合は距離・所要時間が近い順
    if (centerLat != null && centerLng != null) {
      final da = LocationService.calculateDistanceKm(
        startLat: centerLat,
        startLng: centerLng,
        endLat: a.latitude,
        endLng: a.longitude,
      );
      final db = LocationService.calculateDistanceKm(
        startLat: centerLat,
        startLng: centerLng,
        endLat: b.latitude,
        endLng: b.longitude,
      );
      return da.compareTo(db);
    }
    return a.driveMinutes.compareTo(b.driveMinutes);
  }

  /// スポット一覧をファミリー向け適性スコア順（お祭り・フェス・子ども向け優先）にソートする
  static List<OutingSpot> sortSpotsForFamily(
    List<OutingSpot> spots, {
    double? centerLat,
    double? centerLng,
  }) {
    final copy = List<OutingSpot>.from(spots);
    copy.sort((a, b) => _compareSpotsForFamily(
          a,
          b,
          centerLat: centerLat,
          centerLng: centerLng,
        ));
    return copy;
  }

  /// イベントの開催期間テキストが指定された `targetDateRange`（開始日〜終了日）に開催中かどうかを判定する
  static bool _doesEventOverlapDateRange(String dateText, DateTimeRange targetDateRange) {
    final rangeStart = DateTime(
      targetDateRange.start.year,
      targetDateRange.start.month,
      targetDateRange.start.day,
    );
    final rangeEnd = DateTime(
      targetDateRange.end.year,
      targetDateRange.end.month,
      targetDateRange.end.day,
      23,
      59,
      59,
    );
    final defaultYear = rangeStart.year;

    // 1. YYYY/MM/DD - YYYY/MM/DD 形式（せんだい旅日和など）
    final slashRange = RegExp(
      r'(\d{4})[/年](\d{1,2})[/月](\d{1,2})日?\s*[-〜~～]\s*(?:(\d{4})[/年])?(\d{1,2})[/月](\d{1,2})',
    ).firstMatch(dateText);
    if (slashRange != null) {
      final y1 = int.tryParse(slashRange.group(1)!) ?? defaultYear;
      final m1 = int.tryParse(slashRange.group(2)!) ?? 1;
      final d1 = int.tryParse(slashRange.group(3)!) ?? 1;
      var y2 = int.tryParse(slashRange.group(4) ?? '') ?? y1;
      final m2 = int.tryParse(slashRange.group(5)!) ?? m1;
      final d2 = int.tryParse(slashRange.group(6)!) ?? d1;
      if (slashRange.group(4) == null && m2 < m1) {
        y2 = y1 + 1;
      }
      final evStart = DateTime(y1, m1, d1);
      final evEnd = DateTime(y2, m2, d2, 23, 59, 59);
      return !evStart.isAfter(rangeEnd) && !evEnd.isBefore(rangeStart);
    }

    // 2. 「開催中〜(YYYY年)M月D日」または「開催中〜M/D」形式（Walkerplusなど）
    final ongoingUntil = RegExp(
      r'開催中\s*[〜~～-]\s*(?:(\d{4})[/年])?(\d{1,2})[/月](\d{1,2})',
    ).firstMatch(dateText);
    if (ongoingUntil != null) {
      final m2 = int.tryParse(ongoingUntil.group(2)!) ?? 12;
      final d2 = int.tryParse(ongoingUntil.group(3)!) ?? 31;
      var y2 = int.tryParse(ongoingUntil.group(1) ?? '') ?? defaultYear;
      final now = DateTime.now();
      if (ongoingUntil.group(1) == null && m2 < now.month) {
        y2 = now.year + 1;
      }
      final evStart = DateTime(now.year, now.month, now.day);
      final evEnd = DateTime(y2, m2, d2, 23, 59, 59);
      return !evStart.isAfter(rangeEnd) && !evEnd.isBefore(rangeStart);
    }

    // 3. 「M月D日(曜)〜M月D日(曜)」または「M/D〜M/D」または「M月D日〜D日」形式
    final mdRange = RegExp(
      r'(\d{1,2})[/月](\d{1,2})日?(?:\([月火水木金土日祝]+\))?\s*[-〜~～・]\s*(?:(\d{1,2})[/月])?(\d{1,2})日?',
    ).firstMatch(dateText);
    if (mdRange != null) {
      final m1 = int.tryParse(mdRange.group(1)!) ?? rangeStart.month;
      final d1 = int.tryParse(mdRange.group(2)!) ?? 1;
      final m2 = int.tryParse(mdRange.group(3) ?? '') ?? m1;
      final d2 = int.tryParse(mdRange.group(4)!) ?? d1;
      final y1 = defaultYear;
      final y2 = m2 < m1 ? y1 + 1 : y1;
      final evStart = DateTime(y1, m1, d1);
      final evEnd = DateTime(y2, m2, d2, 23, 59, 59);
      return !evStart.isAfter(rangeEnd) && !evEnd.isBefore(rangeStart);
    }

    // 4. 単一日付「YYYY/MM/DD」または「M月D日」形式
    final singleSlash = RegExp(r'(\d{4})[/年](\d{1,2})[/月](\d{1,2})').firstMatch(dateText);
    if (singleSlash != null) {
      final y = int.tryParse(singleSlash.group(1)!) ?? defaultYear;
      final m = int.tryParse(singleSlash.group(2)!) ?? 1;
      final d = int.tryParse(singleSlash.group(3)!) ?? 1;
      final evDay = DateTime(y, m, d);
      final evEnd = DateTime(y, m, d, 23, 59, 59);
      return !evDay.isAfter(rangeEnd) && !evEnd.isBefore(rangeStart);
    }

    final singleMd = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(dateText);
    if (singleMd != null) {
      final m = int.tryParse(singleMd.group(1)!) ?? rangeStart.month;
      final d = int.tryParse(singleMd.group(2)!) ?? 1;
      final evDay = DateTime(defaultYear, m, d);
      final evEnd = DateTime(defaultYear, m, d, 23, 59, 59);
      return !evDay.isAfter(rangeEnd) && !evEnd.isBefore(rangeStart);
    }

    // 日付文字列が含まれない場合（「通年」「毎週末」など）は含める
    return true;
  }

  /// せんだい旅日和（https://www.sentabi.jp/event/）から指定期間に開催中のイベントを抽出
  static Future<List<OutingSpot>> _scrapeSentabiEvents({
    required double startLat,
    required double startLng,
    required DateTimeRange targetDateRange,
  }) async {
    final events = <OutingSpot>[];
    final dateRangeText = formatDateRange(targetDateRange);

    try {
      final res = await http.get(
        Uri.parse('https://www.sentabi.jp/event/'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) return events;
      final html = utf8.decode(res.bodyBytes, allowMalformed: true);
      final parts = html.split('<li class="text-link-hover');

      for (final part in parts.skip(1)) {
        final h2Match = RegExp(r'<h2[^>]*>(.*?)</h2>', dotAll: true).firstMatch(part);
        final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).firstMatch(part);
        final dateMatch = RegExp(r'(\d{4}/\d{2}/\d{2}\s*-\s*\d{4}/\d{2}/\d{2}|\d{4}/\d{2}/\d{2})').firstMatch(part);
        final altMatch = RegExp(r'<div class="w-\[14px\][^>]*>.*?alt="([^"]+)"', dotAll: true).firstMatch(part);
        final tagsMatches = RegExp(r'rounded-\[10px\][^>]*>(.*?)</span>', dotAll: true).allMatches(part);
        final hrefMatch = RegExp(r'href="(/events/\d+)"').firstMatch(part);

        final title = _cleanHtml(h2Match?.group(1) ?? '');
        if (title.isEmpty) continue;

        final rawDesc = _cleanHtml(pMatch?.group(1) ?? '');
        final dateStr = dateMatch?.group(1)?.trim() ?? '';

        // 指定した週末・期間に開催しているか厳密チェック
        if (dateStr.isNotEmpty && !_doesEventOverlapDateRange(dateStr, targetDateRange)) {
          continue;
        }

        final areaStr = altMatch?.group(1)?.trim() ?? '仙台市内';
        final webTags = tagsMatches.map((m) => _cleanHtml(m.group(1) ?? '')).where((t) => t.isNotEmpty).toList();
        final eventId = hrefMatch?.group(1)?.replaceAll('/', '_') ?? '${events.length}';
        final eventUrl = hrefMatch != null
            ? 'https://www.sentabi.jp${hrefMatch.group(1)}'
            : 'https://www.sentabi.jp/event/';

        final isGourmet = webTags.contains('食') ||
            title.contains('マルシェ') ||
            title.contains('グルメ') ||
            title.contains('食') ||
            title.contains('フルーツ') ||
            title.contains('芋') ||
            title.contains('コーヒー') ||
            title.contains('パン');

        final locInfo = _resolveVenueCoordinates('$title $areaStr $rawDesc');
        final distKm = LocationService.calculateDistanceKm(
          startLat: startLat,
          startLng: startLng,
          endLat: locInfo.lat,
          endLng: locInfo.lng,
        );
        final driveMin = LocationService.estimateDriveMinutes(distKm);

        events.add(
          OutingSpot(
            id: 'sentabi$eventId',
            title: title,
            subtitle: rawDesc.isNotEmpty
                ? rawDesc
                : '【$areaStr】$dateRangeText に開催される注目イベント',
            category: isGourmet ? SpotCategory.dining : SpotCategory.event,
            tags: [
              if (isGourmet) SpotTag.food,
              SpotTag.kids,
              if (locInfo.hasFreeParking) SpotTag.freeParking,
            ],
            driveMinutes: driveMin,
            distanceKm: distKm,
            scheduleText: dateStr.isNotEmpty ? '開催期間: $dateStr（$dateRangeText 開催）' : '$dateRangeText 開催中',
            parkingInfo: locInfo.parking,
            recommendPoints: [
              if (rawDesc.isNotEmpty) rawDesc,
              '開催エリア: $areaStr（ジャンル: ${webTags.isEmpty ? "期間限定イベント" : webTags.join("・")}）',
              '対象期間（$dateRangeText）にお出かけできる宮城・仙台の公式イベント',
            ],
            aiTip: '期間限定イベントのため、公式サイトで開催時間や駐車場状況を確認してのお出かけがおすすめです。',
            address: locInfo.address,
            latitude: locInfo.lat,
            longitude: locInfo.lng,
            weatherText: '☀️ イベント日和',
            sourceInfo: 'せんだい旅日和 公式イベント情報',
            url: eventUrl,
          ),
        );
      }
    } catch (_) {}
    return events;
  }

  /// 仙台つーしん（https://sendai-tushin.jp）のRSSから指定期間に合致するイベント開催情報を抽出
  static Future<List<OutingSpot>> _scrapeSendaiTushinRssEvents({
    required double startLat,
    required double startLng,
    required bool isGourmetFocus,
    required DateTimeRange targetDateRange,
  }) async {
    final events = <OutingSpot>[];
    final targetMonth = targetDateRange.start.month;
    final queries = isGourmetFocus
        ? ['マルシェ $targetMonth月', 'フェス 開催', 'マーケット 開催']
        : ['イベント $targetMonth月 開催', 'フェス 開催'];

    for (final q in queries) {
      try {
        final url = 'https://sendai-tushin.jp/?s=${Uri.encodeComponent(q)}&feed=rss2';
        final res = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0'},
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode != 200) continue;
        final xml = utf8.decode(res.bodyBytes, allowMalformed: true);
        final items = RegExp(
          r'<item>.*?<title>(.*?)</title>.*?(?:<link>(.*?)</link>)?.*?<description><!\[CDATA\[(.*?)\]\]></description>',
          dotAll: true,
        ).allMatches(xml);

        for (final m in items.take(10)) {
          final rawTitle = _cleanHtml(m.group(1) ?? '');
          final articleUrl = m.group(2)?.trim() ?? '';
          final rawDesc = _cleanHtml(m.group(3) ?? '');

          if (rawTitle.contains('閉店') ||
              rawTitle.contains('オープン') ||
              rawTitle.contains('出店予定') ||
              rawTitle.contains('中止') ||
              rawTitle.contains('2024年') ||
              rawTitle.contains('2023年') ||
              rawTitle.contains('2022年') ||
              rawTitle.contains('2021年') ||
              rawTitle.contains('2020年') ||
              rawTitle.contains('分譲住宅')) {
            continue;
          }
          if (!rawTitle.contains('開催') &&
              !rawTitle.contains('マルシェ') &&
              !rawTitle.contains('フェス') &&
              !rawTitle.contains('万博') &&
              !rawTitle.contains('マーケット') &&
              !rawTitle.contains('まつり')) {
            continue;
          }

          // タイトルや本文に日付がある場合、指定期間と重なるか判定
          final combinedText = '$rawTitle $rawDesc';
          final hasExplicitDate = RegExp(r'\d{1,2}[/月]\d{1,2}').hasMatch(combinedText);
          if (hasExplicitDate && !_doesEventOverlapDateRange(combinedText, targetDateRange)) {
            continue;
          }

          final isGourmet = rawTitle.contains('マルシェ') ||
              rawTitle.contains('コーヒー') ||
              rawTitle.contains('パン') ||
              rawTitle.contains('おいも') ||
              rawTitle.contains('芋煮') ||
              rawTitle.contains('グルメ') ||
              rawTitle.contains('マーケット') ||
              rawTitle.contains('ラーメン') ||
              rawTitle.contains('フルーツ');

          final locInfo = _resolveVenueCoordinates(combinedText);
          final distKm = LocationService.calculateDistanceKm(
            startLat: startLat,
            startLng: startLng,
            endLat: locInfo.lat,
            endLng: locInfo.lng,
          );
          final driveMin = LocationService.estimateDriveMinutes(distKm);

          final dateMatch = RegExp(r'(\d{4}年)?\d{1,2}月\d{1,2}日[^。！!]*').firstMatch(combinedText);
          final schedule = dateMatch != null
              ? '${dateMatch.group(0)} 開催'
              : '${formatDateRange(targetDateRange)} 対象イベント';

          events.add(
            OutingSpot(
              id: 'st_${rawTitle.hashCode.abs()}',
              title: rawTitle.replaceAll('みたい！', '').replaceAll('みたい。', ''),
              subtitle: rawDesc.length > 90 ? '${rawDesc.substring(0, 90)}...' : rawDesc,
              category: isGourmet ? SpotCategory.dining : SpotCategory.event,
              tags: [
                if (isGourmet) SpotTag.food,
                SpotTag.kids,
                if (locInfo.hasFreeParking) SpotTag.freeParking,
              ],
              driveMinutes: driveMin,
              distanceKm: distKm,
              scheduleText: schedule,
              parkingInfo: locInfo.parking,
              recommendPoints: [
                rawDesc.isNotEmpty ? rawDesc : '地元で話題の週末限定イベント・催し物',
                '開催エリア: ${locInfo.address}',
              ],
              aiTip: '週末限定開催のイベントのため、午前中の早い時間帯のお出かけがおすすめです。',
              address: locInfo.address,
              latitude: locInfo.lat,
              longitude: locInfo.lng,
              weatherText: '☀️ お出かけ日和',
              sourceInfo: '仙台つーしん 最新イベント情報',
              url: articleUrl,
            ),
          );
        }
      } catch (_) {}
    }
    return events;
  }

  /// Walkerplus から指定地域＆指定期間に開催されるイベントを抽出
  static Future<List<OutingSpot>> _scrapeWalkerplusEvents({
    required double startLat,
    required double startLng,
    required _WalkerplusAreaTarget areaTarget,
    required DateTimeRange targetDateRange,
  }) async {
    final areaEvents = <OutingSpot>[];
    final dateRangeLabel = formatDateRange(targetDateRange);

    // 「今週末（weekend）」一覧と「地域イベント総合（指定期間を含む今後のイベント）」一覧の両方を並列取得
    final urls = <String>[
      'https://www.walkerplus.com/event_list/weekend/${areaTarget.code}/',
      'https://www.walkerplus.com/event_list/${areaTarget.code}/',
      'https://www.walkerplus.com/event_list/today/${areaTarget.code}/',
    ];

    try {
      final responses = await Future.wait(
        urls.map(
          (u) => http
              .get(Uri.parse(u), headers: {'User-Agent': 'Mozilla/5.0'})
              .timeout(const Duration(seconds: 4))
              .catchError((_) => http.Response('', 500)),
        ),
      );

      final seenLinks = <String>{};
      final matchingDateEvents = <OutingSpot>[];
      final fallbackAreaEvents = <OutingSpot>[];

      for (final res in responses) {
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) continue;
        final html = utf8.decode(res.bodyBytes, allowMalformed: true);
        final items = html.split('<div class="m-mainlist-item"');

        for (final itemHtml in items.skip(1).take(15)) {
          final ttlMatch = RegExp(
            r'<span class="m-mainlist-item__ttl"[^>]*>(.*?)</span>',
            dotAll: true,
          ).firstMatch(itemHtml);
          final linkMatch = RegExp(r'href="(/event/[^"]+)"').firstMatch(itemHtml);

          final title = _cleanHtml(ttlMatch?.group(1) ?? '');
          if (title.isEmpty) continue;

          final eventPath = linkMatch?.group(1) ?? title;
          if (seenLinks.contains(eventPath)) continue;
          seenLinks.add(eventPath);

          final eventUrl = linkMatch != null
              ? 'https://www.walkerplus.com${linkMatch.group(1)}'
              : 'https://www.walkerplus.com/event_list/${areaTarget.code}/';

          // アイテムHTML内の開催期間・場所テキストを抽出
          final plainItem = _cleanHtml(itemHtml);
          final periodMatch = RegExp(
            r'(開催中\s*[〜~～-]\s*(?:\d{4}年)?\d{1,2}月\d{1,2}日(?:\([^\)]+\))?|(?:\d{4}年)?\d{1,2}月\d{1,2}日(?:\([^\)]+\))?\s*[〜~～-]\s*(?:\d{4}年)?(?:\d{1,2}月)?\d{1,2}日(?:\([^\)]+\))?|(?:\d{4}年)?\d{1,2}月\d{1,2}日(?:\([^\)]+\))?)',
          ).firstMatch(plainItem);
          final periodText = periodMatch?.group(1)?.trim() ?? '';

          final placeMatch = RegExp(r'【開催場所】\s*([^\s　]+)|([^\s　]+(?:市|町|村|区)[^\s　]*)').firstMatch(plainItem);
          final placeHint = placeMatch?.group(1) ?? placeMatch?.group(2) ?? '';

          final isGourmet = title.contains('グルメ') ||
              title.contains('マルシェ') ||
              title.contains('食') ||
              title.contains('芋煮') ||
              title.contains('そば') ||
              title.contains('ラーメン') ||
              title.contains('スイーツ') ||
              title.contains('フルーツ') ||
              title.contains('フェス') ||
              title.contains('収穫祭') ||
              title.contains('味覚');

          final locInfo = _resolveVenueCoordinates(
            '$title $placeHint ${areaTarget.prefName}',
            fallbackLat: areaTarget.defaultLat,
            fallbackLng: areaTarget.defaultLng,
            fallbackAddress: placeHint.isNotEmpty
                ? '${areaTarget.prefName} $placeHint'
                : '${areaTarget.prefName}内（イベント会場）',
          );
          final distKm = LocationService.calculateDistanceKm(
            startLat: startLat,
            startLng: startLng,
            endLat: locInfo.lat,
            endLng: locInfo.lng,
          );
          final driveMin = LocationService.estimateDriveMinutes(distKm);

          final spot = OutingSpot(
            id: 'wp_${areaTarget.code}_${title.hashCode.abs()}',
            title: title,
            subtitle: periodText.isNotEmpty
                ? '【${areaTarget.prefName}】開催期間: $periodText'
                : '【${areaTarget.prefName}】$dateRangeLabel に楽しめる注目イベント',
            category: isGourmet ? SpotCategory.dining : SpotCategory.event,
            tags: [
              if (isGourmet) SpotTag.food,
              SpotTag.kids,
              if (locInfo.hasFreeParking) SpotTag.freeParking,
            ],
            driveMinutes: driveMin,
            distanceKm: distKm,
            scheduleText: periodText.isNotEmpty
                ? '$periodText（対象: $dateRangeLabel）'
                : '開催期間: $dateRangeLabel 開催中',
            parkingInfo: locInfo.parking,
            recommendPoints: [
              '${areaTarget.prefName}で$dateRangeLabelにお出かけできる注目イベント',
              '開催場所・エリア: ${locInfo.address}',
              '周辺の温泉や神社仏閣、公園と組み合わせて週末ドライブに最適',
            ],
            aiTip: 'ドライブ地図タブに切り替えると、このイベント会場の周辺にある温泉や神社・公園もワンタップで探せます！',
            address: locInfo.address,
            latitude: locInfo.lat,
            longitude: locInfo.lng,
            weatherText: '☀️ お出かけ日和',
            sourceInfo: 'Walkerplus ${areaTarget.prefName}イベント情報',
            url: eventUrl,
          );

          if (periodText.isEmpty || _doesEventOverlapDateRange(periodText, targetDateRange)) {
            matchingDateEvents.add(spot);
          } else {
            fallbackAreaEvents.add(spot);
          }
        }
      }

      if (matchingDateEvents.isNotEmpty) {
        areaEvents.addAll(matchingDateEvents);
      } else {
        areaEvents.addAll(fallbackAreaEvents);
      }
    } catch (_) {}
    return areaEvents;
  }


  /// 「子どもとお出かけ情報 いこーよ（iko-yo.net）」から小学生・ファミリー向けイベントを取得
  static Future<List<OutingSpot>> _scrapeIkoyoEvents({
    required double startLat,
    required double startLng,
    required TohokuRegion region,
    required DateTimeRange targetDateRange,
  }) async {
    final events = <OutingSpot>[];
    final dateRangeLabel = formatDateRange(targetDateRange);
    final prefId = region.ikoyoPrefectureId;

    // 「今週末（term=7）」一覧と「全イベント」一覧の両方を並列取得
    final urls = [
      'https://iko-yo.net/events?prefecture_ids%5B%5D=$prefId&term=7',
      'https://iko-yo.net/events?prefecture_ids%5B%5D=$prefId',
    ];

    try {
      final responses = await Future.wait(
        urls.map(
          (u) => http.get(
            Uri.parse(u),
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          ).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
        ),
      );

      final seenTitles = <String>{};

      for (final res in responses) {
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) continue;
        final html = utf8.decode(res.bodyBytes, allowMalformed: true);

        // <script type="application/ld+json">...</script> から抽出
        final scriptMatches = RegExp(
          r'<script\s+type="application/ld\+json"\s*>(.*?)</script>',
          dotAll: true,
        ).allMatches(html);

        for (final m in scriptMatches) {
          final jsonStr = m.group(1)?.trim() ?? '';
          if (!jsonStr.contains('"@type":"Event"') && !jsonStr.contains('"@type": "Event"')) {
            continue;
          }

          try {
            final data = jsonDecode(jsonStr);
            if (data is! Map) continue;
            if (data['@type'] != 'Event') continue;

            final name = (data['name'] ?? '').toString().trim();
            if (name.isEmpty || seenTitles.contains(name)) continue;

            final desc = (data['description'] ?? '').toString().trim();
            final startDateStr = (data['startDate'] ?? '').toString().trim();
            final endDateStr = (data['endDate'] ?? startDateStr).toString().trim();

            // 開催期間と指定週末が重なっているか判定
            if (startDateStr.isNotEmpty) {
              DateTime? evStart;
              DateTime? evEnd;
              try {
                evStart = DateTime.parse(startDateStr);
                evEnd = DateTime.parse(endDateStr);
              } catch (_) {}

              if (evStart != null && evEnd != null) {
                final rStart = DateTime(targetDateRange.start.year, targetDateRange.start.month, targetDateRange.start.day);
                final rEnd = DateTime(targetDateRange.end.year, targetDateRange.end.month, targetDateRange.end.day, 23, 59, 59);
                if (evStart.isAfter(rEnd) || evEnd.isBefore(rStart)) {
                  continue;
                }
              }
            }

            seenTitles.add(name);

            // 会場・住所の抽出
            var venueName = '';
            var addressLocality = '';
            final loc = data['location'];
            if (loc is Map) {
              venueName = (loc['name'] ?? '').toString().trim();
              final addr = loc['address'];
              if (addr is Map) {
                addressLocality = (addr['addressLocality'] ?? '').toString().trim();
              }
            }

            final eventUrl = (data['url'] ?? 'https://iko-yo.net/events?prefecture_ids%5B%5D=$prefId').toString().trim();
            final offerName = data['offers'] is Map ? (data['offers']['name'] ?? '').toString().trim() : '';

            // 会場座標と駐車場の解決
            final combinedLocText = '$venueName $addressLocality ${region.label}';
            final locInfo = _resolveVenueCoordinates(
              combinedLocText,
              fallbackLat: region.centerLat,
              fallbackLng: region.centerLng,
              fallbackAddress: addressLocality.isNotEmpty ? addressLocality : '${region.label}内（イベント会場）',
            );

            final distKm = LocationService.calculateDistanceKm(
              startLat: startLat,
              startLng: startLng,
              endLat: locInfo.lat,
              endLng: locInfo.lng,
            );
            final driveMin = LocationService.estimateDriveMinutes(distKm);

            final isGourmet = name.contains('マルシェ') ||
                name.contains('グルメ') ||
                name.contains('食') ||
                name.contains('味覚') ||
                name.contains('収穫') ||
                name.contains('フェス') ||
                offerName.contains('グルメ');

            final scheduleStr = startDateStr.isNotEmpty && endDateStr.isNotEmpty
                ? (startDateStr == endDateStr ? '$startDateStr 開催' : '$startDateStr〜$endDateStr 開催中')
                : '$dateRangeLabel 開催中';

            events.add(
              OutingSpot(
                id: 'ikoyo_${region.ikoyoPrefectureId}_${name.hashCode.abs()}',
                title: name,
                subtitle: desc.length > 90 ? '${desc.substring(0, 90)}...' : desc,
                category: isGourmet ? SpotCategory.dining : SpotCategory.event,
                tags: [
                  SpotTag.kids,
                  if (isGourmet) SpotTag.food,
                  if (desc.contains('自然') || desc.contains('公園') || desc.contains('森')) SpotTag.nature,
                  if (desc.contains('体験') || desc.contains('工作') || desc.contains('クラフト')) SpotTag.toddler,
                  if (locInfo.hasFreeParking) SpotTag.freeParking,
                  if (desc.contains('無料') || desc.contains('入場無料')) SpotTag.freeEntry,
                ],
                driveMinutes: driveMin,
                distanceKm: distKm,
                scheduleText: scheduleStr,
                parkingInfo: locInfo.parking,
                recommendPoints: [
                  if (desc.isNotEmpty) desc,
                  '開催会場: ${venueName.isNotEmpty ? venueName : locInfo.address}',
                  if (offerName.isNotEmpty) '体験ジャンル: $offerName',
                  '子どもとお出かけ情報サイト「いこーよ」掲載の注目ファミリーイベント',
                ],
                aiTip: '小学生連れファミリーに大人気の体験イベントです。事前予約が必要な場合があるため公式サイトを確認してのお出かけがおすすめです。',
                address: locInfo.address,
                latitude: locInfo.lat,
                longitude: locInfo.lng,
                weatherText: '☀️ お出かけ日和',
                sourceInfo: '子どもとお出かけ情報 いこーよ',
                url: eventUrl,
              ),
            );
          } catch (_) {}
        }
      }
    } catch (_) {}

    return events;
  }

  /// 座標から最も近い都道府県の Walkerplus ターゲットを返す
  static _WalkerplusAreaTarget _resolveAreaTargetFromCoords(double lat, double lng) {
    TohokuRegion closest = TohokuRegion.miyagi;
    double minDist = double.infinity;
    for (final r in TohokuRegion.values) {
      final d = LocationService.calculateDistanceKm(
        startLat: lat,
        startLng: lng,
        endLat: r.centerLat,
        endLng: r.centerLng,
      );
      if (d < minDist) {
        minDist = d;
        closest = r;
      }
    }
    return _WalkerplusAreaTarget(
      closest.walkerplusCode,
      closest.label,
      closest.centerLat,
      closest.centerLng,
    );
  }

  /// 座標からおおよその県名・エリア名を返す
  static String _guessPrefectureOrCityName(double lat, double lng) {
    if (lat >= 40.2) return '青森県エリア';
    if (lat >= 39.2 && lng < 140.6) return '秋田県エリア';
    if (lat >= 38.8 && lng >= 140.6) return '岩手県エリア';
    if (lat >= 37.8 && lat < 39.0 && lng < 140.5) return '山形県エリア';
    if (lat < 37.9 && lat >= 36.8) return '福島県エリア';
    if (lat >= 37.8 && lat < 39.0 && lng >= 140.5) return '宮城県エリア';
    return '地図表示エリア周辺';
  }

  /// 検索クエリから地域名やジャンル定型語を除いた固有キーワードを取り出す
  static String _stripAreaAndGenreWords(String query) {
    var s = query;
    const words = [
      '宮城県', '宮城', '山形県', '山形', '岩手県', '岩手', '福島県', '福島', '秋田県', '秋田', '青森県', '青森',
      '期間限定イベント', '期間限定', 'イベント', 'グルメ・マルシェ', 'グルメ', 'マルシェ',
      '地元グルメ・食事処', '地元グルメ', '食事処', '観光地・名所', '観光地', '名所',
      '大きな公園（小学生）', '大きな公園', '小さな公園', '公園', '温泉・日帰り銭湯', '温泉', '銭湯',
      '屋内スポット', '屋内', '神社仏閣', '神社', '仏閣', '寺院',
    ];
    for (final w in words) {
      s = s.replaceAll(w, ' ');
    }
    return s.trim();
  }

  // ===========================================================================
  // 2. Google Places API (New) による純粋な常設スポット大量検索エンジン
  //    イベントに引っ張られず、地域タブ・フリーワード・地図中心周辺のスポットを多数取得！
  // ===========================================================================
  static Future<AiSearchResult?> _callGooglePlacesLiveSearch({
    required String mapsApiKey,
    required String query,
    required TohokuRegion selectedRegion,
    _WalkerplusAreaTarget? externalArea,
    required DateTimeRange targetDateRange,
    double? userLat,
    double? userLng,
    double? searchCenterLat,
    double? searchCenterLng,
    String? mapCenterLabel,
    SpotCategory? targetCategory,
  }) async {
    final startLat = userLat ?? 38.3866;
    final startLng = userLng ?? 140.8712;

    final effectiveRegion = _resolveEffectiveTohokuRegion(query, selectedRegion);
    final isMapSearch = searchCenterLat != null && searchCenterLng != null;

    // 検索の中心座標とエリア名称を決定
    final double biasLat = isMapSearch
        ? searchCenterLat
        : (externalArea?.defaultLat ?? effectiveRegion.centerLat);
    final double biasLng = isMapSearch
        ? searchCenterLng
        : (externalArea?.defaultLng ?? effectiveRegion.centerLng);

    final String areaName = isMapSearch
        ? (mapCenterLabel ?? _guessPrefectureOrCityName(searchCenterLat, searchCenterLng).replaceAll('エリア', ''))
        : (externalArea?.prefName ?? effectiveRegion.label);

    final specificKeyword = _stripAreaAndGenreWords(query);
    final queryPrefix = specificKeyword.isNotEmpty
        ? '$areaName $specificKeyword'
        : areaName;

    // ジャンルごとに複数の検索クエリを並列で投げて、純粋なスポットを豊富（20〜35件）に取得する！
    final List<String> searchQueries;
    double biasRadiusMeters = isMapSearch ? 22000.0 : 48000.0;

    switch (targetCategory) {
      case SpotCategory.event:
        searchQueries = specificKeyword.isNotEmpty
            ? ['$specificKeyword 周辺 週末イベント まつり', '$specificKeyword 周辺 マルシェ 催し物 フェスティバル']
            : [
                '$queryPrefix 週末イベント まつり 催し物 フェスティバル',
                '$queryPrefix マルシェ フリーマーケット クラフト市 収穫祭',
              ];
        break;

      case SpotCategory.onsen:
        searchQueries = specificKeyword.isNotEmpty
            ? ['$specificKeyword 周辺 温泉 日帰り入浴 露天風呂', '$specificKeyword 周辺 スーパー銭湯 銭湯 足湯']
            : [
                '$queryPrefix 日帰り温泉 温泉 露天風呂 源泉',
                '$queryPrefix スーパー銭湯 銭湯 サウナ スパ 共同浴場',
              ];
        break;

      case SpotCategory.indoor:
        searchQueries = specificKeyword.isNotEmpty
            ? ['$specificKeyword 周辺 科学館 博物館 水族館 記念館', '$specificKeyword 周辺 屋内 遊び場 美術館 体験施設']
            : [
                '$queryPrefix 科学館 博物館 水族館 天文台 美術館',
                '$queryPrefix 屋内遊び場 児童館 体験施設 こども館',
              ];
        break;

      case SpotCategory.park:
        searchQueries = specificKeyword.isNotEmpty
            ? ['$specificKeyword 周辺 大型公園 アスレチック 総合公園', '$specificKeyword 周辺 運動公園 自然公園 広場']
            : [
                '$queryPrefix 大型公園 総合公園 国営公園 県立公園 運動公園',
                '$queryPrefix フィールドアスレチック 冒険広場 大型遊具 森林公園',
              ];
        break;

      case SpotCategory.smallPark:
        // 小さな公園：地図中心検索または現在地と同じ県なら近傍を優先しつつ複数取得
        biasRadiusMeters = isMapSearch ? 12000.0 : 25000.0;
        searchQueries = specificKeyword.isNotEmpty
            ? ['$specificKeyword 周辺 公園 緑地 広場', '$specificKeyword 周辺 児童公園 親水公園']
            : [
                '$queryPrefix 公園 緑地 親水公園 芝生広場',
                '$queryPrefix 児童公園 近隣公園 街区公園',
              ];
        break;

      case SpotCategory.tourism:
        searchQueries = specificKeyword.isNotEmpty
            ? ['$specificKeyword 周辺 観光スポット 名所 展望台', '$specificKeyword 周辺 観光地 絶景 史跡 散策 道の駅']
            : [
                '$queryPrefix 観光スポット 名所 観光地 展望台 城跡',
                '$queryPrefix 渓谷 滝 絶景 ドライブスポット 観光名所 道の駅',
              ];
        break;

      case SpotCategory.sightseeing:
        searchQueries = specificKeyword.isNotEmpty
            ? ['$specificKeyword 周辺 神社 寺院 仏閣', '$specificKeyword 周辺 八幡宮 東照宮 観音']
            : [
                '$queryPrefix 神社 八幡宮 東照宮 稲荷神社 神宮',
                '$queryPrefix 寺院 仏閣 観音 不動尊 大社',
              ];
        break;

      case SpotCategory.dining:
      case SpotCategory.gourmet:
        searchQueries = specificKeyword.isNotEmpty
            ? [
                '$specificKeyword 周辺 ランチ 美味しい 食事処',
                '$specificKeyword 周辺 名物 そば 定食 食堂 カフェ レストラン',
                '$specificKeyword 周辺 道の駅 ご当地グルメ 食べ歩き',
              ]
            : [
                '$queryPrefix ご当地グルメ 名物ランチ 食堂 定食屋',
                '$queryPrefix 人気ランチ 子連れ 美味しい レストラン',
                '$queryPrefix 道の駅 食堂 ドライブイン 名物料理',
              ];
        break;



      default:
        // フリーワード検索または「すべて」
        if (query.isNotEmpty) {
          searchQueries = [
            '$query 周辺 観光 お出かけ スポット',
            '$query 周辺 ランチ グルメ 名所',
          ];
        } else {
          searchQueries = [
            '$queryPrefix 大型公園 科学館 水族館 日帰り温泉',
            '$queryPrefix 道の駅 神社 観光スポット 家族',
          ];
        }
        break;
    }

    final uri = Uri.parse('https://places.googleapis.com/v1/places:searchText');
    final requests = searchQueries.map((qText) {
      final reqBody = <String, dynamic>{
        'textQuery': qText,
        'languageCode': 'ja',
        'maxResultCount': 20,
      };
      // 具体的な地名・目的地キーワード（例：「山寺」）が入力されていない通常エリア検索、または地図中心検索のときのみ locationBias を付与
      if (isMapSearch || (externalArea == null && specificKeyword.isEmpty)) {
        reqBody['locationBias'] = {
          'circle': {
            'center': {
              'latitude': biasLat,
              'longitude': biasLng,
            },
            'radius': biasRadiusMeters,
          },
        };
      }
      return reqBody;
    }).toList();

    final placeList = <dynamic>[];
    final responses = await Future.wait(
      requests.map(
        (reqBody) => http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': mapsApiKey,
                'X-Goog-FieldMask':
                    'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.editorialSummary,places.parkingOptions,places.goodForChildren,places.regularOpeningHours.weekdayDescriptions,places.reviews,places.types,places.websiteUri,places.googleMapsUri',
              },
              body: jsonEncode(reqBody),
            )
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('', 500)),
      ),
    );

    for (final response in responses) {
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final items = decoded['places'] as List<dynamic>? ?? [];
        placeList.addAll(items);
      }
    }

    if (placeList.isEmpty) {
      return null;
    }

    final dateRangeText = formatDateRange(targetDateRange);
    final liveSpots = <OutingSpot>[];
    final seenPlaceIds = <String>{};

    for (final raw in placeList) {
      if (raw is! Map<String, dynamic>) continue;

      final id = raw['id'] as String? ?? 'place_${liveSpots.length}';
      if (seenPlaceIds.contains(id)) continue;
      seenPlaceIds.add(id);

      final displayNameMap = raw['displayName'] as Map<String, dynamic>?;
      final rawTitle = displayNameMap?['text'] as String? ?? '';
      if (rawTitle.isEmpty) continue;

      // ノイズ除去：単なる駐車場・葬儀場・墓地・オフィス等を除外
      if (rawTitle.endsWith('駐車場') ||
          rawTitle.contains('コインパーキング') ||
          rawTitle.contains('葬祭') ||
          rawTitle.contains('斎場') ||
          rawTitle.contains('霊園') ||
          rawTitle.contains('墓地') ||
          rawTitle.contains('管理事務所')) {
        continue;
      }

      final locMap = raw['location'] as Map<String, dynamic>?;
      final lat = (locMap?['latitude'] as num?)?.toDouble();
      final lng = (locMap?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      // 地図中心検索の場合は、地図の中心から極端に遠い（半径40km超）ノイズだけ除外
      if (isMapSearch) {
        final distFromMapCenter = LocationService.calculateDistanceKm(
          startLat: searchCenterLat,
          startLng: searchCenterLng,
          endLat: lat,
          endLng: lng,
        );
        if (distFromMapCenter > 45.0) continue;
      }

      final distKm = LocationService.calculateDistanceKm(
        startLat: startLat,
        startLng: startLng,
        endLat: lat,
        endLng: lng,
      );
      final driveMin = LocationService.estimateDriveMinutes(distKm);
      final rating = (raw['rating'] as num?)?.toDouble();
      final ratingCount = (raw['userRatingCount'] as num?)?.toInt() ?? 0;

      final ratingBadge =
          rating != null ? ' ★${rating.toStringAsFixed(1)} ($ratingCount件)' : '';
      final rawAddress = (raw['formattedAddress'] as String? ?? '')
          .replaceFirst(RegExp(r'^日本、〒\d{3}-\d{4}\s*'), '')
          .replaceFirst('日本、', '');

      // 地域タブ指定時（かつ具体的な地名・目的地キーワードや他県を指定していない時）のみ、他県の無関係なスポットが混ざらないようチェック
      if (!isMapSearch &&
          externalArea == null &&
          specificKeyword.isEmpty &&
          rawAddress.isNotEmpty) {
        final targetPrefShort = effectiveRegion.label.substring(0, 2); // 宮城, 山形, 岩手, 福島, 秋田, 青森
        // 他の都道府県のスポットが混入していたらスキップ（県境付近の施設は許容）
        const allPrefs = ['宮城県', '山形県', '岩手県', '福島県', '秋田県', '青森県', '東京都', '北海道'];
        final hasOtherPref = allPrefs.any(
          (p) => !p.startsWith(targetPrefShort) && rawAddress.contains(p),
        );
        if (hasOtherPref) continue;
      }

      final editorialMap = raw['editorialSummary'] as Map<String, dynamic>?;
      final editorial = editorialMap?['text'] as String?;

      final reviewsRaw = raw['reviews'] as List<dynamic>? ?? [];
      final reviewTexts = <String>[];
      final formattedGoogleReviews = <String>[];
      for (final rev in reviewsRaw) {
        if (rev is Map<String, dynamic>) {
          final textMap = rev['text'] as Map<String, dynamic>?;
          final t = textMap?['text'] as String?;
          final revRating = (rev['rating'] as num?)?.toInt();
          if (t != null && t.trim().isNotEmpty) {
            final cleanRev = t.replaceAll('\n', ' ').trim();
            reviewTexts.add(cleanRev);
            if (formattedGoogleReviews.length < 4) {
              final shortRev = cleanRev.length > 95
                  ? '${cleanRev.substring(0, 95)}...'
                  : cleanRev;
              final starPrefix = revRating != null ? '★$revRating: ' : '💬 ';
              formattedGoogleReviews.add('$starPrefix$shortRev');
            }
          }
        }
      }

      // 駐車場オプション解析
      final parkingMap = raw['parkingOptions'] as Map<String, dynamic>?;
      String parkingLabel = '専用駐車場・周辺駐車場あり';
      bool hasFreeParking = false;
      if (parkingMap != null) {
        final freeLot = parkingMap['freeParkingLot'] == true;
        final paidLot = parkingMap['paidParkingLot'] == true;
        if (freeLot) {
          parkingLabel = '無料駐車場あり（Googleマップ確認済み）';
          hasFreeParking = true;
        } else if (paidLot) {
          parkingLabel = '有料駐車場あり（Googleマップ確認済み）';
        }
      }

      // 営業時間解析
      final hoursMap = raw['regularOpeningHours'] as Map<String, dynamic>?;
      final weekdayList = hoursMap?['weekdayDescriptions'] as List<dynamic>?;
      String scheduleLabel = '$dateRangeText 営業';
      if (weekdayList != null && weekdayList.isNotEmpty) {
        final sat = weekdayList.firstWhere(
          (e) => e.toString().contains('土曜日'),
          orElse: () => '',
        );
        if (sat.toString().isNotEmpty) {
          scheduleLabel = sat.toString().replaceAll('土曜日: ', '週末営業: ');
        }
      }

      // カテゴリとタグの決定
      final SpotCategory category =
          targetCategory ?? _guessSpotCategory(rawTitle, editorial ?? '');

      // おすすめポイント（Googleマップのレビューとは分離し、スポット自体の魅力・特徴・設備を表示）
      final points = <String>[];
      if (editorial != null && editorial.isNotEmpty) {
        points.add(editorial);
      } else {
        points.add('${category.icon} ${category.label}として家族や夫婦のお出かけに人気のスポット');
      }
      points.add('📍 エリア: $rawAddress（$parkingLabel）');
      if (raw['goodForChildren'] == true) {
        points.add('🧒 小学生・お子様連れファミリーにもおすすめのスポット');
      } else {
        points.add('🕒 $scheduleLabel ｜ 周辺の観光やグルメ巡りにも好アクセス');
      }

      // アドバイス抽出
      String tipText = 'お出かけやイベント帰りの立ち寄りスポットとしてもおすすめです。';
      for (final rText in reviewTexts) {
        if (rText.contains('駐車') ||
            rText.contains('混') ||
            rText.contains('広') ||
            rText.contains('子') ||
            rText.contains('湯') ||
            rText.contains('遊具')) {
          final snippet =
              rText.length > 80 ? '${rText.substring(0, 80)}...' : rText;
          tipText = 'ドライブメモ：「$snippet」';
          break;
        }
      }

      final tags = <SpotTag>{};
      if (hasFreeParking) tags.add(SpotTag.freeParking);
      if (category == SpotCategory.park) {
        tags.add(SpotTag.kids);
        tags.add(SpotTag.nature);
      } else if (category == SpotCategory.onsen) {
        tags.add(SpotTag.onsen);
        tags.add(SpotTag.nature);
      } else if (category == SpotCategory.indoor) {
        tags.add(SpotTag.indoor);
        tags.add(SpotTag.kids);
      } else if (category == SpotCategory.smallPark) {
        tags.add(SpotTag.nature);
        tags.add(SpotTag.freeEntry);
      } else if (category == SpotCategory.tourism) {
        tags.add(SpotTag.nature);
        tags.add(SpotTag.baby);
      } else if (category == SpotCategory.sightseeing) {
        tags.add(SpotTag.baby);
      } else if (category == SpotCategory.dining) {
        tags.add(SpotTag.food);
        tags.add(SpotTag.kids);
      } else if (category == SpotCategory.gourmet) {
        tags.add(SpotTag.food);
      }

      final websiteUri = raw['websiteUri'] as String?;
      final mapsUri = raw['googleMapsUri'] as String?;
      final spotUrl = websiteUri ?? mapsUri ?? '';

      liveSpots.add(
        OutingSpot(
          id: 'google_place_$id',
          title: rawTitle,
          subtitle: editorial ?? 'Google評価$ratingBadge！${category.label}の人気スポット',
          category: category,
          tags: tags.toList(),
          driveMinutes: driveMin,
          distanceKm: distKm,
          scheduleText: scheduleLabel,
          parkingInfo: parkingLabel,
          recommendPoints: points,
          aiTip: tipText,
          address: rawAddress,
          latitude: lat,
          longitude: lng,
          weatherText: category == SpotCategory.indoor
              ? '🏛️ 屋内施設（雨や寒い日も快適）'
              : (category == SpotCategory.onsen
                  ? '♨️ 温泉・日帰り入浴（立ち寄り湯に最適）'
                  : '☀️ お出かけスポット'),
          sourceInfo: 'Google Places リアルタイム検索$ratingBadge',
          url: spotUrl,
          googleRating: rating,
          googleRatingCount: ratingCount > 0 ? ratingCount : null,
          googleReviews: formattedGoogleReviews,
        ),
      );
    }

    if (liveSpots.isEmpty) return null;

    // 同一施設の重複ゲートのみ集約（別施設を誤って消さない）
    final aggregatedSpots = _deduplicateAndAggregateSpots(liveSpots);

    // 地図中心検索なら地図中心から近い順、通常時は選択地域の中心または現在地から近い順にソート
    if (isMapSearch) {
      aggregatedSpots.sort((a, b) {
        final da = LocationService.calculateDistanceKm(
          startLat: searchCenterLat,
          startLng: searchCenterLng,
          endLat: a.latitude,
          endLng: a.longitude,
        );
        final db = LocationService.calculateDistanceKm(
          startLat: searchCenterLat,
          startLng: searchCenterLng,
          endLat: b.latitude,
          endLng: b.longitude,
        );
        return da.compareTo(db);
      });
    } else {
      aggregatedSpots.sort((a, b) => a.driveMinutes.compareTo(b.driveMinutes));
    }

    final genreLabel =
        targetCategory?.label ?? (query.isEmpty ? 'おすすめスポット' : '「$query」');
    return AiSearchResult(
      aiSummaryComment: isMapSearch
          ? '🗺️ 地図の表示エリア（$areaName）周辺にある【$genreLabel】を ${aggregatedSpots.length}件 取得しました！ピンをタップして「❤️」で登録できます。'
          : '📍 【$areaName】の【$genreLabel】を ${aggregatedSpots.length}件 取得しました！',
      spots: aggregatedSpots,
      isLiveAi: true,
    );
  }

  /// Gemini AI に実際の検索結果リストを渡し、固定事例バイアスのない要約コメントを生成する
  static Future<AiSearchResult?> _enhanceSpotsWithGeminiAi({
    required String apiKey,
    required String query,
    required String areaLabel,
    required String dateRangeLabel,
    required List<OutingSpot> spots,
  }) async {
    try {
      final spotSummaries = spots
          .take(6)
          .map((s) => '・${s.title}（${s.category.label}、${s.address}）')
          .join('\n');
      final prompt = '''
あなたは小学生の子どもがいる夫婦向けの週末お出かけAIナビゲーターです。
対象エリア「$areaLabel」（対象期間: $dateRangeLabel）で以下のスポット・イベントが見つかりました：
$spotSummaries

検索ジャンル・要望: 「$query」
上記リストに実際に含まれているスポット・イベントだけをもとに、小学生の子どもとのお出かけや立ち寄りドライブにおすすめの理由を70〜100文字程度で魅力的に要約してください。
※上記リストに無いイベント名（過去の事例など）は絶対に出さないでください。要約文のみを出力してください。
''';

      // Gemini 3.5/3.6/3.8 では廃止された temperature パラメータを含めず公式仕様に準拠して呼び出す
      final targetModels = [
        'gemini-3.5-flash-lite',
        'gemini-3.8-flash',
        'gemini-2.5-flash',
      ];
      for (final model in targetModels) {
        try {
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 200,
              },
            }),
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
            if (jsonResponse is Map<String, dynamic>) {
              final candidates = jsonResponse['candidates'] as List<dynamic>?;
              if (candidates != null && candidates.isNotEmpty) {
                final content = (candidates.first as Map<String, dynamic>)['content']
                    as Map<String, dynamic>?;
                final parts = content?['parts'] as List<dynamic>?;
                if (parts != null && parts.isNotEmpty) {
                  final text = (parts.first as Map<String, dynamic>)['text'] as String?;
                  if (text != null && text.trim().isNotEmpty) {
                    return AiSearchResult(
                      aiSummaryComment:
                          '🤖 【Gemini AI ナビ（$areaLabel / ${spots.length}件ヒット）】\n${text.trim()}',
                      spots: spots,
                      isLiveAi: true,
                    );
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  /// 夫婦のお気に入り履歴をもとに、Gemini 3.5 Flash-Lite が好みを分析＆おすすめ提案を生成
  static Future<CouplePreferenceAiInsight> generatePersonalizedInsight({
    required List<OutingSpot> favorites,
    required TohokuRegion currentRegion,
    required List<OutingSpot> currentSpots,
    required DateTimeRange dateRange,
  }) async {
    // favorites が空の場合はガイド文を返す
    if (favorites.isEmpty) {
      return CouplePreferenceAiInsight(
        preferenceSummary: 'お気に入り未登録',
        recommendationText:
            '気になるスポットの「❤️」を押すと、Geminiがおふたりの好み（温泉・自然・食事等）を自動分析し、${currentRegion.label}のおすすめ巡り方を提案します！',
        favoriteKeywords: const ['ハートを付けて好みを学習'],
        analyzedAt: DateTime.now(),
      );
    }

    final apiKey = AppApiKeys.geminiApiKey.trim();
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      return _generateLocalPreferenceInsight(favorites, currentRegion);
    }

    final dateLabel = formatDateRange(dateRange);
    final favListText = favorites
        .take(10)
        .map((s) {
          final note = s.coupleNote.isNotEmpty ? '（メモ: ${s.coupleNote}）' : '';
          final pick = s.pickedBy?.label ?? '2人とも';
          return '・${s.title} [${s.category.label}] 担当: $pick $note';
        })
        .join('\n');

    final candidateListText = currentSpots
        .where((s) => !favorites.any((f) => f.id == s.id))
        .take(6)
        .map((s) => '・${s.title} [${s.category.label}]（${s.address}）')
        .join('\n');

    final prompt = '''
あなたは小学生連れファミリー向けのお出かけコンシェルジュAIです。
あるご夫婦が「行きたい！」とハートを付けたスポット履歴はこちらです：
$favListText

現在、ご夫婦は【${currentRegion.label}】の週末（$dateLabel）のお出かけを調べています。
現地で訪問可能なスポット候補例:
$candidateListText

【依頼】
ご夫婦のお気に入り履歴から好みや傾向を分析し、${currentRegion.label}での週末の過ごし方やイチオシ候補を提案してください。
必ず以下のJSONフォーマットのみを出力してください（Markdownの```json等のコードブロックは不要）：
{
  "summary": "ご夫婦の好み傾向（20〜30文字程度。例：名物グルメと自然の温泉が大好きなご夫婦）",
  "keywords": ["温泉好き", "ご当地グルメ", "のんびり散策"],
  "recommendation": "このご夫婦の好みに合わせた、${currentRegion.label}でのおすすめスポットや週末ドライブの巡り方アドバイス（100〜140文字程度。親しみやすい丁寧な日本語）"
}
''';

    final targetModels = [
      'gemini-3.5-flash-lite',
      'gemini-3.8-flash',
      'gemini-2.5-flash',
    ];

    for (final model in targetModels) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'maxOutputTokens': 300,
            },
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          final candidates = jsonResponse['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = (candidates.first as Map<String, dynamic>)['content']
                as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final rawText =
                  (parts.first as Map<String, dynamic>)['text'] as String?;
              if (rawText != null) {
                try {
                  final cleaned = rawText
                      .replaceAll('```json', '')
                      .replaceAll('```', '')
                      .trim();
                  final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
                  final summary =
                      parsed['summary'] as String? ?? '夫婦のお気に入り分析';
                  final rawKw = parsed['keywords'] as List<dynamic>? ?? [];
                  final keywords = rawKw.map((k) => k.toString()).toList();
                  final rec = parsed['recommendation'] as String? ?? '';
                  if (rec.isNotEmpty) {
                    return CouplePreferenceAiInsight(
                      preferenceSummary: summary,
                      recommendationText: rec,
                      favoriteKeywords:
                          keywords.isEmpty ? ['夫婦のイチオシ'] : keywords,
                      analyzedAt: DateTime.now(),
                    );
                  }
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    }

    // 万が一AI通信が失敗した場合のオフライン推論フォールバック
    return _generateLocalPreferenceInsight(favorites, currentRegion);
  }

  /// オフライン・安全フォールバック用の夫婦傾向分析
  static CouplePreferenceAiInsight _generateLocalPreferenceInsight(
    List<OutingSpot> favorites,
    TohokuRegion currentRegion,
  ) {
    final catCounts = <SpotCategory, int>{};
    for (final spot in favorites) {
      catCounts[spot.category] = (catCounts[spot.category] ?? 0) + 1;
    }
    final topCat = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mainCatLabel =
        topCat.isNotEmpty ? topCat.first.key.label : 'お出かけ';

    final keywords = <String>[];
    if (favorites.any((s) => s.category == SpotCategory.onsen)) {
      keywords.add('♨️ 温泉好き');
    }
    if (favorites.any((s) =>
        s.category == SpotCategory.dining ||
        s.category == SpotCategory.gourmet)) {
      keywords.add('🍽️ グルメ好き');
    }
    if (favorites.any((s) =>
        s.category == SpotCategory.park ||
        s.category == SpotCategory.smallPark)) {
      keywords.add('🌳 公園・自然派');
    }
    if (favorites.any((s) => s.category == SpotCategory.sightseeing)) {
      keywords.add('⛩️ 歴史・散策');
    }
    if (keywords.isEmpty) keywords.add('🚗 ドライブ好き');

    final favTitles = favorites.take(2).map((s) => s.title).join('や');
    return CouplePreferenceAiInsight(
      preferenceSummary: '$mainCatLabelを中心としたお出かけ好き',
      recommendationText:
          '「$favTitles」をお気に入りに選ばれたおふたりには、${currentRegion.label}でも立ち寄りドライブやご当地グルメ・スポットを巡るコースがぴったりです！',
      favoriteKeywords: keywords,
      analyzedAt: DateTime.now(),
    );
  }

  /// フォールバック検索（オフライン・テスト環境用）
  static AiSearchResult _fallbackCategorySearch({
    required String query,
    required String areaLabel,
    SpotCategory? targetCategory,
    double? userLat,
    double? userLng,
  }) {
    final startLat = userLat ?? 38.3866;
    final startLng = userLng ?? 140.8712;

    var spots = getInitialSpots().map((s) {
      final distKm = LocationService.calculateDistanceKm(
        startLat: startLat,
        startLng: startLng,
        endLat: s.latitude,
        endLng: s.longitude,
      );
      final driveMin = LocationService.estimateDriveMinutes(distKm);
      return s.copyWith(distanceKm: distKm, driveMinutes: driveMin);
    }).toList();

    if (targetCategory != null) {
      final filtered =
          spots.where((s) => s.category == targetCategory).toList();
      if (filtered.isNotEmpty) {
        spots = filtered;
      } else {
        // 指定ジャンルと異なるスポット（温泉など）が誤って表示されるのを防止
        spots = spots.where((s) => s.category == targetCategory).toList();
      }
    }

    spots.sort((a, b) => a.driveMinutes.compareTo(b.driveMinutes));

    return AiSearchResult(
      aiSummaryComment:
          '📍 【$areaLabel】の【${targetCategory?.label ?? "おすすめスポット"}】を表示しています。',
      spots: spots,
      isLiveAi: true,
    );
  }

  /// Web版（CORS制限時）やスクレイピング不通時にも確実に期間限定イベントを表示するためのデータ
  static List<OutingSpot> _getCuratedEventsForRegion({
    required TohokuRegion selectedRegion,
    _WalkerplusAreaTarget? externalArea,
    required String dateRangeText,
    double? userLat,
    double? userLng,
  }) {
    final startLat = userLat ?? 38.3866;
    final startLng = userLng ?? 140.8712;

    // 1. 全125件の最新スクレイピングイベントマスターから対象地域のイベントを全件抽出（Web版でも36〜45件を確実に即座に表示！）
    final allEvents = CachedEventsData.getAllSpots();
    if (allEvents.isNotEmpty) {
      final targetPrefName = externalArea?.prefName ?? selectedRegion.label;
      final matchedSpots = allEvents.where((s) {
        if (s.address.contains(targetPrefName) ||
            s.title.contains(targetPrefName) ||
            s.subtitle.contains(targetPrefName)) {
          return true;
        }
        if (targetPrefName == '宮城県' &&
            (s.sourceInfo.contains('仙台') ||
                s.sourceInfo.contains('せんだい') ||
                s.address.contains('仙台') ||
                s.address.contains('名取') ||
                s.address.contains('松島') ||
                s.address.contains('利府') ||
                s.address.contains('石巻') ||
                s.address.contains('大崎') ||
                s.address.contains('柴田') ||
                s.address.contains('白石'))) {
          return true;
        }
        return false;
      }).toList();

      if (matchedSpots.isNotEmpty) {
        return matchedSpots.map((s) {
          final distKm = LocationService.calculateDistanceKm(
            startLat: startLat,
            startLng: startLng,
            endLat: s.latitude,
            endLng: s.longitude,
          );
          final driveMin = LocationService.estimateDriveMinutes(distKm);
          return s.copyWith(
            distanceKm: distKm,
            driveMinutes: driveMin,
            scheduleText:
                s.scheduleText.isEmpty ? '$dateRangeText 開催' : s.scheduleText,
          );
        }).toList();
      }
    }

    final allCurated = <TohokuRegion, List<OutingSpot>>{
      TohokuRegion.miyagi: [
        OutingSpot(
          id: 'event_sendai_craft_marche',
          title: '仙台・定禅寺通 週末青空クラフトマルシェ＆フードフェス',
          subtitle: 'ケヤキ並木の下で手作り雑貨・焼き菓子・地元キッチンカーが集結する人気週末マーケット',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.kids, SpotTag.freeEntry],
          driveMinutes: 20,
          distanceKm: 12.0,
          scheduleText: '$dateRangeText 開催（10:00〜16:30）',
          parkingInfo: '近隣のコインパーキング多数あり',
          recommendPoints: const [
            '定禅寺通りの緑豊かな遊歩道に並ぶ、ここでしか出会えない作家の手づくり作品',
            '焼き立てパンや自家焙煎コーヒー、東北ご当地フードのキッチンカーがずらり',
            'ベビーカーでも歩きやすく、家族で爽やかな散策が楽しめます',
          ],
          aiTip: '午後はお客さんで賑わうため、お目当てのパンやスイーツは午前中に回るのがおすすめです！',
          address: '宮城県仙台市青葉区定禅寺通',
          latitude: 38.2652,
          longitude: 140.8698,
          weatherText: '☀️ 晴れ（マルシェ散策日和）',
          sourceInfo: 'せんだい旅日和 / 週末イベント特集',
          url: 'https://www.sentabi.jp/',
          isFavorite: false,
          googleRating: 4.4,
          googleRatingCount: 2150,
          googleReviews: const [
            '★5: ケヤキ並木の下で雰囲気最高！作家さんの手作り雑貨や美味しい焼き菓子がたくさん並んでいて楽しめました。',
            '★5: キッチンカーのクラフトバーガーとコーヒーを買ってベンチでのんびり。家族連れにもおすすめです。',
          ],
        ),
        OutingSpot(
          id: 'event_kotodai_food_fes',
          title: '勾当台公園 みやぎ週末うまいもの収穫祭＆パンマルシェ',
          subtitle: '宮城の旬の味覚と行列ベーカリーが集まる青空グルメフェスティバル！大道芸も開催',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.kids, SpotTag.indoor],
          driveMinutes: 22,
          distanceKm: 12.5,
          scheduleText: '$dateRangeText 開催（10:00〜16:00）',
          parkingInfo: '地下有料駐車場あり / 地下鉄勾当台公園駅直結',
          recommendPoints: const [
            '県内各地の有名パン屋さんとスイーツが大集合する人気企画',
            '芝生広場ではお子様向けの大道芸パフォーマンスやバルーンアートも',
            '地下鉄直結でアクセス抜群、手軽にお祭り気分を味わえます',
          ],
          aiTip: 'レジャーシートを持っていくと、芝生エリアで買ったばかりのパンやグルメをピクニック気分で楽しめます。',
          address: '宮城県仙台市青葉区本町3-9-2',
          latitude: 38.2682,
          longitude: 140.8719,
          weatherText: '☀️ 快晴',
          sourceInfo: '仙台つーしん / イベント情報',
          url: 'https://sendai-tushin.jp/',
          isFavorite: false,
          googleRating: 4.3,
          googleRatingCount: 3410,
          googleReviews: const [
            '★5: 仙台の中心で毎週末いろんなイベントをやっていて飽きません。美味しいものがたくさん買えました！',
            '★4: 子どもが芝生広場で楽しそうに走り回っていました。地下鉄直結でアクセスも抜群です。',
          ],
        ),
        OutingSpot(
          id: 'event_akiu_craft_fair',
          title: '秋保ヴィレッジ アグリエの森 週末ファーマーズ＆ハンドメイド市',
          subtitle: '採れたて野菜の即売やワークショップ、足湯も楽しめる人気のお出かけスポット',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.kids, SpotTag.freeParking],
          driveMinutes: 38,
          distanceKm: 24.0,
          scheduleText: '$dateRangeText 開催（9:00〜17:00）',
          parkingInfo: '無料大駐車場完備（約250台）',
          recommendPoints: const [
            '秋保温泉の入り口にある大人気施設で毎週末開催されるハンドメイドマーケット',
            '無料の足湯（茶湯）に入りながらのんびりリラックス',
            '秋保名物のおはぎや地元のお惣菜・新鮮な果物も勢ぞろい',
          ],
          aiTip: '隣接するガーデンには子どもが走り回れる芝生スペースやプチ遊具もあります。',
          address: '宮城県仙台市太白区茂庭字中谷地房32-1',
          latitude: 38.2325,
          longitude: 140.7511,
          weatherText: '☀️ 晴れ',
          sourceInfo: '秋保ヴィレッジ 公式',
          url: 'https://akiu-village.jp/',
          isFavorite: false,
          googleRating: 4.2,
          googleRatingCount: 2890,
          googleReviews: const [
            '★5: 新鮮野菜に美味しいスイーツ、無料の足湯まであって半日ゆっくり過ごせます。ドライブの目的地に最適！',
            '★4: ハンドメイド作家さんのお店がたくさん並んでいて可愛い雑貨を買えました。',
          ],
        ),
        OutingSpot(
          id: 'event_sendai_aquarium_show',
          title: '仙台うみの杜水族館 週末オーシャンフェスタ＆イルカパフォーマンス',
          subtitle: '東北最大級の水族館！週末限定のバックヤードツアーやイルカ・アシカの特別ショー開催',
          category: SpotCategory.event,
          tags: const [SpotTag.kids, SpotTag.indoor, SpotTag.toddler],
          driveMinutes: 28,
          distanceKm: 18.0,
          scheduleText: '$dateRangeText 開催（9:00〜17:30）',
          parkingInfo: '大型無料駐車場完備（約800台）',
          recommendPoints: const [
            '巨大水槽「いのちきらめく うみ」のイワシの群泳ショーは圧巻の迫力',
            'スタジアムで行われるイルカ・アシカパフォーマンスは小学生も大興奮',
            '雨の日でも全館屋内展示で安心してお出かけできます',
          ],
          aiTip: 'イルカショーは開演の20分前にスタジアム席に着くと中央の見やすい席を確保できます。',
          address: '宮城県仙台市宮城野区中野4丁目6',
          latitude: 38.2731,
          longitude: 141.0195,
          weatherText: '🏛️ 屋内快適（雨でも安心）',
          sourceInfo: 'うみの杜水族館 公式',
          url: 'http://www.uminomori.jp/',
          isFavorite: false,
          googleRating: 4.3,
          googleRatingCount: 6850,
          googleReviews: const [
            '★5: イルカとアシカのショーが本当に素晴らしい！水槽も綺麗で子どもたちが大喜びでした。',
            '★4: 三井アウトレットパーク仙台港のすぐ隣なので、水族館の後に買い物やランチもできて便利です。',
          ],
        ),
        OutingSpot(
          id: 'event_yurage_morning_market',
          title: 'ゆりあげ港朝市 週末海鮮炉端焼きまつり＆名物せり鍋フェス',
          subtitle: '名取の港町で毎週日曜・祝日開催！買ったばかりの新鮮魚介をその場で炭火焼き',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.freeParking, SpotTag.kids],
          driveMinutes: 30,
          distanceKm: 21.0,
          scheduleText: '$dateRangeText 開催（日曜祝日 朝6:00〜13:00）',
          parkingInfo: '無料大駐車場完備（約500台）',
          recommendPoints: const [
            '無料の炭火炉端焼きコーナーで、ホタテやエビ・牡蠣を家族でジュージュー焼いて食べる楽しさ',
            '名取名物のせり鍋や水餃子、海鮮丼など朝から絶品ご当地グルメを満喫',
            'かわまちてらす閖上にも近く、食後の川沿い散策やカフェも楽しめます',
          ],
          aiTip: '午前8時〜10時は活気と品揃えのピーク！早めに出発するのがおすすめです。',
          address: '宮城県名取市閖上東1丁目1-7',
          latitude: 38.1695,
          longitude: 140.9472,
          weatherText: '☀️ 爽快な浜風',
          sourceInfo: 'ゆりあげ港朝市協同組合 公式',
          url: 'https://yuriageminatoasaichi.jp/',
          isFavorite: false,
          googleRating: 4.3,
          googleRatingCount: 4210,
          googleReviews: const [
            '★5: 炉端焼きが最高に楽しい！新鮮なホタテやハラスを焼いて朝から大満足でした。',
            '★5: 子どもたちも自分で網焼き体験ができて大喜び。閖上名物の水餃子も絶品でした。',
          ],
        ),
        OutingSpot(
          id: 'event_matsushima_seaside_fes',
          title: '松島海岸 週末シーサイドクラフトフェス＆遊覧船ナイトクルーズ',
          subtitle: '松島湾の絶景を望む海辺のプロムナードでクラフト市＆名物焼き牡蠣・笹かま手焼き体験',
          category: SpotCategory.event,
          tags: const [SpotTag.nature, SpotTag.food, SpotTag.kids],
          driveMinutes: 32,
          distanceKm: 23.0,
          scheduleText: '$dateRangeText 開催（10:00〜17:00）',
          parkingInfo: '松島公園周辺 駐車場多数あり',
          recommendPoints: const [
            '日本三景の絶景を眺めながら海辺の特設マーケットをゆったり散策',
            '熱々の名物焼き牡蠣や牛たんつくね、笹かまの手焼き体験がその場で楽しめる',
            '赤い福浦橋を渡って島内をプチハイキングするのも最高',
          ],
          aiTip: '遊覧船の乗船券はネット事前予約しておくと並ばずにスムーズに乗船できます。',
          address: '宮城県宮城郡松島町松島字町内',
          latitude: 38.3719,
          longitude: 141.0598,
          weatherText: '☀️ 絶景海日和',
          sourceInfo: '松島観光協会 公式',
          url: 'https://www.matsushima-kanko.com/',
          isFavorite: false,
          googleRating: 4.4,
          googleRatingCount: 5420,
          googleReviews: const [
            '★5: 海風が心地よく、景色もグルメも最高！手焼き笹かま体験は家族みんなで楽しめました。',
            '★4: 五大堂からの眺めが絶景。周辺に美味しいカフェや甘味処もたくさんあって半日遊べます。',
          ],
        ),
        OutingSpot(
          id: 'event_benyland_spring_fes',
          title: '八木山ベニーランド 週末ファミリーフェスタ＆遊園地アトラクション',
          subtitle: '仙台の老舗遊園地！スリリングなコースターから観覧車まで家族みんなで大はしゃぎ',
          category: SpotCategory.event,
          tags: const [SpotTag.kids, SpotTag.toddler, SpotTag.freeParking],
          driveMinutes: 25,
          distanceKm: 14.0,
          scheduleText: '$dateRangeText 開催（9:30〜17:00）',
          parkingInfo: '有料駐車場完備（普通車500円）',
          recommendPoints: const [
            '観覧車からは仙台市街地から太平洋まで見渡せる大パノラマ絶景',
            '小学生向けコースターやゴーカート・コーヒーカップなど30種近いアトラクション',
            '八木山動物公園がすぐ目の前なので1日で遊園地と動物園のハシゴも可能',
          ],
          aiTip: '地下鉄東西線「八木山動物公園駅」から徒歩数分なので地下鉄で行くのも渋滞知らずでおすすめです。',
          address: '宮城県仙台市太白区長町越路19-1',
          latitude: 38.2435,
          longitude: 140.8521,
          weatherText: '☀️ 遊園地日和',
          sourceInfo: '八木山ベニーランド 公式',
          url: 'http://www.benyland.com/',
          isFavorite: false,
          googleRating: 4.1,
          googleRatingCount: 2310,
          googleReviews: const [
            '★5: 昔懐かしいレトロな雰囲気が最高！小学生くらいまでの子どもには待ち時間も少なくて大満足の遊園地です。',
            '★4: スタッフの方がとても親切。八木山動物公園とセットで1日たっぷり遊べました。',
          ],
        ),
      ],
      TohokuRegion.yamagata: [
        OutingSpot(
          id: 'event_yamagata_kajyo',
          title: '山形・霞城公園 週末歴史と工芸の手づくり市',
          subtitle: 'お城の石垣を望む広場で伝統工芸体験や地元の名物玉こんにゃく・だんごが味わえる',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.nature, SpotTag.freeEntry],
          driveMinutes: 70,
          distanceKm: 65.0,
          scheduleText: '$dateRangeText 開催（9:30〜16:00）',
          parkingInfo: '霞城公園内 無料駐車場あり',
          recommendPoints: const [
            '山形城跡の美しいお濠と自然に囲まれた開放的なロケーション',
            '手づくり木工玩具や染物など、小学生も喜ぶワークショップが多数',
            '熱々の名物玉こんにゃくや季節のフルーツスイーツをその場で堪能',
          ],
          aiTip: '東大手門の復元された迫力ある櫓も見学できます。',
          address: '山形県山形市霞城町1-7',
          latitude: 38.2520,
          longitude: 140.3275,
          weatherText: '☀️ 晴れ',
          sourceInfo: '山形市観光協会 / ウォーカープラス',
          url: 'https://yamagatakanko.com/',
          isFavorite: false,
        ),
      ],
      TohokuRegion.fukushima: [
        OutingSpot(
          id: 'event_inawashiro_fes',
          title: '猪苗代湖畔 週末ネイチャークラフト＆アウトドアフェスタ',
          subtitle: '磐梯山を望む湖畔で開催！カヌー体験や木工クラフト・地元バーベキューフェス',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.nature, SpotTag.kids],
          driveMinutes: 85,
          distanceKm: 90.0,
          scheduleText: '$dateRangeText 開催（10:00〜16:00）',
          parkingInfo: '湖畔無料駐車場完備',
          recommendPoints: const [
            '雄大な磐梯山と猪苗代湖の絶景をバックにした贅沢なアウトドアイベント',
            '子ども向けの自然工作教室や薪割り体験などアクティビティが充実',
            '福島名物の円盤餃子や喜多方ラーメンの出店も大人気',
          ],
          aiTip: '湖畔は風が心地よいですが、夕方は少し冷え込むことがあるため羽織る上着があると安心です。',
          address: '福島県耶麻郡猪苗代町翁沢長浜',
          latitude: 37.5140,
          longitude: 140.0620,
          weatherText: '☀️ 晴れ',
          sourceInfo: '福島県観光物産交流協会',
          url: 'https://www.tif.ne.jp/',
          isFavorite: false,
        ),
      ],
      TohokuRegion.iwate: [
        OutingSpot(
          id: 'event_morioka_castle_fes',
          title: '盛岡城跡公園 もりおか手づくりクラフト市＆春のマルシェ',
          subtitle: '盛岡の城跡広場で南部鉄器や手織り・木工芸品と地元グルメが集うクラフトフェア',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.kids, SpotTag.freeEntry],
          driveMinutes: 110,
          distanceKm: 130.0,
          scheduleText: '$dateRangeText 開催（10:00〜16:00）',
          parkingInfo: '盛岡城跡公園地下駐車場（有料）',
          recommendPoints: const [
            '城跡の美しい石垣に囲まれた芝生広場でゆったり過ごせる人気イベント',
            '盛岡冷麺や福田パンなど地元ソウルフードの屋台も充実',
            '手づくり作家との対話を楽しみながら一点物のお気に入りを見つけられます',
          ],
          aiTip: '公園内を散策した後は、すぐ近くの中津川沿いのカフェ巡りもおすすめです。',
          address: '岩手県盛岡市内丸1-37',
          latitude: 39.7001,
          longitude: 141.1528,
          weatherText: '☀️ 晴れ',
          sourceInfo: '盛岡観光コンベンション協会',
          url: 'https://www.odette.or.jp/',
          isFavorite: false,
        ),
      ],
      TohokuRegion.akita: [
        OutingSpot(
          id: 'event_akita_senshu',
          title: '千秋公園 あきた週末城下町クラフト市＆比内地鶏まつり',
          subtitle: '久保田城跡の緑の中で秋田の伝統工芸品と絶品比内地鶏グルメを味わう週末祭',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.kids, SpotTag.freeEntry],
          driveMinutes: 150,
          distanceKm: 180.0,
          scheduleText: '$dateRangeText 開催（10:00〜16:00）',
          parkingInfo: '千秋公園駐車場（有料）',
          recommendPoints: const [
            'お濠と城跡の風情ある景観の中で秋田の伝統文化を体験',
            '比内地鶏の焼き鳥やきりたんぽ鍋など熱々グルメが目白押し',
            '秋田犬とのふれあいイベントも同時開催',
          ],
          aiTip: '園内は少し階段があるため、歩きやすいスニーカーでお出かけください。',
          address: '秋田県秋田市千秋公園1-1',
          latitude: 39.7214,
          longitude: 140.1238,
          weatherText: '⛅ 曇りのち晴れ',
          sourceInfo: '秋田観光コンベンション協会',
          url: 'https://www.acvb.or.jp/',
          isFavorite: false,
        ),
      ],
      TohokuRegion.aomori: [
        OutingSpot(
          id: 'event_aomori_bay',
          title: '青森・ワ・ラッセ前 週末青森ベイサイドクラフトマルシェ',
          subtitle: '津軽海峡を望むウォーターフロントで手作り工芸やアップルパイ・海鮮グルメが集結',
          category: SpotCategory.event,
          tags: const [SpotTag.food, SpotTag.kids, SpotTag.freeEntry],
          driveMinutes: 190,
          distanceKm: 230.0,
          scheduleText: '$dateRangeText 開催（10:00〜16:00）',
          parkingInfo: '青森駅前駐車場多数あり',
          recommendPoints: const [
            'ねぶたの家ワ・ラッセやA-FACTORYに隣接する開放的な海辺の広場',
            '青森県内各地の厳選アップルパイ食べ比べコーナーが大好評',
            '海風を感じながらのんびり買い出しやカフェタイムを楽しめます',
          ],
          aiTip: 'A-FACTORY内でシードルの試飲も楽しめます。',
          address: '青森県青森市安方1-1-1',
          latitude: 40.8306,
          longitude: 140.7358,
          weatherText: '☀️ 晴れ',
          sourceInfo: '青森市観光物産協会',
          url: 'https://www.atca.info/',
          isFavorite: false,
        ),
      ],
    };

    final list = allCurated[selectedRegion] ?? allCurated[TohokuRegion.miyagi]!;
    return list.map((s) {
      final distKm = LocationService.calculateDistanceKm(
        startLat: startLat,
        startLng: startLng,
        endLat: s.latitude,
        endLng: s.longitude,
      );
      final driveMin = LocationService.estimateDriveMinutes(distKm);
      return s.copyWith(distanceKm: distKm, driveMinutes: driveMin);
    }).toList();
  }

  /// タイトルと説明文からカテゴリを推定
  static SpotCategory _guessSpotCategory(String title, String desc) {
    final t = '$title $desc';
    if (t.contains('神社') ||
        t.contains('寺') ||
        t.contains('八幡宮') ||
        t.contains('東照宮') ||
        t.contains('定義') ||
        t.contains('院') ||
        t.contains('観音') ||
        t.contains('不動')) {
      return SpotCategory.sightseeing;
    }
    if (t.contains('温泉') ||
        t.contains('銭湯') ||
        t.contains('サウナ') ||
        t.contains('露天風呂') ||
        t.contains('湯') ||
        t.contains('スパ') ||
        t.contains('竜泉寺')) {
      return SpotCategory.onsen;
    }
    if (t.contains('科学館') ||
        t.contains('博物館') ||
        t.contains('水族館') ||
        t.contains('天文台') ||
        t.contains('美術館') ||
        t.contains('屋内') ||
        t.contains('児童館')) {
      return SpotCategory.indoor;
    }
    if (t.contains('食堂') ||
        t.contains('定食') ||
        t.contains('ランチ') ||
        t.contains('レストラン') ||
        t.contains('ラーメン') ||
        t.contains('そば') ||
        t.contains('蕎麦') ||
        t.contains('うどん') ||
        t.contains('カフェ') ||
        t.contains('食事処') ||
        t.contains('ごはん') ||
        t.contains('御食事')) {
      return SpotCategory.dining;
    }
    if (t.contains('グルメ') ||
        t.contains('朝市') ||
        t.contains('市場')) {
      return SpotCategory.dining;
    }
    if (t.contains('マルシェ') ||
        t.contains('道の駅') ||
        t.contains('直売所')) {
      return SpotCategory.tourism;
    }
    if (t.contains('展望') ||
        t.contains('城') ||
        t.contains('渓谷') ||
        t.contains('滝') ||
        t.contains('名所') ||
        t.contains('観光') ||
        t.contains('お釜') ||
        t.contains('松島') ||
        t.contains('鍾乳洞')) {
      return SpotCategory.tourism;
    }
    if (t.contains('特別展') ||
        t.contains('スタンプラリー') ||
        t.contains('ライトアップ') ||
        t.contains('イベント')) {
      return SpotCategory.event;
    }
    return SpotCategory.park;
  }

  /// イベントの会場名・エリア名から東北6県（宮城・山形・岩手・福島・秋田・青森）の緯度経度・駐車場情報を解決
  static _VenueLocationInfo _resolveVenueCoordinates(
    String text, {
    double fallbackLat = 38.2601,
    double fallbackLng = 140.8800,
    String fallbackAddress = '宮城県仙台市青葉区中央（仙台市中心部 イベント会場）',
  }) {
    if (text.contains('定義')) {
      return const _VenueLocationInfo(
        lat: 38.3662,
        lng: 140.6644,
        address: '宮城県仙台市青葉区大倉字上下（定義如来西方寺 門前町）',
        parking: '定義如来 無料大駐車場あり（約700台）',
        hasFreeParking: true,
      );
    }
    if (text.contains('東北歴史博物館') || text.contains('多賀城')) {
      return const _VenueLocationInfo(
        lat: 38.3005,
        lng: 140.9882,
        address: '宮城県多賀城市高崎1-22-1（東北歴史博物館）',
        parking: '東北歴史博物館 無料駐車場あり（約320台）',
        hasFreeParking: true,
      );
    }
    if (text.contains('ブランチ') ||
        text.contains('BRANCH') ||
        text.contains('長命ヶ丘') ||
        text.contains('長命ケ丘')) {
      return const _VenueLocationInfo(
        lat: 38.3085,
        lng: 140.8402,
        address: '宮城県仙台市泉区長命ケ丘2-21-1（ブランチ仙台）',
        parking: 'ブランチ仙台 無料駐車場あり（約450台）',
        hasFreeParking: true,
      );
    }
    if (text.contains('泉区') ||
        text.contains('いずみ') ||
        text.contains('泉中央') ||
        text.contains('七北田')) {
      return const _VenueLocationInfo(
        lat: 38.3235,
        lng: 140.8805,
        address: '宮城県仙台市泉区（泉中央・七北田エリア）',
        parking: '会場周辺に駐車場・コインパーキングあり',
        hasFreeParking: false,
      );
    }
    if (text.contains('ロイヤルパーク') ||
        text.contains('IZUMI PEAK') ||
        text.contains('泉ヶ岳')) {
      return const _VenueLocationInfo(
        lat: 38.3422,
        lng: 140.8375,
        address: '宮城県仙台市泉区寺岡6-2-1（泉パークタウン・寺岡エリア）',
        parking: '無料大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('うみの杜水族館') || text.contains('仙台港') || text.contains('夢メッセ')) {
      return const _VenueLocationInfo(
        lat: 38.2708,
        lng: 140.9856,
        address: '宮城県仙台市宮城野区中野（仙台港・夢メッセ・うみの杜水族館エリア）',
        parking: '無料大駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('松島') ||
        text.contains('瑞巌寺') ||
        text.contains('円通院') ||
        text.contains('圓通院')) {
      return const _VenueLocationInfo(
        lat: 38.3719,
        lng: 141.0598,
        address: '宮城県宮城郡松島町松島字町内（松島海岸エリア）',
        parking: '松島公園駐車場ほか周辺駐車場多数あり',
        hasFreeParking: false,
      );
    }
    if (text.contains('秋保') ||
        text.contains('アキウルミナ') ||
        text.contains('磊々峡') ||
        text.contains('天守閣自然公園')) {
      return const _VenueLocationInfo(
        lat: 38.2255,
        lng: 140.7185,
        address: '宮城県仙台市太白区秋保町湯元（秋保温泉エリア）',
        parking: '各会場に無料駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('みちのく公園') || text.contains('川崎町')) {
      return const _VenueLocationInfo(
        lat: 38.2104,
        lng: 140.6738,
        address: '宮城県柴田郡川崎町小野字二本松53-9（国営みちのく杜の湖畔公園）',
        parking: '大型駐車場完備（約1,600台）',
        hasFreeParking: false,
      );
    }
    if (text.contains('西公園') ||
        text.contains('定禅寺') ||
        text.contains('勾当台') ||
        text.contains('錦町公園')) {
      return const _VenueLocationInfo(
        lat: 38.2625,
        lng: 140.8628,
        address: '宮城県仙台市青葉区（勾当台公園・定禅寺通・西公園エリア）',
        parking: '周辺コインパーキング・市営駐車場あり',
        hasFreeParking: false,
      );
    }
    if (text.contains('石巻') || text.contains('女川')) {
      return const _VenueLocationInfo(
        lat: 38.4344,
        lng: 141.3028,
        address: '宮城県石巻市・女川エリア',
        parking: '周辺駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('気仙沼') || text.contains('南三陸')) {
      return const _VenueLocationInfo(
        lat: 38.9081,
        lng: 141.5700,
        address: '宮城県気仙沼・南三陸エリア',
        parking: '無料観光駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('大崎') || text.contains('古川') || text.contains('鳴子')) {
      return const _VenueLocationInfo(
        lat: 38.7450,
        lng: 140.7158,
        address: '宮城県大崎市（鳴子温泉・古川エリア）',
        parking: '無料駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('富谷') || text.contains('とみやど')) {
      return const _VenueLocationInfo(
        lat: 38.3995,
        lng: 140.8872,
        address: '宮城県富谷市富谷新町111-1（とみやど周辺）',
        parking: '無料駐車場あり',
        hasFreeParking: true,
      );
    }
    // --- 山形県 ---
    if (text.contains('東根') || text.contains('あそびあランド')) {
      return const _VenueLocationInfo(
        lat: 38.4316,
        lng: 140.4112,
        address: '山形県東根市エリア',
        parking: '無料大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('天童') || text.contains('山寺') || text.contains('立石寺')) {
      return const _VenueLocationInfo(
        lat: 38.3536,
        lng: 140.3768,
        address: '山形県天童市・山寺エリア',
        parking: '専用駐車場・周辺駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('上山') ||
        text.contains('リナワールド') ||
        text.contains('寒河江') ||
        text.contains('チェリーランド')) {
      return const _VenueLocationInfo(
        lat: 38.1778,
        lng: 140.2895,
        address: '山形県上山市・寒河江エリア',
        parking: '無料大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('米沢') || text.contains('南陽') || text.contains('高畠')) {
      return const _VenueLocationInfo(
        lat: 37.9222,
        lng: 140.1167,
        address: '山形県米沢・置賜エリア',
        parking: '周辺駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('鶴岡') || text.contains('酒田') || text.contains('加茂水族館') || text.contains('庄内')) {
      return const _VenueLocationInfo(
        lat: 38.7272,
        lng: 139.8267,
        address: '山形県鶴岡・酒田・庄内エリア',
        parking: '無料大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('蔵王')) {
      return const _VenueLocationInfo(
        lat: 38.1685,
        lng: 140.3980,
        address: '山形蔵王・宮城蔵王エリア',
        parking: '各施設に無料駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('山形')) {
      return const _VenueLocationInfo(
        lat: 38.2404,
        lng: 140.3633,
        address: '山形県山形市（霞城公園・文翔館・山形駅周辺）',
        parking: '会場周辺駐車場あり',
        hasFreeParking: false,
      );
    }
    // --- 岩手県 ---
    if (text.contains('平泉') ||
        text.contains('中尊寺') ||
        text.contains('毛越寺') ||
        text.contains('一関') ||
        text.contains('厳美渓')) {
      return const _VenueLocationInfo(
        lat: 38.9865,
        lng: 141.1065,
        address: '岩手県西磐井郡平泉町・一関市エリア',
        parking: '観光駐車場あり',
        hasFreeParking: false,
      );
    }
    if (text.contains('花巻') || text.contains('北上') || text.contains('奥州') || text.contains('遠野')) {
      return const _VenueLocationInfo(
        lat: 39.3886,
        lng: 141.1167,
        address: '岩手県花巻・北上・奥州エリア',
        parking: '無料大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('盛岡') || text.contains('雫石') || text.contains('小岩井') || text.contains('岩手')) {
      return const _VenueLocationInfo(
        lat: 39.7036,
        lng: 141.1527,
        address: '岩手県盛岡・雫石エリア',
        parking: '会場周辺に駐車場あり',
        hasFreeParking: true,
      );
    }
    // --- 福島県 ---
    if (text.contains('会津') || text.contains('猪苗代') || text.contains('磐梯') || text.contains('喜多方')) {
      return const _VenueLocationInfo(
        lat: 37.4947,
        lng: 139.9297,
        address: '福島県会津若松・猪苗代・裏磐梯エリア',
        parking: '観光駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('郡山') || text.contains('須賀川') || text.contains('白河')) {
      return const _VenueLocationInfo(
        lat: 37.3980,
        lng: 140.3880,
        address: '福島県郡山・県中エリア',
        parking: '周辺駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('いわき') || text.contains('ハワイアンズ') || text.contains('小名浜')) {
      return const _VenueLocationInfo(
        lat: 36.9536,
        lng: 140.9039,
        address: '福島県いわき・小名浜エリア',
        parking: '大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('あづま') ||
        text.contains('こむこむ') ||
        text.contains('四季の里') ||
        text.contains('飯坂') ||
        text.contains('相馬') ||
        text.contains('福島')) {
      return const _VenueLocationInfo(
        lat: 37.7503,
        lng: 140.4676,
        address: '福島県福島市・県北エリア',
        parking: '大型駐車場あり',
        hasFreeParking: true,
      );
    }
    // --- 秋田県 ---
    if (text.contains('横手') || text.contains('角館') || text.contains('田沢湖') || text.contains('大仙')) {
      return const _VenueLocationInfo(
        lat: 39.5967,
        lng: 140.5614,
        address: '秋田県角館・田沢湖・横手エリア',
        parking: '無料大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('男鹿') || text.contains('秋田')) {
      return const _VenueLocationInfo(
        lat: 39.7186,
        lng: 140.1024,
        address: '秋田県秋田市・男鹿エリア',
        parking: '会場周辺に駐車場あり',
        hasFreeParking: true,
      );
    }
    // --- 青森県 ---
    if (text.contains('弘前') || text.contains('五所川原')) {
      return const _VenueLocationInfo(
        lat: 40.6030,
        lng: 140.4640,
        address: '青森県弘前・津軽エリア',
        parking: '周辺駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('八戸') || text.contains('十和田') || text.contains('奥入瀬') || text.contains('三沢')) {
      return const _VenueLocationInfo(
        lat: 40.5122,
        lng: 141.4883,
        address: '青森県八戸・十和田・三沢エリア',
        parking: '無料大型駐車場あり',
        hasFreeParking: true,
      );
    }
    if (text.contains('青森')) {
      return const _VenueLocationInfo(
        lat: 40.8244,
        lng: 140.7400,
        address: '青森県青森市エリア',
        parking: '会場周辺に駐車場あり',
        hasFreeParking: true,
      );
    }

    return _VenueLocationInfo(
      lat: fallbackLat,
      lng: fallbackLng,
      address: fallbackAddress,
      parking: '周辺の提携駐車場・コインパーキングあり',
      hasFreeParking: false,
    );
  }

  static String _cleanHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#8211;', '-')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeTitle(String s) {
    return s
        .replaceAll(RegExp(r'【.*?】'), '')
        .replaceAll(RegExp(r'[\s　「」『』♪！!・ー―-｜|〜~（）()\[\]]'), '')
        .toLowerCase();
  }

  // ===========================================================================
  // 3. 同一施設・同一イベントのシンプルな名寄せ（別施設を誤って統合しない安全設計）
  // ===========================================================================
  static List<OutingSpot> _deduplicateAndAggregateSpots(List<OutingSpot> spots) {
    final result = <OutingSpot>[];
    for (final spot in spots) {
      final dupIdx = _findDuplicateSpotIndex(result, spot);
      if (dupIdx != -1) {
        result[dupIdx] = _mergeDuplicateSpots(result[dupIdx], spot);
      } else {
        result.add(spot);
      }
    }
    return result;
  }

  static int _findDuplicateSpotIndex(List<OutingSpot> existingList, OutingSpot candidate) {
    final candCore = _extractCoreSpotName(candidate.title);
    final candNorm = _normalizeTitle(candidate.title);

    for (var i = 0; i < existingList.length; i++) {
      final ex = existingList[i];
      final exCore = _extractCoreSpotName(ex.title);
      final exNorm = _normalizeTitle(ex.title);

      // 1. 正規化タイトルまたはコア名称が完全一致する場合のみ重複とみなす
      if (candNorm.isNotEmpty && (candCore == exCore || candNorm == exNorm)) {
        return i;
      }

      // 2. 座標がごく至近（半径180m以内）で、かつ先頭5文字以上が一致する場合（同じ公園の「東門」と「西門」など）
      final distBetweenKm = LocationService.calculateDistanceKm(
        startLat: ex.latitude,
        startLng: ex.longitude,
        endLat: candidate.latitude,
        endLng: candidate.longitude,
      );
      if (distBetweenKm < 0.18 &&
          candCore.length >= 5 &&
          exCore.length >= 5 &&
          candCore.substring(0, 5) == exCore.substring(0, 5)) {
        return i;
      }
    }
    return -1;
  }

  static String _extractCoreSpotName(String rawTitle) {
    var s = rawTitle;
    s = s.replaceAll(RegExp(r'【.*?】'), '');
    s = s.replaceAll(RegExp(r'｜.*$'), '');
    s = s.replaceAll(RegExp(r'\|.*$'), '');
    s = s.replaceAll(RegExp(r'\d{4}年?\d{1,2}月\d{1,2}日.*$'), '');
    s = s.replaceAll(RegExp(r'\d{1,2}月\d{1,2}日.*$'), '');
    s = s.replaceAll(
      RegExp(r'(\s+|　+)(東門|西門|北門|南門|正門|第一駐車場|第二駐車場).*$'),
      '',
    );
    return _normalizeTitle(s);
  }

  static OutingSpot _mergeDuplicateSpots(OutingSpot primary, OutingSpot secondary) {
    final primaryIsNewsHeadline = primary.title.contains('｜') || primary.title.length > 38;
    final secondaryIsNewsHeadline = secondary.title.contains('｜') || secondary.title.length > 38;
    final bestTitle = (primaryIsNewsHeadline && !secondaryIsNewsHeadline)
        ? secondary.title
        : primary.title;

    final mergedPoints = <String>[...primary.recommendPoints];
    for (final p in secondary.recommendPoints) {
      if (mergedPoints.length >= 4) break;
      final isDupPoint = mergedPoints.any(
        (ep) =>
            _normalizeTitle(ep).contains(_normalizeTitle(p)) ||
            _normalizeTitle(p).contains(_normalizeTitle(ep)),
      );
      if (!isDupPoint) {
        mergedPoints.add(p);
      }
    }

    final mergedTags = <SpotTag>{...primary.tags, ...secondary.tags}.toList();

    String mergedSource = primary.sourceInfo;
    final secSourceShort = secondary.sourceInfo.split(' ').first;
    if (!mergedSource.contains(secSourceShort)) {
      mergedSource = '$mergedSource / $secSourceShort';
    }

    final bestUrl = primary.url.isNotEmpty ? primary.url : secondary.url;

    return primary.copyWith(
      title: bestTitle,
      tags: mergedTags,
      recommendPoints: mergedPoints,
      sourceInfo: mergedSource,
      url: bestUrl,
      isFavorite: primary.isFavorite || secondary.isFavorite,
    );
  }

  /// 選んだスポットを軸に、近くのランチ・温泉を組み合わせた「1日ドライブコースしおり」を自動生成（案A）
  static TripPlan buildDayDrivePlanFromSpot({
    required OutingSpot mainSpot,
    required List<OutingSpot> regionalSpots,
  }) {
    OutingSpot? nearestLunch;
    double minLunchDist = 99999;
    OutingSpot? nearestOnsen;
    double minOnsenDist = 99999;

    for (final candidate in regionalSpots) {
      if (candidate.id == mainSpot.id) continue;
      final dist = LocationService.calculateDistanceKm(
        startLat: mainSpot.latitude,
        startLng: mainSpot.longitude,
        endLat: candidate.latitude,
        endLng: candidate.longitude,
      );
      if ((candidate.category == SpotCategory.dining ||
              candidate.category == SpotCategory.gourmet) &&
          dist < minLunchDist) {
        minLunchDist = dist;
        nearestLunch = candidate;
      }
      if (candidate.category == SpotCategory.onsen && dist < minOnsenDist) {
        minOnsenDist = dist;
        nearestOnsen = candidate;
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final items = <TripScheduleItem>[
      TripScheduleItem(
        id: 'drive_${nowMs}_1',
        dayNumber: 1,
        timeText: '09:30',
        title: '自宅を出発 ➔ ${mainSpot.title}へ（${mainSpot.driveTimeLabel}）',
        type: TripItemType.car,
        location: mainSpot.address,
        memo: '駐車場: ${mainSpot.parkingInfo}',
      ),
      TripScheduleItem(
        id: 'drive_${nowMs}_2',
        dayNumber: 1,
        timeText: '10:30',
        title: '${mainSpot.title} を家族で満喫！',
        type: TripItemType.sightseeing,
        location: mainSpot.address,
        memo: mainSpot.recommendPoints.isNotEmpty
            ? mainSpot.recommendPoints.first
            : mainSpot.subtitle,
        url: mainSpot.url,
      ),
      TripScheduleItem(
        id: 'drive_${nowMs}_3',
        dayNumber: 1,
        timeText: '12:30',
        title: nearestLunch != null
            ? 'ランチ：${nearestLunch.title}'
            : '${mainSpot.address}周辺のご当地グルメ・食事処でランチ',
        type: TripItemType.food,
        location: nearestLunch?.address ?? '${mainSpot.address}周辺',
        memo: nearestLunch != null
            ? '${nearestLunch.subtitle}（メイン会場から約${minLunchDist.toStringAsFixed(1)}km）'
            : '名物グルメや道の駅で楽しいお昼ごはん🍽️',
        url: nearestLunch?.url ?? '',
      ),
      TripScheduleItem(
        id: 'drive_${nowMs}_4',
        dayNumber: 1,
        timeText: '14:30',
        title: nearestOnsen != null
            ? '立ち寄り湯：${nearestOnsen.title}'
            : '${mainSpot.address}周辺の日帰り温泉でほっこり',
        type: TripItemType.hotel,
        location: nearestOnsen?.address ?? '${mainSpot.address}周辺',
        memo: nearestOnsen != null
            ? '${nearestOnsen.subtitle}（会場から約${minOnsenDist.toStringAsFixed(1)}km）'
            : 'たくさん遊んだ後は露天風呂・温泉でリフレッシュ♨️',
        url: nearestOnsen?.url ?? '',
      ),
      TripScheduleItem(
        id: 'drive_${nowMs}_5',
        dayNumber: 1,
        timeText: '16:30',
        title: 'お土産を買って帰路へ ➔ 自宅着',
        type: TripItemType.car,
        location: '帰路ドライブ',
        memo: '安全運転で帰宅🏠',
      ),
    ];

    return TripPlan(
      id: 'trip_drive_$nowMs',
      title: '🚗 ${mainSpot.title} 1日満喫コース',
      subtitle: '移動時間・周辺ランチ・温泉つきの1日モデルスケジュール',
      totalDays: 1,
      items: items,
      updatedAtMs: nowMs,
    );
  }

  /// Gemini AI を使って、大阪・名古屋旅行など自由な行き先・日数の旅のしおりを自動生成（案A）
  static Future<TripPlan> generateCustomTripPlanWithAi({
    required String destinationAndTheme,
    required int totalDays,
  }) async {
    final cleanTheme = destinationAndTheme.trim().isEmpty
        ? '大阪・名古屋 家族旅行'
        : destinationAndTheme.trim();
    final days = totalDays.clamp(1, 5);
    final apiKey = AppApiKeys.geminiApiKey.trim();

    if (apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY') {
      final prompt = '''
あなたは小学生の子どもがいるご夫婦・家族向けの旅行プランナーAIです。
以下の条件で、家族みんなが楽しめて無理のない「旅のしおり（タイムスケジュール）」を作成してください。

・行き先・やりたいこと: $cleanTheme
・日数: $days日間（Day 1 〜 Day $days）
・対象: ご夫婦＋小学生のお子さん

必ず以下のJSONフォーマットのみを出力してください（コードブロック不要）：
{
  "title": "しおりのタイトル（絵文字付き、例：🏯 大阪・名古屋 家族旅行しおり）",
  "subtitle": "プランの魅力ひとこと（例：USJもジブリパークも名古屋めしも満喫！）",
  "items": [
    {
      "dayNumber": 1,
      "timeText": "09:30",
      "title": "予定のタイトル",
      "type": "shinkansen または flight, train, car, sightseeing, food, hotel, shopping",
      "location": "場所や駅・施設名",
      "memo": "小学生や夫婦向けのワンポイントメモ"
    }
  ]
}
''';

      final targetModels = [
        'gemini-3.5-flash-lite',
        'gemini-3.8-flash',
        'gemini-2.5-flash',
      ];

      for (final model in targetModels) {
        try {
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );
          final response = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'contents': [
                    {
                      'parts': [
                        {'text': prompt}
                      ]
                    }
                  ],
                  'generationConfig': {
                    'responseMimeType': 'application/json',
                    'maxOutputTokens': 1400,
                  },
                }),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
            final candidates = jsonResponse['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content =
                  (candidates.first as Map<String, dynamic>)['content']
                      as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final rawText =
                    (parts.first as Map<String, dynamic>)['text'] as String?;
                if (rawText != null) {
                  final cleaned = rawText
                      .replaceAll('```json', '')
                      .replaceAll('```', '')
                      .trim();
                  final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
                  final title =
                      parsed['title'] as String? ?? '✈️ $cleanTheme しおり';
                  final subtitle =
                      parsed['subtitle'] as String? ?? 'AI作成の家族旅行スケジュール';
                  final rawItems = parsed['items'] as List<dynamic>? ?? [];
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  final items = <TripScheduleItem>[];
                  for (var i = 0; i < rawItems.length; i++) {
                    final m = rawItems[i] as Map<String, dynamic>;
                    items.add(
                      TripScheduleItem(
                        id: 'ai_${nowMs}_$i',
                        dayNumber:
                            ((m['dayNumber'] as num?)?.toInt() ?? 1).clamp(1, days),
                        timeText: m['timeText'] as String? ?? '10:00',
                        title: m['title'] as String? ?? 'お出かけ予定',
                        type: TripItemType.fromName(m['type'] as String?),
                        location: m['location'] as String? ?? '',
                        memo: m['memo'] as String? ?? '',
                      ),
                    );
                  }
                  if (items.isNotEmpty) {
                    return TripPlan(
                      id: 'trip_ai_$nowMs',
                      title: title,
                      subtitle: subtitle,
                      totalDays: days,
                      items: items,
                      updatedAtMs: nowMs,
                    );
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    if (cleanTheme.contains('大阪') || cleanTheme.contains('名古屋')) {
      final starter = TripPlan.createOsakaNagoyaStarter();
      return starter.copyWith(
        id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
        title: '🏯 $cleanTheme',
        totalDays: days,
      );
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fallbackItems = <TripScheduleItem>[];
    for (int d = 1; d <= days; d++) {
      fallbackItems.addAll([
        TripScheduleItem(
          id: 'fb_${nowMs}_${d}_1',
          dayNumber: d,
          timeText: '09:30',
          title: d == 1 ? '出発 ➔ $cleanTheme エリアへ移動' : '$cleanTheme Day $d スタート！',
          type: d == 1 ? TripItemType.shinkansen : TripItemType.car,
          location: cleanTheme,
          memo: '家族みんなで楽しい1日にしよう！',
        ),
        TripScheduleItem(
          id: 'fb_${nowMs}_${d}_2',
          dayNumber: d,
          timeText: '11:00',
          title: '$cleanTheme メイン観光・体験スポット',
          type: TripItemType.sightseeing,
          location: cleanTheme,
          memo: '小学生も大人もワクワクするメインスポット🎡',
        ),
        TripScheduleItem(
          id: 'fb_${nowMs}_${d}_3',
          dayNumber: d,
          timeText: '12:30',
          title: '$cleanTheme 名物グルメ・ランチ',
          type: TripItemType.food,
          location: cleanTheme,
          memo: '地元で人気のご当地グルメを堪能🍽️',
        ),
        TripScheduleItem(
          id: 'fb_${nowMs}_${d}_4',
          dayNumber: d,
          timeText: d == days ? '16:00' : '17:30',
          title: d == days ? 'お土産選び ➔ 帰路へ' : 'ホテル・温泉にチェックイン＆夕食',
          type: d == days ? TripItemType.shopping : TripItemType.hotel,
          location: cleanTheme,
          memo: d == days ? '思い出とお土産をたくさん持って帰宅🏠' : 'ゆっくり休んで疲れを癒やす♨️',
        ),
      ]);
    }

    return TripPlan(
      id: 'trip_custom_$nowMs',
      title: '✈️ $cleanTheme（$days日間）',
      subtitle: '自由に予定を追加・編集できる家族のしおり',
      totalDays: days,
      items: fallbackItems,
      updatedAtMs: nowMs,
      // end of generateCustomTripPlanWithAi
    );
  }
}

class _WalkerplusAreaTarget {
  final String code;
  final String prefName;
  final double defaultLat;
  final double defaultLng;
  final List<String> keywords;

  const _WalkerplusAreaTarget(
    this.code,
    this.prefName,
    this.defaultLat,
    this.defaultLng, [
    this.keywords = const [],
  ]);
}

class _VenueLocationInfo {
  final double lat;
  final double lng;
  final String address;
  final String parking;
  final bool hasFreeParking;

  const _VenueLocationInfo({
    required this.lat,
    required this.lng,
    required this.address,
    required this.parking,
    required this.hasFreeParking,
  });
}
