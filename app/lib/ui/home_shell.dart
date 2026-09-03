import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ad_banner.dart';

import '../app_state.dart';
import '../data/locale_controller.dart';
import '../data/stockpile.dart';
import '../l10n/l10n.dart';
import '../util/jst.dart';
import 'bosai_screen.dart';
import 'detail_screen.dart';
import 'favorites_screen.dart';
import 'list_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'stockpile_screen.dart';

/// 5タブのシェル（地図 / 一覧 / 災害速報 / 備え / 設定）。
///
/// お気に入りはタブではなく地図画面右上の★ボタンから開く（1.4.1）。
/// 「防災の備え」は設定の中では見つけにくかったためタブに昇格した。
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.app,
    required this.localeController,
  });

  final AppState app;
  final LocaleController localeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// 災害速報タブが表示中か（BosaiScreen の自動更新に使う）
  final ValueNotifier<bool> _bosaiVisible = ValueNotifier<bool>(false);

  /// 備えタブが表示中か（開いた日の記録＝点検日バッジの解除に使う）
  final ValueNotifier<bool> _stockpileVisible = ValueNotifier<bool>(false);

  /// 備えタブのバッジ（期限1か月以内・期限切れの品目数＋点検日超過）
  int _stockpileAlertCount = 0;

  void _setIndex(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _bosaiVisible.value = i == 2;
    _stockpileVisible.value = i == 3;
  }

  Future<void> _refreshStockpileAlerts() async {
    try {
      final s = await StockpileStore.load();
      final count = computeStockpileAlerts(s, jstNow()).count;
      if (mounted && count != _stockpileAlertCount) {
        setState(() => _stockpileAlertCount = count);
      }
    } catch (_) {
      // 保存領域が使えない環境（テスト等）ではバッジ無し
    }
  }

  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_maybeShowUpdateDialog);
    widget.app.addListener(_onAppChanged);
    widget.app.navigationRequest.addListener(_onNavigationRequest);
    StockpileStore.changes.addListener(_refreshStockpileAlerts);
    _refreshStockpileAlerts();
    _onNavigationRequest(); // 起動前に届いていた要求(終了状態からの通知タップ)
  }

  /// 通知タップ等の遷移要求（'bosai/...' なら災害速報タブへ、
  /// `camera/<id>` ならウィジェットからのカメラ詳細）
  void _onNavigationRequest() {
    final r = widget.app.navigationRequest.value;
    if (r == null || !mounted) return;
    if (r.startsWith('bosai')) _setIndex(2);
    if (r.startsWith('map')) _setIndex(0);
    if (r.startsWith('camera/')) _openCamera(r.substring('camera/'.length));
  }

  /// 台帳がまだ読めていない起動直後はIDを保持し、読めた時点で開く
  String? _pendingCameraId;

  void _openCamera(String id) {
    _pendingCameraId = id;
    _tryOpenPendingCamera();
  }

  void _tryOpenPendingCamera() {
    final id = _pendingCameraId;
    if (id == null || !mounted) return;
    final cameras = widget.app.repository.cameras;
    if (cameras.isEmpty) return; // init() の loadCached/refresh 後に再試行
    _pendingCameraId = null;
    final camera = cameras.where((c) => c.id == id).firstOrNull;
    _setIndex(0);
    // 起動直後(initState経由)はビルド中のためフレーム後に遷移する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 台帳から消えたカメラ: お気に入り一覧へ
      final page = camera == null
          ? FavoritesScreen(app: widget.app)
          : DetailScreen(camera: camera, app: widget.app);
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    });
  }

  @override
  void dispose() {
    widget.app.removeListener(_maybeShowUpdateDialog);
    widget.app.removeListener(_onAppChanged);
    widget.app.navigationRequest.removeListener(_onNavigationRequest);
    StockpileStore.changes.removeListener(_refreshStockpileAlerts);
    _bosaiVisible.dispose();
    _stockpileVisible.dispose();
    super.dispose();
  }

  /// 特別警報バッジ等の反映（AppState変更で下部バーを再描画する）
  void _onAppChanged() {
    if (mounted) setState(() {});
    if (_pendingCameraId != null) _tryOpenPendingCamera();
  }

  /// 強制アップデート（HANDOFF 2-8-1）。manifest の min_app_version を
  /// 下回ったら閉じられないダイアログでストアへ誘導する
  void _maybeShowUpdateDialog() {
    if (!widget.app.updateRequired || _updateDialogShown || !mounted) return;
    _updateDialogShown = true;
    final storeUrl = widget.app.storeUrl;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(context.l10n.updateRequiredTitle),
          content: Text(context.l10n.updateRequiredBody),
          actions: [
            if (storeUrl != null)
              FilledButton(
                onPressed: () => launchUrl(
                  Uri.parse(storeUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(context.l10n.updateOpenStore),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 下部固定バナー: 一覧・災害速報・備えタブ（地図と設定には出さない）。
    // 備えは以前リスト途中に 300×250 の大型広告を置いていたが、
    // 邪魔だという指摘で他タブと同じ下部固定の横長バナーに統一した
    // 利用者が特別警報の発表エリアに居る間は防災アプリとして広告を出さない
    // （エリア外の人には出す。AppState.viewerInSpecialWarningArea）
    final showAd =
        (_index == 1 || _index == 2 || _index == 3) &&
        !widget.app.viewerInSpecialWarningArea;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                MapScreen(app: widget.app),
                ListScreen(app: widget.app),
                BosaiScreen(app: widget.app, visible: _bosaiVisible),
                StockpileScreen(app: widget.app, visible: _stockpileVisible),
                SettingsScreen(
                  app: widget.app,
                  localeController: widget.localeController,
                ),
              ],
            ),
          ),
          // 表示するタブのときだけ広告を組み立てる。
          // 以前は Offstage で保持していたが、画面外のまま表示回数だけが積み上がり
          // 「見られていない在庫」と評価されて eCPM が9円まで落ちていた
          // （2026-09-01 実測。日本のバナーの相場は100〜300円）
          if (showAd) const AnchoredAdBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _setIndex,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            label: context.l10n.tabMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list),
            label: context.l10n.tabList,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.app.specialWarningActive,
              backgroundColor: const Color(0xFFD93025),
              child: const Icon(Icons.crisis_alert),
            ),
            label: context.l10n.tabBosai,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _stockpileAlertCount > 0,
              label: Text('$_stockpileAlertCount'),
              backgroundColor: const Color(0xFFE8710A),
              child: const Icon(Icons.inventory_2_outlined),
            ),
            label: context.l10n.tabStockpile,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: context.l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
