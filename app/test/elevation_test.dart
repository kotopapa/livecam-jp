import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/elevation.dart';

void main() {
  setUp(Elevation.clearCacheForTest);

  group('parse', () {
    test('数値の標高', () {
      // 国土地理院の実応答（東京駅付近, 2026-08-31実測）
      expect(Elevation.parse('{"elevation":3.6,"hsrc":"1m（レーザ）"}'), 3.6);
      expect(Elevation.parse('{"elevation":0,"hsrc":"5m（レーザ）"}'), 0.0);
      expect(Elevation.parse('{"elevation":-1.2,"hsrc":"10m（標高点計測）"}'), -1.2);
    });

    test('データ無しは "-----" が返るので必ず数値判定する', () {
      // 海上の実応答（2026-08-31実測）
      expect(Elevation.parse('{"elevation":"-----","hsrc":"-----"}'), isNull);
    });

    test('文字列の数値は受け付ける', () {
      expect(Elevation.parse('{"elevation":"3.4","hsrc":"1m（レーザ）"}'), 3.4);
    });

    test('壊れた応答・欠落・HTMLでも例外にならない', () {
      expect(Elevation.parse(''), isNull);
      expect(Elevation.parse('<html>error</html>'), isNull);
      expect(Elevation.parse('{"hsrc":"-----"}'), isNull);
      expect(Elevation.parse('[1,2,3]'), isNull);
    });
  });

  group('format', () {
    test('小数1桁・1000m以上は整数', () {
      expect(Elevation.format(3.6), '3.6m');
      expect(Elevation.format(0), '0.0m');
      expect(Elevation.format(-1.25), '-1.3m');
      expect(Elevation.format(3776.1), '3776m');
    });
  });

  group('uriFor', () {
    test('lon/lat/outtype を付ける', () {
      final u = Elevation.uriFor(35.6812, 139.7671);
      expect(u.queryParameters['lat'], '35.681200');
      expect(u.queryParameters['lon'], '139.767100');
      expect(u.queryParameters['outtype'], 'JSON');
    });
  });

  group('fetch', () {
    test('同じ地点は1回しか取得しない', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"elevation":3.6,"hsrc":"1m"}', 200);
      });
      expect(await Elevation.fetch(35.1, 139.1, client: client), 3.6);
      expect(await Elevation.fetch(35.1, 139.1, client: client), 3.6);
      expect(calls, 1);
      expect(Elevation.isCached(35.1, 139.1), isTrue);
      // 別地点は取りに行く
      expect(await Elevation.fetch(36.1, 139.1, client: client), 3.6);
      expect(calls, 2);
    });

    test('データ無しも確定値として覚える（再取得しない）', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"elevation":"-----","hsrc":"-----"}', 200);
      });
      expect(await Elevation.fetch(30.0, 150.0, client: client), isNull);
      expect(await Elevation.fetch(30.0, 150.0, client: client), isNull);
      expect(calls, 1);
      expect(Elevation.isCached(30.0, 150.0), isTrue);
    });

    test('HTTPエラー・通信エラーはキャッシュせず次回取り直す', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('oops', 503)
            : http.Response('{"elevation":12.5,"hsrc":"5m"}', 200);
      });
      expect(await Elevation.fetch(34.0, 135.0, client: client), isNull);
      expect(Elevation.isCached(34.0, 135.0), isFalse);
      expect(await Elevation.fetch(34.0, 135.0, client: client), 12.5);
      expect(calls, 2);
    });

    test('例外も null で返す', () async {
      final client = MockClient((_) async => throw Exception('boom'));
      expect(await Elevation.fetch(33.0, 133.0, client: client), isNull);
      expect(Elevation.isCached(33.0, 133.0), isFalse);
    });
  });
}
