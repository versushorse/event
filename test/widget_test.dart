// アプリ全体の基本動作・東北地域タブ・直近週末計算を確認するテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weekend_outing/main.dart';
import 'package:weekend_outing/models/outing_spot.dart';
import 'package:weekend_outing/services/gemini_service.dart';
import 'package:weekend_outing/services/location_service.dart';
import 'package:weekend_outing/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('週末お出かけナビのホーム画面・東北6県タブ・ジャンルボタンが表示されるかテスト',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeekendOutingApp());
    await tester.pumpAndSettle();

    // アプリタイトルと東北地域タブ・ジャンルボタンが表示されていることを確認
    expect(find.text('週末どこ行く？AIナビ'), findsOneWidget);
    expect(find.text('宮城県'), findsWidgets);
    expect(find.text('山形県'), findsWidgets);
    expect(find.text('岩手県'), findsWidgets);
    expect(find.text('期間限定イベント'), findsWidgets);
    expect(find.text('地元グルメ・食事処'), findsWidgets);
    expect(find.text('観光地・名所'), findsWidgets);
    expect(find.text('温泉・日帰り銭湯'), findsWidgets);

    // 夫婦の好みAIナビが表示されていることを確認
    expect(find.text('夫婦の好みAIナビ'), findsOneWidget);

    // 下部ナビゲーションの3つのタブが表示されていることを確認
    expect(find.text('AI提案・検索'), findsOneWidget);
    expect(find.text('ドライブ地図'), findsOneWidget);
    expect(find.text('夫婦の行きたい！'), findsOneWidget);
  });

  test('直近の週末（11/9月曜日に調べたら11/14土〜11/15日）の自動算出テスト', () {
    final mondayNov9 = DateTime(2026, 11, 9);
    final weekendRange = GeminiOutingService.getUpcomingWeekendRange(mondayNov9);

    expect(weekendRange.start, DateTime(2026, 11, 14));
    expect(weekendRange.end, DateTime(2026, 11, 15));
    expect(
      GeminiOutingService.formatDateRange(weekendRange),
      '11/14(土)〜11/15(日)',
    );
  });

  test('距離計算と車での所要時間推定の単体テスト', () {
    // 渋谷から横浜（約30km）の計算テスト
    const startLat = 35.658034;
    const startLng = 139.701636;
    const endLat = 35.443708;
    const endLng = 139.638026;

    final dist = LocationService.calculateDistanceKm(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    expect(dist, greaterThan(20.0));
    expect(dist, lessThan(35.0));

    final driveMin = LocationService.estimateDriveMinutes(dist);
    expect(driveMin, greaterThan(25));
    expect(driveMin, lessThan(60));
  });

  test('夫婦共有用テキスト生成と合言葉保存のテスト', () async {
    const room = 'tanaka-family';
    await CoupleSyncService.saveRoomCode(room);
    final loadedRoom = await CoupleSyncService.getRoomCode();
    expect(loadedRoom, room);

    // スマホ使用者（夫 or 妻）の設定・取得テスト（ハート押下時の自動識別用）
    await CoupleSyncService.saveMyRole(PartnerPick.wife);
    final loadedRole = await CoupleSyncService.getMyRole();
    expect(loadedRole, PartnerPick.wife);

    final spots = GeminiOutingService.getInitialSpots().take(2).toList();
    final text = CoupleSyncService.exportFavoritesShareText(spots, room);
    expect(text.contains('夫婦の行きたいスポット一覧'), isTrue);
    expect(text.contains(room), isTrue);
  });

  test('ファミリー・お祭り・公園優先スコアリングソートのテスト', () {
    final hotelSpot = OutingSpot(
      id: 'hotel_event',
      title: '仙台ロイヤルパークホテル ガーデンシネマナイト',
      subtitle: '芝生の上で映画を楽しむナイトタイムイベント',
      category: SpotCategory.event,
      tags: const [SpotTag.kids],
      driveMinutes: 10, // 距離的には一番近い
      distanceKm: 5.0,
      scheduleText: '11/8開催',
      parkingInfo: '駐車場あり',
      recommendPoints: const ['夜間のガーデン映画'],
      aiTip: '',
      address: '仙台市泉区寺岡',
      latitude: 38.34,
      longitude: 140.83,
      weatherText: '晴れ',
      sourceInfo: 'テスト',
      url: '',
    );

    final dinoSpot = OutingSpot(
      id: 'dino_event',
      title: '大恐竜パークみちのく公園',
      subtitle: '小学生・子どもが大興奮！恐竜アドベンチャーフェス',
      category: SpotCategory.event,
      tags: const [SpotTag.kids, SpotTag.nature],
      driveMinutes: 40, // 距離的には遠い
      distanceKm: 30.0,
      scheduleText: '11/7〜11/8開催',
      parkingInfo: '無料駐車場あり',
      recommendPoints: const ['恐竜体験フェスティバル'],
      aiTip: '',
      address: '宮城県柴田郡川崎町',
      latitude: 38.21,
      longitude: 140.67,
      weatherText: '晴れ',
      sourceInfo: 'テスト',
      url: '',
    );

    final pikachuSpot = OutingSpot(
      id: 'pikachu_event',
      title: 'ピカチュウがやってくる！ポケモンキッズフェスタ',
      subtitle: '小学生親子で参加できるクイズ＆スタンプラリー',
      category: SpotCategory.event,
      tags: const [SpotTag.kids],
      driveMinutes: 25,
      distanceKm: 15.0,
      scheduleText: '11/8開催',
      parkingInfo: '無料駐車場あり',
      recommendPoints: const ['ポケモンふれあい体験'],
      aiTip: '',
      address: '利府町',
      latitude: 38.33,
      longitude: 140.97,
      weatherText: '晴れ',
      sourceInfo: 'テスト',
      url: '',
    );

    final list = [hotelSpot, dinoSpot, pikachuSpot];
    // GeminiOutingService内部の比較ロジックをテスト
    // ピカチュウや恐竜が上位になり、ホテルシネマナイトが最下位になることを確認
    final sorted = GeminiOutingService.sortSpotsForFamily(list);

    expect(sorted.first.title.contains('ピカチュウ') || sorted.first.title.contains('恐竜'), isTrue);
    expect(sorted.last.id, 'hotel_event');
  });

  test('東北6県のいこーよ都道府県コード（JISコード）設定テスト', () {
    expect(TohokuRegion.miyagi.ikoyoPrefectureId, 4);
    expect(TohokuRegion.yamagata.ikoyoPrefectureId, 6);
    expect(TohokuRegion.iwate.ikoyoPrefectureId, 3);
    expect(TohokuRegion.fukushima.ikoyoPrefectureId, 7);
    expect(TohokuRegion.akita.ikoyoPrefectureId, 5);
    expect(TohokuRegion.aomori.ikoyoPrefectureId, 2);
  });

  test('子どもとお出かけ情報「いこーよ」のイベントが最優先で上位に来るテスト', () {
    final generalEvent = OutingSpot(
      id: 'general_event',
      title: '秋の蔵王観光キャンペーン',
      subtitle: '地域の観光物産展',
      category: SpotCategory.event,
      tags: const [SpotTag.food],
      driveMinutes: 20,
      distanceKm: 12.0,
      scheduleText: '11/7〜11/8開催',
      parkingInfo: '駐車場あり',
      recommendPoints: const ['物産フェア'],
      aiTip: '',
      address: '蔵王町',
      latitude: 38.1,
      longitude: 140.5,
      weatherText: '晴れ',
      sourceInfo: 'Walkerplusイベント情報',
      url: '',
    );

    final ikoyoEvent = OutingSpot(
      id: 'ikoyo_4_nature_kids',
      title: 'むかっち博士の自然観察会「冬越しの動物探し」',
      subtitle: '小学生・親子で楽しむ生き物ふれあい＆自然体験',
      category: SpotCategory.event,
      tags: const [SpotTag.kids, SpotTag.nature],
      driveMinutes: 30, // 距離的には一般イベントより少し遠い
      distanceKm: 20.0,
      scheduleText: '11/7開催',
      parkingInfo: '無料駐車場あり',
      recommendPoints: const ['子ども向け自然体験'],
      aiTip: '',
      address: '仙台市若林区荒井',
      latitude: 38.25,
      longitude: 140.95,
      weatherText: '晴れ',
      sourceInfo: '子どもとお出かけ情報 いこーよ',
      url: '',
    );

    final sorted = GeminiOutingService.sortSpotsForFamily([generalEvent, ikoyoEvent]);
    // 距離が遠くても「いこーよ」のファミリー向けイベントが第1位になることを確認
    expect(sorted.first.id, 'ikoyo_4_nature_kids');
    expect(sorted.first.sourceInfo, contains('いこーよ'));
    expect(sorted.first.sourceBadgeLabel, 'いこーよ');
    expect(sorted.first.sourceBadgeIcon, '🧒');
    expect(generalEvent.sourceBadgeLabel, 'Walkerplus');
    expect(generalEvent.sourceBadgeIcon, '🚶');

    final osakaNagoyaPlan = TripPlan.createOsakaNagoyaStarter();
    expect(osakaNagoyaPlan.title, contains('大阪・名古屋'));
    expect(osakaNagoyaPlan.totalDays, 3);
    expect(osakaNagoyaPlan.items.any((i) => i.title.contains('ジブリパーク')), isTrue);
    expect(osakaNagoyaPlan.toShareText(), contains('Day 1'));

    final spot = GeminiOutingService.getInitialSpots().first;
    final visitedSpot = spot.copyWith(
      isVisited: true,
      visitedDate: '2026/11/08',
      visitedRating: 5,
      visitedMemory: '子どもが大喜び！',
    );
    final restored = OutingSpot.fromJson(visitedSpot.toJson());
    expect(restored.isVisited, isTrue);
    expect(restored.visitedDate, '2026/11/08');
    expect(restored.visitedRating, 5);
    expect(restored.visitedMemory, '子どもが大喜び！');
    expect(restored.toTimeTreeCopyText(), contains(spot.title));
    expect(
      restored.toGoogleCalendarUrl(DateTime(2026, 11, 14)),
      contains('calendar/render'),
    );
  });

  test('旧gourmetカテゴリが食事処（dining）へ自動集約フォールバックされるテスト', () {
    final oldGourmetJson = {
      'id': 'gourmet_old_1',
      'title': 'あ・ら・伊達な道の駅',
      'subtitle': '全国人気ナンバーワンの道の駅',
      'category': 'gourmet',
      'tags': ['food', 'kids'],
      'driveMinutes': 50,
      'distanceKm': 45.0,
      'scheduleText': '9:00〜18:00',
      'parkingInfo': '無料駐車場300台',
      'recommendPoints': ['ロイズソフトクリーム'],
      'aiTip': '',
      'address': '大崎市岩出山',
      'latitude': 38.65,
      'longitude': 140.85,
    };

    final spot = OutingSpot.fromJson(oldGourmetJson);
    expect(spot.category, SpotCategory.dining);
  });
}
