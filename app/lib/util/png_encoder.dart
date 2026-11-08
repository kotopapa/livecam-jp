import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';

/// 生の RGBA 画素から PNG を組み立てる最小のエンコーダ。
///
/// `image` パッケージの encodePng の代わり（タイル画像の書き出しにしか使って
/// いなかったのに実行コードが数MB増えていた。2026-11-09 アプリサイズ削減）。
/// Flutter の `ImageByteFormat.png`（RGBA＋sBIT）は iOS 実機の Google Maps SDK が
/// 受け付けないため、ここでは sBIT を書かず 8bit の truecolor（＋alpha）で出す。
///
/// [stripAlpha] が true なら RGB（color type 2）、false なら RGBA（color type 6）。
/// フィルタは全行 None（0）。圧縮は zlib レベル 1（速さ優先。タイルは一時的な画像）。
Uint8List encodePngFromRgba(
  int width,
  int height,
  Uint8List rgba, {
  bool stripAlpha = false,
}) {
  assert(rgba.length == width * height * 4);
  final channels = stripAlpha ? 3 : 4;
  final stride = width * channels;
  final raw = Uint8List((stride + 1) * height);
  var o = 0;
  var i = 0;
  for (var y = 0; y < height; y++) {
    raw[o++] = 0; // filter: None
    if (stripAlpha) {
      for (var x = 0; x < width; x++) {
        raw[o++] = rgba[i];
        raw[o++] = rgba[i + 1];
        raw[o++] = rgba[i + 2];
        i += 4;
      }
    } else {
      raw.setRange(o, o + stride, rgba, i);
      o += stride;
      i += stride;
    }
  }
  final idat = ZLibEncoder(level: 1).convert(raw);

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, stripAlpha ? 2 : 6) // color type
    ..setUint8(10, 0) // compression
    ..setUint8(11, 0) // filter
    ..setUint8(12, 0); // interlace

  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _chunk(out, 'IDAT', Uint8List.fromList(idat));
  _chunk(out, 'IEND', Uint8List(0));
  return out.takeBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);
  var crc = _crc32(0xFFFFFFFF, typeBytes);
  crc = _crc32(crc, data);
  final crcBytes = ByteData(4)..setUint32(0, crc ^ 0xFFFFFFFF);
  out.add(crcBytes.buffer.asUint8List());
}

final Uint32List _crcTable = (() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
})();

int _crc32(int crc, Uint8List data) {
  var c = crc;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c;
}
