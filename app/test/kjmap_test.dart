import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/data/kjmap.dart';

const _json = '''{"regions":[
 {"id":"tokyo50","name":"首都圏","zmax":16,"n":36.0,"w":139.25,"s":35.25,"e":140.25,
  "eras":[{"f":"2man","start":1896,"end":1909,"n":35.87,"w":139.3,"s":35.27,"e":140.2},
          {"f":"07","start":1998,"end":2005,"n":36.0,"w":139.25,"s":35.25,"e":140.25}]},
 {"id":"kanto","name":"関東","zmax":15,"n":37.17,"w":138.25,"s":34.84,"e":141.0,
  "eras":[{"f":"00","start":1894,"end":1915,"n":37.17,"w":138.25,"s":34.84,"e":141.0}]},
 {"id":"sapporo","name":"札幌","zmax":16,"n":43.25,"w":140.87,"s":42.92,"e":141.62,
  "eras":[{"f":"00","start":1916,"end":1916,"n":43.25,"w":140.87,"s":42.92,"e":141.62}]}
]}''';

void main() {
  final regions = Kjmap.parse(jsonDecode(_json));

  test('地域表を読む（時期は古い順のまま、ズーム上限は地域ごと）', () {
    expect(regions.length, 3);
    expect(regions[0].eras.map((e) => e.folder), ['2man', '07']);
    expect(regions[1].maxZoom, 15);
    expect(regions[0].era('07')!.start, 1998);
    expect(regions[0].era('99'), isNull);
  });

  test('地点を含む地域は狭い順（東京は首都圏→関東、札幌は札幌だけ、海上は無し）', () {
    final tokyo = Kjmap.regionsAt(regions, const LatLng(35.66, 139.80));
    expect(tokyo.map((r) => r.id), ['tokyo50', 'kanto']);
    expect(Kjmap.regionsAt(regions, const LatLng(43.06, 141.35)).map((r) => r.id), ['sapporo']);
    expect(Kjmap.regionsAt(regions, const LatLng(30.0, 130.0)), isEmpty);
  });

  test('タイルURLと時期の表示', () {
    expect(Kjmap.tileTemplate('tokyo50', '2man'),
        'https://ktgis.net/kjmapw/kjtilemap/tokyo50/2man/{z}/{x}/{y}.png');
    expect(Kjmap.eraLabel(regions[0].eras[0]), '1896〜1909年');
    expect(Kjmap.eraLabel(regions[2].eras[0]), '1916年');
  });

  test('同梱アセットが読めて59地域ある', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Kjmap.setRegions(null);
    final rs = await Kjmap.load();
    expect(rs.length, greaterThanOrEqualTo(59));
    expect(rs.any((r) => r.id == 'tokyo50' && r.eras.length >= 9), isTrue);
    expect(rs.firstWhere((r) => r.id == 'kanto').maxZoom, 15);
  });
}
