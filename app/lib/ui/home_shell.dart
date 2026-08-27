import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import 'bosai_screen.dart';
import 'favorites_screen.dart';
import 'list_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// 4タブのシェル（地図 / 一覧 / お気に入り / 設定。デザイン案準拠）。
/// 地図以外は次フェーズで実装するプレースホルダ。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app});

  final AppState app;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_maybeShowUpdateDialog);
    widget.app.addListener(_onAppChanged);
    widget.app.navigationRequest.addListener(_onNavigationRequest);
    _onNavigationRequest(); // 起動前に届いていた要求(終了状態からの通知タップ)
  }

  /// 通知タップ等の遷移要求（'bosai/...' なら災害速報タブへ）
  void _onNavigationRequest() {
    final r = widget.app.navigationRequest.value;
    if (r == null || !mounted) return;
    if (r.startsWith('bosai') && _index != 2) setState(() => _index = 2);
    if (r.startsWith('map') && _index != 0) setState(() => _index = 0);
  }

  @override
  void dispose() {
    widget.app.removeListener(_maybeShowUpdateDialog);
    widget.app.removeListener(_onAppChanged);
    widget.app.navigationRequest.removeListener(_onNavigationRequest);
    super.dispose();
  }

  /// 特別警報バッジ等の反映（AppState変更で下部バーを再描画する）
  void _onAppChanged() {
    if (mounted) setState(() {});
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
          title: const Text('アップデートが必要です'),
          content: const Text('このバージョンはサポートが終了しました。\n'
              'App Storeから最新版に更新してください。'),
          actions: [
            if (storeUrl != null)
              FilledButton(
                onPressed: () => launchUrl(Uri.parse(storeUrl),
                    mode: LaunchMode.externalApplication),
                child: const Text('App Storeを開く'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        MapScreen(app: widget.app),
        ListScreen(app: widget.app),
        BosaiScreen(app: widget.app),
        FavoritesScreen(app: widget.app),
        SettingsScreen(app: widget.app),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.map_outlined), label: '地図'),
          const NavigationDestination(icon: Icon(Icons.list), label: '一覧'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.app.specialWarningActive,
              backgroundColor: const Color(0xFFD93025),
              child: const Icon(Icons.crisis_alert),
            ),
            label: '災害速報',
          ),
          const NavigationDestination(
              icon: Icon(Icons.star_border), label: 'お気に入り'),
          const NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: '設定'),
        ],
      ),
    );
  }
}

