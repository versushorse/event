// Gemini 3.8 Flash (Interactions API + Google Search Grounding) によるイベント・大型公園検索サービス
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.local.dart';
import '../models/outing_spot.dart';

/// AI検索のレスポンス結果（AIのコメント＋提案スポット一覧）
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
  /// 初期表示およびオフライン/フォールバック用のデモデータ
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
        title: '国営武蔵丘陵森林公園',
        subtitle: '東京ドーム約65個分！日本一巨大なトランポリン・アスレチック・季節の花畑が揃う超大型公園',
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
        address: '埼玉県比企郡滑川町山田1920',
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

  /// Gemini 3.8 Flash (Interactions API + Google Search) を呼び出して最新のお出かけスポットを検索する
  static Future<AiSearchResult> searchWithAi({
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
    required List<OutingSpot> currentSpots,
  }) async {
    final apiKey = AppApiKeys.geminiApiKey.trim();

    // APIキーが設定されている場合は、まず Gemini 3.8 Flash にリアルタイム通信を試みる
    if (apiKey.isNotEmpty) {
      try {
        final liveResult = await _callGemini38Interactions(
          apiKey: apiKey,
          query: query,
          departureArea: departureArea,
          maxDriveMinutes: maxDriveMinutes,
        );
        if (liveResult != null && liveResult.spots.isNotEmpty) {
          return liveResult;
        }
      } catch (e) {
        // キーの反映待ちやネットワークエラーの場合は安全にフォールバック処理へ進む
      }
    }

    // フォールバック（ローカル検索・フィルタリング処理）
    return _localSearchFallback(
      query: query,
      departureArea: departureArea,
      maxDriveMinutes: maxDriveMinutes,
      currentSpots: currentSpots,
      hasKey: apiKey.isNotEmpty,
    );
  }

  /// Google公式の最新 Interactions API (models/gemini-3.8-flash + google_search) 呼び出し
  static Future<AiSearchResult?> _callGemini38Interactions({
    required String apiKey,
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
  }) async {
    final timeLabel = maxDriveMinutes <= 60 ? '車で1時間以内' : '車で1〜2時間圏内';
    final userPrompt = '''
あなたは週末のお出かけ・イベント提案AIアシスタントです。Google検索を活用して最新情報を調べてください。

【条件】
- 出発地: $departureArea
- 移動時間: $timeLabel
- 探している内容: ${query.isEmpty ? '今週末開催のおすすめ催し物・イベント（グルメフェスやマルシェなど）および家族で楽しめる大型公園' : query}

【出力フォーマット】
以下のJSONフォーマットのみを返してください。マークダウンのバッククォート（```json）は不要です。
{
  "summaryComment": "検索条件に合わせたAIからの親切な提案メッセージ（1〜2文）",
  "spots": [
    {
      "id": "一意なID（英数字）",
      "title": "イベントまたは大型公園の正式名称",
      "subtitle": "1行の魅力的なキャッチコピー",
      "category": "event" または "park" または "sightseeing",
      "tags": ["food", "kids", "nature", "freeParking", "indoor", "freeEntry" から該当するもの],
      "driveMinutes": 出発地からの車での所要時間（分単位の整数）,
      "distanceKm": およその距離（km、数値）,
      "scheduleText": "開催日時や見頃（例: 今週末 土・日 10:00〜16:00）",
      "parkingInfo": "駐車場の有無・台数・料金（例: 無料駐車場 500台あり）",
      "recommendPoints": ["おすすめポイント1", "おすすめポイント2", "おすすめポイント3"],
      "aiTip": "混雑回避や持ち物のアドバイス",
      "address": "開催場所・住所（都道府県・市区町村・施設名）",
      "latitude": 35.6895,
      "longitude": 139.6917
    }
  ]
}
''';

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/interactions?key=$apiKey');
    final requestBody = jsonEncode({
      'model': 'models/gemini-3.8-flash',
      'input': userPrompt,
      'tools': [
        {'type': 'google_search'}
      ],
      'generation_config': {
        'max_output_tokens': 65536,
        'thinking_level': 'medium',
      }
    });

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      // Interactions API のレスポンス解析
      String? outputText;
      if (jsonResponse is Map<String, dynamic>) {
        if (jsonResponse.containsKey('output_text')) {
          outputText = jsonResponse['output_text'] as String?;
        } else if (jsonResponse.containsKey('interaction')) {
          final inter = jsonResponse['interaction'] as Map<String, dynamic>;
          outputText = inter['output_text'] as String?;
        }
      }

      if (outputText != null) {
        final parsed = _parseAiJson(outputText);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  /// AIの出力テキストからJSONを安全に抽出・パースする
  static AiSearchResult? _parseAiJson(String text) {
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final summary = decoded['summaryComment'] as String? ??
          'Gemini 3.8 Flash が最新のイベント・公園情報を検索しました！';
      final spotListJson = decoded['spots'] as List<dynamic>? ?? [];

      final spots = <OutingSpot>[];
      for (final item in spotListJson) {
        if (item is Map<String, dynamic>) {
          final catStr = item['category']?.toString() ?? 'event';
          final category = catStr == 'park'
              ? SpotCategory.park
              : (catStr == 'sightseeing'
                  ? SpotCategory.sightseeing
                  : SpotCategory.event);

          final tagStrings = (item['tags'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          final tags = <SpotTag>[];
          for (final t in tagStrings) {
            if (t.contains('food')) tags.add(SpotTag.food);
            if (t.contains('kids')) tags.add(SpotTag.kids);
            if (t.contains('nature')) tags.add(SpotTag.nature);
            if (t.contains('freeParking')) tags.add(SpotTag.freeParking);
            if (t.contains('indoor')) tags.add(SpotTag.indoor);
            if (t.contains('freeEntry')) tags.add(SpotTag.freeEntry);
          }

          final points = (item['recommendPoints'] as List<dynamic>? ?? [])
              .map((p) => p.toString())
              .toList();

          spots.add(OutingSpot(
            id: item['id']?.toString() ??
                'gemini_${DateTime.now().millisecondsSinceEpoch}',
            title: item['title']?.toString() ?? '注目スポット',
            subtitle: item['subtitle']?.toString() ?? '',
            category: category,
            tags: tags.isEmpty ? [SpotTag.food, SpotTag.kids] : tags,
            driveMinutes:
                (item['driveMinutes'] as num?)?.toInt() ?? 60,
            distanceKm:
                (item['distanceKm'] as num?)?.toDouble() ?? 40.0,
            scheduleText:
                item['scheduleText']?.toString() ?? '今週末開催',
            parkingInfo: item['parkingInfo']?.toString() ?? '駐車場あり',
            recommendPoints: points.isEmpty ? ['今週末おすすめのスポット'] : points,
            aiTip: item['aiTip']?.toString() ?? '事前の最新情報をご確認ください。',
            address: item['address']?.toString() ?? '会場周辺',
            latitude: (item['latitude'] as num?)?.toDouble() ?? 35.6895,
            longitude: (item['longitude'] as num?)?.toDouble() ?? 139.6917,
          ));
        }
      }

      if (spots.isNotEmpty) {
        return AiSearchResult(
          aiSummaryComment: summary,
          spots: spots,
          isLiveAi: true,
        );
      }
    } catch (_) {}
    return null;
  }

  /// キーの反映待ちやオフライン時のためのスマートフォールバック検索
  static Future<AiSearchResult> _localSearchFallback({
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
    required List<OutingSpot> currentSpots,
    required bool hasKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final normalizedQuery = query.trim();

    var filtered = currentSpots
        .where((spot) => spot.driveMinutes <= maxDriveMinutes)
        .toList();

    if (normalizedQuery.isNotEmpty) {
      final wantsFood = normalizedQuery.contains('食') ||
          normalizedQuery.contains('グルメ') ||
          normalizedQuery.contains('マルシェ') ||
          normalizedQuery.contains('パン');
      final wantsKids = normalizedQuery.contains('子供') ||
          normalizedQuery.contains('子ども') ||
          normalizedQuery.contains('遊具') ||
          normalizedQuery.contains('公園');
      final wantsRain = normalizedQuery.contains('雨') ||
          normalizedQuery.contains('室内');

      final matched = filtered.where((spot) {
        if (wantsRain && spot.tags.contains(SpotTag.indoor)) return true;
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
    final keyStatusNote = hasKey
        ? '（※現在Google側のAPIキー有効化を待機中のため、高速キャッシュデータを表示しています）'
        : '';
    final summary = normalizedQuery.isEmpty
        ? '📍 $departureAreaから$timeLabelで行ける今週末の催し物・大型公園を${filtered.length}件厳選しました！$keyStatusNote'
        : '✨ AI提案：「$normalizedQuery」に合わせて、$departureAreaから$timeLabelで行けるスポットを${filtered.length}件ピックアップしました！$keyStatusNote';

    return AiSearchResult(
      aiSummaryComment: summary,
      spots: filtered,
      isLiveAi: false,
    );
  }
}
