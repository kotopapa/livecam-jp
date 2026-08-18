import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import 'detail_screen.dart' show disclaimerText;

const _repoIssues = 'https://github.com/kotopapa/livecam-jp/issues/new';
const _termsUrl = 'https://kotopapa.github.io/livecam-jp/terms.html';
const _privacyUrl = 'https://kotopapa.github.io/livecam-jp/privacy.html';

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// 設定タブ（SPEC 9.2⑥）。
/// 置いてはいけない項目: 更新間隔の変更（60秒固定）・プッシュ通知（スコープ外）。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.app});

  final AppState app;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _clearingCache = false;

  AppState get app => widget.app;

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    try {
      await app.clearCacheAndReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('キャッシュを削除して再取得しました')));
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(children: [
        const _SectionHeader('データ取得'),
        SwitchListTile(
          secondary: const Icon(Icons.wifi),
          title: const Text('Wi-Fi接続時のみ画像を取得'),
          subtitle: const Text('モバイル通信量を抑えます（地図とカメラ一覧は表示されます）'),
          value: app.wifiOnly,
          onChanged: (v) async {
            await app.setWifiOnly(v);
            if (mounted) setState(() {});
          },
        ),
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
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('キャッシュを削除'),
          subtitle: const Text('カメラ一覧などの保存データを消去して再取得します'),
          trailing: _clearingCache
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _clearingCache ? null : _clearCache,
        ),
        const Divider(),
        const _SectionHeader('カメラの追加・削除のご依頼'),
        ListTile(
          leading: const Icon(Icons.add_a_photo_outlined),
          title: const Text('ライブカメラの追加を依頼'),
          subtitle: const Text('掲載してほしいカメラのURLをお寄せください（GitHubアカウントが必要です）'),
          onTap: () => _open('$_repoIssues?template=add-camera.yml'),
        ),
        ListTile(
          leading: const Icon(Icons.remove_circle_outline),
          title: const Text('掲載の削除を依頼'),
          subtitle: const Text('設置者・運営者の方からのお申し出に速やかに対応します（GitHubアカウントが必要です）'),
          onTap: () => _open('$_repoIssues?template=remove-camera.yml'),
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
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('利用規約'),
          onTap: () => _open(_termsUrl),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('プライバシーポリシー'),
          onTap: () => _open(_privacyUrl),
        ),
        const Divider(),
        const _SectionHeader('このアプリについて'),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('バージョン'),
          subtitle: Text(appVersion),
        ),
        const Divider(),
        const _SectionHeader('免責'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(disclaimerText,
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ),
        // OSSライセンス（表示義務あり。控えめなテキストリンクとして最下部に置く）
        Center(
          child: TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: '全国ライブカメラ地図',
              applicationVersion: appVersion,
            ),
            child: Text('OSSライセンス',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        ),
        const SizedBox(height: 16),
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
