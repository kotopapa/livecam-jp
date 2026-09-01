import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
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
    // お気に入りはタブではなく地図右上の★から開く
    expect(find.text('お気に入り'), findsNothing);
    await tester.tap(find.byTooltip('お気に入り'));
    await tester.pumpAndSettle();
    expect(find.byType(FavoritesScreen), findsOneWidget);
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
