/// 取得時刻の人向け表示（SPEC 9.2③: 相対時刻だけでなく絶対時刻も出す）。
///
/// 入力はISO 8601（オフセット付き/なし）や "2026-08-18 10:15:26" 形式が混在する。
/// オフセットなしは提供元の日本時間とみなし、オフセット付きは端末ローカルへ変換。
String formatTakenTime(String raw) {
  final dt = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (dt == null) return raw;
  final local = dt.isUtc || raw.contains('+') ? dt.toLocal() : dt;
  final now = DateTime.now();

  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final hm = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  final abs = sameDay ? hm : '${local.month}月${local.day}日 $hm';

  final diff = now.difference(local);
  String rel = '';
  if (!diff.isNegative && diff.inHours < 24) {
    if (diff.inMinutes < 1) {
      rel = '（たった今）';
    } else if (diff.inMinutes < 60) {
      rel = '（${diff.inMinutes}分前）';
    } else {
      rel = '（${diff.inHours}時間前）';
    }
  }
  return '$abs 取得$rel';
}
