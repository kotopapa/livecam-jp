import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/amedas_snow.dart';
import 'package:livecam_jp/data/snow_points.dart';

const _doc = '''{
 "version":"2026-12-30T12:00:00Z",
 "sources":[
  {"id":"mlit","name":"国土交通省 道路情報提供システム（道路気象）","short":"国交省",
   "attribution":"出典：国土交通省","url":"https://example.com/",
   "points":[
    {"id":"1","n":"新利根川橋","lat":36.12,"lng":139.76,"m":"08542","d":0,"at":"2026-12-30 20:50"},
    {"id":"2","n":"鳥居峠","lat":36.3,"lng":137.9,"m":"20202","d":45,"at":"2026-12-30 20:50"},
    {"id":"bad","n":"壊れ","lat":"x","lng":1,"d":3}
   ]},
  {"id":"tottori","name":"鳥取県 雪みちナビ","short":"鳥取県","attribution":"x","url":"",
   "points":[{"id":"1","n":"大山","lat":35.37,"lng":133.54,"m":"31386","d":120,"at":"2026-12-30 20:50"}]},
  {"id":"empty","name":"空","short":"空","attribution":"x","url":"","points":[]}
 ]}''';

SnowReport _amedas() => SnowReport(
      observedAt: DateTime(2026, 12, 30, 21, 0),
      observations: [
        SnowObs(
            station: const SnowStation(
                id: '1', name: '札幌', lat: 43.06, lng: 141.33, municipality: '01101'),
            depth: 35,
            snow24h: 12),
      ],
    );

void main() {
  tearDown(SnowPoints.clearCache);

  test('parse: 点の id は情報源付きで衝突せず、壊れた点は読み飛ばす', () {
    final d = SnowPoints.parse(jsonDecode(_doc))!;
    expect(d.sources.length, 3);
    expect(d.sources.first.points.map((p) => p.station.id), ['mlit:1', 'mlit:2']);
    expect(d.sources[1].points.first.station.id, 'tottori:1');
    final s = d.sources.first.points.first.station;
    expect(s.source, '国交省');
    expect(s.sourceId, 'mlit');
    expect(s.prefecture, '08');
    expect(SnowPoints.parse('x'), isNull);
    expect(SnowPoints.parse({'version': 'v'}), isNull);
  });

  test('merge: アメダス＋積雪1cm以上の外部点。d==0 は observations に入らない', () {
    final d = SnowPoints.parse(jsonDecode(_doc));
    final r = SnowPoints.merge(_amedas(), d)!;
    expect(r.observations.map((o) => o.station.id), ['tottori:1', 'mlit:2', '1']);
    expect(r.observations.first.snow24h, isNull);
    expect(r.observedAt, DateTime(2026, 12, 30, 21, 0));
    expect(r.externalSources.map((s) => s.id), ['mlit', 'tottori']);
    expect(r.byPrefecture().length, 3);
  });

  test('merge: アメダスが無ければ配信の版をJST壁時計にする。両方無ければ null', () {
    final d = SnowPoints.parse(jsonDecode(_doc));
    final r = SnowPoints.merge(null, d)!;
    expect(r.observedAt, DateTime(2026, 12, 30, 21, 0));
    expect(SnowPoints.merge(null, null), isNull);
    final a = SnowPoints.merge(_amedas(), null)!;
    expect(a.observations.length, 1);
    expect(a.externalSources, isEmpty);
  });

  test('nearest: d==0 の外部点も候補に入る', () {
    final d = SnowPoints.parse(jsonDecode(_doc));
    final all = SnowPoints.allStations(
        [const SnowStation(id: '9', name: '遠い', lat: 43.0, lng: 141.0, municipality: null)],
        d);
    expect(all.length, 4);
    final n = AmedasSnow.nearest(all, 36.12, 139.76, count: 1);
    expect(n.first.$1.id, 'mlit:1');
  });

  test('attributionText: 外部の情報源名を「、」で並べる', () {
    final d = SnowPoints.parse(jsonDecode(_doc))!;
    expect(SnowPoints.attributionText(const []), AmedasSnow.attribution);
    expect(SnowPoints.attributionText(d.sources.take(2)),
        '${AmedasSnow.attribution}、国土交通省 道路情報提供システム（道路気象）、鳥取県 雪みちナビ');
  });

  test('fetch: 取得・10分控え・失敗時は控え', () async {
    var calls = 0;
    var fail = false;
    final c = MockClient((req) async {
      calls++;
      return fail ? http.Response('', 500) : http.Response.bytes(utf8.encode(_doc), 200);
    });
    final a = await SnowPoints.fetch(client: c);
    expect(a!.sources.length, 3);
    await SnowPoints.fetch(client: c);
    expect(calls, 1);
    fail = true;
    final b = await SnowPoints.fetch(client: c, force: true);
    expect(b, same(a));
    SnowPoints.clearCache();
    expect(await SnowPoints.fetch(client: c), isNull);
  });
}
