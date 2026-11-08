import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/util/png_encoder.dart';

Future<ui.Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RGBA の画素が PNG として復号でき、色と透過が保たれる', () async {
    // 2x2: 赤(不透明)・緑(半透明)・青(透明)・白(不透明)
    final rgba = Uint8List.fromList([
      255, 0, 0, 255, //
      0, 255, 0, 128, //
      0, 0, 255, 0, //
      255, 255, 255, 255, //
    ]);
    final png = encodePngFromRgba(2, 2, rgba);
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final img = await _decode(png);
    expect(img.width, 2);
    expect(img.height, 2);
    final out = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
        .buffer
        .asUint8List();
    expect(out.sublist(0, 4), [255, 0, 0, 255]);
    expect(out.sublist(4, 8), [0, 255, 0, 128]);
    expect(out[11], 0); // 透明
    expect(out.sublist(12, 16), [255, 255, 255, 255]);
  });

  test('stripAlpha なら RGB（color type 2）で書き出し、画素は不透明になる', () async {
    final rgba = Uint8List.fromList([10, 20, 30, 0, 40, 50, 60, 255]);
    final png = encodePngFromRgba(2, 1, rgba, stripAlpha: true);
    // IHDR の color type は 8バイト署名 + 4(長さ) + 4(種別) + 9 バイト目
    expect(png[8 + 4 + 4 + 9], 2);
    final img = await _decode(png);
    final out = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
        .buffer
        .asUint8List();
    expect(out, [10, 20, 30, 255, 40, 50, 60, 255]);
  });

  test('256x256 のタイル相当を書き出せる', () async {
    final rgba = Uint8List(256 * 256 * 4);
    for (var i = 0; i < 256 * 256; i++) {
      rgba[i * 4] = i & 0xFF;
      rgba[i * 4 + 1] = (i >> 8) & 0xFF;
      rgba[i * 4 + 3] = 255;
    }
    final img = await _decode(encodePngFromRgba(256, 256, rgba));
    expect(img.width, 256);
    final out = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
        .buffer
        .asUint8List();
    expect(out, rgba);
  });
}
