import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/data/shelter_layers.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/util/clustering.dart';

Camera cam(String id, String pref, double lat, double lng) => Camera(
      id: id,
      name: id,
      category: 'river',
      prefecture: pref,
      feed: const Feed(type: FeedType.stillImage, url: 'https://example.jp/x.jpg'),
      operator: 'x',
      attribution: 'x',
      lat: lat,
      lng: lng,
      coordAccuracy: CoordAccuracy.exact,
    );

Shelter sh(String id, double lat, double lng, {List<int> f = const [0], bool s = false}) =>
    Shelter(id: id, name: id, address: '', lat: lat, lng: lng, hazards: f, designated: s);

const _prefJson = {
  'version': 'v1',
  'pref': '14',
  'shelters': [
    {'id': 'E1', 'n': 'さちが丘小学校', 'a': '横浜市旭区', 'lat': 35.457, 'lng': 139.523, 'f': [0, 1, 3], 's': 1},
    {'id': 'E2', 'n': '公園', 'a': '横浜市', 'lat': 35.46, 'lng': 139.52, 'f': [3]},
    {'id': '', 'n': 'IDなし', 'lat': 35.0, 'lng': 139.0},
    {'id': 'E3', 'n': '座標なし', 'a': ''},
    'broken',
  ],
};

void main() {
  test('県ファイルのJSONを解析し、壊れたレコードは読み飛ばす', () {
    final list = ShelterLayers.parseFile(_prefJson);
    expect(list.map((s) => s.id), ['E1', 'E2']);
    expect(list.first.name, 'さちが丘小学校');
    expect(list.first.address, '横浜市旭区');
    expect(list.first.hazards, [0, 1, 3]);
    expect(list.first.designated, isTrue);
    expect(list[1].designated, isFalse);
    expect(list.first.pos, const LatLng(35.457, 139.523));
  });

  test('index.json の解析（hazards 未指定なら既定の8種別）', () {
    final idx = ShelterIndex.fromJson({
      'version': '2026-08-30T14:13:29Z',
      'counts': {'14': 3507, '01': 9600},
      'hazards': ['洪水', '土砂', '高潮', '地震', '津波', '火事', '内水', '火山'],
      'notice': '注意',
      'attribution': '出典：国土地理院「指定緊急避難場所データ」',
    });
    expect(idx.version, '2026-08-30T14:13:29Z');
    expect(idx.counts['14'], 3507);
    expect(idx.hazards.length, 8);
    expect(ShelterIndex.fromJson({}).hazards, ShelterLayers.defaultHazards);
  });

  test('表示範囲内のカメラの県の集合を返し、無ければ中心から最寄りの県', () {
    final cams = [
      cam('yokohama', '14', 35.45, 139.63),
      cam('tokyo', '13', 35.68, 139.76),
      cam('sapporo', '01', 43.06, 141.35),
      cam('world', '99', 35.5, 139.6), // 海外は除外
      cam('unknown', '00', 35.5, 139.6), // 県不明は除外
    ];
    expect(
      ShelterLayers.prefsForBounds(cams,
          south: 35.4, north: 35.7, west: 139.5, east: 139.8, center: const LatLng(35.55, 139.65)),
      {'14', '13'},
    );
    // 範囲内にカメラが無い（海上など）→ 中心から最寄りのカメラの県
    expect(
      ShelterLayers.prefsForBounds(cams,
          south: 42.0, north: 42.2, west: 140.0, east: 140.2, center: const LatLng(42.1, 140.1)),
      {'01'},
    );
    expect(ShelterLayers.prefsForBounds(const [],
        south: 0, north: 1, west: 0, east: 1, center: const LatLng(0.5, 0.5)), isEmpty);
  });

  test('表示範囲でのカリングと災害種別フィルタ', () {
    final list = [
      sh('a', 35.45, 139.60, f: [0, 3]),
      sh('b', 35.46, 139.61, f: [3]),
      sh('c', 36.00, 139.60, f: [0]), // 範囲外
    ];
    final culled = ShelterLayers.cull(list, south: 35.4, north: 35.5, west: 139.5, east: 139.7);
    expect(culled.map((s) => s.id), ['a', 'b']);
    expect(ShelterLayers.filterByHazard(culled, null).length, 2);
    expect(ShelterLayers.filterByHazard(culled, 0).map((s) => s.id), ['a']);
    expect(ShelterLayers.filterByHazard(culled, 3).map((s) => s.id), ['a', 'b']);
    expect(ShelterLayers.filterByHazard(culled, 7), isEmpty);
  });

  test('経路URL（iOS=Apple Maps / Android=Google Maps）', () {
    final s = sh('a', 35.457, 139.523);
    expect(ShelterLayers.routeUri(s, android: false).toString(),
        'https://maps.apple.com/?daddr=35.457,139.523');
    expect(ShelterLayers.routeUri(s, android: true).toString(),
        contains('destination=35.457,139.523'));
  });

  test('汎用クラスタリングで件数が保存される', () {
    final list = [for (var i = 0; i < 50; i++) sh('$i', 35.45 + i * 0.0001, 139.6 + i * 0.0001)];
    final groups = clusterPoints(list, 11.0, (s) => s.lat, (s) => s.lng);
    expect(groups.fold<int>(0, (a, g) => a + g.count), 50);
    expect(groups.length, lessThan(50));
  });

  group('ShelterStore', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('shelters_test');
    });
    tearDown(() => dir.delete(recursive: true));

    http.Client client(Map<String, dynamic> index, Map<String, Map<String, dynamic>> files, List<String> log) =>
        MockClient((req) async {
          log.add(req.url.path);
          final name = req.url.pathSegments.last.replaceAll('.json', '');
          // 日本語を含むためUTF-8で返す（既定のlatin1では壊れる）
          http.Response ok(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
          if (name == 'index') return ok(index);
          final f = files[name];
          return f == null ? http.Response('nf', 404) : ok(f);
        });

    test('表示範囲の県だけ取得し、2回目はディスクキャッシュを使う', () async {
      final log = <String>[];
      final index = {'version': 'v1', 'hazards': ShelterLayers.defaultHazards};
      final store = ShelterStore(cacheDir: dir, client: client(index, {'14': _prefJson}, log));
      final done = Completer<void>();
      store.addListener(() {
        if (store.hasPref('14') && !done.isCompleted) done.complete();
      });
      store.request(['14']);
      await done.future.timeout(const Duration(seconds: 5));
      expect(store.sheltersFor(['14']).length, 2);
      expect(store.sheltersFor(['13']), isEmpty);
      expect(log, containsAll(['/livecam-jp/v1/shelters/index.json', '/livecam-jp/v1/shelters/14.json']));
      expect(File('${dir.path}/shelters_14.json').existsSync(), isTrue);

      // 新しいストア（次回起動相当）: index は取得するが県ファイルはネットワークを使わない
      final log2 = <String>[];
      final store2 = ShelterStore(cacheDir: dir, client: client(index, {}, log2));
      final done2 = Completer<void>();
      store2.addListener(() {
        if (store2.hasPref('14') && !done2.isCompleted) done2.complete();
      });
      store2.request(['14']);
      await done2.future.timeout(const Duration(seconds: 5));
      expect(store2.sheltersFor(['14']).length, 2);
      expect(log2.where((p) => p.endsWith('/14.json')), isEmpty);

      // index.version が変わったら再取得する
      final log3 = <String>[];
      final newFile = Map<String, dynamic>.from(_prefJson)..['version'] = 'v2';
      final store3 = ShelterStore(cacheDir: dir, client: client({'version': 'v2'}, {'14': newFile}, log3));
      final done3 = Completer<void>();
      store3.addListener(() {
        if (store3.hasPref('14') && !done3.isCompleted) done3.complete();
      });
      store3.request(['14']);
      await done3.future.timeout(const Duration(seconds: 5));
      expect(log3.where((p) => p.endsWith('/14.json')).length, 1);
    });

    test('取得失敗は failed に記録され、retry で即時に取り直す', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (req.url.path.endsWith('index.json')) {
          return http.Response.bytes(utf8.encode(jsonEncode({'version': 'v1', 'hazards': []})), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (calls <= 2) return http.Response('down', 503);
        return http.Response.bytes(
            utf8.encode(jsonEncode({'version': 'v1', 'pref': '14', 'shelters': []})), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final dir = await Directory.systemTemp.createTemp('shelter_fail');
      final store = ShelterStore(cacheDir: dir, client: client);
      store.request(['14']);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(store.failed, contains('14'));
      // 30秒以内の自動再要求は抑制される
      store.request(['14']);
      expect(store.loading, isFalse);
      // 利用者の再試行は即時
      store.retry(['14']);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(store.failed, isEmpty);
      expect(store.hasPref('14'), isTrue);
    });

    test('取得失敗は失敗として記録され、直後の自動再要求は抑制・強制再要求は即時', () async {
      final log = <String>[];
      final store = ShelterStore(cacheDir: dir, client: client({'version': 'v1'}, {}, log));
      store.request(['13']);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(store.hasPref('13'), isFalse);
      expect(store.loading, isFalse);
      expect(store.failed, contains('13'));
      store.request(['13']); // 30秒以内 → 抑制（連続アクセスを防ぐ）
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(log.where((p) => p.endsWith('/13.json')).length, 1);
      store.request(['13'], force: true); // 利用者の再試行相当
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(log.where((p) => p.endsWith('/13.json')).length, 2);
    });
  });
}
