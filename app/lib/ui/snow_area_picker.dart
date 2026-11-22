import 'package:flutter/material.dart';

import '../data/jma_area.dart';
import '../data/notification_settings.dart';
import '../l10n/l10n.dart';

/// 大雪警報・暴風雪警報の通知する地域を選ぶ画面。
///
/// 都道府県ごとに「都道府県全体」か、市区町村（気象庁の市町村等の区分）を選ぶ。
/// 同じ県でも山沿いと平野で発表が分かれるため、市区町村単位で選べるようにしている。
/// 何も選ばなければ全国。OK で選んだ集合（JIS 2桁 or 市町村等コード7桁）を返す。
class SnowAreaPickerScreen extends StatefulWidget {
  const SnowAreaPickerScreen({super.key, required this.initial});

  final Set<String> initial;

  @override
  State<SnowAreaPickerScreen> createState() => _SnowAreaPickerScreenState();
}

class _SnowAreaPickerScreenState extends State<SnowAreaPickerScreen> {
  late final Set<String> _selected = Set<String>.from(widget.initial);
  bool _loading = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    if (JmaAreaNames.isLoaded) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      await JmaAreaNames.load();
    } catch (_) {
      _loadFailed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 県の市町村等コード（コード順）
  List<String> _municipalitiesOf(String pref) =>
      JmaAreaNames.class20Name.keys
          .where((c) => c.length == 7 && c.startsWith(pref))
          .toList()
        ..sort();

  void _toggleWhole(String pref, bool on) {
    setState(() {
      if (on) {
        _selected.removeWhere((a) => a.length == 7 && a.startsWith(pref));
        _selected.add(pref);
      } else {
        _selected.remove(pref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsNotifyArea),
        actions: [
          TextButton(
            key: const ValueKey('snow_area_reset'),
            onPressed: () => setState(_selected.clear),
            child: Text(l10n.settingsNotifyAreaResetAll),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton(
            key: const ValueKey('snow_area_ok'),
            onPressed: () => Navigator.of(context).pop(
              NotificationSettings.normalizeSnowAreas(_selected),
            ),
            child: Text(l10n.commonOk),
          ),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              l10n.settingsSnowAreaHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_loadFailed)
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.commonRetry),
              onTap: _loadAreas,
            ),
          for (final pref in NotificationSettings.allPrefCodes)
            _prefTile(l10n, pref, ja),
        ],
      ),
    );
  }

  Widget _prefTile(AppLocalizations l10n, String pref, bool ja) {
    final whole = _selected.contains(pref);
    final count = _selected
        .where((a) => a.length == 7 && a.startsWith(pref))
        .length;
    return ExpansionTile(
      key: PageStorageKey('snow_area_$pref'),
      title: Text(prefectureNameOf(l10n, pref)),
      subtitle: whole
          ? Text(l10n.settingsSnowAreaWholePref)
          : (count > 0 ? Text('$count') : null),
      children: [
        CheckboxListTile(
          key: ValueKey('snow_area_whole_$pref'),
          dense: true,
          title: Text(l10n.settingsSnowAreaWholePref),
          value: whole,
          onChanged: (v) => _toggleWhole(pref, v!),
        ),
        for (final code in _municipalitiesOf(pref))
          CheckboxListTile(
            key: ValueKey('snow_area_$code'),
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: Text(
              JmaAreaNames.class20DisplayName(code, japanese: ja) ?? code,
            ),
            // 県全体を選んでいる間は、市区町村は選択済みの扱いで固定する
            value: whole || _selected.contains(code),
            onChanged: whole
                ? null
                : (v) => setState(
                    () => v! ? _selected.add(code) : _selected.remove(code),
                  ),
          ),
      ],
    );
  }
}
