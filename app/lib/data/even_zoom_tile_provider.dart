/// 偶数ズームのタイルしか生成されない配信元（気象庁の雨雲・降水短時間予報・
/// キキクル。各 properties.xml の `zoomUse="even"`）用のタイルプロバイダ。
///
/// 奇数ズーム z のタイルを要求されたら、1段下の偶数ズーム z-1 の親タイルを取得し、
/// 該当する4分の1を2倍に拡大して返す（メッシュ表示なので補間なし）。
/// TileLayer 側は通常の 256px タイルのまま扱えるので、ズームの偶奇でレイヤーを
/// 組み直す必要がなく、ズーム中や時刻更新時に一瞬消える現象も起きない。
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

class EvenZoomTileProvider extends TileProvider {
  EvenZoomTileProvider({super.headers});

  /// 奇数ズームの (z, x, y) → 取得元の親タイル (z-1, x>>1, y>>1) と、
  /// その中の位置 (qx, qy)（0 または 1）。偶数ズームなら null
  static ({int z, int x, int y, int qx, int qy})? parentFor(
      int z, int x, int y) {
    if (z.isEven) return null;
    return (z: z - 1, x: x >> 1, y: y >> 1, qx: x & 1, qy: y & 1);
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final p = parentFor(coordinates.z, coordinates.x, coordinates.y);
    if (p == null) {
      return NetworkImage(getTileUrl(coordinates, options), headers: headers);
    }
    final parentUrl =
        getTileUrl(TileCoordinates(p.x, p.y, p.z), options);
    return QuadrantImage(
      NetworkImage(parentUrl, headers: headers),
      qx: p.qx,
      qy: p.qy,
      size: options.tileDimension,
    );
  }
}

/// 親画像の4分の1（qx, qy）を [size]px 四方に拡大した画像
@immutable
class QuadrantImage extends ImageProvider<QuadrantImage> {
  const QuadrantImage(this.source,
      {required this.qx, required this.qy, this.size = 256});

  final ImageProvider source;
  final int qx;
  final int qy;
  final int size;

  @override
  Future<QuadrantImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<QuadrantImage>(this);

  @override
  ImageStreamCompleter loadImage(
          QuadrantImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load());

  Future<ImageInfo> _load() async {
    final completer = Completer<ImageInfo>();
    final stream = source.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info);
        stream.removeListener(listener);
      },
      onError: (e, s) {
        if (!completer.isCompleted) {
          completer.completeError(e, s ?? StackTrace.current);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final info = await completer.future;
    try {
      final img = info.image;
      final w = img.width / 2;
      final h = img.height / 2;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(qx * w, qy * h, w, h),
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..filterQuality = FilterQuality.none,
      );
      final out = await recorder.endRecording().toImage(size, size);
      return ImageInfo(image: out, scale: info.scale);
    } finally {
      info.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is QuadrantImage &&
      other.source == source &&
      other.qx == qx &&
      other.qy == qy &&
      other.size == size;

  @override
  int get hashCode => Object.hash(source, qx, qy, size);
}
