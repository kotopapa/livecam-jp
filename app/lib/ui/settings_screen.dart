import 'package:firebase_messaging/firebase_messaging.dart' as fbm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'stockpile_screen.dart';
import 'tip_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:in_app_review/in_app_review.dart';

import '../app_state.dart';
import '../config.dart';
import '../data/locale_controller.dart';
import '../data/notification_settings.dart';
import '../l10n/l10n.dart';
import 'detail_screen.dart' show disclaimerTextOf;
import 'language_switcher.dart';

const _requestFormUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLScRz0Enqfrq-lrbuDVBdFD1jwSyl4GJEZtgTJxAoZfYo-QWJw/viewform';
const _termsUrl = 'https://kotopapa.github.io/livecam-jp/terms.html';
const _privacyUrl = 'https://kotopapa.github.io/livecam-jp/privacy.html';
/// 気象庁「気象情報等に関する多言語辞書」（防災用語の各言語訳の出典）。
/// 公共データ利用規約（第1.0版）＝CC BY 4.0互換。出典表示が必須
const _jmaDictionaryUrl = 'https://www.data.jma.go.jp/developer/multilingual.html';
/// 開発者のXアカウント（Xアプリがあればユニバーサルリンクでアプリが開く）
const _xUrl = 'https://x.com/kotopapa8';

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// 設定タブ（SPEC 9.2⑥）。
/// 置いてはいけない項目: 更新間隔の変更（60秒固定）・プッシュ通知（スコープ外）。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen(
      {super.key, required this.app, required this.localeController});

  final AppState app;
  final LocaleController localeController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showMoreApps = false;
  bool _clearingCache = false;
  final _notify = NotificationSettings();
  bool _notifyLoaded = false;

  @override
  void initState() {
    super.initState();
    _notify.load().then((_) {
      // トークン健全性チェック込みの自己修復（APNs入替え等での不達を復旧）
      unawaited(_notify.healTokenAndReapply());
      if (mounted) setState(() => _notifyLoaded = true);
    });
  }

  String get _storeUrl => app.storeUrl ?? appStoreUrl;

  /// 友達を招待: App Store ページのQRコードとURL（コピー・共有）
  void _showInvite() {
    final url = _storeUrl;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settingsInvite),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.l10n.settingsInviteDialogBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: QrImageView(data: url, size: 200),
          ),
          const SizedBox(height: 12),
          SelectableText(url,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        ]),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: Text(context.l10n.commonCopy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                  content: Text(this.context.l10n.settingsLinkCopied)));
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(context.l10n.commonShare),
            onPressed: () => SharePlus.instance.share(ShareParams(
                text: '${this.context.l10n.settingsInviteShareText}\n$url')),
          ),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonClose)),
        ],
      ),
    );
  }

  /// アプリを評価: App Store のレビュー画面へ（開けない場合はストアページ）
  Future<void> _openReview() async {
    try {
      final review = InAppReview.instance;
      await review.openStoreListing(appStoreId: appStoreId);
    } catch (_) {
      await launchUrl(Uri.parse('$_storeUrl?action=write-review'),
          mode: LaunchMode.externalApplication);
    }
  }

  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsNotifyDenied)));
  }

  AppState get app => widget.app;

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    try {
      await app.clearCacheAndReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.settingsClearCacheDone)));
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  String _warningPrefsSummary(AppLocalizations l10n) {
    final prefs = _notify.warningPrefs;
    if (prefs.isEmpty) return l10n.settingsNotifyAreaAll;
    final names =
        (prefs.toList()..sort()).map((c) => prefectureNameOf(l10n, c)).toList();
    final sep =
        Localizations.localeOf(context).languageCode == 'ja' ? '・' : ', ';
    if (names.length <= 3) return names.join(sep);
    return l10n.settingsNotifyAreaSummary(names.take(3).join(sep), names.length);
  }

  // 通知診断の隠し表示(バージョン5回タップで解放)
  bool _diagUnlocked = false;
  int _diagTapCount = 0;

  /// MetricKitがDocuments/mx_diagnosticsへ保存した診断JSONを表示する。
  /// クラッシュ翌回の起動時に配送されるため、再現直後に開くと記録がある
  Future<void> _showCrashDiagnosis() async {
    final l10n = context.l10n;
    String summary = '';
    String latestJson = '';
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/mx_diagnostics');
      if (!dir.existsSync()) {
        summary = l10n.settingsCrashDiagNoneHint;
      } else {
        final files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
        if (files.isEmpty) {
          summary = l10n.settingsCrashDiagNone;
        } else {
          summary = l10n.settingsDiagCrashRecords(
              files.length, files.first.uri.pathSegments.last);
          latestJson = files.first.readAsStringSync();
          // 概要(クラッシュ種別)を先頭に抽出
          try {
            final d = jsonDecode(latestJson) as Map<String, dynamic>;
            final kinds = <String>[
              if (d['crashDiagnostics'] != null) l10n.settingsDiagKindCrash,
              if (d['hangDiagnostics'] != null) l10n.settingsDiagKindHang,
              if (d['cpuExceptionDiagnostics'] != null) l10n.settingsDiagKindCpu,
              if (d['diskWriteExceptionDiagnostics'] != null)
                l10n.settingsDiagKindDiskWrite,
            ];
            if (kinds.isNotEmpty) {
              final sep = l10n.localeName.startsWith('ja') ? '・' : ', ';
              summary += '\n${l10n.settingsDiagCrashKinds(kinds.join(sep))}';
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      summary = l10n.settingsDiagReadError('$e');
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsCrashDiag),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary),
              if (latestJson.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  latestJson.length > 1500
                      ? '${latestJson.substring(0, 1500)}…'
                      : latestJson,
                  style: const TextStyle(fontSize: 9),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (latestJson.isNotEmpty)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: latestJson));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.settingsJsonCopied)));
              },
              child: Text(l10n.settingsCopyFullText),
            ),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  Future<void> _showNotifyDiagnosis() async {
    final l10n = context.l10n;
    final fm = fbm.FirebaseMessaging.instance;
    final failed = l10n.settingsDiagFetchFailed;
    String perm = failed, apns = failed, fcm = failed;
    try {
      final s = await fm.getNotificationSettings();
      perm = s.authorizationStatus.name;
    } catch (_) {}
    try {
      final a = await fm.getAPNSToken();
      apns = a == null
          ? l10n.settingsDiagNotAcquired
          : l10n.settingsDiagAcquired(a.substring(0, 8));
    } catch (e) {
      apns = l10n.settingsDiagError('$e');
    }
    try {
      fcm = await fm.getToken() ?? l10n.settingsDiagNotAcquired;
    } catch (e) {
      fcm = l10n.settingsDiagError('$e');
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsNotifyDiag),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.settingsNotifyPermission(perm)),
              const SizedBox(height: 6),
              Text(l10n.settingsNotifyApns(apns)),
              const SizedBox(height: 6),
              Text(l10n.settingsNotifyFcm),
              SelectableText(fcm, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fcm));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsTokenCopied)));
            },
            child: Text(l10n.settingsCopyToken),
          ),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  Future<void> _pickWarningPrefs() async {
    final l10n = context.l10n;
    final selected = Set<String>.from(_notify.warningPrefs);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.settingsNotifyArea),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(l10n.settingsNotifyAreaHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final code in NotificationSettings.allPrefCodes)
                    CheckboxListTile(
                      dense: true,
                      title: Text(prefectureNameOf(l10n, code)),
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
              child: Text(l10n.settingsNotifyAreaResetAll),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(l10n.commonOk),
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(children: [
        _SupportCard(onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TipScreen()))),
        // 防災の備え（備蓄チェックリスト）。1.4.0 で追加
        ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(l10n.stockpileEntryTitle),
          subtitle: Text(l10n.stockpileEntrySubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StockpileScreen(app: widget.app))),
        ),
        // 言語切替（1.4.0。いつでも切り替えられる。選択は端末に保存される）
        LanguageSettingTile(controller: widget.localeController),
        const Divider(),
        _SectionHeader(l10n.settingsSectionNotify),
        SwitchListTile(
          secondary: const Icon(Icons.rss_feed),
          title: Text(l10n.settingsQuakeTitle),
          subtitle: Text(_notifyLoaded && _notify.quakeEnabled
              ? l10n.settingsQuakeSubtitleOn(
                  quakeLevelLabelOf(l10n, _notify.quakeLevel))
              : l10n.settingsQuakeSubtitleOff),
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
                  label: Text(quakeLevelLabelOf(l10n, level)),
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
          title: Text(l10n.settingsWarningTitle),
          subtitle: Text(l10n.settingsWarningSubtitle),
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
            title: Text(l10n.settingsNotifyArea),
            subtitle: Text(_warningPrefsSummary(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickWarningPrefs,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settingsNotifyLevel),
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: Text(l10n.settingsNotifyLevelSpecialOnly),
                    selected: _notify.warningLevel == '5',
                    onSelected: (_) async {
                      await _notify.setWarningLevel('5');
                      if (mounted) setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: Text(l10n.settingsNotifyLevelDangerUp),
                    selected: _notify.warningLevel == '4',
                    onSelected: (_) async {
                      await _notify.setWarningLevel('4');
                      if (mounted) setState(() {});
                    },
                  ),
                ]),
                const SizedBox(height: 2),
                Text(l10n.settingsNotifyLevelNote,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
        if (_diagUnlocked) ...[
          ListTile(
            leading: const Icon(Icons.troubleshoot),
            title: Text(l10n.settingsNotifyDiag),
            subtitle: Text(l10n.settingsNotifyDiagSubtitle),
            onTap: _showNotifyDiagnosis,
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l10n.settingsCrashDiag),
            subtitle: Text(l10n.settingsCrashDiagSubtitle),
            onTap: _showCrashDiagnosis,
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.settingsNotifyDelayNote,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        const Divider(),
        _SectionHeader(l10n.settingsSectionData),
        SwitchListTile(
          secondary: const Icon(Icons.wifi),
          title: Text(l10n.settingsWifiOnly),
          subtitle: Text(l10n.settingsWifiOnlySubtitle),
          value: app.wifiOnly,
          onChanged: (v) async {
            await app.setWifiOnly(v);
            if (mounted) setState(() {});
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(l10n.settingsClearCache),
          subtitle: Text(l10n.settingsClearCacheSubtitle),
          trailing: _clearingCache
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _clearingCache ? null : _clearCache,
        ),
        const Divider(),
        _SectionHeader(l10n.settingsSectionFilterDefaults),
        SwitchListTile(
          secondary: const Icon(Icons.public),
          title: Text(l10n.settingsShowWorld),
          value: app.showWorld,
          onChanged: (v) async {
            app.setShowWorld(v);
            await app.saveFilterDefault('showWorld', v);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.videocam_outlined),
          title: Text(l10n.settingsVideoOnly),
          value: app.videoOnly,
          onChanged: (v) async {
            app.setVideoOnly(v);
            await app.saveFilterDefault('videoOnly', v);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.location_off_outlined),
          title: Text(l10n.settingsHideUncertain),
          subtitle: Text(l10n.settingsHideUncertainSubtitle),
          value: app.hideUncertain,
          onChanged: (v) async {
            app.setHideUncertain(v);
            await app.saveFilterDefault('hideUncertain', v);
            if (mounted) setState(() {});
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.settingsFilterDefaultsNote,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        const Divider(),
        _SectionHeader(l10n.settingsSectionRequest),
        ListTile(
          leading: const Icon(Icons.contact_support_outlined),
          title: Text(l10n.settingsRequestForm),
          subtitle: Text(l10n.settingsRequestFormSubtitle),
          onTap: () => _open(_requestFormUrl),
        ),
        const Divider(),
        _SectionHeader(l10n.settingsSectionLicense),
        ListTile(
          leading: const Icon(Icons.source_outlined),
          title: Text(l10n.settingsAttributionList),
          subtitle: Text(l10n.settingsAttributionListSubtitle),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _AttributionScreen(app: app))),
        ),
        // 気象庁「気象情報等に関する多言語辞書」の出典表示（公共データ利用規約）
        ListTile(
          leading: const Icon(Icons.translate),
          title: Text(l10n.settingsJmaDictionary),
          subtitle: Text(l10n.settingsJmaDictionaryNote),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _open(_jmaDictionaryUrl),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: Text(l10n.settingsTerms),
          onTap: () => _open(_termsUrl),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(l10n.settingsPrivacy),
          onTap: () => _open(_privacyUrl),
        ),
        // 規約類の本文は日本語のみ。日本語を正文とする旨をアプリ内に明示する
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.settingsLegalJapaneseOnly,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        const Divider(),
        _SectionHeader(l10n.settingsSectionAbout),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.settingsVersion),
          subtitle: const Text(appVersion),
          // 隠し機能: 5回タップで「通知診断」を表示する
          onTap: () {
            if (_diagUnlocked) return;
            _diagTapCount++;
            if (_diagTapCount >= 5) {
              setState(() => _diagUnlocked = true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l10n.settingsNotifyDiagUnlocked)));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.qr_code_2),
          title: Text(l10n.settingsInvite),
          subtitle: Text(l10n.settingsInviteSubtitle),
          onTap: _showInvite,
        ),
        ListTile(
          leading: const Icon(Icons.star_rate_outlined),
          title: Text(l10n.settingsReview),
          subtitle: Text(l10n.settingsReviewSubtitle),
          onTap: _openReview,
        ),
        ListTile(
          leading: const Icon(Icons.alternate_email),
          title: Text(l10n.settingsFollowX),
          subtitle: Text(l10n.settingsFollowXSubtitle),
          onTap: () => _open(_xUrl),
        ),
        if (widget.app.repository.manifest?.apps.isNotEmpty ?? false) ...[
          const Divider(),
          _SectionHeader(l10n.settingsOtherApps),
          for (final a in widget.app.repository.manifest!.apps)
            if (!a.collapsed || _showMoreApps)
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: a.iconUrl != null
                    ? Image.network(a.iconUrl!, width: 44, height: 44, cacheWidth: 132,
                        errorBuilder: (_, _, _) => const Icon(Icons.apps, size: 44))
                    : const Icon(Icons.apps, size: 44),
              ),
              title: Text(a.name),
              subtitle: a.tagline.isEmpty ? null : Text(a.tagline),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _open(a.storeUrl),
            ),
          if (!_showMoreApps &&
              widget.app.repository.manifest!.apps.any((a) => a.collapsed))
            TextButton.icon(
              onPressed: () => setState(() => _showMoreApps = true),
              icon: const Icon(Icons.expand_more),
              label: Text(l10n.settingsShowMoreApps),
            ),
        ],
        const Divider(),
        _SectionHeader(l10n.settingsSectionDisclaimer),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(disclaimerTextOf(l10n),
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            if (widget.localeController.language != AppLanguage.ja) ...[
              const SizedBox(height: 4),
              Text(l10n.legalJapaneseAuthoritative,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ]),
        ),
        // OSSライセンス（表示義務あり。控えめなテキストリンクとして最下部に置く）
        Center(
          child: TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: appVersion,
            ),
            child: Text(l10n.settingsOssLicenses,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

/// 設定画面の最上部に置く「開発者を応援する」カード（目立つ配色・ボタン付き）
class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7A5C46);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Material(
        color: const Color(0xFFFFF6EC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.volunteer_activism, color: accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.l10n.settingsSupportTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accent)),
                  const SizedBox(height: 2),
                  Text(context.l10n.settingsSupportBody,
                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ]),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                onPressed: onTap,
                child: Text(context.l10n.settingsSupportButton,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ),
      ),
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
/// 各行から提供元のサイトへ移動できる（利用規約URL → 掲載元ページの順で
/// 台帳から導出。YouTube配信はアイコンで区別）
class _AttributionScreen extends StatelessWidget {
  const _AttributionScreen({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    // attribution 文字列ごとに台数と、代表URL(最頻)を集計して多い順に並べる
    final counts = <String, int>{};
    final terms = <String, Map<String, int>>{};
    final pages = <String, Map<String, int>>{};
    for (final c in app.repository.cameras) {
      final key = c.attribution.isNotEmpty ? c.attribution : c.operator;
      counts[key] = (counts[key] ?? 0) + 1;
      final t = c.termsUrl;
      if (t != null && t.isNotEmpty) {
        (terms[key] ??= {})[t] = ((terms[key]![t]) ?? 0) + 1;
      }
      final pg = c.sourcePageUrl;
      if (pg != null && pg.isNotEmpty) {
        (pages[key] ??= {})[pg] = ((pages[key]![pg]) ?? 0) + 1;
      }
    }
    String? mostCommon(Map<String, int>? m) {
      if (m == null || m.isEmpty) return null;
      return (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.attributionScreenTitle)),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final key = entries[i].key;
          final url = mostCommon(terms[key]) ?? mostCommon(pages[key]);
          final isYoutube = url != null && url.contains('youtube.com');
          return ListTile(
            dense: true,
            title: Text(key),
            subtitle: url == null
                ? null
                : Text(
                    isYoutube
                        ? context.l10n.attributionOpenYoutube
                        : context.l10n.attributionOpenSite,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(context.l10n.commonCameraCount(entries[i].value),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (url != null) ...[
                const SizedBox(width: 8),
                Icon(isYoutube ? Icons.play_circle_outline : Icons.open_in_new,
                    size: 18, color: Colors.grey[600]),
              ],
            ]),
            onTap: url == null ? null : () => _open(url),
          );
        },
      ),
    );
  }
}
