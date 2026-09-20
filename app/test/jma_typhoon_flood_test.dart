import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/jma_flood.dart';
import 'package:livecam_jp/data/jma_typhoon.dart';
import 'package:livecam_jp/models/camera.dart';

Object? _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());

Camera _cam(String id, String pref, String? river) => Camera.tryParse({
      'id': id,
      'name': id,
      'lat': 35.0,
      'lng': 139.0,
      'category': 'river',
      'prefecture': pref,
      'river_or_route': river,
      'feed': {'type': 'still_image', 'url': 'https://example.com/$id.jpg'},
      'source': {'page_url': 'https://example.com/', 'license': 'unknown'},
      'review': {'status': 'approved'},
    })!;

void main() {
  group('台風情報', () {
    test('specifications + forecast から実況・予報・経路を組み立てる', () {
      final t = JmaTyphoon.parse('TC2630',
          _fixture('typhoon_specifications.json'),
          _fixture('typhoon_forecast.json'))!;
      expect(t.id, 'TC2630');
      expect(t.typhoonNumber, 'a');
      expect(t.number, isNull); // 台風になる見込みの熱帯低気圧
      expect(t.isTyphoonNow, isFalse);
      expect(t.analysis.categoryEn, 'TD');
      expect(t.analysis.center.latitude, 15.5);
      expect(t.analysis.pressureHpa, 1002);
      expect(t.analysis.maxWindMs, 15);
      expect(t.analysis.location, 'マリアナ諸島');
      expect(t.analysis.course, '北北西');
      expect(t.analysis.speedKmh, 15);
      expect(t.analysis.validAt.isUtc, isTrue);
      expect(t.analysis.validAt, DateTime.utc(2026, 9, 15, 12));
      expect(t.issuedAt, DateTime.utc(2026, 9, 15, 13, 20));
      // 予報は 12/24/48/72/96/120 の6点
      expect(t.forecasts.map((p) => p.hours).toList(), [12, 24, 48, 72, 96, 120]);
      final f12 = t.forecasts.first;
      expect(f12.categoryEn, 'TS');
      // 予報円半径は forecast.json の m を優先（specifications は km）
      expect(f12.probabilityRadiusM, 114824);
      expect(f12.stormRadiusKm, isNull);
      final f72 = t.forecasts[3];
      expect(f72.intensity, '強い');
      expect(f72.stormRadiusKm, 440);
      expect(f72.probabilityRadiusM, 305580);
      // 経路は preTyphoon 13点、最後が現在位置
      expect(t.track.length, 13);
      expect(t.track.last.latitude, 15.5);
      expect(t.points.length, 7);
    });

    test('forecast.json が無くても specifications の km から予報円を作る', () {
      final t = JmaTyphoon.parse('TC1', _fixture('typhoon_specifications.json'), null)!;
      expect(t.forecasts.first.probabilityRadiusM, 115000);
      expect(t.track, [t.analysis.center]);
    });

    test('台風番号: 4桁は下2桁が号数', () {
      final spec = [
        {'part': 'title', 'issue': {'UTC': '2026-09-15T13:20:00Z'}, 'typhoonNumber': '2618'},
        {
          'advancedHours': 0,
          'position': {'deg': [30.0, 135.0]},
          'validtime': {'UTC': '2026-09-15T12:00:00Z'},
          'category': {'jp': '台風', 'en': 'TY'},
          'intensity': '非常に強い',
        },
      ];
      final t = JmaTyphoon.parse('TC2618', spec, null)!;
      expect(t.number, 18);
      expect(t.isTyphoonNow, isTrue);
      expect(t.analysis.intensity, '非常に強い');
    });

    test('壊れた入力は null', () {
      expect(JmaTyphoon.parse('x', {'a': 1}, null), isNull);
      expect(JmaTyphoon.parse('x', [{'part': 'title'}], null), isNull);
    });
  });

  group('指定河川洪水予報', () {
    Map<String, dynamic> rec(String code, String river, String status,
            {String at = '2026-09-15T10:00:00Z', String info = '通常',
            List<String> munis = const ['11100', '11201'],
            List<String> offices = const ['110000']}) =>
        {
          'riverCode': code,
          'riverName': river,
          'reportDatetime': at,
          'infoType': info,
          'item': {'code': status, 'name': _kindName(status)},
          'class20s': munis,
          'officeCodes': offices,
          'text': '本文',
        };

    test('発表が無ければ空', () {
      expect(JmaFlood.parse([]), isEmpty);
      expect(JmaFlood.parse(null), isEmpty);
    });

    test('段階コード → 警戒レベル相当', () {
      expect(FloodLevel.fromCode('10'), FloodLevel.none);
      expect(FloodLevel.fromCode('22'), FloodLevel.caution);
      expect(FloodLevel.fromCode('31'), FloodLevel.warning);
      expect(FloodLevel.fromCode('40'), FloodLevel.danger);
      expect(FloodLevel.fromCode('53'), FloodLevel.occurred);
      expect(FloodLevel.occurred.level, 5);
    });

    test('河川ごとに最新1件、訓練と解除は除外、段階の高い順', () {
      final list = JmaFlood.parse([
        rec('R1', '荒川', '30', at: '2026-09-15T09:00:00Z'),
        rec('R1', '荒川', '40', at: '2026-09-15T10:00:00Z'),
        rec('R2', '利根川', '20'),
        rec('R3', '訓練川', '50', info: '訓練'),
        rec('R4', '解除川', '10'),
        rec('R5', '多摩川', '52'),
      ]);
      expect(list.map((f) => f.riverName).toList(), ['多摩川', '荒川', '利根川']);
      expect(list[1].level, FloodLevel.danger);
      expect(list[1].kindName, '氾濫危険情報');
      expect(list[1].prefectures, {'11'});
      expect(list[1].reportAt.isUtc, isTrue);
    });

    test('河川名で台帳のカメラを引く（都道府県で絞る）', () {
      final f = JmaFlood.parse([rec('R1', '荒川', '40')]).single;
      final cams = [
        _cam('a', '11', '荒川'),
        _cam('b', '11', '荒川水系 入間川'), // 荒川を含む
        _cam('c', '15', '荒川'), // 新潟の荒川は対象外
        _cam('d', '11', '利根川'),
        _cam('e', '11', null),
      ];
      expect(f.matchCameras(cams).map((c) => c.id).toList(), ['a', 'b']);
      // 対象市町村が無い報は官署コードから都道府県を導く（110000=埼玉）
      final g = JmaFlood.parse([rec('R9', '荒川', '40', munis: [])]).single;
      expect(g.prefectures, {'11'});
      expect(g.matchCameras(cams).map((c) => c.id).toList(), ['a', 'b']);
      // 市町村も官署も無ければ全国から名前だけで引く
      final h = JmaFlood.parse([rec('R9', '荒川', '40', munis: [], offices: [])]).single;
      expect(h.matchCameras(cams).map((c) => c.id).toList(), ['a', 'b', 'c']);
    });

    test('class20s が無い実発表（2026-09-20 善福寺川）は officeCodes から都道府県を導く', () {
      final f = FloodForecast.fromJson({
        'riverName': '善福寺川',
        'riverCode': '830304004900',
        'reportDatetime': '2026-09-20T21:50:00+09:00',
        'infoType': '発表',
        'item': {
          'name': 'レベル４氾濫危険警報',
          'code': '40',
          'condition': 'レベル４氾濫危険警報（発表）',
          'areas': [{'name': '善福寺川', 'code': '830304004900'}],
        },
        'officeCodes': ['130000'],
      })!;
      expect(f.level, FloodLevel.danger);
      expect(f.kindName, 'レベル４氾濫危険警報');
      expect(f.prefectures, {'13'});
    });

    test('項目名の揺れ（status / kind）にも耐える', () {
      final f = JmaFlood.parse([
        {
          'riverCode': 'R1',
          'riverName': '鶴見川',
          'reportDatetime': '2026-09-15T10:00:00+09:00',
          'status': '41',
          'kind': '氾濫危険情報',
        }
      ]).single;
      expect(f.level, FloodLevel.danger);
      expect(f.reportAt, DateTime.utc(2026, 9, 15, 1));
      expect(f.prefectures, isEmpty);
    });
  });
}

String _kindName(String code) => switch (code.substring(0, 1)) {
      '5' => '氾濫発生情報',
      '4' => '氾濫危険情報',
      '3' => '氾濫警戒情報',
      '2' => '氾濫注意情報',
      _ => '解除',
    };
