import 'package:flutter/material.dart';

import '../app_state.dart';
import 'map_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        MapScreen(app: widget.app),
        const _PlaceholderTab(label: '一覧（実装予定）'),
        const _PlaceholderTab(label: 'お気に入り（実装予定）'),
        const _PlaceholderTab(label: '設定（実装予定）'),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: '地図'),
          NavigationDestination(icon: Icon(Icons.list), label: '一覧'),
          NavigationDestination(icon: Icon(Icons.star_border), label: 'お気に入り'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '設定'),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}
