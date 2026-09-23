import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/amedas_snow.dart';

const _stations = '''{"source":"x","stations":[
 {"id":"14163","n":"札幌","lat":43.06,"lng":141.3283,"m":"01101"},
 {"id":"14116","n":"小樽","lat":43.18,"lng":141.0,"m":"01203"},
 {"id":"54232","n":"新潟","lat":37.89,"lng":139.02,"m":"15103"},
 {"id":"56227","n":"富山","lat":36.71,"lng":137.2,"m":"16201"},
 {"id":"91197","n":"那覇","lat":26.2,"lng":127.68}
]}''';

/// 10分値の抜粋。積雪のある地点にだけ snow 系のキーがある（無雪期はキー自体が無い）
const _map = '''{
 "14163": {"temp":[-1.2,0],"snow":[35,0],"snow1h":[1,0],"snow6h":[4,0],"snow24h":[12,0]},
 "14116": {"temp":[-0.5,0],"snow":[80,0],"snow24h":[20,0]},
 "54232": {"temp":[2.0,0],"snow":[0,0]},
 "56227": {"temp":[1.0,0],"snow":[null,4]},
 "91197": {"temp":[22.0,0]},
 "99999": {"snow":[50,0]}
}''';

void main() {
  test('観測点表を読む（市区町村が無い地点は都道府県も無し）', () {
    final st = AmedasSnow.parseStations(jsonDecode(_stations));
    expect(st.length, 5);
    expect(st.first.prefecture, '01');
    expect(st.last.municipality, isNull);
    expect(st.last.prefecture, isNull);
  });

  test('10分値から積雪のある地点だけ取り出し、都道府県＞市区町村に並べる', () {
    final st = AmedasSnow.parseStations(jsonDecode(_stations));
    final r = AmedasSnow.parseMap(jsonDecode(_map), st, DateTime(2027, 1, 15, 7, 0));
    // 0cm・欠測・キー無し・表に無い地点は除く
    expect(r.observations.map((o) => o.station.id), ['14116', '14163']);
    expect(r.observations.first.snow24h, 20);
    expect(r.observations.last.snow1h, 1);
    final prefs = r.byPrefecture();
    expect(prefs.length, 1);
    expect(prefs.first.prefCode, '01');
    expect(prefs.first.maxDepth, 80);
    expect(prefs.first.deepest.station.name, '小樽');
    expect(prefs.first.stationCount, 2);
    expect(prefs.first.municipalities.map((m) => m.code), ['01203', '01101']);
  });

  test('冬季は熱中症の運用期間の外（10/22〜4/21）', () {
    expect(AmedasSnow.isSeason(DateTime(2026, 10, 21)), isFalse);
    expect(AmedasSnow.isSeason(DateTime(2026, 10, 22)), isTrue);
    expect(AmedasSnow.isSeason(DateTime(2027, 1, 1)), isTrue);
    expect(AmedasSnow.isSeason(DateTime(2027, 4, 21)), isTrue);
    expect(AmedasSnow.isSeason(DateTime(2027, 4, 22)), isFalse);
  });

  test('latest_time.txt の +09:00 をJST壁時計に戻してファイル名を組む', () async {
    AmedasSnow.setStations(AmedasSnow.parseStations(jsonDecode(_stations)));
    final urls = <String>[];
    final client = MockClient((req) async {
      urls.add(req.url.toString());
      if (req.url.path.endsWith('latest_time.txt')) {
        return http.Response('2027-01-15T07:00:00+09:00', 200);
      }
      return http.Response(_map, 200);
    });
    final r = await AmedasSnow.fetch(client: client);
    expect(urls.last, endsWith('/map/20270115070000.json'));
    expect(r!.observedAt, DateTime(2027, 1, 15, 7, 0));
    expect(r.observations.length, 2);
    // 同じ観測時刻のあいだは map を再取得しない
    await AmedasSnow.fetch(client: client);
    expect(urls.where((u) => u.contains('/map/')).length, 1);
    AmedasSnow.setStations(null);
  });

  test('近くの観測点は距離順', () {
    final st = AmedasSnow.parseStations(jsonDecode(_stations));
    final near = AmedasSnow.nearest(st, 43.1, 141.2, count: 2);
    expect(near.map((e) => e.$1.name), ['札幌', '小樽']);
  });
}
