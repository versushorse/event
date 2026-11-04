// アプリ全体の基本動作を確認するウィジェットテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:weekend_outing/main.dart';

void main() {
  testWidgets('週末お出かけナビのホーム画面とタブが表示されるかテスト',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeekendOutingApp());

    // アプリタイトルと初期スポットが表示されていることを確認
    expect(find.text('週末どこ行く？AIお出かけナビ'), findsOneWidget);
    expect(find.text('秋の収穫祭＆キッチンカーマルシェ'), findsOneWidget);

    // 下部ナビゲーションの3つのタブが表示されていることを確認
    expect(find.text('AI提案・検索'), findsOneWidget);
    expect(find.text('ドライブ地図'), findsOneWidget);
    expect(find.text('夫婦の行きたい！'), findsOneWidget);
  });
}
