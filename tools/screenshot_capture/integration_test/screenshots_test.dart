// ストア用スクリーンショットの自動撮影。
// `--dart-define=SCREENSHOT_MODE=true` でデバッグリボンと広告を消して起動し、
// 主要画面を順に開いて binding.takeScreenshot() で保存する（保存先は driver 側）。
//
// 実データ（台帳・気象庁・カメラ画像）を通信で取るため、読み込み待ちは
// 固定秒数で行う。撮り逃しは画像を見て秒数を調整する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/data/locale_controller.dart';
import 'package:livecam_jp/l10n/gen/app_localizations.dart';
import 'package:livecam_jp/main.dart' as app;
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/detail_screen.dart';
import 'package:livecam_jp/ui/home_shell.dart';
import 'package:livecam_jp/ui/onboarding_screen.dart';
import 'package:livecam_jp/ui/ranking_screen.dart';
import 'package:livecam_jp/ui/situation_card.dart';
import 'package:livecam_jp/ui/x_accounts_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final l10n = lookupAppLocalizations(const Locale('ja'));
  var surfaceConverted = false;
  // 撮る画面の組: all / maps / details / tabs（--dart-define=CAPTURE_SET=...）
  const captureSet = String.fromEnvironment('CAPTURE_SET', defaultValue: 'all');
  bool want(String set) => captureSet == 'all' || captureSet == set;

  /// 実時間で待つ（地図タイル・画像は通信なので pumpAndSettle は使わない）
  Future<void> wait(WidgetTester tester, double seconds) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> snap(WidgetTester tester, String name) async {
    final file = name;
    // 起動画面の除去がテスト環境では効かないことがある（25枚全部が起動画面になった）
    FlutterNativeSplash.remove();
    // Android は最初の撮影前に一度だけ描画先を画像へ切り替える
    if (Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await wait(tester, 1);
    }
    await tester.pump();
    await binding.takeScreenshot(file);
  }

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    double after = 1.5,
  }) async {
    final f = find.text(text).first;
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f, warnIfMissed: false);
    await wait(tester, after);
  }

  Future<void> tapTooltip(
    WidgetTester tester,
    String tip, {
    double after = 1.5,
  }) async {
    await tester.tap(find.byTooltip(tip).first, warnIfMissed: false);
    await wait(tester, after);
  }

  Future<void> pickLayer(
    WidgetTester tester,
    String title, {
    double after = 6,
  }) async {
    await tapTooltip(tester, l10n.mapLayersTooltip);
    await tapText(tester, title, after: after);
  }

  void moveMap(WidgetTester tester, LatLng center, double zoom) {
    final ctx = tester.element(find.byType(TileLayer).first);
    MapController.of(ctx).move(center, zoom);
  }

  // 詳細画面を重ねると HomeShell はオフステージになるので skipOffstage: false
  Future<void> pop(WidgetTester tester) async {
    final nav = Navigator.of(
      tester.element(find.byType(HomeShell, skipOffstage: false)),
    );
    if (nav.canPop()) nav.pop();
    await wait(tester, 1);
  }

  Future<void> push(
    WidgetTester tester,
    Widget page, {
    double after = 5,
  }) async {
    final nav = Navigator.of(
      tester.element(find.byType(HomeShell, skipOffstage: false)),
    );
    await nav
        .push(MaterialPageRoute<void>(builder: (_) => page))
        .timeout(Duration(seconds: after.ceil()), onTimeout: () {});
  }

  testWidgets('store screenshots', (tester) async {
    // オンボーディング済み・日本語で起動する
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefsKey, true);
    await prefs.setString(LocaleController.prefsKey, AppLanguage.ja.tag);
    // 初回説明ダイアログ（避難場所・防災拠点）は出さない
    await prefs.setBool('shelter_notice_seen', true);
    await prefs.setBool('facility_notice_seen', true);
    await app.main();
    await wait(tester, 3);
    FlutterNativeSplash.remove();
    expect(find.byType(HomeShell), findsOneWidget);
    final shell = tester.widget<HomeShell>(find.byType(HomeShell));
    final state = shell.app;
    // 台帳の読み込み待ち（最大 90 秒）
    for (var i = 0; i < 90 && state.repository.cameras.isEmpty; i++) {
      await wait(tester, 1);
    }
    // 起動直後は控え（古い台帳）のことがあるので、件数が落ち着くまで待つ
    var count = state.repository.cameras.length;
    for (var i = 0; i < 40; i++) {
      await wait(tester, 2);
      final n = state.repository.cameras.length;
      if (n == count && i >= 5) break;
      count = n;
    }
    final cams = state.repository.cameras;
    debugPrint('cameras loaded: ${cams.length}');

    Camera? byId(String id) => cams.where((c) => c.id == id).firstOrNull;
    Camera? byName(String part, {required bool live}) => cams
        .where(
          (c) =>
              c.name.contains(part) &&
              c.hasLocation &&
              (live
                  ? c.feed.type == FeedType.youtubeChannel ||
                        c.feed.type == FeedType.youtubeVideo
                  : c.feed.type == FeedType.stillImage),
        )
        .firstOrNull ??
        cams.where((c) => c.name.contains(part) && c.hasLocation).firstOrNull;

    // 1) 地図: 全国 → 首都圏（クラスタ）→ 東京都心（個別ピン）→ 富士山周辺
    if (want('maps')) {
      await snap(tester, 'map_japan');
      moveMap(tester, const LatLng(35.66, 139.72), 10.5);
      await wait(tester, 5);
      await snap(tester, 'map_tokyo');
      moveMap(tester, const LatLng(35.700, 139.800), 13.2);
      await wait(tester, 6);
      await snap(tester, 'map_tokyo_pins');
      // 「いま起きていること」カードを閉じた素の地図も撮る
      final close = find.descendant(
          of: find.byType(SituationCard), matching: find.byIcon(Icons.close));
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first, warnIfMissed: false);
        await wait(tester, 2);
        await snap(tester, 'map_tokyo_pins_clean');
        moveMap(tester, const LatLng(35.66, 139.72), 10.5);
        await wait(tester, 5);
        await snap(tester, 'map_tokyo_clean');
      }
      moveMap(tester, const LatLng(35.50, 138.76), 12.3);
      await wait(tester, 6);
      await snap(tester, 'map_fuji');
    }

    // 2) カメラ詳細: 富士山（河口湖）・河川・ライブ配信
    for (final (id, name, label) in <(String?, String, String)>[
      if (want('details')) ...[
        (
          'curated-still-fujikawaguchiko-kawaguchiko',
          '河口湖',
          'detail_kawaguchiko',
        ),
        (
          'curated-still-mountain-fuefuki-shindo-toge-fuji',
          '富士山',
          'detail_fuji',
        ),
        ('curated-still-muni-oshino-omiyabashi', '富士山', 'detail_oshino'),
        ('curated-still-lcdb-7b436918', '荒川', 'detail_river'),
        ('curated-still-kanagawa-coast-chigasaki', '海岸', 'detail_coast'),
        ('curated-shibuya-ann', '渋谷', 'detail_live'),
        (null, '東京タワー', 'detail_tokyotower'),
        (null, '桜島', 'detail_sakurajima'),
      ],
    ]) {
      final cam =
          (id != null ? byId(id) : null) ??
          byName(name, live: label == 'detail_live' || label == 'detail_tokyotower');
      if (cam == null) {
        debugPrint('camera not found: $id $name');
        continue;
      }
      debugPrint('detail: ${cam.id} ${cam.name}');
      await push(tester, DetailScreen(camera: cam, app: state), after: 8);
      await snap(tester, label);
      await pop(tester);
    }

    // 3) 地図レイヤー
    if (want('maps')) {
      moveMap(tester, const LatLng(36.5, 137.5), 5.3);
      await wait(tester, 2);
      await pickLayer(tester, l10n.mapLayerRainRadarTitle, after: 8);
      await snap(tester, 'layer_rain_radar');
      moveMap(tester, const LatLng(35.7, 139.6), 8.5);
      await wait(tester, 6);
      await snap(tester, 'layer_rain_radar_kanto');
      await pickLayer(tester, l10n.riskLandTitle, after: 8);
      await snap(tester, 'layer_kikikuru_land');
      await pickLayer(tester, l10n.riskInundTitle, after: 8);
      await snap(tester, 'layer_kikikuru_inund');
      await pickLayer(tester, l10n.mapLayerTyphoonTitle, after: 8);
      await snap(tester, 'layer_typhoon');
      moveMap(tester, const LatLng(35.68, 139.77), 14.5);
      await wait(tester, 2);
      await pickLayer(tester, l10n.mapLayerShelterTitle, after: 8);
      await snap(tester, 'layer_shelters');
      moveMap(tester, const LatLng(35.75, 139.78), 12.5);
      await wait(tester, 2);
      await pickLayer(tester, l10n.hazardFloodTitle, after: 8);
      await snap(tester, 'layer_hazard_flood');
      await pickLayer(tester, l10n.mapLayerNone, after: 2);
    }

    // 4) 一覧・ランキング
    if (!want('tabs')) return;
    await tapText(tester, l10n.tabList, after: 4);
    await snap(tester, 'list');
    await push(tester, RankingScreen(app: state), after: 6);
    await snap(tester, 'ranking');
    await pop(tester);

    // 5) 災害速報（地震・警報・暑さ）
    await tapText(tester, l10n.tabBosai, after: 6);
    await snap(tester, 'bosai_quake');
    await tapText(tester, l10n.bosaiTabWarning, after: 4);
    await snap(tester, 'bosai_warning');
    await tapText(tester, l10n.bosaiTabHeat, after: 4);
    await snap(tester, 'bosai_heat');
    await push(tester, const XAccountsScreen(), after: 5);
    await snap(tester, 'x_accounts');
    await pop(tester);

    // 6) 備え
    await tapText(tester, l10n.tabStockpile, after: 4);
    await snap(tester, 'stockpile');

    // 7) 設定
    await tapText(tester, l10n.tabSettings, after: 3);
    await snap(tester, 'settings');

    await tapText(tester, l10n.tabMap, after: 2);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
