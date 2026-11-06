// アプリ全体の基本動作・東北地域タブ・直近週末計算を確認するテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weekend_outing/main.dart';
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
    expect(find.text('温泉・日帰り銭湯'), findsWidgets);

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
}
