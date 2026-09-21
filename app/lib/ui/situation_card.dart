import 'package:flutter/material.dart';

import '../data/jma_flood.dart';
import '../data/situation.dart';
import '../l10n/l10n.dart';
import '../util/jst.dart';
import '../util/prefectures.dart';

/// 地図の上に重ねる「いま起きていること」カード（1.5.0）。
/// 特別警報・危険警報・台風・洪水予報・震度4以上の地震があるときだけ出す。
/// 行をタップすると該当画面へ、×で閉じる（同じ内容のあいだは再表示しない）
class SituationCard extends StatelessWidget {
  const SituationCard({
    super.key,
    required this.situation,
    required this.onClose,
    required this.onOpenWarning,
    required this.onOpenQuake,
    required this.onOpenTyphoon,
    required this.onOpenUnderpass,
    this.collapsed = false,
    this.onToggle,
  });

  final Situation situation;
  final VoidCallback onClose;

  /// 折りたたみ（見出し行だけ表示）。地図を広く使いたいときのため（2026-09-21 要望）
  final bool collapsed;
  final VoidCallback? onToggle;
  final VoidCallback onOpenWarning;
  final VoidCallback onOpenQuake;
  /// 台風行のタップ（TC番号を渡す。地図はその台風だけを表示する）
  final ValueChanged<String> onOpenTyphoon;

  /// 地下道の冠水行のタップ（地図の冠水状況レイヤーを開く）
  final VoidCallback onOpenUnderpass;

  static const _maxRows = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <_Row>[];
    final s = situation;
    if (s.warnings.special.isNotEmpty) {
      rows.add(_Row(
        icon: Icons.warning,
        color: const Color(0xFF9C27B0),
        text: l10n.situationSpecial(_prefs(l10n, s.warnings.special)),
        onTap: onOpenWarning,
      ));
    }
    if (s.warnings.danger.isNotEmpty) {
      rows.add(_Row(
        icon: Icons.warning_amber,
        color: const Color(0xFFAA00AA),
        text: l10n.situationDanger(_prefs(l10n, s.warnings.danger)),
        onTap: onOpenWarning,
      ));
    }
    for (final t in s.typhoons) {
      final a = t.analysis;
      final intensity = typhoonIntensityOf(l10n, a.intensity);
      final name = intensity.isEmpty
          ? typhoonNameOf(l10n, t)
          : '${typhoonNameOf(l10n, t)}（$intensity）';
      rows.add(_Row(
        icon: Icons.cyclone,
        color: const Color(0xFFD32F2F),
        text: l10n.situationTyphoon(name, a.location.isEmpty ? '-' : a.location),
        onTap: () => onOpenTyphoon(t.id),
      ));
    }
    if (s.floods.isNotEmpty) {
      final f = s.floods.first;
      final kind = floodKindNameOf(l10n, f.level);
      final text = s.floods.length == 1
          ? l10n.situationFlood(f.riverName, kind)
          : '${l10n.situationFlood(f.riverName, kind)} ${l10n.situationMore(s.floods.length - 1)}';
      rows.add(_Row(
        icon: Icons.water,
        color: f.level == FloodLevel.caution ? const Color(0xFFB8A800) : f.level.color,
        text: text,
        onTap: onOpenWarning,
      ));
    }
    for (final src in s.underpass) {
      final alerts = src.alerts;
      if (alerts.isEmpty) continue;
      final worst = alerts.map((p) => p.level).reduce((a, b) => a > b ? a : b);
      final names = alerts.take(3).map((p) => p.name).join('・') +
          (alerts.length > 3 ? ' ${l10n.situationMore(alerts.length - 3)}' : '');
      rows.add(_Row(
        icon: Icons.water_damage,
        color: worst >= 2 ? const Color(0xFFD32F2F) : const Color(0xFFF9A825),
        text: l10n.situationUnderpass(src.operator.isNotEmpty ? src.operator : src.name, names,
            worst >= 2 ? l10n.underpassLevel2 : l10n.underpassLevel1),
        onTap: onOpenUnderpass,
      ));
    }
    if (s.quakes.isNotEmpty) {
      final q = s.quakes.first;
      final j = toJstWallClock(q.at.toUtc());
      final hhmm = '${j.hour.toString().padLeft(2, '0')}:${j.minute.toString().padLeft(2, '0')}';
      final text = s.quakes.length == 1
          ? l10n.situationQuake(intensityLabelOf(l10n, q.maxIntensity), q.place, hhmm)
          : '${l10n.situationQuake(intensityLabelOf(l10n, q.maxIntensity), q.place, hhmm)} ${l10n.situationMore(s.quakes.length - 1)}';
      rows.add(_Row(
        icon: Icons.vibration,
        color: const Color(0xFFE65100),
        text: text,
        onTap: onOpenQuake,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final shown = rows.take(_maxRows).toList();
    final hidden = rows.length - shown.length;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: onToggle,
                child: Row(children: [
                  Flexible(
                    child: Text(
                        collapsed
                            ? '${l10n.situationTitle} · ${l10n.situationCount(rows.length)}'
                            : l10n.situationTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (onToggle != null)
                    Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 18, color: Colors.black54),
                ]),
              ),
            ),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ]),
          if (!collapsed)
            for (final r in shown)
              InkWell(
              onTap: r.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(r.icon, size: 16, color: r.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.black38),
                ]),
              ),
            ),
          if (!collapsed && hidden > 0)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(l10n.situationMore(hidden),
                  style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l10n.situationSource,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            ),
        ]),
      ),
    );
  }

  /// 都道府県名を最大3つ、超えた分は「ほかN」
  static String _prefs(AppLocalizations l10n, Set<String> prefs) {
    final codes = prefs.where(prefectureNames.containsKey).toList()..sort();
    final names = codes.take(3).map((c) => prefectureNameOf(l10n, c)).join('・');
    return codes.length > 3 ? '$names ${l10n.situationMore(codes.length - 3)}' : names;
  }
}

class _Row {
  const _Row({required this.icon, required this.color, required this.text, required this.onTap});
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
}
