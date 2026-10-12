import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/jma_area.dart';
import 'package:livecam_jp/data/wave_forecast.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/wave_forecast_card.dart';

import 'l10n_test_app.dart';

Camera cam({String category = 'coast', String? municipality = '14201', String pref = '14'}) =>
    Camera(
      id: 'c1', name: '海のカメラ', category: category, prefecture: pref,
      municipality: municipality,
      feed: Feed(type: FeedType.stillImage, url: 'https://example.jp/a.jpg'),
      operator: 'x', attribution: 'x', sourcePageUrl: 'https://example.jp/',
      coordAccuracy: CoordAccuracy.exact,
    );

Map<String, dynamic> readJson(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

List<dynamic> forecastJson() =>
    jsonDecode(File('test/fixtures/forecast_140000.json').readAsStringSync()) as List<dynamic>;

void main() {
  final now = DateTime(2026, 10, 12, 18, 0); // JST 壁時計

  setUp(() {
    JmaAreaNames.reset();
    JmaAreaNames.parse(readJson('area_wave.json'));
    WaveForecasts.resetCache();
  });

  group('解析', () {
    WaveSeq main(String s) => WaveForecasts.parse(s)!.main;

    test('全角・全角空白を正規化して高さを読む', () {
      final s = main('０．５メートル');
      expect(s.heights, [const WaveHeight(0.5)]);
      expect(s.swell, isFalse);
    });

    test('後・うねり', () {
      final s = main('２メートル\u3000後\u3000１．５メートル\u3000うねり\u3000を伴う');
      expect(s.heights.map((h) => h.meters), [2, 1.5]);
      expect(s.connectors, [WaveConnector.then]);
      expect(s.swell, isTrue);
    });

    test('時々・一時・未満', () {
      final s = main('１メートル未満\u3000時々\u3000２メートル\u3000一時\u3000３メートル');
      expect(s.heights.first.under, isTrue);
      expect(s.connectors, [WaveConnector.sometimes, WaveConnector.temporarily]);
    });

    test('ただし書き', () {
      final p = WaveForecasts.parse(
          '２．５メートル\u3000後\u3000３メートル\u3000うねり\u3000を伴う\u3000ただし\u3000新島\u3000では\u3000３メートル\u3000うねり\u3000を伴う'
      )!;
      expect(p.main.heights.length, 2);
      expect(p.exception!.place, '新島');
      expect(p.exception!.seq.swell, isTrue);
    });

    test('解析できない文字列は null', () {
      expect(WaveForecasts.parse('高く'), isNull);
      expect(WaveForecasts.parse('２メートル 高い'), isNull);
      expect(WaveForecasts.parse(''), isNull);
    });
  });

  group('区域の解決', () {
    test('市区町村 → 一次細分区域 → 官署', () {
      final a = JmaAreaNames.class10Of('14201')!;
      expect((a.code, a.office, a.name), ('140010', '140000', '東部'));
    });

    test('市コードだけの政令市は先頭が同じ区域を使う', () {
      expect(JmaAreaNames.class10Of('14100')!.code, '140010');
    });

    test('政令市の区コードは市単位の区域に寄せる', () {
      JmaAreaNames.parse({
        'class20s': {'0110000': {'name': '札幌市', 'parent': '016012'}},
        'class15s': {'016012': {'name': '石狩地方中部', 'parent': '016010'}},
        'class10s': {'016010': {'name': '石狩地方', 'enName': 'Ishikari', 'parent': '016000'}},
      });
      expect(JmaAreaNames.class10Of('01103')!.office, '016000');
    });

    test('引けないとき・無いときは null', () {
      expect(JmaAreaNames.class10Of('99999'), isNull);
      expect(JmaAreaNames.class10Of(null), isNull);
    });
  });

  group('予報の取り出し', () {
    test('3日分（今日・明日・明後日）', () {
      final d = WaveForecasts.parseDays(forecastJson(), '140010', now);
      expect(d.map((e) => e.dayOffset), [0, 1, 2]);
      expect(d[1].parsed!.main.heights.map((h) => h.meters), [2, 1.5]);
      expect(d[2].parsed!.main.heights.single.meters, 1);
    });

    test('日付は JST の壁時計で判定する（翌日 0:00 JST を今日にしない）', () {
      final d = WaveForecasts.parseDays(forecastJson(), '140010', DateTime(2026, 10, 13, 8));
      expect(d.map((e) => e.dayOffset), [0, 1]); // 10/12 は過去として落ち、10/13 が今日
    });

    test('waves が無い区域は空', () {
      expect(WaveForecasts.parseDays(forecastJson(), '149999', now), isEmpty);
    });
  });

  group('fetch', () {
    test('取得・オフィス単位のメモリ控え・対象外は null', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(req.url.path, endsWith('/140000.json'));
        return http.Response.bytes(utf8.encode(jsonEncode(forecastJson())), 200);
      });
      final f = await WaveForecasts.fetch(cam(), client: client, nowJst: now);
      expect(f!.name, '東部');
      expect(f.days.length, 3);
      await WaveForecasts.fetch(cam(municipality: '14100'), client: client, nowJst: now);
      expect(calls, 1);
      expect(await WaveForecasts.fetch(cam(category: 'river'), client: client), isNull);
      expect(await WaveForecasts.fetch(cam(municipality: null), client: client), isNull);
      expect(await WaveForecasts.fetch(cam(pref: '99'), client: client), isNull);
    });

    test('通信失敗は null', () async {
      final client = MockClient((_) async => http.Response('', 500));
      expect(await WaveForecasts.fetch(cam(), client: client, nowJst: now), isNull);
    });
  });

  group('カード', () {
    WaveForecast sample() => WaveForecast(
        name: '東部',
        enName: 'Eastern Region',
        days: WaveForecasts.parseDays(forecastJson(), '140010', now));

    testWidgets('予報があれば出る', (tester) async {
      await tester.pumpWidget(testApp(SingleChildScrollView(
          child: WaveForecastCard(camera: cam(), loader: (_) async => sample()))));
      await tester.pumpAndSettle();
      expect(find.text('波の予報（東部）'), findsOneWidget);
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('2 m（うねりを伴う）'), findsOneWidget);
      expect(find.text('2 m → 1.5 m（うねりを伴う）'), findsOneWidget);
      expect(find.textContaining('気象庁「天気予報」'), findsOneWidget);
      expect(find.textContaining('現地の状況で判断'), findsOneWidget);
    });

    testWidgets('英語では区域名が英語になる', (tester) async {
      await tester.pumpWidget(testApp(
          SingleChildScrollView(
              child: WaveForecastCard(camera: cam(), loader: (_) async => sample())),
          locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Wave forecast (Eastern Region)'), findsOneWidget);
      expect(find.text('2 m → 1.5 m (with sea swell)'), findsOneWidget);
    });

    testWidgets('解析できない文は日本語では原文、英語では（Japanese）付き', (tester) async {
      final f = WaveForecast(name: '東部', enName: '', days: const [
        WaveDay(dayOffset: 0, raw: '高く\u3000なる', parsed: null),
      ]);
      await tester.pumpWidget(testApp(WaveForecastCard(camera: cam(), loader: (_) async => f)));
      await tester.pumpAndSettle();
      expect(find.text('高く なる'), findsOneWidget);
      await tester.pumpWidget(testApp(
          WaveForecastCard(camera: cam(), loader: (_) async => f),
          locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('高く なる (Japanese)'), findsOneWidget);
    });

    testWidgets('予報が無ければ何も出ない', (tester) async {
      await tester.pumpWidget(testApp(WaveForecastCard(camera: cam(), loader: (_) async => null)));
      await tester.pumpAndSettle();
      expect(find.text('今日'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('復帰の合図で取り直す', (tester) async {
      final tick = ValueNotifier(0);
      var n = 0;
      await tester.pumpWidget(testApp(WaveForecastCard(
          camera: cam(), resumeTick: tick, loader: (_) async { n++; return sample(); })));
      await tester.pumpAndSettle();
      tick.value++;
      await tester.pumpAndSettle();
      expect(n, 2);
    });
  });
}
