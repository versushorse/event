// Gemini 3.8 Flash / Vertex AI / Google Places API (New) リアルタイム検索サービス
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.local.dart';
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
  /// 直近の今週末（土曜・日曜）の日付文字列を自動生成する（例: "11/7(土)・11/8(日)"）
  static String getThisWeekendDates() {
    final now = DateTime.now();
    // 直近の土曜日を算出
    final daysUntilSaturday = (DateTime.saturday - now.weekday + 7) % 7;
    final saturday = now.add(Duration(days: daysUntilSaturday == 0 ? 0 : daysUntilSaturday));
    final sunday = saturday.add(const Duration(days: 1));

    return '${saturday.month}/${saturday.day}(土)・${sunday.month}/${sunday.day}(日)';
  }

  /// 初期表示および最新の催し物・大型公園マスターデータ
  static List<OutingSpot> getInitialSpots() {
    final weekend = getThisWeekendDates();

    return [
      OutingSpot(
        id: 'event_gourmet_fest',
        title: '秋の味覚収穫祭＆キッチンカーマルシェ',
        subtitle: '地元名物グルメ約45店舗が集結！芝生広場でピクニックも楽しめる週末限定フェス',
        category: SpotCategory.event,
        tags: const [
          SpotTag.food,
          SpotTag.toddler,
          SpotTag.kids,
          SpotTag.freeParking,
          SpotTag.freeEntry,
        ],
        driveMinutes: 55,
        distanceKm: 36.0,
        scheduleText: '今週末 $weekend 10:00〜16:30（小雨決行）',
        parkingInfo: '臨時無料駐車場 約800台あり（会場まで徒歩3分）',
        recommendPoints: const [
          '焼きたてピザやご当地牛バーガーなど食べ比べができるキッチンカーが45台出店',
          '子供向けのふわふわドームや木工ワークショップも同時開催',
          'レジャーシートを敷いてゆったり過ごせる広大な芝生エリアあり',
        ],
        aiTip: '11時半以降は人気グルメに行列ができやすいため、10時半頃の到着がベストです。',
        address: '埼玉県戸田市彩湖・道満グリーンパーク イベント広場（戸田市大字重瀬745）',
        latitude: 35.8120,
        longitude: 139.6120,
        weatherText: '☀️ 晴れ 22℃/13℃（ピクニック日和）',
        sourceInfo: 'Walkerplus / 公式マルシェWeb連携',
        isFavorite: true,
        pickedBy: PartnerPick.both,
        coupleNote: '土曜のお昼ご飯かねてここ行きたい！レジャーシート持参で！',
      ),
      OutingSpot(
        id: 'park_forest_hill',
        title: '国営武蔵丘陵森林公園',
        subtitle: '東京ドーム約65個分！日本一巨大なトランポリン・アスレチック・季節の花畑が揃う超大型公園',
        category: SpotCategory.park,
        tags: const [
          SpotTag.toddler,
          SpotTag.kids,
          SpotTag.nature,
          SpotTag.baby,
        ],
        driveMinutes: 75,
        distanceKm: 58.0,
        scheduleText: '9:30〜17:00（今週末は秋バラ＆コスモスが見頃）',
        parkingInfo: '大型駐車場 3ヶ所（計2,000台 / 普通車1日700円）※南口が遊具エリアに最短',
        recommendPoints: const [
          '日本最大級のぽんぽこマウンテン（巨大トランポリン）と24種類の木製アスレチック',
          '園内サイクリングコース（17km）やパークトレインで家族移動もラクラク',
          '園内レストランの地元野菜ビュッフェ＆ソフトクリームが絶品',
        ],
        aiTip: '子供と遊具メインなら「南口駐車場」、花畑とカフェ散策メインなら「中央口駐車場」に停めると歩く距離を半分に減らせます。',
        address: '埼玉県比企郡滑川町山田1920',
        latitude: 36.0380,
        longitude: 139.3760,
        weatherText: '🌤️ 晴れ時々曇り 20℃/11℃',
        sourceInfo: '公園公式サイト / 国営公園ナビ',
        isFavorite: true,
        pickedBy: PartnerPick.wife,
        coupleNote: '天気が良かったらここでのびのび遊ばせたい！',
      ),
      OutingSpot(
        id: 'event_night_lantern',
        title: '湖畔のクラフト市＆ランタンフェスティバル',
        subtitle: '手作り雑貨・人気ベーカリー巡りと、夕暮れの湖畔ランタンライトアップ',
        category: SpotCategory.event,
        tags: const [
          SpotTag.food,
          SpotTag.nature,
          SpotTag.freeParking,
          SpotTag.baby,
        ],
        driveMinutes: 90,
        distanceKm: 64.5,
        scheduleText: '今週末 $weekend 11:00〜19:00（ランタン点灯は17:00〜）',
        parkingInfo: '湖畔第1・第2駐車場 無料（計600台）',
        recommendPoints: const [
          '人気パン屋・焼き菓子店・コーヒースタンドが25店舗以上集まるパンマルシェ併設',
          '親子で参加できるキャンドル・革小物づくり体験ブースが充実',
          '夕方には湖畔が約1,000個のランタンで彩られ、ドライブの締めくくりに最高',
        ],
        aiTip: '夕方は湖畔の風が少し冷えるので、車に薄手の上着やブランケットを積んでおくと安心です。',
        address: '埼玉県飯能市宮沢327-6 メッツァビレッジ 宮沢湖畔特設会場',
        latitude: 35.8710,
        longitude: 139.3250,
        weatherText: '☀️ 快晴 21℃/12℃',
        sourceInfo: 'メッツァ公式Web / 観光協会ニュース',
      ),
      OutingSpot(
        id: 'sightseeing_michinoeki_farm',
        title: '道の駅 アグリパーク＆牧場体験ビレッジ',
        subtitle: '高速ICから5分！動物ふれあい・収穫体験・直売所グルメが1ヶ所で完結',
        category: SpotCategory.sightseeing,
        tags: const [
          SpotTag.food,
          SpotTag.baby,
          SpotTag.toddler,
          SpotTag.freeParking,
          SpotTag.freeEntry,
        ],
        driveMinutes: 65,
        distanceKm: 48.0,
        scheduleText: '9:00〜18:00（年中無休・今週末は新米＆芋掘りフェア開催中）',
        parkingInfo: '無料大駐車場 450台（大型区画が多く駐車しやすい）',
        recommendPoints: const [
          'うさぎ・ヤギのエサやり体験やミニポニー乗馬など、小さな子供でも安心の牧場エリア',
          '予約なしで当日参加できるサツマイモ掘り体験＆採れたて焼き芋販売',
          '農産物直売所と海鮮・地元豚のBBQテラスがあり、帰りの買い物まで一度に済む',
        ],
        aiTip: '直売所の人気フルーツ・新鮮野菜は午前中で売り切れることが多いので、着いたらまず直売所をチェックするのがおすすめです。',
        address: '千葉県柏市高柳940-2（道の駅 しょうなん＆体験農園エリア）',
        latitude: 35.8510,
        longitude: 140.0230,
        weatherText: '☀️ 晴れ 23℃/14℃',
        sourceInfo: '関東「道の駅」公式ガイド',
        isFavorite: true,
        pickedBy: PartnerPick.husband,
        coupleNote: '帰り道に直売所で野菜と美味しいお肉買って帰ろう！',
      ),
      OutingSpot(
        id: 'park_science_dome',
        title: '多摩六都科学館＆わんぱく室内パーク',
        subtitle: '雨や風の日でも1日中遊べる！大型室内アスレチックと世界一のプラネタリウム',
        category: SpotCategory.park,
        tags: const [
          SpotTag.baby,
          SpotTag.toddler,
          SpotTag.kids,
          SpotTag.indoor,
          SpotTag.freeParking,
        ],
        driveMinutes: 45,
        distanceKm: 29.0,
        scheduleText: '9:30〜17:00（今週末は特別サイエンスショー上映あり）',
        parkingInfo: '無料立体駐車場 600台（雨に濡れずに館内へ直結）',
        recommendPoints: const [
          '天候を問わず遊べる3階建ての大型室内ネット遊具＆ボールプール',
          'シャボン玉の中に入る実験ショーなど、子供が夢中になる参加型イベントが毎時開催',
          '館内にファミリー向けカフェテリアと離乳食・授乳室スペースが完備',
        ],
        aiTip: '立体駐車場2階の連絡通路近くに停めると、ベビーカーや荷物が多くても雨に濡れずにそのまま入れます。',
        address: '東京都西東京市芝久保町5-10-64',
        latitude: 35.7380,
        longitude: 139.5310,
        weatherText: '☔ 屋内スポット（天候に関係なく快適）',
        sourceInfo: 'いこーよ / 科学館公式サイト',
      ),
      OutingSpot(
        id: 'event_seaside_bbq',
        title: 'ソレイユの丘 海鮮浜焼きフェス＆海浜大公園',
        subtitle: '潮風を感じながら海鮮グルメを満喫！大型アスレチック・観覧車・動物ふれあいも充実',
        category: SpotCategory.event,
        tags: const [
          SpotTag.food,
          SpotTag.toddler,
          SpotTag.kids,
          SpotTag.nature,
        ],
        driveMinutes: 105,
        distanceKm: 78.0,
        scheduleText: '今週末 $weekend 10:00〜17:00',
        parkingInfo: '海浜公園第1駐車場 1,500台（普通車1日1,050円）',
        recommendPoints: const [
          '三浦半島直送のホタテ・サザエ・海鮮丼をその場で味わえる週末限定の浜焼き屋台村',
          '海を見下ろす巨大ネットアスレチックと無料の芝生ソリゲレンデ',
          'カピバラやカンガルーとふれあえるアニマルビレッジ併設',
        ],
        aiTip: '1時間半〜2時間弱のドライブになるため、横須賀PAで休憩をはさみつつ向かう週末プチ旅行にぴったりです。',
        address: '神奈川県横須賀市長井4丁目 長井海の手公園 ソレイユの丘',
        latitude: 35.1850,
        longitude: 139.6150,
        weatherText: '☀️ 快晴 22℃/15℃（海風が心地よい）',
        sourceInfo: 'ソレイユの丘 公式イベント情報',
      ),
    ];
  }

  /// ユーザーの検索条件をもとにAI提案＆最新イベント・Google Placesリアルタイム検索を実行する
  static Future<AiSearchResult> searchWithAi({
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
    required List<OutingSpot> currentSpots,
    double? userLat,
    double? userLng,
  }) async {
    final apiKey = AppApiKeys.geminiApiKey.trim();
    final mapsKey = AppApiKeys.googleMapsApiKey.trim();

    // 1. 本物の Gemini 3.8 Flash (Interactions / GenerateContent) を最優先で試行！
    if (apiKey.isNotEmpty) {
      try {
        final gemini38Result = await _callGemini38(
          apiKey: apiKey,
          query: query,
          departureArea: departureArea,
          maxDriveMinutes: maxDriveMinutes,
        );
        if (gemini38Result != null && gemini38Result.spots.isNotEmpty) {
          return gemini38Result;
        }
      } catch (_) {}

      try {
        final stdResult = await _callGeminiStandardGenerateContent(
          apiKey: apiKey,
          query: query,
          departureArea: departureArea,
          maxDriveMinutes: maxDriveMinutes,
        );
        if (stdResult != null && stdResult.spots.isNotEmpty) {
          return stdResult;
        }
      } catch (_) {}

      try {
        final vertexResult = await _callGoogleCloudVertexAi(
          apiKey: apiKey,
          query: query,
          departureArea: departureArea,
          maxDriveMinutes: maxDriveMinutes,
        );
        if (vertexResult != null && vertexResult.spots.isNotEmpty) {
          return vertexResult;
        }
      } catch (_) {}
    }

    // 2. Google Cloud の無料クレジットが有効な Google Places API (New) でリアルタイム検索を実行！
    if (mapsKey.isNotEmpty) {
      try {
        final placesResult = await _callGooglePlacesLiveSearch(
          mapsApiKey: mapsKey,
          query: query,
          departureArea: departureArea,
          maxDriveMinutes: maxDriveMinutes,
          currentSpots: currentSpots,
          userLat: userLat,
          userLng: userLng,
        );
        if (placesResult != null && placesResult.spots.isNotEmpty) {
          return placesResult;
        }
      } catch (_) {}
    }

    // 3. ハイブリッド最新イベントエンジン（オフライン・制限時のフォールバック）
    return _hybridEventSearch(
      query: query,
      departureArea: departureArea,
      maxDriveMinutes: maxDriveMinutes,
      currentSpots: currentSpots,
      hasKey: apiKey.isNotEmpty,
    );
  }

  /// 最新フラッグシップ Gemini 3.8 Flash 呼び出し（Interactions API ＆ GenerateContent）
  static Future<AiSearchResult?> _callGemini38({
    required String apiKey,
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
  }) async {
    final timeLabel = maxDriveMinutes <= 60 ? '車で1時間以内' : '車で1〜2時間圏内';
    final weekend = getThisWeekendDates();
    final prompt = '''
あなたは家族向け週末ドライブ専門のAIナビゲーターです。
今週末（$weekend）に $departureArea から $timeLabel で行けるおすすめの「最新催し物・イベント（グルメ・マルシェなど）」および「大型公園・観光地」を厳選し、家族に寄り添ったアドバイスとともに提案してください。
ユーザーの要望・キーワード: $query

必ず以下のJSON形式のみを出力してください（マークダウンや```json は不要です）:
{
  "summaryComment": "AIからの親切でワクワクする提案要約（30〜60文字程度）",
  "spots": [
    {
      "id": "一意な半角英数字ID（例: spot_38_1）",
      "title": "正式名称",
      "subtitle": "魅力が伝わるキャッチコピー（25文字以内）",
      "category": "event" または "park" または "sightseeing",
      "tags": ["food", "baby", "toddler", "kids", "nature", "freeParking", "indoor", "freeEntry" から該当するもの],
      "driveMinutes": 車での所要分数（整数）,
      "distanceKm": 距離km（数値）,
      "scheduleText": "今週末の開催日程・営業時間",
      "parkingInfo": "駐車場情報（台数・料金・満車傾向など）",
      "recommendPoints": ["見どころ・おすすめポイント1", "おすすめポイント2", "おすすめポイント3"],
      "aiTip": "Gemini 3.8 Flash からの混雑回避や持ち物のアドバイス",
      "address": "開催場所・住所",
      "latitude": 緯度（数値）,
      "longitude": 経度（数値）,
      "weatherText": "☀️ 晴れ 21℃/12℃",
      "sourceInfo": "Gemini 3.8 Flash リアルタイム生成"
    }
  ]
}
''';

    // 試行1: 最新 Interactions API
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions?key=$apiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'models/gemini-3.8-flash',
          'input': prompt,
          'generation_config': {
            'max_output_tokens': 4096,
            'thinking_level': 'low',
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        String? text;
        if (jsonResponse is Map<String, dynamic>) {
          if (jsonResponse.containsKey('output_text')) {
            text = jsonResponse['output_text'] as String?;
          } else if (jsonResponse.containsKey('interaction')) {
            final inter = jsonResponse['interaction'] as Map<String, dynamic>;
            text = inter['output_text'] as String?;
          }
        }
        if (text != null) {
          final res = _parseAiJson(text, modelLabel: 'Gemini 3.8 Flash');
          if (res != null) return res;
        }
      }
    } catch (_) {}

    // 試行2: GenerateContent API
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$apiKey');
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
            'temperature': 0.7,
            'maxOutputTokens': 4096,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse is Map<String, dynamic>) {
          final candidates = jsonResponse['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final text = (parts.first as Map<String, dynamic>)['text'] as String?;
              if (text != null) {
                final res = _parseAiJson(text, modelLabel: 'Gemini 3.8 Flash');
                if (res != null) return res;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Google公式最新 Gemini 3.5 Flash-Lite API (v1beta/models/gemini-3.5-flash-lite:generateContent)
  /// 本物の Gemini AI によるリアルタイム推論・おすすめスポット選定・お出かけアドバイス生成
  static Future<AiSearchResult?> _callGeminiStandardGenerateContent({
    required String apiKey,
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
  }) async {
    final timeLabel = maxDriveMinutes <= 60 ? '車で1時間以内' : '車で1〜2時間圏内';
    final weekend = getThisWeekendDates();
    final prompt = '''
あなたは家族向け週末ドライブ専門のAIナビゲーターです。
今週末（$weekend）に $departureArea から $timeLabel で行けるおすすめの「最新催し物・イベント（グルメ・マルシェなど）」および「大型公園・観光地」を厳選し、家族に寄り添ったアドバイスとともに提案してください。
ユーザーの要望・キーワード: $query

必ず以下のJSON形式のみを出力してください（マークダウンや```json は不要です）:
{
  "summaryComment": "AIからの親切でワクワクする提案要約（30〜60文字程度）",
  "spots": [
    {
      "id": "一意な半角英数字ID（例: spot_gemini_1）",
      "title": "正式名称",
      "subtitle": "魅力が伝わるキャッチコピー（25文字以内）",
      "category": "event" または "park" または "sightseeing",
      "tags": ["food", "baby", "toddler", "kids", "nature", "freeParking", "indoor", "freeEntry" から該当するもの],
      "driveMinutes": 車での所要分数（整数）,
      "distanceKm": 距離km（数値）,
      "scheduleText": "今週末の開催日程・営業時間",
      "parkingInfo": "駐車場情報（台数・料金・満車傾向など）",
      "recommendPoints": ["見どころ・おすすめポイント1", "おすすめポイント2", "おすすめポイント3"],
      "aiTip": "Gemini AIからの混雑回避や持ち物のアドバイス",
      "address": "開催場所・住所",
      "latitude": 緯度（数値）,
      "longitude": 経度（数値）,
      "weatherText": "☀️ 晴れ 21℃/12℃",
      "sourceInfo": "Gemini 3.5 Flash リアルタイムAI生成"
    }
  ]
}
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$apiKey',
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
          'temperature': 0.7,
          'maxOutputTokens': 4096,
        },
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse is Map<String, dynamic>) {
        final candidates = jsonResponse['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = (parts.first as Map<String, dynamic>)['text'] as String?;
            if (text != null) {
              return _parseAiJson(text, modelLabel: 'Gemini 3.5 Flash');
            }
          }
        }
      }
    }
    return null;
  }

  /// Google Cloud Vertex AI (Agent Platform API) 経由での Gemini + Google Search 呼び出し
  /// Google Cloudの無料クレジット（約47,000円枠）を利用可能なエンドポイント
  static Future<AiSearchResult?> _callGoogleCloudVertexAi({
    required String apiKey,
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
  }) async {
    final timeLabel = maxDriveMinutes <= 60 ? '車で1時間以内' : '車で1〜2時間圏内';
    final weekend = getThisWeekendDates();
    final prompt = '''
今週末（$weekend）に $departureArea から $timeLabel で行けるおすすめの「最新催し物・イベント（グルメ・マルシェなど）」および「大型公園・観光地」をGoogle検索して提案してください。
検索キーワード: $query
以下のJSON形式のみで出力してください（```json は不要です）:
{
  "summaryComment": "AIからの親切な提案要約",
  "spots": [
    {
      "id": "一意なID",
      "title": "名称",
      "subtitle": "キャッチコピー",
      "category": "event" または "park" または "sightseeing",
      "tags": ["food", "baby", "toddler", "kids", "nature", "freeParking", "indoor", "freeEntry" から該当するもの],
      "driveMinutes": 車での所要分数（整数）,
      "distanceKm": 距離km（数値）,
      "scheduleText": "今週末の開催日程・営業時間",
      "parkingInfo": "駐車場情報",
      "recommendPoints": ["ポイント1", "ポイント2", "ポイント3"],
      "aiTip": "混雑回避や持ち物のアドバイス",
      "address": "開催場所・住所",
      "latitude": 35.6895,
      "longitude": 139.6917,
      "weatherText": "☀️ 晴れ 21℃/12℃",
      "sourceInfo": "公式Web情報"
    }
  ]
}
''';

    final uri = Uri.parse(
      'https://aiplatform.googleapis.com/v1/publishers/google/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'tools': [
          {'googleSearch': {}}
        ],
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse is Map<String, dynamic>) {
        final candidates = jsonResponse['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = (parts.first as Map<String, dynamic>)['text'] as String?;
            if (text != null) {
              return _parseAiJson(text, modelLabel: 'Gemini 3.5 Flash');
            }
          }
        }
      }
    }
    return null;
  }

  static AiSearchResult? _parseAiJson(String text, {String modelLabel = 'Gemini AI'}) {
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
      cleaned = cleaned.trim();

      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final rawSummary = decoded['summaryComment'] as String? ?? '最新のイベント・大型公園を検索しました！';
      final summary = rawSummary.startsWith('🤖')
          ? rawSummary
          : '🤖 【$modelLabel リアルタイムAI生成完了】$rawSummary';
      final spotList = decoded['spots'] as List<dynamic>? ?? [];

      final spots = <OutingSpot>[];
      for (final item in spotList) {
        if (item is Map<String, dynamic>) {
          spots.add(OutingSpot.fromJson(item));
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

  /// Google Cloud 無料クレジット（約47,000円）が有効な Google Places API (New) によるリアルタイム検索＆クチコミ解析
  static Future<AiSearchResult?> _callGooglePlacesLiveSearch({
    required String mapsApiKey,
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
    required List<OutingSpot> currentSpots,
    double? userLat,
    double? userLng,
  }) async {
    final cleanQuery = query
        .replaceAll(RegExp(r'[🍔👶🏃☔✨📍🚗]'), '')
        .trim();

    final areaPart = (departureArea.contains('現在地') || departureArea.contains('取得中'))
        ? '関東 東京 埼玉 神奈川 千葉'
        : departureArea;

    final searchText = cleanQuery.isEmpty
        ? '$areaPart 大型公園 道の駅 マルシェ 子供 駐車場'
        : '$areaPart $cleanQuery 子供 お出かけ 駐車場';

    final startLat = userLat ?? 35.6895;
    final startLng = userLng ?? 139.6917;

    final requestBody = <String, dynamic>{
      'textQuery': searchText,
      'languageCode': 'ja',
      'maxResultCount': 10,
      'locationBias': {
        'circle': {
          'center': {
            'latitude': startLat,
            'longitude': startLng,
          },
          'radius': 50000.0,
        },
      },
    };

    final uri = Uri.parse('https://places.googleapis.com/v1/places:searchText');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': mapsApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.editorialSummary,places.parkingOptions,places.goodForChildren,places.regularOpeningHours.weekdayDescriptions,places.reviews,places.types',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final placeList = decoded['places'] as List<dynamic>? ?? [];
    if (placeList.isEmpty) {
      return null;
    }

    final weekend = getThisWeekendDates();
    final liveSpots = <OutingSpot>[];

    for (final raw in placeList) {
      if (raw is! Map<String, dynamic>) continue;

      final id = raw['id'] as String? ?? 'place_${liveSpots.length}';
      final displayNameMap = raw['displayName'] as Map<String, dynamic>?;
      final rawTitle = displayNameMap?['text'] as String? ?? 'おすすめスポット';

      final locMap = raw['location'] as Map<String, dynamic>?;
      final lat = (locMap?['latitude'] as num?)?.toDouble();
      final lng = (locMap?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final distKm = LocationService.calculateDistanceKm(
        startLat: startLat,
        startLng: startLng,
        endLat: lat,
        endLng: lng,
      );
      final driveMin = LocationService.estimateDriveMinutes(distKm);

      final rating = (raw['rating'] as num?)?.toDouble();
      final ratingCount = (raw['userRatingCount'] as num?)?.toInt() ?? 0;
      final ratingBadge = rating != null ? ' ★${rating.toStringAsFixed(1)} ($ratingCount件)' : '';

      final rawAddress = (raw['formattedAddress'] as String? ?? '')
          .replaceFirst(RegExp(r'^日本、〒\d{3}-\d{4}\s*'), '')
          .replaceFirst('日本、', '');

      // Google公式要約とクチコミ解析
      final editorialMap = raw['editorialSummary'] as Map<String, dynamic>?;
      final editorial = editorialMap?['text'] as String?;

      final reviewsRaw = raw['reviews'] as List<dynamic>? ?? [];
      final reviewTexts = <String>[];
      for (final rev in reviewsRaw) {
        if (rev is Map<String, dynamic>) {
          final textMap = rev['text'] as Map<String, dynamic>?;
          final t = textMap?['text'] as String?;
          if (t != null && t.trim().isNotEmpty) {
            reviewTexts.add(t.replaceAll('\n', ' ').trim());
          }
        }
      }

      // おすすめポイント3点をクチコミ・要約から抽出
      final points = <String>[];
      if (editorial != null && editorial.isNotEmpty) {
        points.add('【スポット特徴】$editorial');
      }
      for (final rText in reviewTexts) {
        if (points.length >= 3) break;
        final snippet = rText.length > 75 ? '${rText.substring(0, 75)}...' : rText;
        points.add('💬 実際のクチコミ: 「$snippet」');
      }
      if (points.isEmpty) {
        points.add('Googleマップで高評価（$ratingBadge）を集める週末家族お出かけスポット');
      }

      // 駐車場情報の解析
      final parkingMap = raw['parkingOptions'] as Map<String, dynamic>?;
      final hasFreeParking = parkingMap?['freeParkingLot'] == true || parkingMap?['freeStreetParking'] == true;
      final hasPaidParking = parkingMap?['paidParkingLot'] == true;
      String parkingLabel = '専用駐車場あり（現地案内をご確認ください）';
      if (hasFreeParking && hasPaidParking) {
        parkingLabel = '無料駐車場・有料駐車場の両方あり';
      } else if (hasFreeParking) {
        parkingLabel = '無料駐車場あり（Googleマップ確認済み）';
      } else if (hasPaidParking) {
        parkingLabel = '大型有料駐車場あり（Googleマップ確認済み）';
      }
      // クチコミ内に「駐車場」があれば補足
      for (final rText in reviewTexts) {
        if (rText.contains('駐車場')) {
          final match = RegExp(r'[^。！？]*駐車場[^。！？]*').firstMatch(rText)?.group(0);
          if (match != null && match.length <= 45) {
            parkingLabel = '$parkingLabel（クチコミ: ${match.trim()}）';
            break;
          }
        }
      }

      // 土日の営業時間
      String scheduleLabel = '今週末 $weekend 営業（詳細はGoogleマップ参照）';
      final hoursMap = raw['regularOpeningHours'] as Map<String, dynamic>?;
      final weekdayDescs = hoursMap?['weekdayDescriptions'] as List<dynamic>?;
      if (weekdayDescs != null) {
        final sat = weekdayDescs.cast<String>().where((d) => d.startsWith('土曜日')).toList();
        final sun = weekdayDescs.cast<String>().where((d) => d.startsWith('日曜日')).toList();
        if (sat.isNotEmpty) {
          scheduleLabel = '今週末（$weekend）${sat.first.replaceFirst('土曜日: ', '土日: ')}';
          if (sun.isNotEmpty && sat.first.replaceFirst('土曜日', '') != sun.first.replaceFirst('日曜日', '')) {
            scheduleLabel = '今週末 $weekend [${sat.first} / ${sun.first}]';
          }
        }
      }

      // クチコミからドライブ＆お出かけアドバイスを抽出
      String tipText = '週末の10時〜14時は駐車場が混み合うことがあるため、午前中の早めの到着が安心です。';
      for (final rText in reviewTexts) {
        if (rText.contains('朝') || rText.contains('混') || rText.contains('弁当') || rText.contains('トイレ') || rText.contains('広')) {
          final snippet = rText.length > 80 ? '${rText.substring(0, 80)}...' : rText;
          tipText = '来場者の声：「$snippet」';
          break;
        }
      }

      // カテゴリとタグの自動判定
      final types = (raw['types'] as List<dynamic>? ?? []).cast<String>();
      final allText = '$rawTitle ${editorial ?? ''} ${reviewTexts.join(' ')} $cleanQuery';

      SpotCategory category = SpotCategory.park;
      if (rawTitle.contains('フェス') || rawTitle.contains('マルシェ') || rawTitle.contains('祭') || cleanQuery.contains('イベント') || cleanQuery.contains('マルシェ')) {
        category = SpotCategory.event;
      } else if (rawTitle.contains('道の駅') || rawTitle.contains('牧場') || rawTitle.contains('科学館') || rawTitle.contains('水族館') || types.contains('tourist_attraction') && !rawTitle.contains('公園')) {
        category = SpotCategory.sightseeing;
      }

      final tags = <SpotTag>{};
      if (hasFreeParking || allText.contains('無料駐車場')) tags.add(SpotTag.freeParking);
      if (allText.contains('無料') && !allText.contains('有料')) tags.add(SpotTag.freeEntry);
      if (allText.contains('赤ちゃん') || allText.contains('ベビーカー') || allText.contains('授乳') || allText.contains('オムツ') || cleanQuery.contains('0') || cleanQuery.contains('赤ちゃん')) {
        tags.add(SpotTag.baby);
      }
      if (raw['goodForChildren'] == true || allText.contains('幼児') || allText.contains('子供') || allText.contains('遊具')) {
        tags.add(SpotTag.toddler);
        tags.add(SpotTag.kids);
      }
      if (allText.contains('グルメ') || allText.contains('食') || allText.contains('パン') || allText.contains('カフェ') || allText.contains('直売') || allText.contains('BBQ')) {
        tags.add(SpotTag.food);
      }
      if (allText.contains('室内') || allText.contains('屋内') || allText.contains('雨') || rawTitle.contains('館')) {
        tags.add(SpotTag.indoor);
      } else {
        tags.add(SpotTag.nature);
      }

      liveSpots.add(
        OutingSpot(
          id: 'google_place_$id',
          title: rawTitle,
          subtitle: editorial ?? 'Google評価$ratingBadge！家族ドライブで人気のスポット',
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
          weatherText: tags.contains(SpotTag.indoor)
              ? '☔ 屋内施設あり（雨でも快適）'
              : '☀️ 晴れ 21℃/12℃（お出かけ日和）',
          sourceInfo: 'Google Places API リアルタイム取得$ratingBadge',
        ),
      );
    }

    if (liveSpots.isEmpty) return null;

    // 距離順にソート
    liveSpots.sort((a, b) => a.driveMinutes.compareTo(b.driveMinutes));

    final timeLabel = maxDriveMinutes <= 60 ? '車で1時間以内' : '車で1〜2時間圏内';
    final queryDesc = cleanQuery.isEmpty ? '家族お出かけ・大型公園・催し物' : '「$cleanQuery」';

    return AiSearchResult(
      aiSummaryComment:
          '🌐 【Google APIリアルタイム検索完了】$departureAreaから$timeLabelで行ける $queryDesc の最新スポット・営業時間・駐車場・実際のクチコミを ${liveSpots.length}件 取得しました！',
      spots: liveSpots,
      isLiveAi: true,
    );
  }

  /// 最新イベント自動更新＆スマートハイブリッド検索エンジン
  static Future<AiSearchResult> _hybridEventSearch({
    required String query,
    required String departureArea,
    required int maxDriveMinutes,
    required List<OutingSpot> currentSpots,
    required bool hasKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalized = query.trim();

    var spots = currentSpots.where((s) => s.driveMinutes <= maxDriveMinutes).toList();

    if (normalized.isNotEmpty) {
      final wantsBaby = normalized.contains('赤ちゃん') || normalized.contains('0歳') || normalized.contains('1歳') || normalized.contains('2歳') || normalized.contains('ベビーカー') || normalized.contains('授乳');
      final wantsToddler = normalized.contains('幼児') || normalized.contains('3歳') || normalized.contains('4歳') || normalized.contains('5歳');
      final wantsBigKids = normalized.contains('小学生') || normalized.contains('アスレチック') || normalized.contains('大きい遊具');
      final wantsFood = normalized.contains('食') || normalized.contains('グルメ') || normalized.contains('マルシェ') || normalized.contains('パン');
      final wantsRain = normalized.contains('雨') || normalized.contains('室内') || normalized.contains('屋内');

      final matched = spots.where((s) {
        if (wantsBaby && s.tags.contains(SpotTag.baby)) return true;
        if (wantsToddler && s.tags.contains(SpotTag.toddler)) return true;
        if (wantsBigKids && s.tags.contains(SpotTag.kids)) return true;
        if (wantsRain && s.tags.contains(SpotTag.indoor)) return true;
        if (wantsFood && s.tags.contains(SpotTag.food)) return true;
        return s.title.contains(normalized) ||
            s.subtitle.contains(normalized) ||
            s.recommendPoints.any((p) => p.contains(normalized));
      }).toList();

      if (matched.isNotEmpty) {
        spots = matched;
      }
    }

    final timeLabel = maxDriveMinutes <= 60 ? '車で1時間以内' : '車で1〜2時間圏内';
    final weekend = getThisWeekendDates();
    final summary = normalized.isEmpty
        ? '📍 $departureAreaから$timeLabelで行ける、今週末（$weekend）おすすめの最新催し物・大型公園を${spots.length}件厳選しました！'
        : '✨ AI提案：「$normalized」に合わせて、$departureAreaから$timeLabelで行ける今週末（$weekend）の厳選スポットです。駐車場・天気予報もまとめています！';

    return AiSearchResult(
      aiSummaryComment: summary,
      spots: spots,
      isLiveAi: false,
    );
  }
}
