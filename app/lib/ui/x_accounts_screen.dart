import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/x_accounts.dart';
import '../data/analytics.dart';
import '../l10n/l10n.dart';

/// 自治体・国の機関の災害情報 X アカウント一覧。
///
/// - ポストは表示せず、タップで外部ブラウザの X プロフィールを開くだけ
/// - 運営主体の種別（自治体公式／国の機関 など）を必ず併記する（誤認防止）
/// - [pref] を渡すと、その都道府県に関係するものを先頭の「この地域」に出す
class XAccountsScreen extends StatefulWidget {
  const XAccountsScreen({super.key, this.pref, this.repository});

  final String? pref;
  final XAccountsRepository? repository;

  @override
  State<XAccountsScreen> createState() => _XAccountsScreenState();
}

class _XAccountsScreenState extends State<XAccountsScreen> {
  XAccounts? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Analytics.screen('x_accounts');
    _load();
  }

  Future<void> _load() async {
    var repo = widget.repository;
    if (repo == null) {
      try {
        repo = XAccountsRepository(cacheDir: await getTemporaryDirectory());
      } catch (_) {
        repo = XAccountsRepository();
      }
    }
    final d = await repo.load();
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.xAccountsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.xAccountsEmpty,
                        textAlign: TextAlign.center),
                  ),
                )
              : _list(context, _data!),
    );
  }

  Widget _list(BuildContext context, XAccounts data) {
    final l10n = context.l10n;
    final pref = widget.pref;
    final area = pref == null ? const <XAccount>[] : data.forPrefecture(pref);
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Text(l10n.xAccountsIntro,
            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ),
      if (area.isNotEmpty) ...[
        _header(context, l10n.xAccountsSectionArea),
        for (final a in area) _tile(context, a),
        _header(context, l10n.xAccountsSectionAll),
      ],
      if (data.prefectures.isNotEmpty)
        _header(context, l10n.xAccountsSectionPrefectures),
      for (final a in data.prefectures) _tile(context, a),
      if (data.nationalOffices.isNotEmpty)
        _header(context, l10n.xAccountsSectionNational),
      for (final a in data.nationalOffices) _tile(context, a),
      if (data.municipalities.isNotEmpty)
        _header(context, l10n.xAccountsSectionMunicipalities),
      for (final a in data.municipalities) _tile(context, a),
      const SizedBox(height: 24),
    ];
    return ListView(children: rows);
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );

  Widget _tile(BuildContext context, XAccount a) {
    final l10n = context.l10n;
    final typeLabel = xAccountTypeLabelOf(l10n, a.type);
    final sub = <String>[
      '@${a.handle}',
      typeLabel,
      if (a.operator.isNotEmpty) a.operator,
      if (!a.dedicated) l10n.xAccountsNotDedicated,
    ];
    return ListTile(
      dense: true,
      leading: const Icon(Icons.campaign_outlined),
      title: Text(a.displayName),
      subtitle: Text(sub.join(' · '),
          style: const TextStyle(fontSize: 11), maxLines: 3),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: () => launchUrl(a.url, mode: LaunchMode.externalApplication),
    );
  }
}
