import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/jma_tsunami.dart';

Map<String, dynamic> rep(String eid, String rdt, List<String> kinds, {String ift = '発表'}) => {
      'eid': eid, 'rdt': rdt, 'at': rdt, 'ift': ift, 'json': '$eid.json',
      'kind': [for (final k in kinds) {'code': '000', 'kind': k}],
    };

void main() {
  final now = DateTime.parse('2026-10-02T12:00:00+09:00');

  test('有効期限を過ぎた津波予報は効力なし（2026-09-30 与那国島近海の実例）', () {
    final e = TsunamiEntry(rep('20260930140037', '2026-09-30T14:08:00+09:00', ['津波予報（若干の海面変動）']));
    expect(e.forecastOnly, isTrue);
    expect(isTsunamiActive(e, now, validUntil: DateTime.parse('2026-09-30T18:00:00+09:00')), isFalse);
    expect(isTsunamiActive(e, DateTime.parse('2026-09-30T15:00:00+09:00'),
        validUntil: DateTime.parse('2026-09-30T18:00:00+09:00')), isTrue);
    // 期限が取れないときは発表から12時間
    expect(isTsunamiActive(e, now), isFalse);
  });

  test('同じ地震は最新報で判定し、解除・取消は終わったものとする', () {
    final list = [
      rep('E1', '2026-10-02T10:00:00+09:00', ['津波注意報']),
      rep('E1', '2026-10-02T11:30:00+09:00', ['津波注意報解除', '津波なし']),
      rep('E2', '2026-10-02T11:00:00+09:00', ['津波警報']),
      rep('E3', '2026-10-02T11:00:00+09:00', ['津波注意報'], ift: '取消'),
    ];
    final latest = latestByEvent(list);
    expect(latest['E1']!.allCleared, isTrue);
    expect(isTsunamiActive(latest['E1']!, now), isFalse);
    expect(isTsunamiActive(latest['E2']!, now), isTrue, reason: '警報・注意報は解除の報が出るまで有効');
    expect(isTsunamiActive(latest['E3']!, now), isFalse);
  });

  test('本文から有効期限を取り出す', () {
    expect(validUntilOf({'Head': {'ValidDateTime': '2026-09-30T18:00:00+09:00'}}),
        DateTime.parse('2026-09-30T18:00:00+09:00'));
    expect(validUntilOf({}), isNull);
  });
}
