// お出かけスポット・イベントおよび旅のしおりデータモデル定義

/// 東北6県の地域タブ定義
enum TohokuRegion {
  miyagi('宮城県', '📍', 'ar0204', 4, 38.2682, 140.8694),
  yamagata('山形県', '🍒', 'ar0206', 6, 38.2404, 140.3633),
  iwate('岩手県', '⛰️', 'ar0203', 3, 39.7036, 141.1527),
  fukushima('福島県', '🍑', 'ar0207', 7, 37.7503, 140.4676),
  akita('秋田県', '🌾', 'ar0205', 5, 39.7186, 140.1024),
  aomori('青森県', '🍎', 'ar0202', 2, 40.8244, 140.7400);

  final String label;
  final String icon;
  final String walkerplusCode;
  final int ikoyoPrefectureId;
  final double centerLat;
  final double centerLng;

  const TohokuRegion(
    this.label,
    this.icon,
    this.walkerplusCode,
    this.ikoyoPrefectureId,
    this.centerLat,
    this.centerLng,
  );
}

/// スポットのジャンル（ユーザー指定の優先順）
enum SpotCategory {
  event('期間限定イベント', '🎪'),
  gourmet('グルメ・マルシェ', '🍠'),
  dining('地元グルメ・食事処', '🍽️'),
  tourism('観光地・名所', '📸'),
  park('大きな公園（小学生）', '🏃'),
  onsen('温泉・日帰り銭湯', '♨️'),
  indoor('屋内スポット', '🏛️'),
  smallPark('小さな公園', '🌳'),
  sightseeing('神社仏閣', '⛩️');

  final String label;
  final String icon;
  const SpotCategory(this.label, this.icon);
}

/// 夫婦のお気に入り傾向からGemini 3.5 Flash-Liteが導き出したパーソナライズAI分析結果
class CouplePreferenceAiInsight {
  final String preferenceSummary; // 例: 「温泉＆名物グルメに目がない自然派ファミリー」
  final String recommendationText; // 例: 「秋保温泉や定義如来がお好きなご夫婦なら、山形では...」
  final List<String> favoriteKeywords; // 例: ['温泉', 'ご当地グルメ', '自然散策']
  final DateTime analyzedAt;

  const CouplePreferenceAiInsight({
    required this.preferenceSummary,
    required this.recommendationText,
    required this.favoriteKeywords,
    required this.analyzedAt,
  });
}

/// イベント・スポットのタイプ別タグ（小学生向け・グルメ・駐車場など）
enum SpotTag {
  food('グルメ・マルシェ', '🍠'),
  kids('小学生・アスレチック', '🏃'),
  onsen('温泉・露天風呂・サウナ', '♨️'),
  nature('自然・広大な広場', '🌿'),
  indoor('屋内・雨でもOK', '🏛️'),
  freeParking('無料駐車場あり', '🅿️'),
  freeEntry('入場無料・コスパ◎', '🆓'),
  toddler('体験・アクティビティ', '🎠'),
  baby('散策・食べ歩き', '🚶');

  final String label;
  final String icon;
  const SpotTag(this.label, this.icon);

  static SpotTag? fromKey(String key) {
    for (final tag in SpotTag.values) {
      if (tag.name == key) return tag;
    }
    return null;
  }
}

/// 誰が「行きたい！」に追加したか（夫婦共有用）
enum PartnerPick {
  husband('夫が気になる', '🙋‍♂️'),
  wife('妻が気になる', '🙋‍♀️'),
  both('2人とも行きたい！', '💑');

  final String label;
  final String icon;
  const PartnerPick(this.label, this.icon);

  static PartnerPick? fromKey(String? key) {
    if (key == null) return null;
    for (final pick in PartnerPick.values) {
      if (pick.name == key) return pick;
    }
    return null;
  }
}

/// 旅のしおり・予定のアイコン種別（新幹線・飛行機・車・観光・グルメ・ホテルなど）
enum TripItemType {
  shinkansen('新幹線・特急', '🚄'),
  flight('飛行機・空港', '✈️'),
  train('電車・バス', '🚃'),
  car('ドライブ・車移動', '🚗'),
  sightseeing('観光・テーマパーク', '🎡'),
  food('グルメ・食事・カフェ', '🍽️'),
  hotel('ホテル・温泉・宿', '🏨'),
  shopping('お土産・ショッピング', '🛍️'),
  other('その他予定', '📌');

  final String label;
  final String icon;
  const TripItemType(this.label, this.icon);

  static TripItemType fromName(String? name) {
    if (name == null) return TripItemType.sightseeing;
    for (final t in TripItemType.values) {
      if (t.name == name) return t;
    }
    return TripItemType.sightseeing;
  }
}

/// 旅のしおりの1コマ分のスケジュール予定
class TripScheduleItem {
  final String id;
  final int dayNumber; // 1 = Day 1, 2 = Day 2...
  final String timeText; // 例: '09:30'
  final String title; // 例: '新幹線で新大阪駅へ ➔ 海遊館'
  final TripItemType type;
  final String location; // 例: '大阪市港区海岸通'
  final String memo; // 例: 'ジンベエザメを見る！チケット事前購入済み'
  final String url;

  const TripScheduleItem({
    required this.id,
    this.dayNumber = 1,
    required this.timeText,
    required this.title,
    this.type = TripItemType.sightseeing,
    this.location = '',
    this.memo = '',
    this.url = '',
  });

  TripScheduleItem copyWith({
    String? id,
    int? dayNumber,
    String? timeText,
    String? title,
    TripItemType? type,
    String? location,
    String? memo,
    String? url,
  }) {
    return TripScheduleItem(
      id: id ?? this.id,
      dayNumber: dayNumber ?? this.dayNumber,
      timeText: timeText ?? this.timeText,
      title: title ?? this.title,
      type: type ?? this.type,
      location: location ?? this.location,
      memo: memo ?? this.memo,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayNumber': dayNumber,
        'timeText': timeText,
        'title': title,
        'type': type.name,
        'location': location,
        'memo': memo,
        'url': url,
      };

  factory TripScheduleItem.fromJson(Map<String, dynamic> json) {
    return TripScheduleItem(
      id: json['id'] as String? ??
          'item_${DateTime.now().microsecondsSinceEpoch}',
      dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
      timeText: json['timeText'] as String? ?? '10:00',
      title: json['title'] as String? ?? '',
      type: TripItemType.fromName(json['type'] as String?),
      location: json['location'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

/// 家族の旅のしおり（大阪・名古屋などの旅行や週末1日ドライブコース）
class TripPlan {
  final String id;
  final String title; // 例: '🏯 大阪・名古屋 家族旅行'
  final String subtitle; // 例: '来週のお出かけしおり（小学生＆夫婦）'
  final int totalDays; // 例: 3 (Day 1〜Day 3)
  final List<TripScheduleItem> items;
  final int updatedAtMs;

  const TripPlan({
    required this.id,
    required this.title,
    this.subtitle = '家族のお出かけスケジュール',
    this.totalDays = 1,
    required this.items,
    required this.updatedAtMs,
  });

  TripPlan copyWith({
    String? id,
    String? title,
    String? subtitle,
    int? totalDays,
    List<TripScheduleItem>? items,
    int? updatedAtMs,
  }) {
    return TripPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      totalDays: totalDays ?? this.totalDays,
      items: items ?? this.items,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'totalDays': totalDays,
        'items': items.map((i) => i.toJson()).toList(),
        'updatedAtMs': updatedAtMs,
      };

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return TripPlan(
      id: json['id'] as String? ??
          'trip_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? '家族のお出かけしおり',
      subtitle: json['subtitle'] as String? ?? '',
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 1,
      items: rawItems
          .map((e) => TripScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// LINEやTimeTreeにそのまま貼り付けられる共有テキストを生成
  String toShareText() {
    final buf = StringBuffer();
    buf.writeln('📒【旅のしおり】$title');
    if (subtitle.isNotEmpty) {
      buf.writeln('✨ $subtitle');
    }
    buf.writeln('━━━━━━━━━━━━━━');
    for (int d = 1; d <= totalDays; d++) {
      final dayItems = items.where((i) => i.dayNumber == d).toList();
      buf.writeln('\n📅【Day $d】');
      if (dayItems.isEmpty) {
        buf.writeln('  （予定なし）');
      } else {
        for (final item in dayItems) {
          buf.writeln('⏰ ${item.timeText}  ${item.type.icon} ${item.title}');
          if (item.location.isNotEmpty) {
            buf.writeln('   📍 ${item.location}');
          }
          if (item.memo.isNotEmpty) {
            buf.writeln('   💬 ${item.memo}');
          }
          if (item.url.isNotEmpty) {
            buf.writeln('   🌐 ${item.url}');
          }
        }
      }
    }
    return buf.toString().trim();
  }

  /// Googleカレンダー（およびTimeTreeのOSカレンダー連携）へ一括登録するURL
  String toGoogleCalendarUrl(DateTime targetDate, {int? dayFilter}) {
    final baseDate = dayFilter != null && dayFilter > 1
        ? targetDate.add(Duration(days: dayFilter - 1))
        : targetDate;
    final y = baseDate.year.toString().padLeft(4, '0');
    final m = baseDate.month.toString().padLeft(2, '0');
    final d = baseDate.day.toString().padLeft(2, '0');
    final nextDay = baseDate.add(const Duration(days: 1));
    final ny = nextDay.year.toString().padLeft(4, '0');
    final nm = nextDay.month.toString().padLeft(2, '0');
    final nd = nextDay.day.toString().padLeft(2, '0');

    final eventTitle =
        dayFilter != null ? '$title (Day $dayFilter)' : title;
    final filteredItems = dayFilter != null
        ? items.where((i) => i.dayNumber == dayFilter).toList()
        : items;
    final details = filteredItems
        .map((i) =>
            '${i.timeText} ${i.type.icon}${i.title}${i.location.isNotEmpty ? " (${i.location})" : ""}${i.memo.isNotEmpty ? " - ${i.memo}" : ""}')
        .join('\n');
    final firstLocation = filteredItems
        .map((i) => i.location)
        .firstWhere((loc) => loc.isNotEmpty, orElse: () => '');

    return Uri.https('www.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': eventTitle,
      'dates': '$y$m$d/$ny$nm$nd',
      'details': details,
      if (firstLocation.isNotEmpty) 'location': firstLocation,
    }).toString();
  }

  /// 来週の「大阪・名古屋 家族旅行」初期サンプルしおり（自由に編集・追加可能！）
  static TripPlan createOsakaNagoyaStarter() {
    return TripPlan(
      id: 'trip_osaka_nagoya_starter',
      title: '🏯 大阪・名古屋 家族旅行しおり',
      subtitle: '来週の家族旅行プラン（自由に時間・予定を編集できます！）',
      totalDays: 3,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      items: const [
        // Day 1: 大阪
        TripScheduleItem(
          id: 'on_d1_1',
          dayNumber: 1,
          timeText: '09:00',
          title: '出発 ➔ 大阪へ移動（飛行機 / 新幹線）',
          type: TripItemType.shinkansen,
          location: '伊丹空港 / 新大阪駅',
          memo: '移動中のおやつ・飲み物を準備！',
        ),
        TripScheduleItem(
          id: 'on_d1_2',
          dayNumber: 1,
          timeText: '11:30',
          title: '大阪名物ランチ（たこ焼き・お好み焼き・串カツ）',
          type: TripItemType.food,
          location: '道頓堀・なんばエリア（大阪市中央区）',
          memo: 'くいだおれ散策＆グリコ看板で家族記念撮影📸',
        ),
        TripScheduleItem(
          id: 'on_d1_3',
          dayNumber: 1,
          timeText: '13:30',
          title: '海遊館 または USJ（ユニバーサル・スタジオ・ジャパン）',
          type: TripItemType.sightseeing,
          location: '大阪市港区海岸通 / 此花区',
          memo: '小学生が大興奮！ジンベエザメやアトラクションを満喫',
          url: 'https://www.kaiyukan.com/',
        ),
        TripScheduleItem(
          id: 'on_d1_4',
          dayNumber: 1,
          timeText: '18:30',
          title: '大阪のホテルにチェックイン＆夕食',
          type: TripItemType.hotel,
          location: '大阪市内ホテル',
          memo: 'ゆっくりお風呂に入って明日に備える♨️',
        ),
        // Day 2: 大阪 ➔ 名古屋
        TripScheduleItem(
          id: 'on_d2_1',
          dayNumber: 2,
          timeText: '09:30',
          title: '新大阪駅 ➔ 名古屋駅へ新幹線移動（約50分）',
          type: TripItemType.shinkansen,
          location: 'JR新大阪駅 ➔ JR名古屋駅',
          memo: 'のぞみ号であっという間に名古屋へ！',
        ),
        TripScheduleItem(
          id: 'on_d2_2',
          dayNumber: 2,
          timeText: '11:00',
          title: 'ジブリパーク または レゴランド・ジャパン',
          type: TripItemType.sightseeing,
          location: '愛知県長久手市 / 名古屋市港区',
          memo: '子どもが一番楽しみにしているメインスポット！',
          url: 'https://ghibli-park.jp/',
        ),
        TripScheduleItem(
          id: 'on_d2_3',
          dayNumber: 2,
          timeText: '18:00',
          title: '名古屋めしディナー（ひつまぶし・味噌カツ・手羽先）',
          type: TripItemType.food,
          location: '名古屋駅・栄エリア',
          memo: 'あつた蓬莱軒や矢場とんなど名古屋名物を堪能🍽️',
        ),
        // Day 3: 名古屋観光 ➔ 帰路
        TripScheduleItem(
          id: 'on_d3_1',
          dayNumber: 3,
          timeText: '10:00',
          title: '名古屋城 または 名古屋市科学館・名古屋港水族館',
          type: TripItemType.sightseeing,
          location: '名古屋市中区・港区',
          memo: '金のシャチホコ見学や世界最大級のプラネタリウム！',
        ),
        TripScheduleItem(
          id: 'on_d3_2',
          dayNumber: 3,
          timeText: '13:00',
          title: '名古屋駅でお土産選び＆ランチ（きしめん・ぴよりん）',
          type: TripItemType.shopping,
          location: 'JR名古屋駅 うまいもん通り・高島屋',
          memo: '赤福・ういろう・じゃがりこ手羽先味などをチェック🛍️',
        ),
        TripScheduleItem(
          id: 'on_d3_3',
          dayNumber: 3,
          timeText: '15:30',
          title: '名古屋から帰路へ（新幹線 / 飛行機）',
          type: TripItemType.shinkansen,
          location: '名古屋駅 / 中部国際空港セントレア',
          memo: '気をつけて帰ろう！お疲れさまでした🏠',
        ),
      ],
    );
  }
}

/// お出かけスポット・イベントの1件分のデータ
class OutingSpot {
  final String id;
  final String title;
  final String subtitle;
  final SpotCategory category;
  final List<SpotTag> tags;

  /// 現在地からの車での所要時間（分）
  final int driveMinutes;

  /// 現在地からのおよその距離（km）
  final double distanceKm;

  /// 開催期間や営業時間
  final String scheduleText;

  /// 駐車場の詳細情報（台数・料金・混雑予想など）
  final String parkingInfo;

  /// AIおすすめポイント（3点）
  final List<String> recommendPoints;

  /// AIからのワンポイントアドバイス（混雑回避・おすすめ時間など）
  final String aiTip;

  /// 住所・エリア名
  final String address;

  /// 緯度・経度
  final double latitude;
  final double longitude;

  /// 今週末の天気予報アイコン＆気温（例: '☀️ 晴れ 21℃/12℃'）
  final String weatherText;

  /// 情報の出所（例: '公式Web / Gemini AI検索'）
  final String sourceInfo;

  /// 公式サイトや元記事のWebリンクURL
  final String url;

  /// 夫婦のお気に入り登録状態
  final bool isFavorite;

  /// 夫婦のどちらがピックアップしたか
  final PartnerPick? pickedBy;

  /// 夫婦間のひとことメモ
  final String coupleNote;

  /// 💮「行ったよ！」スタンプ登録状態（案C）
  final bool isVisited;

  /// 💮 行った日付（例: '2026/11/08'）
  final String visitedDate;

  /// 💮 家族の満足度（1〜5、デフォルト5）
  final int visitedRating;

  /// 💮 行ったときの思い出ひとことメモ
  final String visitedMemory;

  /// ⭐ Googleマップの星評価（例: 4.3）
  final double? googleRating;

  /// 💬 Googleマップのクチコミ件数（例: 320）
  final int? googleRatingCount;

  /// 💬 Googleマップの実際のレビュー抜粋リスト
  final List<String> googleReviews;

  const OutingSpot({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.tags,
    required this.driveMinutes,
    required this.distanceKm,
    required this.scheduleText,
    required this.parkingInfo,
    required this.recommendPoints,
    required this.aiTip,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.weatherText = '☀️ 晴れ 21℃/12℃',
    this.sourceInfo = 'Gemini AI ＆ Web最新イベント情報',
    this.url = '',
    this.isFavorite = false,
    this.pickedBy,
    this.coupleNote = '',
    this.isVisited = false,
    this.visitedDate = '',
    this.visitedRating = 5,
    this.visitedMemory = '',
    this.googleRating,
    this.googleRatingCount,
    this.googleReviews = const [],
  });

  /// Googleマップの評価・レビュー情報が存在するかどうか
  bool get hasGoogleReviewData =>
      (googleRating != null && googleRating! > 0) || googleReviews.isNotEmpty;

  /// Googleマップの星評価ラベル（例: '⭐ 4.3 (240件)'）
  String get googleRatingBadgeText {
    if (googleRating == null || googleRating! <= 0) return '';
    final r = googleRating!.toStringAsFixed(1);
    if (googleRatingCount != null && googleRatingCount! > 0) {
      return '⭐ $r ($googleRatingCount件)';
    }
    return '⭐ $r';
  }

  /// 車での所要時間を「約1時間15分」のような文字列に変換する
  String get driveTimeLabel {
    if (driveMinutes < 60) {
      return '車で約$driveMinutes分';
    }
    final hours = driveMinutes ~/ 60;
    final mins = driveMinutes % 60;
    if (mins == 0) {
      return '車で約$hours時間';
    }
    return '車で約$hours時間$mins分';
  }

  /// 雨の日・寒い日でも安心なスポットかどうか（案B：天候連動フィルター用）
  bool get isRainOrColdFriendly {
    if (category == SpotCategory.indoor ||
        category == SpotCategory.onsen ||
        category == SpotCategory.dining) {
      return true;
    }
    if (tags.contains(SpotTag.indoor) || tags.contains(SpotTag.onsen)) {
      return true;
    }
    final combined = '$title $subtitle ${recommendPoints.join(" ")}';
    return RegExp(
            r'(屋内|室内|科学館|水族館|博物館|美術館|児童館|プラネタリウム|温泉|銭湯|スパ|サウナ|ドーム|ホール|ワークショップ|工作)')
        .hasMatch(combined);
  }

  /// 情報ソースの表示用短縮ラベル（例: 'いこーよ', 'せんだい旅日和', '仙台つーしん', 'Walkerplus', 'Googleマップ'）
  String get sourceBadgeLabel {
    if (sourceInfo.contains('いこーよ') ||
        id.startsWith('ikoyo_') ||
        url.contains('iko-yo.net')) {
      return 'いこーよ';
    }
    if (sourceInfo.contains('せんだい旅日和') ||
        url.contains('sendai-tabibiyori.info')) {
      return 'せんだい旅日和';
    }
    if (sourceInfo.contains('仙台つーしん') ||
        url.contains('sendai-tushin.jp')) {
      return '仙台つーしん';
    }
    if (sourceInfo.contains('Walkerplus') ||
        url.contains('walkerplus.com')) {
      return 'Walkerplus';
    }
    if (sourceInfo.contains('Google') || id.startsWith('places_')) {
      return 'Googleマップ';
    }
    if (sourceInfo.contains('公式')) {
      return '公式サイト';
    }
    return sourceInfo.isNotEmpty ? sourceInfo.split(' ').first : 'Web情報';
  }

  /// 情報ソースのアイコン
  String get sourceBadgeIcon {
    if (sourceInfo.contains('いこーよ') ||
        id.startsWith('ikoyo_') ||
        url.contains('iko-yo.net')) {
      return '🧒';
    }
    if (sourceInfo.contains('せんだい旅日和') ||
        url.contains('sendai-tabibiyori.info')) {
      return '🏯';
    }
    if (sourceInfo.contains('仙台つーしん') ||
        url.contains('sendai-tushin.jp')) {
      return '📰';
    }
    if (sourceInfo.contains('Walkerplus') ||
        url.contains('walkerplus.com')) {
      return '🚶';
    }
    if (sourceInfo.contains('Google') || id.startsWith('places_')) {
      return '🗺️';
    }
    return '🌐';
  }

  /// 公式サイトまたは元記事を開くためのURL（未指定の場合はGoogle検索を開く）
  String get officialWebUrl {
    if (url.isNotEmpty && url.startsWith('http')) {
      return url;
    }
    final query = Uri.encodeComponent('$title $address 公式');
    return 'https://www.google.com/search?q=$query';
  }

  /// Googleマップで場所・ルートを検索するためのURLを生成する
  String get googleMapsUrl {
    final query = Uri.encodeComponent('$title $address');
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }

  /// Googleカレンダー（＆TimeTreeのOSカレンダー連携）へ予定追加するURL（案E）
  String toGoogleCalendarUrl(DateTime targetDate) {
    final y = targetDate.year.toString().padLeft(4, '0');
    final m = targetDate.month.toString().padLeft(2, '0');
    final d = targetDate.day.toString().padLeft(2, '0');
    final nextDay = targetDate.add(const Duration(days: 1));
    final ny = nextDay.year.toString().padLeft(4, '0');
    final nm = nextDay.month.toString().padLeft(2, '0');
    final nd = nextDay.day.toString().padLeft(2, '0');

    final details = [
      '${category.icon} $subtitle',
      '🚗 $driveTimeLabel（約${distanceKm.toStringAsFixed(0)}km）',
      '📅 $scheduleText',
      '🅿️ $parkingInfo',
      if (coupleNote.isNotEmpty) '💬 夫婦メモ: $coupleNote',
      if (url.isNotEmpty) '🌐 公式/元記事: $url',
      '🗺️ 地図: $googleMapsUrl',
    ].join('\n');

    return Uri.https('www.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': '🚗 $title',
      'dates': '$y$m$d/$ny$nm$nd',
      'details': details,
      'location': address,
    }).toString();
  }

  /// TimeTreeアプリへ貼り付けやすいコンパクト予定テキスト（案E）
  String toTimeTreeCopyText() {
    return '【$title】\n'
        '📍 場所: $address\n'
        '🚗 移動: $driveTimeLabel\n'
        '📅 日時: $scheduleText\n'
        '🅿️ 駐車場: $parkingInfo\n'
        '${coupleNote.isNotEmpty ? "💬 メモ: $coupleNote\n" : ""}'
        '🌐 ${url.isNotEmpty ? url : googleMapsUrl}';
  }

  /// 夫婦でLINEなどに共有するためのテキストを生成する
  String toShareText() {
    final tagText = tags.map((t) => '#${t.label}').join(' ');
    final points = recommendPoints.map((p) => '・$p').join('\n');
    final notePart = coupleNote.isNotEmpty ? '\n💬 夫婦メモ: $coupleNote\n' : '';
    final visitedPart = isVisited
        ? '\n💮 行ったよ記録（$visitedDate / ★$visitedRating）: $visitedMemory\n'
        : '';
    final urlPart = url.isNotEmpty ? '\n🌐 公式/元記事: $url\n' : '';
    return '【週末お出かけ候補】${category.icon} $title\n'
        '🏷️ 情報元: $sourceBadgeIcon $sourceBadgeLabel\n'
        '📍 開催場所: $address\n'
        '🚗 $driveTimeLabel（約${distanceKm.toStringAsFixed(0)}km）\n'
        '📅 $scheduleText\n'
        '🅿️ $parkingInfo\n'
        '🌤️ 天気予報: $weatherText\n'
        '$tagText$notePart$visitedPart$urlPart\n'
        '✨ おすすめポイント\n$points\n\n'
        '💡 ドライブアドバイス: $aiTip\n\n'
        '🗺️ Googleマップ: $googleMapsUrl';
  }

  /// 状態を一部更新した新しいインスタンスを返す
  OutingSpot copyWith({
    String? id,
    String? title,
    String? subtitle,
    SpotCategory? category,
    List<SpotTag>? tags,
    int? driveMinutes,
    double? distanceKm,
    String? scheduleText,
    String? parkingInfo,
    List<String>? recommendPoints,
    String? aiTip,
    String? address,
    double? latitude,
    double? longitude,
    String? weatherText,
    String? sourceInfo,
    String? url,
    bool? isFavorite,
    PartnerPick? pickedBy,
    String? coupleNote,
    bool? isVisited,
    String? visitedDate,
    int? visitedRating,
    String? visitedMemory,
    double? googleRating,
    int? googleRatingCount,
    List<String>? googleReviews,
  }) {
    return OutingSpot(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      driveMinutes: driveMinutes ?? this.driveMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      scheduleText: scheduleText ?? this.scheduleText,
      parkingInfo: parkingInfo ?? this.parkingInfo,
      recommendPoints: recommendPoints ?? this.recommendPoints,
      aiTip: aiTip ?? this.aiTip,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      weatherText: weatherText ?? this.weatherText,
      sourceInfo: sourceInfo ?? this.sourceInfo,
      url: url ?? this.url,
      isFavorite: isFavorite ?? this.isFavorite,
      pickedBy: pickedBy ?? this.pickedBy,
      coupleNote: coupleNote ?? this.coupleNote,
      isVisited: isVisited ?? this.isVisited,
      visitedDate: visitedDate ?? this.visitedDate,
      visitedRating: visitedRating ?? this.visitedRating,
      visitedMemory: visitedMemory ?? this.visitedMemory,
      googleRating: googleRating ?? this.googleRating,
      googleRatingCount: googleRatingCount ?? this.googleRatingCount,
      googleReviews: googleReviews ?? this.googleReviews,
    );
  }

  /// 夫婦共有（JSON保存・クラウド通信）用のシリアライズ
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'category': category.name,
      'tags': tags.map((t) => t.name).toList(),
      'driveMinutes': driveMinutes,
      'distanceKm': distanceKm,
      'scheduleText': scheduleText,
      'parkingInfo': parkingInfo,
      'recommendPoints': recommendPoints,
      'aiTip': aiTip,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'weatherText': weatherText,
      'sourceInfo': sourceInfo,
      'url': url,
      'isFavorite': isFavorite,
      'pickedBy': pickedBy?.name,
      'coupleNote': coupleNote,
      'isVisited': isVisited,
      'visitedDate': visitedDate,
      'visitedRating': visitedRating,
      'visitedMemory': visitedMemory,
      if (googleRating != null) 'googleRating': googleRating,
      if (googleRatingCount != null) 'googleRatingCount': googleRatingCount,
      if (googleReviews.isNotEmpty) 'googleReviews': googleReviews,
    };
  }

  /// JSONからのデシリアライズ
  factory OutingSpot.fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String? ?? 'event';
    final category = SpotCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => SpotCategory.event,
    );

    final rawTags = json['tags'] as List<dynamic>? ?? [];
    final tags = rawTags
        .map((t) => SpotTag.fromKey(t.toString()))
        .whereType<SpotTag>()
        .toList();

    final rawPoints = json['recommendPoints'] as List<dynamic>? ?? [];
    final points = rawPoints.map((p) => p.toString()).toList();

    final rawReviews = json['googleReviews'] as List<dynamic>? ?? [];
    final reviews = rawReviews.map((r) => r.toString()).toList();

    return OutingSpot(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      category: category,
      tags: tags.isEmpty ? [SpotTag.food, SpotTag.kids] : tags,
      driveMinutes: (json['driveMinutes'] as num?)?.toInt() ?? 60,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 30.0,
      scheduleText: json['scheduleText'] as String? ?? '',
      parkingInfo: json['parkingInfo'] as String? ?? '',
      recommendPoints: points.isEmpty ? ['おすすめのスポット'] : points,
      aiTip: json['aiTip'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 35.6895,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 139.6917,
      weatherText: json['weatherText'] as String? ?? '☀️ 晴れ 21℃/12℃',
      sourceInfo: json['sourceInfo'] as String? ?? '最新イベント情報',
      url: json['url'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
      pickedBy: PartnerPick.fromKey(json['pickedBy'] as String?),
      coupleNote: json['coupleNote'] as String? ?? '',
      isVisited: json['isVisited'] as bool? ?? false,
      visitedDate: json['visitedDate'] as String? ?? '',
      visitedRating: (json['visitedRating'] as num?)?.toInt() ?? 5,
      visitedMemory: json['visitedMemory'] as String? ?? '',
      googleRating: (json['googleRating'] as num?)?.toDouble(),
      googleRatingCount: (json['googleRatingCount'] as num?)?.toInt(),
      googleReviews: reviews,
    );
  }
}
