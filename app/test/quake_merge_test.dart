import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/jma_layers.dart';

void main() {
  // 実例(2026-08-23 茨城県南部): 同一eidに震度速報(震源・M空)、震源に関する情報(震度空)、
  // 顕著な地震の震源要素更新(cod が度分形式)が並ぶ
  final entries = <Map<String, dynamic>>[
    {'eid': 'e1', 'at': '2026-08-23T02:00:00+09:00', 'maxi': '', 'anm': '茨城県南部', 'mag': '5.9',
     'cod': '+3559.9+14005.7-68000/', 'ttl': '顕著な地震の震源要素更新のお知らせ'},
    {'eid': 'e1', 'at': '2026-08-23T02:00:00+09:00', 'maxi': '5-', 'anm': '茨城県南部', 'mag': '5.9',
     'cod': '+36.0+140.1-70000/', 'ttl': '震源・震度情報'},
    {'eid': 'e1', 'at': '2026-08-23T02:00:00+09:00', 'maxi': '5-', 'anm': '', 'mag': '', 'cod': '', 'ttl': '震度速報'},
    {'eid': 'e1', 'at': '2026-08-23T02:00:00+09:00', 'maxi': '', 'anm': '茨城県南部', 'mag': '5.9',
     'cod': '+36.0+140.1-70000/', 'ttl': '震源に関する情報'},
    {'eid': 'e2', 'at': '2026-08-23T22:45:00+09:00', 'maxi': '4', 'anm': '', 'mag': '', 'cod': '', 'ttl': '震度速報'},
  ];
  final since = DateTime.parse('2026-08-01T00:00:00+09:00');

  test('同一eidの複数報を合成し最大震度を採る', () {
    final out = JmaLayers.mergeQuakeReports(entries, since: since);
    expect(out.length, 1); // e2 は座標のある報がないので対象外
    final q = out.single;
    expect(q.maxIntensity, '5-');
    expect(q.place, '茨城県南部');
    expect(q.magnitude, '5.9');
    expect(q.pos!.latitude, closeTo(35.998, 0.01));
    expect(q.pos!.longitude, closeTo(140.095, 0.01));
  });

  test('度分形式のcodを度に変換する', () {
    final p = JmaLayers.parseCod('+3559.9+14005.7-68000/')!;
    expect(p.latitude, closeTo(35.998, 0.001));
    expect(p.longitude, closeTo(140.095, 0.001));
    expect(JmaLayers.parseCod('+36.0+140.1-70000/')!.latitude, 36.0);
    expect(JmaLayers.parseCod(''), isNull);
  });

  test('震度速報→詳報で震度が上がった場合は上位を採る', () {
    final out = JmaLayers.mergeQuakeReports([
      {'eid': 'e3', 'at': '2026-08-10T00:00:00+09:00', 'maxi': '5-', 'anm': '', 'mag': '', 'cod': ''},
      {'eid': 'e3', 'at': '2026-08-10T00:00:00+09:00', 'maxi': '5+', 'anm': '千葉県北西部', 'mag': '6.1', 'cod': '+35.7+140.1-70000/'},
    ], since: since);
    expect(out.single.maxIntensity, '5+');
  });
}
