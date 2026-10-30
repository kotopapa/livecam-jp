import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/kawabou_snow.dart';

const _ok = '{"obsValue":{"snwdp":7,"snwdpCcd":0,"obsTime":"2026/10/30 22:00"},'
    '"hrValues":[{"snwdp":6,"snwdpCcd":0,"obsTime":"2026/10/30 22:00"}]}';

void main() {
  setUp(KawabouSnow.resetCache);

  test('parse: 正常・欠測・hrValues への後退', () {
    expect(KawabouSnow.parse({'obsValue': {'snwdp': 7, 'snwdpCcd': 0}}), 7);
    expect(KawabouSnow.parse({'obsValue': {'snwdp': 0, 'snwdpCcd': 0}}), 0);
    // 欠測（snwdpCcd≠0）は 0 で届いても捨てる
    expect(KawabouSnow.parse({'obsValue': {'snwdp': 0, 'snwdpCcd': 140}}),
        isNull);
    // obsValue が欠測なら hrValues の最新の有効値
    expect(
        KawabouSnow.parse({
          'obsValue': {'snwdp': 0, 'snwdpCcd': 140},
          'hrValues': [
            {'snwdp': 0, 'snwdpCcd': 140},
            {'snwdp': 12, 'snwdpCcd': 0},
            {'snwdp': 9, 'snwdpCcd': 0},
          ]
        }),
        12);
    expect(KawabouSnow.parse('x'), isNull);
    expect(KawabouSnow.parse({}), isNull);
  });

  test('parseStations: id は kawabou: 付き', () {
    final l = KawabouSnow.parseStations({
      'stations': [
        {'id': '2329700300003', 'n': '旭岳', 'lat': 43.64, 'lng': 142.79, 'm': '01458'},
        {'id': 'bad'}
      ]
    });
    expect(l.length, 1);
    expect(l.first.id, 'kawabou:2329700300003');
    expect(l.first.sourceId, 'kawabou');
    expect(KawabouSnow.obsFcdOf(l.first), '2329700300003');
  });

  test('fetchDepth: 最新スロット 404 なら1つ前を取り、結果は控える', () async {
    final urls = <String>[];
    final client = MockClient((req) async {
      urls.add(req.url.toString());
      if (req.url.path.contains('/2210/')) return http.Response('', 404);
      return http.Response(_ok, 200);
    });
    final now = DateTime(2026, 10, 30, 22, 14);
    final d = await KawabouSnow.fetchDepth('A1', client: client, nowJst: now);
    expect(d, 7);
    expect(urls.length, 2);
    expect(urls[0], endsWith('tmlist/snw/20261030/2210/A1.json'.replaceFirst('2210', '2210')));
    expect(urls[1], endsWith('tmlist/snw/20261030/2200/A1.json'));
    // 控え
    await KawabouSnow.fetchDepth('A1', client: client, nowJst: now);
    expect(urls.length, 2);
  });

  test('fetchDepth: 3スロットとも無ければ null、失敗も控える', () async {
    var n = 0;
    final client = MockClient((req) async {
      n++;
      return http.Response('', 404);
    });
    final now = DateTime(2026, 10, 30, 0, 5);
    expect(await KawabouSnow.fetchDepth('B', client: client, nowJst: now),
        isNull);
    expect(n, 3);
    expect(await KawabouSnow.fetchDepth('B', client: client, nowJst: now),
        isNull);
    expect(n, 3);
  });
}
