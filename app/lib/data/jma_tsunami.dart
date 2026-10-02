/// 気象庁の津波警報・注意報・予報（bosai/tsunami/data/list.json）から、いま効力のある報だけを選ぶ。
///
/// list.json は発表から数日は報が残る（2026-09-30 14:08 の与那国島近海の津波予報は
/// 18:00 で有効期限が切れたが 10/2 にも残っていた）。災害速報タブで「直近72時間」の報を
/// 先頭に固定して出していたため、終わった予報がいつまでも一番上にあった。
/// - 同じ地震（eid）は最新報だけを見る
/// - 取消の報、全区域が「解除」「津波なし」の報は終わったものとして除く
/// - 津波予報（若干の海面変動）だけの報は本文の有効期限（Head.ValidDateTime）を過ぎたら除く。
///   期限が取れないときは発表から12時間で終わったものとみなす
library;

/// list.json の1報
class TsunamiEntry {
  const TsunamiEntry(this.raw);

  final Map<String, dynamic> raw;

  String get eid => raw['eid'] as String? ?? '';
  String get json => raw['json'] as String? ?? '';
  String get ift => raw['ift'] as String? ?? '';
  DateTime? get reportAt => DateTime.tryParse(raw['rdt'] as String? ?? '');
  DateTime? get at => DateTime.tryParse(raw['at'] as String? ?? '');

  /// 区域ごとの種別名（例: 津波予報（若干の海面変動）、津波注意報、津波注意報解除）
  List<String> get kindNames => [
        for (final k in (raw['kind'] as List? ?? const []))
          if (k is Map && k['kind'] is String) k['kind'] as String,
      ];

  /// 全区域が解除・津波なし（＝終わった報）
  bool get allCleared =>
      kindNames.isNotEmpty && kindNames.every((n) => n.contains('解除') || n.contains('なし'));

  /// 警報・注意報を含まない「津波予報」だけの報（有効期限で終わる）
  bool get forecastOnly => kindNames.isNotEmpty && kindNames.every((n) => n.startsWith('津波予報'));
}

/// 地震（eid）ごとの最新報。新しい発表時刻が後
Map<String, TsunamiEntry> latestByEvent(Iterable<Map<String, dynamic>> list) {
  final out = <String, TsunamiEntry>{};
  for (final m in list) {
    final e = TsunamiEntry(m);
    if (e.eid.isEmpty) continue;
    final cur = out[e.eid];
    final t = e.reportAt, ct = cur?.reportAt;
    if (cur == null || (t != null && (ct == null || t.isAfter(ct)))) out[e.eid] = e;
  }
  return out;
}

/// いま効力のある報か。[validUntil] は津波予報の本文の有効期限（取れなければ null）
bool isTsunamiActive(TsunamiEntry e, DateTime now, {DateTime? validUntil}) {
  if (e.ift == '取消' || e.allCleared) return false;
  if (e.forecastOnly) {
    final until = validUntil ?? e.reportAt?.add(const Duration(hours: 12));
    return until != null && now.isBefore(until);
  }
  return true;
}

/// 本文（`bosai/tsunami/data/<json>`）から有効期限を取り出す
DateTime? validUntilOf(Map<String, dynamic> body) =>
    DateTime.tryParse(((body['Head'] as Map?)?['ValidDateTime'] as String?) ?? '');
