import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/data/viewer_area.dart';

void main() {
  group('ViewerArea', () {
    test('逆ジオコーダの muniCd 先頭2桁を県コードにする。海上・国外は null', () {
      expect(ViewerArea.parsePrefecture('{"results":{"muniCd":"19430","lv01Nm":"船津"}}'), '19');
      expect(ViewerArea.parsePrefecture('{"results":{"muniCd":"47207","lv01Nm":"美崎町"}}'), '47');
      expect(ViewerArea.parsePrefecture('{}'), isNull);
      expect(ViewerArea.parsePrefecture('{"results":{"muniCd":"99999"}}'), isNull);
      expect(ViewerArea.parsePrefecture('not json'), isNull);
    });

    test('国土地理院へ lat/lon で問い合わせ、失敗は null', () async {
      Uri? called;
      final ok = ViewerArea(client: MockClient((r) async {
        called = r.url;
        return http.Response(jsonEncode({'results': {'muniCd': '13101'}}), 200);
      }));
      expect(await ok.prefectureOf(35.68, 139.76), '13');
      expect(called!.host, 'mreversegeocoder.gsi.go.jp');
      expect(called!.queryParameters['lat'], '35.68000');
      expect(called!.queryParameters['lon'], '139.76000');
      final ng = ViewerArea(client: MockClient((_) async => http.Response('x', 500)));
      expect(await ng.prefectureOf(35.68, 139.76), isNull);
    });
  });

  group('AppState.viewerInSpecialWarningArea', () {
    AppState app() => AppState(CameraRepository(
          api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
          cache: CacheStore(Directory(Directory.systemTemp.path)),
        ));

    test('発表が無ければ伏せない', () {
      final a = app();
      expect(a.viewerInSpecialWarningArea, isFalse);
    });

    test('発表エリアに居る人だけ伏せる。現在地不明（位置情報オフ等）は無条件で出す', () {
      final a = app()
        ..specialWarningActive = true
        ..specialWarningPrefectures = const {'19', '22'};
      a.viewerPrefecture = '19';
      expect(a.viewerInSpecialWarningArea, isTrue);
      a.viewerPrefecture = '13';
      expect(a.viewerInSpecialWarningArea, isFalse);
      a.viewerPrefecture = null;
      expect(a.viewerInSpecialWarningArea, isFalse);
    });

    test('parseSpecialWarnings: 実データ形式（areaCode・官署×報種別）から県を集める', () {
      // 気象庁 r8 map.json の形（2026-09-03 取得分の抜粋）
      final reports = [
        {
          'publishingOffice': '甲府地方気象台', 'dataTypeCode': 'VPWW55',
          'reportDatetime': '2026-09-03T10:00:00+09:00',
          'warning': {'class10Items': [
            {'areaCode': '190010', 'kinds': [{'code': '33', 'status': '発表'}]},
            {'areaCode': '190020', 'kinds': [{'code': '10', 'status': '発表'}]},
          ]},
        },
        // 同じ官署の土砂災害報（別の dataTypeCode）。官署だけで最新を採ると落ちる
        {
          'publishingOffice': '甲府地方気象台', 'dataTypeCode': 'VPWW56',
          'reportDatetime': '2026-09-03T09:00:00+09:00',
          'warning': {'class10Items': [
            {'areaCode': '190020', 'kinds': [{'code': '39', 'status': '発表'}]},
          ]},
        },
        // 静岡: 解除済みは数えない
        {
          'publishingOffice': '静岡地方気象台', 'dataTypeCode': 'VPWW55',
          'reportDatetime': '2026-09-03T10:00:00+09:00',
          'warning': {'class10Items': [
            {'areaCode': '220010', 'kinds': [{'code': '33', 'status': '解除'}]},
          ]},
        },
        // 同一官署×報種別は最新だけ（古い報の特別警報は無視）
        {
          'publishingOffice': '沖縄気象台', 'dataTypeCode': 'VPWW55',
          'reportDatetime': '2026-09-03T08:00:00+09:00',
          'warning': {'class10Items': [
            {'areaCode': '471010', 'kinds': [{'code': '32', 'status': '発表'}]},
          ]},
        },
        {
          'publishingOffice': '沖縄気象台', 'dataTypeCode': 'VPWW55',
          'reportDatetime': '2026-09-03T10:00:00+09:00',
          'warning': {'class10Items': [
            {'areaCode': '471010', 'kinds': [{'code': '32', 'status': '解除'}]},
          ]},
        },
      ];
      final r = AppState.parseSpecialWarnings(reports);
      expect(r.active, isTrue);
      expect(r.prefs, {'19'});
      final none = AppState.parseSpecialWarnings([reports[2]]);
      expect(none.active, isFalse);
      expect(none.prefs, isEmpty);
    });

    test('checkSpecialWarnings: 特別警報の県を集め、発表中だけ現在地を求める', () async {
      final a = app();
      var resolved = 0;
      a.viewerPrefectureResolver = () async {
        resolved++;
        return '19';
      };
      // http は差し替えられないので、AppState 内の取得は失敗して何も変わらないことだけ確認
      await a.checkSpecialWarnings();
      expect(a.specialWarningActive, isFalse);
      expect(resolved, 0);
    });
  });
}
