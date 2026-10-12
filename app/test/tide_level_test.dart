import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/tide_level.dart';
import 'package:livecam_jp/data/wave_forecast.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/wave_forecast_card.dart';

import 'l10n_test_app.dart';

Map<String, dynamic> fx(String n) =>
    jsonDecode(File('test/fixtures/$n').readAsStringSync()) as Map<String, dynamic>;

Camera cam({double lat = 41.77, double lng = 140.73, String category = 'coast'}) => Camera(
      id: 'c1', name: '海のカメラ', category: category, prefecture: '01',
      municipality: '01202', lat: lat, lng: lng,
      feed: Feed(type: FeedType.stillImage, url: 'https://example.jp/a.jpg'),
      operator: 'x', attribution: 'x', sourcePageUrl: 'https://example.jp/',
      coordAccuracy: CoordAccuracy.exact,
    );

TideInfo sample({bool astro = true, TideTrend? trend = TideTrend.rising}) => TideInfo(
      stationName: '函館', distanceKm: 3, cm: 123, at: DateTime(2026, 10, 12, 14, 30),
      trend: trend,
      extremes: astro
          ? [
              TideExtreme(DateTime(2026, 10, 12, 5, 12), 182, high: true),
              TideExtreme(DateTime(2026, 10, 12, 11, 20), 20, high: false),
              TideExtreme(DateTime(2026, 10, 12, 17, 40), 175, high: true),
              TideExtreme(DateTime(2026, 10, 12, 23, 55), 35, high: false),
            ]
          : const [],
    );

void main() {
  final now = DateTime(2026, 10, 12, 18, 40);
  setUp(TideLevels.resetCache);

  test('観測点表を平らに読む', () {
    final l = TideLevels.parseStations(fx('tide_area_small.json'));
    expect(l.map((s) => s.name).toSet(), {'函館', '横浜', '油壺'});
  });

  test('最寄り選択: 30km 以内だけ・近い順', () {
    final l = TideLevels.parseStations(fx('tide_area_small.json'));
    // 横浜の少し沖 → 横浜が先、函館は圏外
    final n = TideLevels.nearest(l, 35.40, 139.65);
    expect(n.first.$1.name, '横浜');
    expect(n.map((e) => e.$1.name), isNot(contains('函館')));
    expect(n.every((e) => e.$2 <= 30000), isTrue);
    // 函館から 30km 超
    expect(TideLevels.nearest(l, 41.78 + 0.5, 140.72), isEmpty);
  });

  group('実測', () {
    test('tide[i] は 0:00 から i*15 秒。最新=最後の要素 18:34:45', () {
      final o = TideLevels.parseObs(fx('tide_obs_102331_20261012.json'), DateTime(2026, 10, 12))!;
      expect(o.at, DateTime(2026, 10, 12, 18, 34, 45));
      expect(o.cm, -10);
    });

    test('上げ下げ: 30分前との平均の差', () {
      List<int> ramp(int n, int step) => [for (var i = 0; i < n; i++) i * step];
      final d = DateTime(2026, 10, 12);
      // 15秒刻みで 1サンプルごとに +1cm → 上げ潮 / -1 → 下げ潮 / 一定 → 判定なし
      expect(TideLevels.parseObs({'interval': 15, 'tide': ramp(400, 1)}, d)!.trend,
          TideTrend.rising);
      expect(TideLevels.parseObs({'interval': 15, 'tide': ramp(400, -1)}, d)!.trend,
          TideTrend.falling);
      expect(TideLevels.parseObs({'interval': 15, 'tide': List.filled(400, 5)}, d)!.trend,
          isNull);
      // 開始直後（30分前が無い）は判定しない
      expect(TideLevels.parseObs({'interval': 15, 'tide': ramp(100, 1)}, d)!.trend, isNull);
    });

    test('欠測は null', () {
      final d = DateTime(2026, 10, 12);
      expect(TideLevels.parseObs({'interval': 15, 'tide': <int>[]}, d), isNull);
      expect(TideLevels.parseObs({'interval': 15, 'tide': [null, null]}, d), isNull);
    });

    test('末尾が欠けていれば直前の有効値', () {
      final o = TideLevels.parseObs({'interval': 15, 'tide': [10, 11, null]}, DateTime(2026, 10, 12))!;
      expect(o.cm, 11);
      expect(o.at, DateTime(2026, 10, 12, 0, 0, 15));
    });
  });

  group('満潮・干潮（天文潮位）', () {
    test('函館 2026-10-12: 満潮2・干潮2（放物線補間）', () {
      final e = TideLevels.extremes(fx('tide_astro_102331_2026.json'), DateTime(2026, 10, 12));
      expect(e.map((x) => (x.high, x.time.hour, x.time.minute, x.cm)).toList(), [
        (true, 4, 21, 14),
        (false, 9, 47, -32),
        (true, 15, 38, 26),
        (false, 22, 24, -62),
      ]);
    });

    test('その日が無ければ空', () {
      expect(TideLevels.extremes(fx('tide_astro_102331_2026.json'), DateTime(2026, 12, 1)), isEmpty);
    });
  });

  group('fetch', () {
    http.Client client({bool obsMissing = false, List<String>? log}) => MockClient((req) async {
          log?.add(req.url.path);
          final p = req.url.path;
          if (p.endsWith('tide_area.json')) {
            return http.Response.bytes(utf8.encode(File('test/fixtures/tide_area_small.json').readAsStringSync()), 200);
          }
          if (p.contains('tide_obs_')) {
            if (obsMissing || !p.contains('20261012_102331')) {
              return http.Response('{"tide":[]}', obsMissing ? 200 : 404);
            }
            return http.Response.bytes(utf8.encode(File('test/fixtures/tide_obs_102331_20261012.json').readAsStringSync()), 200);
          }
          if (p.contains('tide_astro_2026_102331')) {
            return http.Response.bytes(utf8.encode(File('test/fixtures/tide_astro_102331_2026.json').readAsStringSync()), 200);
          }
          return http.Response('', 404);
        });

    test('取得・距離・控え', () async {
      final log = <String>[];
      final c = client(log: log);
      final t = (await TideLevels.fetch(cam(), client: c, nowJst: now))!;
      expect(t.stationName, '函館');
      expect(t.distanceKm, 1);
      expect(t.cm, -10);
      expect(t.extremes.length, 4);
      final before = log.length;
      await TideLevels.fetch(cam(), client: c, nowJst: now);
      expect(log.length, before); // 全部メモリ控え
    });

    test('30km 超・世界・海岸以外は null', () async {
      expect(await TideLevels.fetch(cam(lat: 42.5), client: client(), nowJst: now), isNull);
      expect(await TideLevels.fetch(cam(category: 'river'), client: client(), nowJst: now), isNull);
    });

    test('欠測なら null', () async {
      expect(await TideLevels.fetch(cam(), client: client(obsMissing: true), nowJst: now), isNull);
    });

    test('0 時台は当日ファイルが無ければ前日を読む', () async {
      final log = <String>[];
      final c = MockClient((req) async {
        log.add(req.url.path);
        final p = req.url.path;
        if (p.endsWith('tide_area.json')) {
          return http.Response.bytes(utf8.encode(File('test/fixtures/tide_area_small.json').readAsStringSync()), 200);
        }
        if (p.contains('20261012_102331')) {
          return http.Response.bytes(utf8.encode(File('test/fixtures/tide_obs_102331_20261012.json').readAsStringSync()), 200);
        }
        return http.Response('', 404);
      });
      final t = await TideLevels.fetch(cam(), client: c, nowJst: DateTime(2026, 10, 13, 0, 20));
      expect(log.any((p) => p.contains('20261013_102331')), isTrue);
      expect(t?.cm, -10);
    });
  });

  group('カード', () {
    Future<void> pump(WidgetTester tester, {WaveForecast? wave, TideInfo? tide, Locale locale = const Locale('ja')}) =>
        tester.pumpWidget(testApp(
          SingleChildScrollView(
              child: WaveForecastCard(
                  camera: cam(), loader: (_) async => wave, tideLoader: (_) async => tide)),
          locale: locale,
        )).then((_) => tester.pumpAndSettle());

    WaveForecast wave() => WaveForecast(name: '渡島地方', enName: 'Oshima', days: [
          WaveDay(dayOffset: 0, raw: '１メートル', parsed: WaveForecasts.parse('１メートル')),
        ]);

    testWidgets('両方あれば「波と潮位」', (tester) async {
      await pump(tester, wave: wave(), tide: sample());
      expect(find.text('波と潮位（渡島地方）'), findsOneWidget);
      expect(find.text('潮位：函館（カメラから約 3 km）'), findsOneWidget);
      expect(find.text('現在 123 cm（14:30）'), findsOneWidget);
      expect(find.text('↑上げ潮'), findsOneWidget);
      expect(find.text('今日の満潮 05:12 182 cm・17:40 175 cm'), findsOneWidget);
      expect(find.text('今日の干潮 11:20 20 cm・23:55 35 cm'), findsOneWidget);
      expect(find.textContaining('T.P.'), findsOneWidget);
      expect(find.textContaining('アプリで算出'), findsOneWidget);
      expect(find.text('出典：気象庁「潮位観測情報」'), findsOneWidget);
      expect(find.text('出典：気象庁「天気予報」'), findsOneWidget);
    });

    testWidgets('波だけなら従来の見出し', (tester) async {
      await pump(tester, wave: wave());
      expect(find.text('波の予報（渡島地方）'), findsOneWidget);
      expect(find.textContaining('潮位'), findsNothing);
    });

    testWidgets('潮位だけなら「潮位」', (tester) async {
      await pump(tester, tide: sample(astro: false, trend: null));
      expect(find.text('潮位'), findsOneWidget);
      expect(find.textContaining('今日の満潮'), findsNothing);
      expect(find.textContaining('天文潮位'), findsNothing);
      expect(find.textContaining('上げ潮'), findsNothing);
      expect(find.text('出典：気象庁「天気予報」'), findsNothing);
    });

    testWidgets('どちらも無ければ何も出ない', (tester) async {
      await pump(tester);
      expect(find.byType(Text), findsNothing);
    });
  });
}
