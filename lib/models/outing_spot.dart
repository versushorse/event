// お出かけスポット・イベントのデータモデル定義

/// スポットの種別（直近のイベント or 大型公園・観光地）
enum SpotCategory {
  event('直近のイベント', '🎪'),
  park('大型公園・自然', '🌳'),
  sightseeing('観光・道の駅', '🚗');

  final String label;
  final String icon;
  const SpotCategory(this.label, this.icon);
}

/// イベント・スポットのタイプ別タグ（食べる系・子供向けなど）
enum SpotTag {
  food('食べる系・グルメ', '🍔'),
  kids('子供が楽しめる', '👨‍👩‍👧‍👦'),
  nature('自然・大型遊具', '🌿'),
  freeParking('無料駐車場あり', '🅿️'),
  indoor('雨でもOK', '☔'),
  freeEntry('入場無料・コスパ◎', '🆓');

  final String label;
  final String icon;
  const SpotTag(this.label, this.icon);
}

/// 誰が「行きたい！」に追加したか（夫婦共有用）
enum PartnerPick {
  husband('夫が気になる', '🙋‍♂️'),
  wife('妻が気になる', '🙋‍♀️'),
  both('2人とも行きたい！', '💑');

  final String label;
  final String icon;
  const PartnerPick(this.label, this.icon);
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

  /// 開催期間や営業時間（例：「今週末 11/7(土)〜11/8(日) 10:00-17:00」）
  final String scheduleText;

  /// 駐車場の詳細情報（車移動で重視するポイント）
  final String parkingInfo;

  /// AIが要約したおすすめポイント（3点程度）
  final List<String> recommendPoints;

  /// AIからのワンポイントアドバイス（混雑回避や持ち物など）
  final String aiTip;

  /// 住所・エリア名
  final String address;

  /// 緯度・経度（マップ表示・Googleマップナビ連携用）
  final double latitude;
  final double longitude;

  /// 夫婦のお気に入り登録状態
  final bool isFavorite;

  /// 夫婦のどちらがピックアップしたか
  final PartnerPick? pickedBy;

  /// 夫婦間のひとことメモ（例：「土曜日の午前中に行きたいね！」）
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
    this.isFavorite = false,
    this.pickedBy,
    this.coupleNote = '',
  });

  /// 車での所要時間を「約1時間15分」のような読みやすい文字列に変換する
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
    return '【週末お出かけ候補】${category.icon} $title\n'
        '📍 開催場所: $address\n'
        '🚗 $driveTimeLabel（約${distanceKm.toStringAsFixed(0)}km）\n'
        '📅 $scheduleText\n'
        '🅿️ $parkingInfo\n'
        '$tagText\n\n'
        '✨ おすすめポイント\n$points\n\n'
        '🗺️ Googleマップ: $googleMapsUrl';
  }

  /// 状態を一部更新した新しいインスタンスを返す
  OutingSpot copyWith({
    bool? isFavorite,
    PartnerPick? pickedBy,
    String? coupleNote,
  }) {
    return OutingSpot(
      id: id,
      title: title,
      subtitle: subtitle,
      category: category,
      tags: tags,
      driveMinutes: driveMinutes,
      distanceKm: distanceKm,
      scheduleText: scheduleText,
      parkingInfo: parkingInfo,
      recommendPoints: recommendPoints,
      aiTip: aiTip,
      address: address,
      latitude: latitude,
      longitude: longitude,
      isFavorite: isFavorite ?? this.isFavorite,
      pickedBy: pickedBy ?? this.pickedBy,
      coupleNote: coupleNote ?? this.coupleNote,
    );
  }
}
