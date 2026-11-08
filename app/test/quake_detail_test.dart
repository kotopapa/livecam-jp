import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/jma_layers.dart';
import 'package:livecam_jp/data/quake_detail.dart';

void main() {
  final json = jsonDecode(File('test/fixtures/quake_detail_vxse53.json').readAsStringSync())
      as Map<String, dynamic>;

  test('詳報から震源・深さ・各地の震度（地域／市区町村／観測点）を取り出す', () {
    final d = parseQuakeDetail(json, eid: '20261108010441');
    expect(d.eid, '20261108010441');
    expect(d.place, '静岡県西部');
    expect(d.magnitude, '5.7');
    expect(d.maxIntensity, '5+');
    expect(d.depthKm, 40);
    expect(d.epicenter!.latitude, 34.9);
    expect(d.epicenter!.longitude, 137.7);
    expect(d.at!.toUtc(), DateTime.utc(2026, 11, 7, 16, 4));

    expect(d.stations, isNotEmpty);
    expect(d.stations.first.intensity, '5+', reason: '強い順');
    expect(d.stations.first.name, '知多市緑町', reason: '末尾の＊（自治体等の観測点の印）は出さない');
    expect(d.stations.every((s) => !s.name.endsWith('＊')), isTrue);
    expect(d.stations.first.pos.latitude, 35.0);
    expect(d.stations.first.pos.longitude, 136.86);

    final shinshiro = d.cities.firstWhere((c) => c.name == '新城市');
    expect(shinshiro.intensity, '5-');
    expect(shinshiro.pos.latitude, closeTo((34.95 + 34.98) / 2, 1e-9), reason: '観測点の平均座標');
    expect(shinshiro.pos.longitude, closeTo((137.61 + 137.42) / 2, 1e-9));

    final west = d.areas.firstWhere((a) => a.name == '愛知県西部');
    expect(west.intensity, '5+');
    expect(west.code, '451');
    expect(d.areas.every((a) => a.rank > 0), isTrue);
    expect(d.hasIntensity, isTrue);
    final b = d.bounds!;
    expect(b.$1 <= 34.9 && b.$3 >= 35.22, isTrue, reason: '震源と観測点を含む');
  });

  test('観測点名の末尾の印を外す', () {
    expect(stripStationMark('知多市緑町＊'), '知多市緑町');
    expect(stripStationMark('豊橋市向山'), '豊橋市向山');
    expect(stripStationMark('x*'), 'x');
  });

  test('ズームに応じた集約段階', () {
    expect(QuakeDetail.levelForZoom(5), QuakeIntensityLevel.area);
    expect(QuakeDetail.levelForZoom(8), QuakeIntensityLevel.city);
    expect(QuakeDetail.levelForZoom(11), QuakeIntensityLevel.station);
  });

  test('震源座標の解析（深さ・ごく浅い・不正）', () {
    final (p0, d0) = parseHypocenterCoordinate('+34.9+137.7-40000/');
    expect(p0!.longitude, 137.7);
    expect(d0, 40);
    final (p, d) = parseHypocenterCoordinate('+36.0+140.1-0/');
    expect(p!.latitude, 36.0);
    expect(d, 0);
    expect(parseHypocenterCoordinate('+36.0+140.1/').$2, isNull);
    expect(parseHypocenterCoordinate('').$1, isNull);
  });

  test('震度速報だけ（観測点なし）でも落ちない', () {
    final d = parseQuakeDetail({'Body': {'Intensity': {'Observation': {'MaxInt': '4', 'Pref': []}}}});
    expect(d.hasIntensity, isFalse);
    expect(d.bounds, isNull);
    expect(d.epicenter, isNull);
    expect(parseQuakeDetail({}).stations, isEmpty);
  });

  test('QuakeDetails.fetch は取得関数を使い、同じ詳報は控えから返す', () async {
    QuakeDetails.clearCache();
    var calls = 0;
    QuakeDetails.fetcher = (uri) async {
      calls++;
      expect(uri.toString(), '${QuakeDetails.base}a.json');
      return jsonEncode(json);
    };
    final d1 = await QuakeDetails.fetch('a.json', eid: 'x');
    final d2 = await QuakeDetails.fetch('a.json', eid: 'x');
    expect(d1, isNotNull);
    expect(identical(d1, d2), isTrue);
    expect(calls, 1);
    QuakeDetails.fetcher = (uri) async => throw Exception('down');
    expect(await QuakeDetails.fetch('b.json'), isNull);
    expect(await QuakeDetails.fetch(''), isNull);
  });

  test('mergeQuakeReports は eid と、各地の震度を持つ報の json 名を引き継ぐ', () {
    final out = JmaLayers.mergeQuakeReports([
      {'eid': 'e1', 'at': '2026-11-08T01:04:00+09:00', 'maxi': '5+', 'anm': '静岡県西部', 'mag': '5.7',
       'cod': '+34.9+137.7-40000/', 'json': 'new_VXSE5k_2.json',
       'int': [{'code': '23', 'maxi': '5+', 'city': [{'code': '2322400', 'maxi': '5+'}]}]},
      {'eid': 'e1', 'at': '2026-11-08T01:04:00+09:00', 'maxi': '', 'anm': '静岡県西部', 'mag': '5.7',
       'cod': '+34.9+137.7-40000/', 'json': 'hypo_VXSE52.json'},
      {'eid': 'e1', 'at': '2026-11-08T01:04:00+09:00', 'maxi': '5+', 'anm': '', 'mag': '', 'cod': '',
       'json': 'sokuho_VXSE51.json', 'int': [{'code': '23', 'maxi': '5+'}]},
    ], since: DateTime.parse('2026-11-01T00:00:00+09:00'));
    final q = out.single;
    expect(q.eid, 'e1');
    expect(q.detailJson, 'new_VXSE5k_2.json', reason: '市区町村別震度のある最新報');
  });
}
