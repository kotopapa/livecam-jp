import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:livecam_jp/data/facility_layers.dart';
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

Facility fac(String id, double lat, double lng,
        {String k = 'fire_water', int s = 0, bool g = false, String pref = '14'}) =>
    Facility(
      id: id,
      pref: pref,
      name: id,
      address: '',
      lat: lat,
      lng: lng,
      kind: k,
      owner: '真鶴町',
      sourceIndex: s,
      geocoded: g,
    );

/// 実際の配信ファイル（/v1/facilities/14.json）と同じ形
const _prefJson = {
  'version': 'v1',
  'pref': '14',
  'sources': [
    {
      'portal': 'BODIK ODCS（九州・全国自治体共同カタログ）',
      'org': '真鶴町',
      'title': '防火水槽',
      'url': 'https://data.bodik.jp/dataset/143839_bokasuiso',
      'license': 'CC BY',
      'license_id': 'cc-by-40-intl',
      'kind': 'fire_water',
      'count': 86,
    },
    {
      'org': '横浜市水道局',
      'title': '応急給水所',
      'url': '',
      'license': '',
      'kind': 'water',
      'count': 2,
    },
  ],
  'facilities': [
    {'id': '6-0', 'n': '防火水槽', 'a': '', 'k': 'fire_water', 'o': '真鶴町', 's': 0, 'lat': 35.15559, 'lng': 139.13255},
    {'id': '7-0', 'n': '本所防災備蓄倉庫', 'a': '墨田区本所2-6-9', 'k': 'stock', 'o': '墨田区', 's': 1, 'lat': 35.70291, 'lng': 139.80087, 'g': 1},
    {'id': '8-0', 'n': '給水所', 'a': '', 'k': 'water', 'o': '横浜市水道局', 's': 9, 'lat': 35.45, 'lng': 139.6},
    {'id': '9-0', 'n': '種別なし', 'lat': 35.4, 'lng': 139.6}, // k 欠落
    {'id': '', 'n': 'IDなし', 'k': 'water', 'lat': 35.4, 'lng': 139.6},
    {'id': 'X', 'n': '座標なし', 'k': 'water'},
    'broken',
  ],
};

void main() {
  test('県ファイルのJSONを解析し、壊れたレコードは読み飛ばす', () {
    final list = FacilityLayers.parseFile(_prefJson);
    expect(list.map((f) => f.id), ['6-0', '7-0', '8-0']);
    expect(list.first.name, '防火水槽');
    expect(list.first.kind, 'fire_water');
    expect(list.first.owner, '真鶴町');
    expect(list.first.sourceIndex, 0);
    expect(list.first.geocoded, isFalse);
    expect(list.first.pref, '14'); // 出典解決のため県を持たせる
    expect(list.first.pos, const LatLng(35.15559, 139.13255));
    expect(list[1].geocoded, isTrue); // g:1 = 住所からの座標補完
    expect(list[1].address, '墨田区本所2-6-9');
  });

  test('sources[] の解析と s による出典の解決（範囲外は null）', () {
    final sources = FacilityLayers.parseSources(_prefJson);
    expect(sources.length, 2);
    expect(sources.first.org, '真鶴町');
    expect(sources.first.license, 'CC BY');
    expect(sources.first.label, '真鶴町「防火水槽」（CC BY）');
    expect(sources[1].label, '横浜市水道局「応急給水所」'); // ライセンス表記なし

    final list = FacilityLayers.parseFile(_prefJson);
    expect(FacilityLayers.resolveSource(sources, list[0].sourceIndex)?.title, '防火水槽');
    expect(FacilityLayers.resolveSource(sources, list[1].sourceIndex)?.title, '応急給水所');
    expect(FacilityLayers.resolveSource(sources, list[2].sourceIndex), isNull); // s=9 は範囲外
    expect(FacilityLayers.resolveSource(sources, -1), isNull);
    expect(FacilityLayers.resolveSource(const [], 0), isNull);
  });

  test('index.json の解析（kinds・counts・attribution）', () {
    final idx = FacilityIndex.fromJson({
      'version': '2026-08-31T07:15:15Z',
      'counts': {'14': 187, '13': 6829, '01': 0},
      'total': 148871,
      'kinds': {
        'water': '給水拠点・応急給水施設',
        'stock': '防災備蓄倉庫',
        'fire_water': '消防水利（消火栓・防火水槽）',
      },
      'notice': '全国を網羅していません',
      'attribution': '出典：各自治体のオープンデータ（CC BY 等）／住所からの座標補完は国土地理院API',
    });
    expect(idx.version, '2026-08-31T07:15:15Z');
    expect(idx.counts['13'], 6829);
    expect(idx.total, 148871);
    expect(idx.labelOf('fire_water'), '消防水利（消火栓・防火水槽）');
    expect(idx.hasPref('14'), isTrue);
    expect(idx.hasPref('01'), isFalse); // 件数0は未提供扱い
    expect(idx.hasPref('47'), isFalse); // counts に無い県

    // 欠損時は既定にフォールバック
    final empty = FacilityIndex.fromJson({});
    expect(empty.attribution, FacilityLayers.attribution);
    expect(empty.labelOf('water'), '給水拠点・応急給水施設');
    expect(empty.labelOf('unknown'), 'unknown');
  });

  test('index.counts に載っている県だけに絞る（index 未取得なら素通し）', () {
    final idx = FacilityIndex.fromJson({
      'version': 'v1',
      'counts': {'14': 187, '13': 6829},
    });
    expect(FacilityLayers.availablePrefs({'14', '13', '15'}, idx), {'14', '13'});
    expect(FacilityLayers.availablePrefs({'15', '16'}, idx), isEmpty);
    expect(FacilityLayers.availablePrefs({'15'}, null), {'15'});
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
      FacilityLayers.prefsForBounds(cams,
          south: 35.4, north: 35.7, west: 139.5, east: 139.8, center: const LatLng(35.55, 139.65)),
      {'14', '13'},
    );
    expect(
      FacilityLayers.prefsForBounds(cams,
          south: 42.0, north: 42.2, west: 140.0, east: 140.2, center: const LatLng(42.1, 140.1)),
      {'01'},
    );
  });

  test('表示範囲でのカリングと種別フィルタ（複数選択）', () {
    final list = [
      fac('a', 35.45, 139.60, k: 'water'),
      fac('b', 35.46, 139.61, k: 'stock'),
      fac('c', 35.47, 139.62, k: 'fire_water'),
      fac('d', 36.50, 139.60, k: 'water'), // 範囲外
    ];
    final culled = FacilityLayers.cull(list, south: 35.4, north: 35.5, west: 139.5, east: 139.7);
    expect(culled.map((f) => f.id), ['a', 'b', 'c']);
    // 既定（給水＋備蓄。消防水利はOFF）
    expect(
      FacilityLayers.filterByKinds(culled, {...FacilityLayers.defaultSelectedKinds}).map((f) => f.id),
      ['a', 'b'],
    );
    expect(FacilityLayers.filterByKinds(culled, {'fire_water'}).map((f) => f.id), ['c']);
    expect(FacilityLayers.filterByKinds(culled, {...FacilityLayers.kindKeys}).length, 3);
    expect(FacilityLayers.filterByKinds(culled, const {}), isEmpty);
  });

  test('既定の絞り込みは給水拠点＋防災備蓄倉庫（消防水利はOFF）', () {
    expect(FacilityLayers.defaultSelectedKinds, {'water', 'stock'});
    expect(FacilityLayers.kindKeys, ['water', 'stock', 'fire_water']);
    expect(FacilityLayers.shortLabel('water'), '給水拠点');
    expect(FacilityLayers.shortLabel('fire_water'), '消防水利');
  });

  test('選択状態の保存・復元（未保存は既定、空文字はすべてOFF）', () {
    expect(FacilityLayers.encodeKinds({'fire_water', 'water'}), 'water,fire_water'); // 順序を正規化
    expect(FacilityLayers.decodeKinds(null), FacilityLayers.defaultSelectedKinds);
    expect(FacilityLayers.decodeKinds(''), isEmpty);
    expect(FacilityLayers.decodeKinds('water,fire_water'), {'water', 'fire_water'});
    expect(FacilityLayers.decodeKinds('water,bogus'), {'water'}); // 未知のキーは捨てる
    final roundTrip = FacilityLayers.decodeKinds(
        FacilityLayers.encodeKinds({'stock', 'fire_water'}));
    expect(roundTrip, {'stock', 'fire_water'});
  });

  test('クラスタの代表種別は最多、同数なら kindKeys の順', () {
    expect(
        FacilityLayers.dominantKind([
          fac('a', 0, 0, k: 'fire_water'),
          fac('b', 0, 0, k: 'fire_water'),
          fac('c', 0, 0, k: 'water'),
        ]),
        'fire_water');
    expect(
        FacilityLayers.dominantKind([
          fac('a', 0, 0, k: 'fire_water'),
          fac('b', 0, 0, k: 'water'),
        ]),
        'water');
    expect(FacilityLayers.dominantKind(const []), isNull);
  });

  test('汎用クラスタリングで件数が保存される', () {
    final list = [for (var i = 0; i < 50; i++) fac('$i', 35.45 + i * 0.0001, 139.6 + i * 0.0001)];
    final groups = clusterPoints(list, 13.0, (f) => f.lat, (f) => f.lng);
    expect(groups.fold<int>(0, (a, g) => a + g.count), 50);
    expect(groups.length, lessThan(50));
  });

  test('経路URLはGoogleマップ(徒歩)', () {
    final u = FacilityLayers.routeUri(fac('a', 35.457, 139.523));
    expect(u.host, 'www.google.com');
    expect(u.toString(), contains('destination=35.457,139.523'));
    expect(u.toString(), contains('travelmode=walking'));
  });

  group('FacilityStore', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('facilities_test');
    });
    tearDown(() => dir.delete(recursive: true));

    http.Client client(Map<String, dynamic> index, Map<String, Map<String, dynamic>> files,
            List<String> log) =>
        MockClient((req) async {
          log.add(req.url.path);
          final name = req.url.pathSegments.last.replaceAll('.json', '');
          // 日本語を含むためUTF-8で返す（既定のlatin1では壊れる）
          http.Response ok(Object body) => http.Response.bytes(
              utf8.encode(jsonEncode(body)), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
          if (name == 'index') return ok(index);
          final f = files[name];
          return f == null ? http.Response('nf', 404) : ok(f);
        });

    Future<void> waitFor(FacilityStore store, bool Function() done) async {
      final c = Completer<void>();
      void check() {
        if (done() && !c.isCompleted) c.complete();
      }

      store.addListener(check);
      check();
      await c.future.timeout(const Duration(seconds: 5));
    }

    test('表示範囲の県だけ取得し、2回目はディスクキャッシュを使う', () async {
      final log = <String>[];
      final index = {'version': 'v1', 'counts': {'14': 187}};
      final store = FacilityStore(cacheDir: dir, client: client(index, {'14': _prefJson}, log));
      store.request(['14']);
      await waitFor(store, () => store.hasPref('14'));
      expect(store.facilitiesFor(['14']).length, 3);
      expect(store.facilitiesFor(['13']), isEmpty);
      expect(store.sourcesFor('14').length, 2);
      expect(store.sourceOf(store.facilitiesFor(['14']).first)?.title, '防火水槽');
      expect(log,
          containsAll(['/livecam-jp/v1/facilities/index.json', '/livecam-jp/v1/facilities/14.json']));
      expect(File('${dir.path}/facilities_14.json').existsSync(), isTrue);

      // 新しいストア（次回起動相当）: index は取得するが県ファイルはネットワークを使わない
      final log2 = <String>[];
      final store2 = FacilityStore(cacheDir: dir, client: client(index, {}, log2));
      store2.request(['14']);
      await waitFor(store2, () => store2.hasPref('14'));
      expect(store2.facilitiesFor(['14']).length, 3);
      expect(log2.where((p) => p.endsWith('/14.json')), isEmpty);

      // index.version が変わったら再取得する
      final log3 = <String>[];
      final newFile = Map<String, dynamic>.from(_prefJson)..['version'] = 'v2';
      final store3 = FacilityStore(
          cacheDir: dir,
          client: client({'version': 'v2', 'counts': {'14': 187}}, {'14': newFile}, log3));
      store3.request(['14']);
      await waitFor(store3, () => store3.hasPref('14'));
      expect(log3.where((p) => p.endsWith('/14.json')).length, 1);
    });

    test('index.counts に無い県は取得を試みず「データ無し」になる', () async {
      final log = <String>[];
      final index = {'version': 'v1', 'counts': {'14': 187}};
      final store = FacilityStore(cacheDir: dir, client: client(index, {'14': _prefJson}, log));
      store.request(['15']); // 富山県はまだ未提供
      await waitFor(store, () => store.isUnavailable('15'));
      expect(log.where((p) => p.endsWith('/15.json')), isEmpty);
      expect(store.failed, isEmpty); // 失敗ではない
      expect(store.allUnavailable(['15']), isTrue);
      expect(store.allUnavailable(const []), isFalse);

      // 提供県が1つでも混ざれば「データ無し」表示にはしない
      store.request(['14', '15']);
      await waitFor(store, () => store.hasPref('14'));
      expect(store.allUnavailable(['14', '15']), isFalse);
    });

    test('取得失敗は failed に記録され、retry で即時に取り直す', () async {
      var calls = 0;
      final client = MockClient((req) async {
        http.Response ok(Object body) => http.Response.bytes(
            utf8.encode(jsonEncode(body)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
        if (req.url.path.endsWith('index.json')) {
          return ok({'version': 'v1', 'counts': {'14': 187}});
        }
        calls++;
        if (calls <= 1) return http.Response('down', 503);
        return ok({'version': 'v1', 'pref': '14', 'sources': [], 'facilities': []});
      });
      final store = FacilityStore(cacheDir: dir, client: client);
      store.request(['14']);
      await waitFor(store, () => store.failed.contains('14'));

      // 30秒以内の自動再要求は抑制される
      store.request(['14']);
      expect(store.loading, isFalse);

      // 利用者操作の retry は即時に取り直す
      store.retry(['14']);
      await waitFor(store, () => store.hasPref('14'));
      expect(store.failed, isEmpty);
    });
  });
}
