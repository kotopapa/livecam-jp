import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/models/status.dart';

const manifestJson = '''
{"schema_version":1,
 "cameras":{"version":"2026-08-18T00:00:00Z","url":"/livecam-jp/v1/cameras.json","count":2},
 "status":{"version":null,"url":"/livecam-jp/v1/status.json"},
 "min_app_version":"1.0.0","notice":null}''';

const camerasJson = '''
{"version":"2026-08-18T00:00:00Z","cameras":[
 {"id":"kawabou-1","name":"多摩川 田園調布","lat":35.59,"lng":139.66,
  "coord_accuracy":"exact","category":"river","prefecture":"13",
  "feed":{"type":"still_image","url":"https://cam.river.go.jp/cam/now/1.jpg",
          "refresh_sec":600,"requires_referer":false,"headers":{}},
  "fallback":{"type":"web_page","url":"https://example.jp/1"},
  "operator":"国土交通省","source":{"page_url":"https://example.jp/1",
  "terms_url":"https://example.jp/t","license":"public_data_1.0","attribution":"出典：国交省"},
  "review":{"status":"approved"}},
 {"id":"mlit-roadinfo-x","name":"堂面川橋","lat":33.05,"lng":130.43,
  "coord_accuracy":"exact","category":"road","prefecture":"40",
  "feed":{"type":"mlit_roadinfo","url":"https://prvs.example.jp/pcImage_89_1.html",
          "camera_ref":"89C01702","requires_referer":false,"headers":{}},
  "fallback":{"type":"web_page","url":"https://prvs.example.jp/"},
  "operator":"国土交通省 九州地方整備局","source":{"page_url":"https://prvs.example.jp/",
  "terms_url":null,"license":"unknown","attribution":"出典：国交省"},
  "review":{"status":"approved"}},
 {"id":"broken","name":"座標なし","category":"road","prefecture":"11",
  "feed":{"type":"still_image","url":"https://example.jp/x.jpg"},
  "operator":"x","source":{"attribution":"x"},"review":{"status":"approved"}}
]}''';

const statusJson = '''
{"generated_at":"2026-08-18T01:46:00Z","statuses":{
 "kawabou-1":{"state":"ok","last_ok_at":"2026-08-18T01:40:00Z","avg_interval_sec":600},
 "mlit-roadinfo-x":{"state":"ok",
   "image_url":"https://prvs.example.jp/img/20260818101500/s_89C01702.jpeg",
   "image_time":"2026-08-18 10:15:26"},
 "dead-cam":{"state":"error"}}}''';

void main() {
  group('モデルのパース', () {
    test('cameras.json を寛容にパースし、未知typeでも落ちない', () {
      final cams = Camera.listFromJson(jsonDecode(camerasJson) as Map<String, dynamic>);
      expect(cams.length, 3);
      expect(cams[0].feed.type, FeedType.stillImage);
      expect(cams[0].coordAccuracy.isUncertain, isFalse);
      expect(cams[1].feed.type, FeedType.mlitRoadinfo);
      expect(cams[1].feed.cameraRef, '89C01702');
      expect(cams[2].isDisplayable, isFalse); // 座標なしは表示対象外
    });

    test('未知のfeed.typeとcoord_accuracyはunknown/noneに落ちる', () {
      final cam = Camera.tryParse({
        'id': 'x', 'name': 'x', 'category': 'road', 'prefecture': '13',
        'feed': {'type': 'hologram_v99', 'url': 'https://example.jp/'},
        'operator': 'x', 'source': {'attribution': 'x'},
        'coord_accuracy': 'quantum',
      })!;
      expect(cam.feed.type, FeedType.unknown);
      expect(cam.coordAccuracy, CoordAccuracy.none);
      expect(cam.coordAccuracy.isUncertain, isTrue);
    });

    test('status.json のimage_urlとstateが読める', () {
      final st = StatusFile.fromJson(jsonDecode(statusJson) as Map<String, dynamic>);
      expect(st['kawabou-1']!.state, CameraState.ok);
      expect(st['mlit-roadinfo-x']!.imageUrl, contains('s_89C01702.jpeg'));
      expect(st['dead-cam']!.state, CameraState.error);
    });
  });

  group('CameraRepository', () {
    late Directory tmp;
    late int camerasFetches;
    late int statusFetches;

    http.Response jsonResponse(String body, String etag) =>
        http.Response.bytes(utf8.encode(body), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
          'etag': etag,
        });

    MockClient buildServer({String camerasVersion = '2026-08-18T00:00:00Z'}) {
      return MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('manifest.json')) {
          return jsonResponse(
              manifestJson.replaceAll('2026-08-18T00:00:00Z', camerasVersion),
              'W/"m1"');
        }
        if (path.endsWith('cameras.json')) {
          camerasFetches++;
          return jsonResponse(camerasJson, 'W/"c1"');
        }
        if (path.endsWith('status.json')) {
          statusFetches++;
          return jsonResponse(statusJson, 'W/"s1"');
        }
        return http.Response('not found', 404);
      });
    }

    CameraRepository buildRepo(http.Client client, {DateTime Function()? now}) {
      return CameraRepository(
        api: ApiClient(client: client, baseUri: Uri.parse('https://host.example/livecam-jp/v1/')),
        cache: CacheStore(tmp, now: now),
        now: now,
      );
    }

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('livecam_test');
      camerasFetches = 0;
      statusFetches = 0;
    });

    tearDown(() async => tmp.delete(recursive: true));

    test('初回refresh: manifest→cameras→statusを取得しキャッシュする', () async {
      final repo = buildRepo(buildServer());
      expect(await repo.refresh(), isTrue);
      expect(repo.cameras.length, 3);
      expect(repo.status['kawabou-1']!.state, CameraState.ok);
      expect(camerasFetches, 1);

      // 2回目: バージョン不変ならcamerasは再取得しない
      final repo2 = buildRepo(buildServer());
      await repo2.loadCached();
      await repo2.refresh();
      expect(camerasFetches, 1, reason: 'version一致ならcameras.jsonは取得しない');
    });

    test('statusは5分以内なら再取得しない', () async {
      var t = DateTime.utc(2026, 8, 18, 1, 0);
      final repo = buildRepo(buildServer(), now: () => t);
      await repo.refresh();
      expect(statusFetches, 1);

      t = t.add(const Duration(minutes: 3));
      await repo.refresh();
      expect(statusFetches, 1, reason: '3分後は再取得しない');

      t = t.add(const Duration(minutes: 3));
      await repo.refresh();
      expect(statusFetches, 2, reason: '6分後は再取得する');
    });

    test('オフライン時はキャッシュで動作を継続する', () async {
      final repo = buildRepo(buildServer());
      await repo.refresh();

      final offline = buildRepo(MockClient((_) async => throw const SocketException('offline')));
      await offline.loadCached();
      expect(await offline.refresh(), isFalse);
      expect(offline.cameras.length, 3, reason: 'キャッシュから復元されている');
      expect(offline.status['kawabou-1']!.state, CameraState.ok);
    });

    test('表示対象の決定: errorと座標なしは出さない、画像URLはtype別に解決', () async {
      final repo = buildRepo(buildServer());
      await repo.refresh();
      final shown = repo.displayableCameras();
      expect(shown.map((c) => c.id), ['kawabou-1', 'mlit-roadinfo-x']);

      expect(repo.imageUrlFor(shown[0]), 'https://cam.river.go.jp/cam/now/1.jpg');
      expect(repo.imageUrlFor(shown[1]), contains('s_89C01702.jpeg'),
          reason: '都度解決型はstatus.jsonのimage_urlを使う');
    });
  });
}
