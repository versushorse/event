// お出かけスポット・イベントのデータモデル定義

/// スポットの種別（直近のイベント or 大型公園・自然 or 観光・道の駅）
enum SpotCategory {
  event('直近のイベント', '🎪'),
  park('大型公園・自然', '🌳'),
  sightseeing('観光・道の駅', '🚗');

  final String label;
  final String icon;
  const SpotCategory(this.label, this.icon);
}

/// イベント・スポットのタイプ別タグ（食べる系・子供年齢別・駐車場など）
enum SpotTag {
  food('食べる系・グルメ', '🍔'),
  baby('0〜2歳向け（授乳室/平坦）', '👶'),
  toddler('3〜5歳（幼児遊具）', '👦'),
  kids('6歳〜（大型アスレチック）', '🏃'),
  nature('自然・広大な芝生', '🌿'),
  freeParking('無料駐車場あり', '🅿️'),
  indoor('雨でもOK（屋内）', '☔'),
  freeEntry('入場無料・コスパ◎', '🆓');

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

  /// 夫婦のお気に入り登録状態
  final bool isFavorite;

  /// 夫婦のどちらがピックアップしたか
  final PartnerPick? pickedBy;

  /// 夫婦間のひとことメモ
  final String coupleNote;

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
    this.isFavorite = false,
    this.pickedBy,
    this.coupleNote = '',
  });

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

  /// Googleマップで場所・ルートを検索するためのURLを生成する
  String get googleMapsUrl {
    final query = Uri.encodeComponent('$title $address');
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }

  /// 夫婦でLINEなどに共有するためのテキストを生成する
  String toShareText() {
    final tagText = tags.map((t) => '#${t.label}').join(' ');
    final points = recommendPoints.map((p) => '・$p').join('\n');
    final notePart = coupleNote.isNotEmpty ? '\n💬 夫婦メモ: $coupleNote\n' : '';
    return '【週末お出かけ候補】${category.icon} $title\n'
        '📍 開催場所: $address\n'
        '🚗 $driveTimeLabel（約${distanceKm.toStringAsFixed(0)}km）\n'
        '📅 $scheduleText\n'
        '🅿️ $parkingInfo\n'
        '🌤️ 天気予報: $weatherText\n'
        '$tagText$notePart\n\n'
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
    bool? isFavorite,
    PartnerPick? pickedBy,
    String? coupleNote,
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
      isFavorite: isFavorite ?? this.isFavorite,
      pickedBy: pickedBy ?? this.pickedBy,
      coupleNote: coupleNote ?? this.coupleNote,
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
      'isFavorite': isFavorite,
      'pickedBy': pickedBy?.name,
      'coupleNote': coupleNote,
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
      isFavorite: json['isFavorite'] as bool? ?? false,
      pickedBy: PartnerPick.fromKey(json['pickedBy'] as String?),
      coupleNote: json['coupleNote'] as String? ?? '',
    );
  }
}
