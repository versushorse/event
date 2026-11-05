// アプリ全体の基本動作を確認するウィジェットテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weekend_outing/main.dart';
import 'package:weekend_outing/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('週末お出かけナビのホーム画面とタブが表示されるかテスト',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeekendOutingApp());
    await tester.pumpAndSettle();

    // アプリタイトルと初期スポットが表示されていることを確認
    expect(find.text('週末どこ行く？AIナビ'), findsOneWidget);
    expect(find.text('秋の味覚収穫祭＆キッチンカーマルシェ'), findsOneWidget);

    // 下部ナビゲーションの3つのタブが表示されていることを確認
    expect(find.text('AI提案・検索'), findsOneWidget);
    expect(find.text('ドライブ地図'), findsOneWidget);
    expect(find.text('夫婦の行きたい！'), findsOneWidget);
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
}
