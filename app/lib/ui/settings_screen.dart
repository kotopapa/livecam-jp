import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import 'detail_screen.dart' show disclaimerText;

/// 設定タブ（SPEC 9.2⑥）。
/// 置いてはいけない項目: 更新間隔の変更（60秒固定）・プッシュ通知（スコープ外）。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(children: [
        const _SectionHeader('データ取得'),
        const ListTile(
          leading: Icon(Icons.timer_outlined),
          title: Text('手動更新の間隔'),
          subtitle: Text('60秒固定です（カメラ提供元への配慮のため変更できません）'),
        ),
        const ListTile(
          leading: Icon(Icons.monitor_heart_outlined),
          title: Text('カメラの死活確認'),
          subtitle: Text('約30分ごとに自動確認し、映らないカメラは地図から自動で非表示になります'),
        ),
        const Divider(),
        const _SectionHeader('出典・ライセンス'),
        ListTile(
          leading: const Icon(Icons.source_outlined),
          title: const Text('出典・ライセンス一覧'),
          subtitle: const Text('カメラ映像の提供元の一覧'),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _AttributionScreen(app: app))),
        ),
        const ListTile(
          leading: Icon(Icons.map_outlined),
          title: Text('地図タイル'),
          subtitle: Text('国土地理院「地理院タイル（淡色地図）」を使用しています'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('OSSライセンス'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: '全国ライブカメラ地図',
            applicationVersion: appVersion,
          ),
        ),
        const Divider(),
        const _SectionHeader('このアプリについて'),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('バージョン'),
          subtitle: Text(appVersion),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('データ配信・開発リポジトリ'),
          subtitle: const Text('github.com/kotopapa/livecam-jp'),
          onTap: () => launchUrl(
              Uri.parse('https://github.com/kotopapa/livecam-jp'),
              mode: LaunchMode.externalApplication),
        ),
        const Divider(),
        const _SectionHeader('免責'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Text(disclaimerText,
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}

/// 出典・ライセンス一覧（SPEC 9.5: 設定画面に一括の出典一覧を置く）。
class _AttributionScreen extends StatelessWidget {
  const _AttributionScreen({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    // attribution 文字列ごとに台数を集計して多い順に並べる
    final counts = <String, int>{};
    for (final c in app.repository.cameras) {
      final key = c.attribution.isNotEmpty ? c.attribution : c.operator;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: const Text('出典・ライセンス一覧')),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => ListTile(
          dense: true,
          title: Text(entries[i].key),
          trailing: Text('${entries[i].value}台',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
      ),
    );
  }
}
