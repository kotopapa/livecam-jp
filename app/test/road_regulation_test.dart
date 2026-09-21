import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/road_regulation.dart';

void main() {
  test('road_regulation.json を読み、線・段階・ラベルを持つ', () {
    final st = RoadRegulationStatus.parse({
      'version': '2026-09-21T09:00:00Z',
      'sources': [
        {
          'id': 'mlit', 'name': '国土交通省 道路情報提供システム', 'url': 'https://www.road-info-prvs.mlit.go.jp/roadinfo/',
          'attribution': '出典：国土交通省 道路情報提供システム',
          'items': [
            {'id': 'a', 'name': '高知県道６号 高知伊予三島線', 'section': '大川村大北川', 'kind': '通行止（都道府県道）',
             'direction': '上下', 'cause': '災害等', 'content': '通行止', 'lat': 33.82, 'lng': 133.43, 'level': 2,
             'label': '通行止（災害等）', 'at': '2026年08月18日 08:30',
             'lines': [[[33.8219, 133.4346], [33.8223, 133.4345]]]},
            {'id': 'b', 'name': '国道1号', 'lat': 35.0, 'lng': 138.5, 'level': 1, 'label': '片側規制（越波）', 'lines': 'x'},
            {'id': 'c', 'name': '', 'lat': 35.0, 'lng': 138.5, 'level': 2},
          ],
        }
      ],
    });
    expect(st.sources.length, 1);
    expect(st.allItems.length, 2);
    expect(st.closedCount, 1);
    final a = st.allItems.first;
    expect(a.lines.length, 1);
    expect(a.lines.first.first.latitude, 33.8219);
    expect(a.label, '通行止（災害等）');
    expect(st.allItems[1].lines, isEmpty);
    expect(RoadRegulationStatus.parse('junk').sources, isEmpty);
  });
}
