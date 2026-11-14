// アプリ全体の基本動作・東北地域タブ・直近週末計算を確認するテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weekend_outing/main.dart';
import 'package:weekend_outing/models/outing_spot.dart';
import 'package:weekend_outing/services/gemini_service.dart';
import 'package:weekend_outing/services/location_service.dart';
import 'package:weekend_outing/services/monetization_service.dart';
import 'package:weekend_outing/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('週末お出かけナビ商用版のホーム画面・東北6県タブ・7大ジャンル・PR広告枠が表示されるかテスト',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WeekendOutingApp());
    await tester.pumpAndSettle();

    // アプリタイトルと東北地域タブ・Google Places主軸の常設ジャンルが表示されていることを確認
    expect(find.text('週末どこ行く？AIナビ'), findsOneWidget);
    expect(find.text('宮城県'), findsWidgets);
    expect(find.text('山形県'), findsWidgets);
    expect(find.text('岩手県'), findsWidgets);
    expect(find.text('地元グルメ・食事処'), findsWidgets);
    expect(find.text('観光地・名所'), findsWidgets);
    expect(find.text('大きな公園（小学生）'), findsWidgets);
    expect(find.text('温泉・日帰り銭湯'), findsWidgets);

    // 期間限定イベントのスクレイピングを終了し、Google検索ショートカットへ移行していることを確認
    expect(find.text('期間限定イベント'), findsNothing);
    expect(find.text('Googleで宮城県のイベント検索'), findsOneWidget);

    // 下部広告バナー枠の非表示リンク（プレミアム案内）が表示されていることを確認
    expect(find.text('広告非表示'), findsOneWidget);

    // 下部ナビゲーションのタブが表示されていることを確認
    expect(find.text('AI提案・検索'), findsOneWidget);
    expect(find.text('ドライブ地図'), findsOneWidget);
    expect(find.text('行きたい！リスト'), findsOneWidget);
    expect(find.text('旅のしおり'), findsOneWidget);
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
    final sorted = GeminiOutingService.sortSpotsForFamily(list);

    expect(
      sorted.first.title.contains('ピカチュウ') || sorted.first.title.contains('恐竜'),
      isTrue,
    );
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

  test('旅のしおり・カレンダー連携・JSON復元のテスト', () {
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
    expect(restored.googleSearchUrl, contains('google.com/search'));
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

  test('商用版：無料検索クォータ消費・リワード回復(+3)・プレミアム無制限テスト', () async {
    expect(await MonetizationService.isPremium(), isFalse);
    expect(
      await MonetizationService.getRemainingSearches(),
      MonetizationService.freeDailySearchLimit,
    );

    // 5回まで検索成功、6回目は上限到達でfalse
    for (int i = 0; i < MonetizationService.freeDailySearchLimit; i++) {
      expect(await MonetizationService.tryConsumeSearch(), isTrue);
    }
    expect(await MonetizationService.getRemainingSearches(), 0);
    expect(await MonetizationService.tryConsumeSearch(), isFalse);

    // リワード動画視聴で+3回回復
    final recovered = await MonetizationService.grantRewardSearchBonus();
    expect(recovered, MonetizationService.rewardRecoveryAmount);
    expect(await MonetizationService.tryConsumeSearch(), isTrue);
    expect(
      await MonetizationService.getRemainingSearches(),
      MonetizationService.rewardRecoveryAmount - 1,
    );

    // プレミアム切替後はクォータを消費せず無制限でtrue
    await MonetizationService.setPremium(true);
    expect(await MonetizationService.isPremium(), isTrue);
    expect(await MonetizationService.tryConsumeSearch(), isTrue);
    expect(
      await MonetizationService.getRemainingSearches(),
      MonetizationService.rewardRecoveryAmount - 1,
    );
  });

  test('商用版：常設7ジャンル定義＆Google検索・アフィリエイトURL生成テスト', () {
    expect(SpotCategory.commercialCategories.length, 7);
    expect(
      SpotCategory.commercialCategories.contains(SpotCategory.event),
      isFalse,
    );
    expect(
      SpotCategory.commercialCategories.contains(SpotCategory.gourmet),
      isFalse,
    );

    expect(
      AffiliateLinkBuilder.buildGoogleEventSearchUrl(areaName: '宮城県'),
      contains('https://www.google.com/search?q='),
    );
    expect(
      AffiliateLinkBuilder.buildJalanUrl('松島 温泉'),
      contains('jalan.net'),
    );
    expect(
      AffiliateLinkBuilder.buildAsoviewUrl('仙台 水族館'),
      contains('asoview.com'),
    );
    expect(
      AffiliateLinkBuilder.buildRakutenTravelUrl('秋保温泉'),
      contains('travel.rakuten.co.jp'),
    );
    expect(
      AffiliateLinkBuilder.buildAmazonGoodsUrl('レジャーシート'),
      contains('amazon.co.jp'),
    );
  });
}
