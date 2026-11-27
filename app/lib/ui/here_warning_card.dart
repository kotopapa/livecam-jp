import 'package:flutter/material.dart';

import '../data/muni_warnings.dart';
import '../data/warning_levels.dart';
import '../l10n/l10n.dart';
import '../util/jst.dart';

/// 現在地の警報の取得状況
enum HereWarningStatus {
  /// 取得中
  loading,

  /// 位置情報が使えない（未許可・最終既知位置なし）
  noLocation,

  /// 市区町村を特定できない（海上・国外）か、取得に失敗した
  unavailable,

  /// 取得済み（発表なしを含む）
  ready,
}

/// 気象警報タブの先頭に置く「現在地の警報・注意報」カード（2026-11-28 ユーザー要望:
/// 都道府県の一覧から自分の市区町村を探さなくても、いま居る場所に何が出ているか分かるように）。
/// 最上位の段階を大きく、発表中の種類をすべてチップで並べる
class HereWarningCard extends StatelessWidget {
  const HereWarningCard({
    super.key,
    required this.status,
    this.warnings,
    this.placeName = '',
    this.onTap,
  });

  final HereWarningStatus status;
  final MuniWarnings? warnings;

  /// 現在地の市区町村名（空なら出さない）
  final String placeName;

  /// タップで周辺のカメラを開く（null なら反応しない）
  final VoidCallback? onTap;

  static String _levelName(AppLocalizations l, int level) => switch (level) {
        5 => l.pwLevel5,
        4 => l.pwLevel4,
        3 => l.pwLevel3,
        _ => l.pwLevel2,
      };

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final grey = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    final w = warnings;
    final ready = status == HereWarningStatus.ready && w != null;
    Widget body;
    switch (status) {
      case HereWarningStatus.loading:
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      case HereWarningStatus.noLocation:
        body = Text(l.mapLocationFailed, style: grey);
      case HereWarningStatus.unavailable:
        body = Text(l.bosaiWarnHereUnavailable, style: grey);
      case HereWarningStatus.ready:
        if (w == null || w.codes.isEmpty) {
          body = Row(children: [
            const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF1E8E3E)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(l.bosaiWarnHereNone, style: const TextStyle(fontSize: 13))),
          ]);
        } else {
          final level = w.topLevel;
          final issued = w.issuedAt == null ? null : toJstWallClock(w.issuedAt!);
          body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              key: const Key('here_warning_top'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: warningBadgeColor(level),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(l.pwWarnBadge(_levelName(l, level), '$level'),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: warningBadgeTextColor(level))),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in w.codes)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: warningBadgeColor(warningLevelOf(c)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(warningNameOf(l, c) ?? advisoryNameOf(l, c) ?? c,
                      style: TextStyle(
                          fontSize: 12, color: warningBadgeTextColor(warningLevelOf(c)))),
                ),
            ]),
            if (issued != null) ...[
              const SizedBox(height: 6),
              Text(
                  l.pwIssued('${issued.month}/${issued.day} '
                      '${_two(issued.hour)}:${_two(issued.minute)}'),
                  style: grey),
            ],
          ]);
        }
    }
    final tappable = ready && onTap != null;
    return Card(
      key: const Key('here_warning_card'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tappable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.my_location, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(l.bosaiWarnHereTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(ready ? placeName : '',
                      style: grey, overflow: TextOverflow.ellipsis)),
              if (tappable) Icon(Icons.videocam_outlined, size: 18, color: grey.color),
            ]),
            const SizedBox(height: 8),
            body,
          ]),
        ),
      ),
    );
  }
}
