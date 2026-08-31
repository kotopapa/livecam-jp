import '../l10n/gen/app_localizations.dart';

/// 取得時刻の人向け表示（SPEC 9.2③: 相対時刻だけでなく絶対時刻も出す）。
///
/// 入力はISO 8601（オフセット付き/なし）や "2026-08-18 10:15:26" 形式が混在する。
/// オフセットなしは提供元の日本時間とみなし、オフセット付きは端末ローカルへ変換。
///
/// 1.4.0: BuildContext を持たない場所からも呼べるよう、`AppLocalizations` を
/// 引数で受け取る（docs/research_2026-09-01/i18n_languages.md 8.6）。
/// 省略時は日本語表記（既存の呼び出し・テスト互換）。
String formatTakenTime(String raw, {AppLocalizations? l10n}) {
  final dt = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (dt == null) return raw;
  final local = dt.isUtc || raw.contains('+') ? dt.toLocal() : dt;
  final now = DateTime.now();

  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final hm = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  final md = l10n == null
      ? '${local.month}月${local.day}日'
      : l10n.timeMonthDay(local.month, local.day);
  final abs = sameDay ? hm : '$md $hm';

  final diff = now.difference(local);
  String rel = '';
  if (!diff.isNegative && diff.inHours < 24) {
    if (diff.inMinutes < 1) {
      rel = l10n == null ? '（たった今）' : l10n.timeRelJustNow;
    } else if (diff.inMinutes < 60) {
      rel = l10n == null
          ? '（${diff.inMinutes}分前）'
          : l10n.timeRelMinutes(diff.inMinutes);
    } else {
      rel = l10n == null
          ? '（${diff.inHours}時間前）'
          : l10n.timeRelHours(diff.inHours);
    }
  }
  return l10n == null ? '$abs 取得$rel' : l10n.timeTakenAt(abs, rel);
}
