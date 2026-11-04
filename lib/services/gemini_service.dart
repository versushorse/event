// Gemini AIによるイベント・大型公園検索およびおすすめ要約サービス
import '../models/outing_spot.dart';

/// AI検索のレスポンス結果（AIのコメント＋提案スポット一覧）
class AiSearchResult {
  final String aiSummaryComment;
  final List<OutingSpot> spots;

  const AiSearchResult({
    required this.aiSummaryComment,
    required this.spots,
  });
}

class GeminiOutingService {
  /// 初期表示およびデモ用の直近イベント＆大型公園・観光地データ（1〜2時間圏内）
  static List<OutingSpot> getInitialSpots() {
    return const [
      OutingSpot(
        id: 'event_gourmet_fest',
        title: '秋の収穫祭＆キッチンカーマルシェ',
        subtitle: '地元グルメ約45店舗が集結！芝生広場でピクニックも楽しめる週末限定フェス',
        category: SpotCategory.event,
        tags: [
          SpotTag.food,
          SpotTag.kids,
          SpotTag.freeParking,
          SpotTag.freeEntry,
        ],
        driveMinutes: 55,
        distanceKm: 36.0,
        scheduleText: '今週末 土・日開催 10:00〜16:30（小雨決行）',
        parkingInfo: '臨時無料駐車場 約800台あり（会場まで徒歩3分）',
        recommendPoints: [
          '焼きたてピザや地元牛バーガーなど食べ比べができるキッチンカーが45台出店',
          '子供向けのふわふわドームや木工ワークショップも同時開催',
          'レジャーシートを敷いてゆったり過ごせる広大な芝生エリアあり',
        ],
        aiTip: '11時半以降は人気グルメに行列ができやすいため、10時半頃の到着がベストです。',
        address: '埼玉県戸田市彩湖・道満グリーンパーク イベント広場（戸田市大字重瀬745）',
        latitude: 35.7820,
        longitude: 139.6120,
        isFavorite: true,
        pickedBy: PartnerPick.both,
        coupleNote: '土曜のお昼ご飯かねてここ行きたい！レジャーシート持参で！',
      ),
      OutingSpot(
        id: 'park_forest_hill',
        title: '国営みどりの丘陵公園',
        subtitle: '東京ドーム約65個分！巨大トランポリン・アスレチック・季節の花畑が揃う超大型公園',
        category: SpotCategory.park,
        tags: [
          SpotTag.kids,
          SpotTag.nature,
          SpotTag.food,
        ],
        driveMinutes: 75,
        distanceKm: 58.0,
        scheduleText: '9:30〜17:00（今週末は秋バラ＆コスモスが見頃）',
        parkingInfo: '大型駐車場 3ヶ所（計2,000台 / 普通車1日700円）※南口が遊具エリアに最短',
        recommendPoints: [
          '日本最大級のぽんぽこマウンテン（巨大トランポリン）と24種類の木製アスレチック',
          '園内サイクリングコース（17km）やパークトレインで移動も楽しい',
          '園内レストランの地元野菜ビュッフェ＆ソフトクリームが絶品',
        ],
        aiTip: '子供と遊具メインなら「南口駐車場」、花畑とカフェ散策メインなら「中央口駐車場」に停めると歩く距離を半分に減らせます。',
        address: '埼玉県比企郡滑川町山田1920（国営武蔵丘陵森林公園）',
        latitude: 36.0380,
        longitude: 139.3760,
        isFavorite: true,
        pickedBy: PartnerPick.wife,
        coupleNote: '天気が良かったらここでのびのび遊ばせたい！',
      ),
      OutingSpot(
        id: 'event_night_lantern',
        title: '湖畔のクラフト市＆ランタンフェスティバル',
        subtitle: '手作り雑貨・地元ベーカリー巡りと、夕暮れのランタンライトアップ',
        category: SpotCategory.event,
        tags: [
          SpotTag.food,
          SpotTag.nature,
          SpotTag.freeParking,
        ],
        driveMinutes: 90,
        distanceKm: 64.5,
        scheduleText: '今週末 土・日 11:00〜19:00（ランタン点灯は17:00〜）',
        parkingInfo: '湖畔第1・第2駐車場 無料（計600台）',
        recommendPoints: [
          '人気パン屋・焼き菓子店・コーヒースタンドが25店舗以上集まるパンマルシェ併設',
          '親子で参加できるキャンドル・革小物づくり体験ブースが充実',
          '夕方には湖畔が約1,000個のランタンで彩られ、ドライブの締めくくりに最高',
        ],
        aiTip: '夕方は湖畔の風が少し冷えるので、車に薄手の上着やブランケットを積んでおくと安心です。',
        address: '埼玉県飯能市宮沢327-6 メッツァビレッジ 宮沢湖畔特設会場',
        latitude: 35.5120,
        longitude: 139.1850,
      ),
      OutingSpot(
        id: 'sightseeing_michinoeki_farm',
        title: '道の駅 アグリパーク＆牧場体験ビレッジ',
        subtitle: '高速ICから5分！動物ふれあい・収穫体験・直売所グルメが1ヶ所で完結',
        category: SpotCategory.sightseeing,
        tags: [
          SpotTag.food,
          SpotTag.kids,
          SpotTag.freeParking,
          SpotTag.freeEntry,
        ],
        driveMinutes: 65,
        distanceKm: 48.0,
        scheduleText: '9:00〜18:00（年中無休・今週末は新米＆芋掘りフェア開催中）',
        parkingInfo: '無料大駐車場 450台（大型区画が多く駐車しやすい）',
        recommendPoints: [
          'うさぎ・ヤギのエサやり体験やミニポニー乗馬など、小さな子供でも安心の牧場エリア',
          '予約なしで当日参加できるサツマイモ掘り体験＆採れたて焼き芋販売',
          '農産物直売所と海鮮・地元豚のBBQテラスがあり、帰りの買い物まで一度に済む',
        ],
        aiTip: '直売所の人気フルーツ・新鮮野菜は午前中で売り切れることが多いので、着いたらまず直売所をチェックするのがおすすめです。',
        address: '千葉県柏市高柳940-2（道の駅 しょうなん＆体験農園エリア）',
        latitude: 35.8910,
        longitude: 140.0230,
        isFavorite: true,
        pickedBy: PartnerPick.husband,
        coupleNote: '帰り道に直売所で野菜と美味しいお肉買って帰ろう！',
      ),
      OutingSpot(
        id: 'park_science_dome',
        title: '県立こども科学館＆わんぱく室内パーク',
        subtitle: '雨や風の日でも1日中遊べる！大型室内アスレチックと体験型サイエンス展示',
        category: SpotCategory.park,
        tags: [
          SpotTag.kids,
          SpotTag.indoor,
          SpotTag.freeParking,
        ],
        driveMinutes: 45,
        distanceKm: 29.0,
        scheduleText: '9:30〜17:00（今週末は特別プラネタリウム上映あり）',
        parkingInfo: '無料立体駐車場 600台（雨に濡れずに館内へ直結）',
        recommendPoints: [
          '天候を問わず遊べる3階建ての大型室内ネット遊具＆ボールプール',
          'シャボン玉の中に入る実験ショーなど、子供が夢中になる参加型イベントが毎時開催',
          '館内にファミリー向けカフェテリアと離乳食・休憩スペースが完備',
        ],
        aiTip: '立体駐車場2階の連絡通路近くに停めると、ベビーカーや荷物が多くてもエレベーター無しでそのまま入口に入れます。',
        address: '東京都西東京市芝久保町5-10-64（多摩六都科学館＆屋内キッズパーク）',
        latitude: 35.6580,
        longitude: 139.4810,
      ),
      OutingSpot(
        id: 'event_seaside_bbq',
        title: 'ベイサイド海鮮浜焼きフェス＆海浜大公園',
        subtitle: '潮風を感じながら海鮮グルメを満喫！ローラー滑り台と芝生ソリ滑りも大人気',
        category: SpotCategory.event,
        tags: [
          SpotTag.food,
          SpotTag.kids,
          SpotTag.nature,
        ],
        driveMinutes: 105,
        distanceKm: 78.0,
        scheduleText: '今週末 土・日・祝 10:00〜16:00',
        parkingInfo: '海浜公園第1駐車場 1,200台（普通車1日600円）',
        recommendPoints: [
          '漁港直送のホタテ・エビ・海鮮丼をその場で味わえる週末限定の浜焼き屋台村',
          '海を見下ろす全長120mのロングローラー滑り台と無料の芝生ソリゲレンデ',
          'ドライブコースとしても気持ち良い海岸線の絶景ルート',
        ],
        aiTip: '1時間半〜2時間弱のドライブになるため、途中のSA/PAで休憩をはさみつつ向かう週末プチ旅行にぴったりです。',
        address: '神奈川県横須賀市長井4丁目 ソレイユの丘 海浜イベント広場',
        latitude: 35.3450,
        longitude: 139.8950,
      ),
    ];
  }

  /// ユーザーの検索キーワード・出発地・移動時間条件をもとにAI提案を生成する
  static Future<AiSearchResult> searchWithAi({
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
    required List<OutingSpot> currentSpots,
  }) async {
    // 検索中の通信演出（実際のGemini API呼び出しに差し替え可能な非同期構成）
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final normalizedQuery = query.trim();

    // 移動時間条件でフィルタリング
    var filtered = currentSpots
        .where((spot) => spot.driveMinutes <= maxDriveMinutes)
        .toList();

    // キーワードに応じたインテリジェント絞り込み＆並び替え
    if (normalizedQuery.isNotEmpty) {
      final wantsFood = normalizedQuery.contains('食') ||
          normalizedQuery.contains('グルメ') ||
          normalizedQuery.contains('マルシェ') ||
          normalizedQuery.contains('パン') ||
          normalizedQuery.contains('おいしい');
      final wantsKids = normalizedQuery.contains('子供') ||
          normalizedQuery.contains('子ども') ||
          normalizedQuery.contains('遊具') ||
          normalizedQuery.contains('アスレチック') ||
          normalizedQuery.contains('家族');
      final wantsEvent = normalizedQuery.contains('イベント') ||
          normalizedQuery.contains('催し') ||
          normalizedQuery.contains('フェス') ||
          normalizedQuery.contains('祭り');
      final wantsPark = normalizedQuery.contains('公園') ||
          normalizedQuery.contains('自然') ||
          normalizedQuery.contains('芝生');
      final wantsRain = normalizedQuery.contains('雨') ||
          normalizedQuery.contains('室内') ||
          normalizedQuery.contains('屋内');

      final matched = filtered.where((spot) {
        if (wantsRain && spot.tags.contains(SpotTag.indoor)) return true;
        if (wantsEvent && spot.category == SpotCategory.event) return true;
        if (wantsPark && spot.category == SpotCategory.park) return true;
        if (wantsFood && spot.tags.contains(SpotTag.food)) return true;
        if (wantsKids && spot.tags.contains(SpotTag.kids)) return true;
        return spot.title.contains(normalizedQuery) ||
            spot.subtitle.contains(normalizedQuery) ||
            spot.recommendPoints.any((p) => p.contains(normalizedQuery));
      }).toList();

      if (matched.isNotEmpty) {
        filtered = matched;
      }
    }

    final timeLabel = maxDriveMinutes <= 60 ? '車で1時間以内' : '車で1〜2時間圏内';
    final summary = normalizedQuery.isEmpty
        ? '📍 $departureAreaから$timeLabelで行ける、今週末おすすめのイベント・大型公園を${filtered.length}件ピックアップしました！すべて駐車場情報付きです。'
        : '✨ Gemini AI提案：「$normalizedQuery」に合わせて、$departureAreaから$timeLabelで行けるスポットを${filtered.length}件厳選しました。駐車場の停めやすさや混雑回避のポイントもまとめています！';

    return AiSearchResult(
      aiSummaryComment: summary,
      spots: filtered,
    );
  }
}
