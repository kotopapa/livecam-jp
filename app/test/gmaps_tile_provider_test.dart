import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show Tile;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/gmaps_tile_provider.dart';

/// 4色の2×2画像（qy行×qx列）をPNGにエンコードする（親タイルのフィクスチャ用）
Future<Uint8List> _quadrantPng(List<List<Color>> byRow) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var qy = 0; qy < 2; qy++) {
    for (var qx = 0; qx < 2; qx++) {
      canvas.drawRect(
        ui.Rect.fromLTWH(qx.toDouble(), qy.toDouble(), 1, 1),
        ui.Paint()..color = byRow[qy][qx],
      );
    }
  }
  final img = await recorder.endRecording().toImage(2, 2);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

/// PNGを1点デコードし、その画素の色を返す（拡大後タイルの検証用）
Future<Color> _pixelAt(Uint8List png, int x, int y) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final i = (y * img.width + x) * 4;
  final c = Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  img.dispose();
  return c;
}

void main() {
  // 気象庁タイルは偶数ズームしか生成されない（zoomUse="even"）。奇数ズームの
  // タイルは1段下の偶数ズームの親タイルの4分の1から作る
  // （旧 test/jma_tile_zoom_test.dart から移設。GoogleMap移行 第3段階）
  group('parentFor', () {
    test('偶数ズームはそのまま（親なし）', () {
      for (final z in [4, 6, 8, 10]) {
        expect(UrlTileProvider.parentFor(z, 123, 45), isNull);
      }
    });

    test('奇数ズームは親タイルと4分の1の位置を返す', () {
      // z7 の (113, 51) → z6 の (56, 25) の右下
      final p = UrlTileProvider.parentFor(7, 113, 51)!;
      expect((p.z, p.x, p.y, p.qx, p.qy), (6, 56, 25, 1, 1));
      // z7 の (112, 50) → 同じ親の左上
      final q = UrlTileProvider.parentFor(7, 112, 50)!;
      expect((q.z, q.x, q.y, q.qx, q.qy), (6, 56, 25, 0, 0));
      // z9 の (455, 201) → z8 の (227, 100) の右下
      final r = UrlTileProvider.parentFor(9, 455, 201)!;
      expect((r.z, r.x, r.y, r.qx, r.qy), (8, 227, 100, 1, 1));
    });

    test('親の4分の1は必ず4通りのどれかに落ちる', () {
      final seen = <(int, int)>{};
      for (var x = 0; x < 4; x++) {
        for (var y = 0; y < 4; y++) {
          final p = UrlTileProvider.parentFor(5, x, y)!;
          seen.add((p.qx, p.qy));
          expect(p.x, x ~/ 2);
          expect(p.y, y ~/ 2);
        }
      }
      expect(seen, {(0, 0), (0, 1), (1, 0), (1, 1)});
    });
  });

  testWidgets('tms は y を南西始点に変換する', (tester) async {
    Uri? requested;
    final provider = UrlTileProvider(
      template: 'https://example.jp/{z}/{x}/{y}.png',
      tms: true,
      client: MockClient((req) async {
        requested = req.url;
        return http.Response.bytes(const [], 404);
      }),
    );
    // z=4 → 1軸16タイル。y=5 → 南西始点では 15-5=10
    await tester.runAsync(() => provider.getTile(3, 5, 4));
    expect(requested, isNotNull);
    expect(requested!.path, '/4/3/10.png');
  });

  testWidgets('最小ズーム未満は通信せず noTile、最大ズーム超は祖先タイルを取りに行く', (tester) async {
    final urls = <String>[];
    final provider = UrlTileProvider(
      template: 'https://example.jp/{z}/{x}/{y}.png',
      minZoom: 4,
      maxZoom: 10,
      client: MockClient((req) async {
        urls.add(req.url.path);
        return http.Response.bytes(const [], 404);
      }),
    );
    final below = await provider.getTile(0, 0, 3);
    expect(below.data, isNull);
    expect(urls, isEmpty);
    // z12 の (13, 7) → z10 の (3, 1) を取得（拡大は取得成功時のみ）
    await tester.runAsync(() => provider.getTile(13, 7, 12));
    expect(urls, ['/10/3/1.png']);
    // 7段以上の拡大は粗すぎるので取りに行かない
    urls.clear();
    final far = await provider.getTile(0, 0, 17);
    expect(far.data, isNull);
    expect(urls, isEmpty);
  });

  testWidgets('取得失敗（404・空本文）は noTile', (tester) async {
    final provider404 = UrlTileProvider(
      template: 'https://example.jp/{z}/{x}/{y}.png',
      client: MockClient((req) async => http.Response.bytes(const [], 404)),
    );
    final provider0 = UrlTileProvider(
      template: 'https://example.jp/{z}/{x}/{y}.png',
      client: MockClient((req) async => http.Response.bytes(const [], 200)),
    );
    late Tile t404, t0;
    await tester.runAsync(() async {
      t404 = await provider404.getTile(1, 1, 5);
      t0 = await provider0.getTile(1, 1, 5);
    });
    expect(t404.data, isNull);
    expect(t0.data, isNull);
  });

  testWidgets('奇数ズームは親タイルの4分の1を拡大して返す（4象限とも正しい）',
      (tester) async {
    // MaterialColor（Colors.red 等）は値が同じでも Color と型が異なり
    // expect() の等値比較で失敗するため、素の Color 定数を使う
    const red = Color(0xFFFF0000);
    const green = Color(0xFF00FF00);
    const blue = Color(0xFF0000FF);
    const yellow = Color(0xFFFFFF00);
    late Uint8List parentPng;
    await tester.runAsync(() async {
      parentPng = await _quadrantPng([
        [red, green], // qy=0: 左上=red 右上=green
        [blue, yellow], // qy=1: 左下=blue 右下=yellow
      ]);
    });
    final provider = UrlTileProvider(
      template: 'https://example.jp/{z}/{x}/{y}.png',
      evenZoomOnly: true,
      client: MockClient((req) async => http.Response.bytes(parentPng, 200)),
    );

    // z7 の (112,50)→左上(qx0,qy0)、(113,50)→右上(qx1,qy0)、
    // (112,51)→左下(qx0,qy1)、(113,51)→右下(qx1,qy1)。いずれも親は z6 (56,25)
    final cases = <(int, int, Color)>[
      (112, 50, red),
      (113, 50, green),
      (112, 51, blue),
      (113, 51, yellow),
    ];
    for (final (x, y, expected) in cases) {
      late Tile tile;
      late Color center;
      await tester.runAsync(() async {
        tile = await provider.getTile(x, y, 7);
        center = await _pixelAt(tile.data!, 128, 128);
      });
      expect(tile.width, 256);
      expect(tile.height, 256);
      expect(center, expected, reason: 'x=$x y=$y');
    }
  });

  testWidgets('偶数ズームはそのまま取得する（親タイル化しない）', (tester) async {
    final requestedUrls = <String>[];
    final provider = UrlTileProvider(
      template: 'https://example.jp/{z}/{x}/{y}.png',
      evenZoomOnly: true,
      client: MockClient((req) async {
        requestedUrls.add(req.url.path);
        return http.Response.bytes(const [], 404);
      }),
    );
    await tester.runAsync(() => provider.getTile(10, 20, 6));
    expect(requestedUrls, ['/6/10/20.png']);
  });
}
