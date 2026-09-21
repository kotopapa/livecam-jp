import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/situation.dart';
import 'package:livecam_jp/data/underpass.dart';

void main() {
  final json = {
    'version': '2026-09-21T00:00:00Z',
    'sources': [
      {
        'id': 'chiba', 'name': '千葉市地下道冠水情報システム', 'operator': '千葉市', 'prefecture': '12',
        'url': 'https://pub.os-alert.info/chiba/devmap', 'attribution': '出典：千葉市地下道冠水情報システム',
        'points': [
          {'id': 'a', 'name': '春日地下道', 'lat': 35.6215, 'lng': 140.1047, 'level': 0, 'label': '通行可能', 'at': '9/21 09:00'},
          {'id': 'b', 'name': '商高前地下道', 'lat': 35.6186, 'lng': 140.1070, 'level': 1, 'label': '通行注意', 'at': '9/21 09:10'},
          {'id': 'c', 'name': '弁天地下道', 'lat': 35.6142, 'lng': 140.1184, 'level': 2, 'label': '通行止め', 'at': '9/21 09:10'},
          {'id': 'bad', 'name': '', 'lat': 1, 'lng': 2, 'level': 0},
        ],
      }
    ],
  };

  test('配信 JSON を読む（壊れた点は捨てる、注意・止めだけ alerts）', () {
    final s = UnderpassStatus.parse(json);
    expect(s.sources.length, 1);
    expect(s.allPoints.length, 3);
    expect(s.alerts.map((p) => p.name).toList(), ['商高前地下道', '弁天地下道']);
    expect(s.alertSources.single.id, 'chiba');
    expect(UnderpassStatus.parse(null).sources, isEmpty);
    expect(UnderpassStatus.parse({'sources': 'x'}).sources, isEmpty);
  });

  test('いま起きていること: 注意・止めがあれば表示対象、signature に段階が入る', () {
    final s = UnderpassStatus.parse(json);
    final sit = Situation(
      warnings: const WarningPrefs(),
      typhoons: const [],
      floods: const [],
      quakes: const [],
      loadedAt: DateTime.utc(2026, 9, 21),
      underpass: s.alertSources,
    );
    expect(sit.isNotable, isTrue);
    expect(sit.signature, endsWith('u:chiba/b/1,chiba/c/2'));
    expect(Situation.empty.signature, endsWith('u:'));
  });
}
