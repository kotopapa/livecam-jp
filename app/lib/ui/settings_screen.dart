import 'package:firebase_messaging/firebase_messaging.dart' as fbm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../data/notification_settings.dart';
import '../util/prefectures.dart';
import 'detail_screen.dart' show disclaimerText;

const _requestFormUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLScRz0Enqfrq-lrbuDVBdFD1jwSyl4GJEZtgTJxAoZfYo-QWJw/viewform';
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
  final _notify = NotificationSettings();
  bool _notifyLoaded = false;

  @override
  void initState() {
    super.initState();
    _notify.load().then((_) {
      _notify.reapply(); // 保存済み購読の自己修復
      if (mounted) setState(() => _notifyLoaded = true);
    });
  }

  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('通知が許可されていません。iOSの設定アプリから通知を許可してください')));
  }

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

  String _warningPrefsSummary() {
    final prefs = _notify.warningPrefs;
    if (prefs.isEmpty) return '全国';
    final names = (prefs.toList()..sort())
        .map((c) => prefectureNames[c] ?? c)
        .toList();
    if (names.length <= 3) return names.join('・');
    return '${names.take(3).join('・')} など${names.length}件';
  }

  // 通知診断の隠し表示(バージョン5回タップで解放)
  bool _diagUnlocked = false;
  int _diagTapCount = 0;

  Future<void> _showNotifyDiagnosis() async {
    final fm = fbm.FirebaseMessaging.instance;
    String perm = '取得失敗', apns = '取得失敗', fcm = '取得失敗';
    try {
      final s = await fm.getNotificationSettings();
      perm = s.authorizationStatus.name;
    } catch (_) {}
    try {
      final a = await fm.getAPNSToken();
      apns = a == null ? '未取得(null)' : '取得済み(${a.substring(0, 8)}…)';
    } catch (e) {
      apns = 'エラー: $e';
    }
    try {
      fcm = await fm.getToken() ?? '未取得(null)';
    } catch (e) {
      fcm = 'エラー: $e';
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('通知診断'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('通知許可: $perm'),
              const SizedBox(height: 6),
              Text('APNsトークン: $apns'),
              const SizedBox(height: 6),
              const Text('FCMトークン:'),
              SelectableText(fcm, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fcm));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('FCMトークンをコピーしました')));
            },
            child: const Text('トークンをコピー'),
          ),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('閉じる')),
        ],
      ),
    );
  }

  Future<void> _pickWarningPrefs() async {
    final selected = Set<String>.from(_notify.warningPrefs);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('通知する地域'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('選択した都道府県の特別警報のみ通知します。何も選ばない場合は全国が対象になります',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final code in NotificationSettings.allPrefCodes)
                    CheckboxListTile(
                      dense: true,
                      title: Text(prefectureNames[code] ?? code),
                      value: selected.contains(code),
                      onChanged: (v) => setDialogState(() =>
                          v! ? selected.add(code) : selected.remove(code)),
                    ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(selected.clear),
              child: const Text('全国に戻す'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('決定'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _notify.setWarningPrefs(result);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(children: [
        const _SectionHeader('災害通知'),
        SwitchListTile(
          secondary: const Icon(Icons.rss_feed),
          title: const Text('震度5弱以上の地震'),
          subtitle: Text(_notifyLoaded && _notify.quakeEnabled
              ? '通知レベル: ${NotificationSettings.quakeLevelLabels[_notify.quakeLevel]}'
              : '大きな地震の発生を通知し、周辺カメラへ誘導します'),
          value: _notifyLoaded && _notify.quakeEnabled,
          onChanged: !_notifyLoaded
              ? null
              : (v) async {
                  final ok = await _notify.setQuakeEnabled(v);
                  if (!ok && mounted) _showPermissionDenied();
                  if (mounted) setState(() {});
                },
        ),
        if (_notifyLoaded && _notify.quakeEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16),
            child: Wrap(spacing: 8, children: [
              for (final level in NotificationSettings.quakeLevels)
                ChoiceChip(
                  label: Text(
                      NotificationSettings.quakeLevelLabels[level] ?? level),
                  selected: _notify.quakeLevel == level,
                  onSelected: (_) async {
                    await _notify.setQuakeLevel(level);
                    if (mounted) setState(() {});
                  },
                ),
            ]),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.warning_amber_outlined),
          title: const Text('特別警報'),
          subtitle: const Text('大雨・暴風・高潮などの特別警報の発表を通知します'),
          value: _notifyLoaded && _notify.warningEnabled,
          onChanged: !_notifyLoaded
              ? null
              : (v) async {
                  final ok = await _notify.setWarningEnabled(v);
                  if (!ok && mounted) _showPermissionDenied();
                  if (mounted) setState(() {});
                },
        ),
        if (_notifyLoaded && _notify.warningEnabled) ...[
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: const Text('通知する地域'),
            subtitle: Text(_warningPrefsSummary()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickWarningPrefs,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('通知するレベル'),
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: const Text('特別警報のみ（レベル5）'),
                    selected: _notify.warningLevel == '5',
                    onSelected: (_) async {
                      await _notify.setWarningLevel('5');
                      if (mounted) setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('危険警報から（レベル4以上）'),
                    selected: _notify.warningLevel == '4',
                    onSelected: (_) async {
                      await _notify.setWarningLevel('4');
                      if (mounted) setState(() {});
                    },
                  ),
                ]),
                const SizedBox(height: 2),
                Text('危険警報は大雨・洪水・高潮・土砂災害の警戒レベル4相当の発表です',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
        if (_diagUnlocked)
          ListTile(
            leading: const Icon(Icons.troubleshoot),
            title: const Text('通知診断'),
            subtitle: const Text('通知が届かないときの状態確認'),
            onTap: _showNotifyDiagnosis,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('※通知は気象庁の発表から5〜15分程度遅れることがあります。緊急地震速報の代わりにはなりません',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        const Divider(),
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
        const _SectionHeader('フィルタの初期設定'),
        SwitchListTile(
          secondary: const Icon(Icons.public),
          title: const Text('世界のカメラを表示'),
          value: app.showWorld,
          onChanged: (v) async {
            app.setShowWorld(v);
            await app.saveFilterDefault('showWorld', v);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.videocam_outlined),
          title: const Text('動画カメラのみ'),
          value: app.videoOnly,
          onChanged: (v) async {
            app.setVideoOnly(v);
            await app.saveFilterDefault('videoOnly', v);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.location_off_outlined),
          title: const Text('位置が曖昧なカメラを非表示'),
          subtitle: const Text('黄色い縁取りのピン（おおよそ/代表点）を隠します'),
          value: app.hideUncertain,
          onChanged: (v) async {
            app.setHideUncertain(v);
            await app.saveFilterDefault('hideUncertain', v);
            if (mounted) setState(() {});
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('ここで設定した内容は次回起動時の初期状態になります（地図の凡例からも一時的に変更できます）',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        const Divider(),
        const _SectionHeader('カメラの追加・削除のご依頼'),
        ListTile(
          leading: const Icon(Icons.contact_support_outlined),
          title: const Text('ご相談・依頼フォーム'),
          subtitle: const Text('カメラの追加要請・掲載削除の依頼はこちらから（ログイン不要）。'
              '設置者・運営者の方からの削除のお申し出には速やかに対応します'),
          onTap: () => _open(_requestFormUrl),
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
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('バージョン'),
          subtitle: const Text(appVersion),
          // 隠し機能: 5回タップで「通知診断」を表示する
          onTap: () {
            if (_diagUnlocked) return;
            _diagTapCount++;
            if (_diagTapCount >= 5) {
              setState(() => _diagUnlocked = true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('通知診断を表示しました（災害通知の項目内）')));
            }
          },
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
