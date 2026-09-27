import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/data/locale_controller.dart';
import 'package:livecam_jp/main.dart';
import 'package:livecam_jp/data/stockpile.dart';
import 'package:livecam_jp/ui/favorites_screen.dart';
import 'package:livecam_jp/ui/home_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_google_maps_platform.dart';

void main() {
  // 地図タブ(MapScreen)が GoogleMap を使うため、ウィジェットテストでは
  // フェイクの platform interface に差し替える（実機の platform view は不要）
  setUp(() {
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
  });

  _legendSheetTests();
  testWidgets('アプリが起動して4タブのシェルが表示される', (tester) async {
    // testWidgets(fake async)内で実I/Oをawaitするとハングするため、
    // ディレクトリは作成せず既存パスを渡す（このテストではキャッシュ未使用）
    final tmp = Directory(Directory.systemTemp.path);
    final app = AppState(
      CameraRepository(
        api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404)),
        ),
        cache: CacheStore(tmp),
      ),
    );
    await tester.pumpWidget(
      LiveCamApp(
        app: app,
        onboardingDone: true,
        localeController: LocaleController(initial: AppLanguage.ja),
      ),
    );
    await tester.pump();
    expect(find.text('地図'), findsOneWidget);
    expect(find.text('一覧'), findsOneWidget);
    expect(find.text('備え'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
    // お気に入りはタブではなく地図下部シートのボタンから開く（既定は畳み状態
    // なので、取っ手をタップして展開してからボタンを押す）
    expect(find.text('お気に入り'), findsNothing);
    await tester.tap(find.byKey(const Key('map_sheet_handle')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('map_panel_favorites')));
    await settle(tester);
    expect(find.byType(FavoritesScreen), findsOneWidget);
  });

  testWidgets('地図に FloatingActionButton が無く、下部パネルとズーム・現在地が出る', (tester) async {
    final tmp = Directory(Directory.systemTemp.path);
    final app = AppState(
      CameraRepository(
        api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404)),
        ),
        cache: CacheStore(tmp),
      ),
    );
    await tester.pumpWidget(
      LiveCamApp(
        app: app,
        onboardingDone: true,
        localeController: LocaleController(initial: AppLanguage.ja),
      ),
    );
    await tester.pump();
    // design/map_ui/PROPOSAL.md 第1段階：右上5個・右下3個の FAB は検索ピル・
    // 下部シート・ズーム/現在地ボタンへ置き換わり、地図上に FloatingActionButton は残らない
    expect(find.byType(FloatingActionButton), findsNothing);
    // 検索ピルは上部固定（シートの折りたたみに関係なく常に見える）
    expect(find.byKey(const Key('map_panel_search')), findsOneWidget);
    expect(find.byKey(const Key('map_zoom_in')), findsOneWidget);
    expect(find.byKey(const Key('map_zoom_out')), findsOneWidget);
    expect(find.byKey(const Key('map_my_location')), findsOneWidget);
    // 下部シートは既定で畳み状態＝ボタン行はまだ見えない
    expect(find.byKey(const Key('map_panel_layers')), findsNothing);
    // 取っ手をタップして展開するとボタン行が出る
    await tester.tap(find.byKey(const Key('map_sheet_handle')));
    await settle(tester);
    expect(find.byKey(const Key('map_panel_layers')), findsOneWidget);
    expect(find.byKey(const Key('map_panel_filter')), findsOneWidget);
    expect(find.byKey(const Key('map_panel_favorites')), findsOneWidget);
  });

  testWidgets('レイヤーONで操作板カードが出て、タイトル行タップで展開される', (tester) async {
    final tmp = Directory(Directory.systemTemp.path);
    final app = AppState(
      CameraRepository(
        api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404)),
        ),
        cache: CacheStore(tmp),
      ),
    );
    await tester.pumpWidget(
      LiveCamApp(
        app: app,
        onboardingDone: true,
        localeController: LocaleController(initial: AppLanguage.ja),
      ),
    );
    await tester.pump();
    // レイヤーOFFのときは操作板カードを出さない
    expect(find.byKey(const Key('map_control_panel_title')), findsNothing);

    // 下部シートは既定で畳み状態なので、取っ手をタップして展開する
    await tester.tap(find.byKey(const Key('map_sheet_handle')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('map_panel_layers')));
    await settle(tester);
    // レイヤー選択シート（グリッド）から台風情報のタイルを選ぶ
    await tester.tap(find.text('台風情報'));
    await settle(tester);

    // レイヤーONで操作板カードが出る（既定は圧縮。凡例はまだ見えない）
    expect(find.byKey(const Key('map_control_panel_title')), findsOneWidget);
    expect(find.text('現在、発表中の台風・熱帯低気圧はありません'), findsNothing);

    // タイトル行タップで展開すると凡例が見える
    await tester.tap(find.byKey(const Key('map_control_panel_title')));
    await settle(tester);
    expect(find.text('現在、発表中の台風・熱帯低気圧はありません'), findsOneWidget);

    // もう一度タップすると圧縮に戻る
    await tester.tap(find.byKey(const Key('map_control_panel_title')));
    await settle(tester);
    expect(find.text('現在、発表中の台風・熱帯低気圧はありません'), findsNothing);
  });

  testWidgets('期限切れの品目があると備えタブにバッジが出る', (tester) async {
    final st = StockpileState()..entryOf('water').expiry = DateTime(2020, 1, 1);
    SharedPreferences.setMockInitialValues({
      StockpileStore.prefsKey: StockpileStore.encode(st),
    });
    final tmp = Directory(Directory.systemTemp.path);
    final app = AppState(
      CameraRepository(
        api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404)),
        ),
        cache: CacheStore(tmp),
      ),
    );
    await tester.pumpWidget(
      LiveCamApp(
        app: app,
        onboardingDone: true,
        localeController: LocaleController(initial: AppLanguage.ja),
      ),
    );
    await tester.pump();
    await tester.pump();
    final badge = tester.widget<Badge>(
      find.ancestor(
        of: find.byIcon(Icons.inventory_2_outlined),
        matching: find.byType(Badge),
      ),
    );
    expect(badge.isLabelVisible, isTrue);
    // 期限切れ1件＋点検日（使い始めているのに開いていない）1件
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('英語ロケールではタブ名が英語になる', (tester) async {
    final tmp = Directory(Directory.systemTemp.path);
    final app = AppState(
      CameraRepository(
        api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404)),
        ),
        cache: CacheStore(tmp),
      ),
    );
    await tester.pumpWidget(
      LiveCamApp(
        app: app,
        onboardingDone: true,
        localeController: LocaleController(initial: AppLanguage.en),
      ),
    );
    await tester.pump();
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Disasters'), findsOneWidget);
    expect(find.text('Prepare'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('地図'), findsNothing);
  });

  testWidgets('7言語すべてでシェルと主要タブが例外なく構築できる', (tester) async {
    for (final lang in AppLanguage.values) {
      final tmp = Directory(Directory.systemTemp.path);
      final app = AppState(
        CameraRepository(
          api: ApiClient(
            client: MockClient((_) async => http.Response('not found', 404)),
          ),
          cache: CacheStore(tmp),
        ),
      );
      await tester.pumpWidget(
        LiveCamApp(
          app: app,
          onboardingDone: true,
          localeController: LocaleController(initial: lang),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${lang.tag} の地図タブ');

      // 一覧・災害速報・備え・設定を順に開く（各言語で描画できること）
      final shell = tester.widget<HomeShell>(find.byType(HomeShell));
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(shell, isNotNull);
      for (var i = 1; i < bar.destinations.length; i++) {
        bar.onDestinationSelected!(i);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${lang.tag} のタブ$i');
      }

      // タブ名は空でなく、改行を含まない（折り返しでレイアウトが壊れないこと）
      for (final d in bar.destinations) {
        final label = (d as NavigationDestination).label;
        expect(label.trim(), isNotEmpty, reason: '${lang.tag} のタブ名が空');
        expect(label, isNot(contains('\n')));
      }
    }
  });

  testWidgets('小さい画面(320x568)でも7言語でオーバーフローしない', (tester) async {
    // ベトナム語・韓国語は文字列が長くなりやすい。iPhone SE 相当の幅で
    // RenderFlex overflow（テストでは例外として現れる）が出ないことを見る
    tester.view.physicalSize = const Size(640, 1136); // 320x568 @2x
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    for (final lang in AppLanguage.values) {
      final tmp = Directory(Directory.systemTemp.path);
      final app = AppState(
        CameraRepository(
          api: ApiClient(
            client: MockClient((_) async => http.Response('not found', 404)),
          ),
          cache: CacheStore(tmp),
        ),
      );
      await tester.pumpWidget(
        LiveCamApp(
          app: app,
          onboardingDone: false, // オンボーディング（言語チップが7つ並ぶ画面）
          localeController: LocaleController(initial: lang),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${lang.tag} のオンボーディングでオーバーフロー',
      );

      await tester.pumpWidget(
        LiveCamApp(
          app: app,
          onboardingDone: true,
          localeController: LocaleController(initial: lang),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${lang.tag} のホーム画面でオーバーフロー',
      );
    }
  });
}

/// 凡例・絞り込みシートは、文言の長い言語（英語など）で内容が画面より高くなっても
/// 外側（バリア）をタップして閉じられること。以前は isScrollControlled のシートが
/// 画面いっぱいまで伸びてバリアが消え、iOS では戻れなくなっていた（2026-09-23 報告）
/// 地図画面は常時アニメーションがあり pumpAndSettle が終わらないので、
/// シートの開閉アニメーション分だけ時間を進める
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void _legendSheetTests() {
  testWidgets('英語・小さい画面でも凡例シートの外側をタップして閉じられる', (tester) async {
    tester.view.physicalSize = const Size(640, 1136); // 320x568 @2x
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final tmp = Directory(Directory.systemTemp.path);
    final app = AppState(
      CameraRepository(
        api: ApiClient(
          client: MockClient((_) async => http.Response('not found', 404)),
        ),
        cache: CacheStore(tmp),
      ),
    );
    await tester.pumpWidget(
      LiveCamApp(
        app: app,
        onboardingDone: true,
        localeController: LocaleController(initial: AppLanguage.en),
      ),
    );
    await tester.pump();
    // 下部シートは既定で畳み状態なので、取っ手をタップして展開する
    await tester.tap(find.byKey(const Key('map_sheet_handle')));
    await settle(tester);
    final filterButton = find.byKey(const Key('map_panel_filter'));
    await tester.tap(filterButton);
    await settle(tester);
    expect(find.text('Filter cameras'), findsOneWidget);
    // シートは画面上部に余白を残す（= バリアが残る）
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.top, greaterThan(20));
    // 上端の余白をタップすると閉じる
    await tester.tapAt(const Offset(160, 5));
    await settle(tester);
    expect(find.text('Filter cameras'), findsNothing);

    // 見出しの閉じるボタンでも閉じる
    await tester.tap(filterButton);
    await settle(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Filter cameras'), findsNothing);
  });
}
