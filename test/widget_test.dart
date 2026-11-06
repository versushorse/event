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
    expect(find.text('グルメ・マルシェ'), findsWidgets);
    expect(find.text('地元グルメ・食事処'), findsWidgets);
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
    expect(sorted.last.id, 'hotel_event'); // ホテルイベントは一番下位に回る
  });
}
