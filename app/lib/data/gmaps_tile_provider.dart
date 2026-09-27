import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_maps_flutter/google_maps_flutter.dart' show Tile, TileProvider;
import 'package:http/http.dart' as http;

/// URLテンプレート（`{z}/{x}/{y}`）から google_maps_flutter 用のタイルを取得する
/// 汎用 TileProvider（GoogleMap移行 第2段階。docs/google_maps_migration.md）。
///
/// - [tms] が true なら y を南西始点（TMS）に変換する（今昔マップ用）
/// - [minZoom]/[maxZoom] の範囲外は `TileProvider.noTile`（透明）を返す
/// - [evenZoomOnly] が true なら奇数ズームは1段下の偶数ズームの親タイルを取得し、
///   該当する4分の1を2倍に拡大して返す（気象庁タイルの `zoomUse="even"` 対策。
///   象限の特定は [UrlTileProvider.parentFor] を流用。補間なし）
/// - 取得失敗・404・本文0バイトは `TileProvider.noTile`
/// - 同一URLの同時要求は Future をまとめ、取得結果（成功/失敗とも）はメモリLRU
///   （[_cacheLimit] 枚）で控える
///
/// 時刻更新（雨雲のスライダー・10分ごとの更新）は [template] を書き換えるだけにし、
/// `TileOverlayId` は変えない。呼び出し側は書き換え後に
/// `GoogleMapController.clearTileCache(id)` を呼ぶこと（このクラス自身は
/// controller を持たないため。map_screen.dart 側で行う）
class UrlTileProvider implements TileProvider {
  UrlTileProvider({
    required this.template,
    this.tms = false,
    this.minZoom,
    this.maxZoom,
    this.headers,
    this.evenZoomOnly = false,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// タイルURLのテンプレート（`{z}/{x}/{y}` を含む）。書き換え後は呼び出し側で
  /// `GoogleMapController.clearTileCache(id)` を呼ぶこと（このクラス自身は
  /// controller を持たない）
  String template;
  final bool tms;
  final int? minZoom;
  final int? maxZoom;
  final Map<String, String>? headers;
  final bool evenZoomOnly;
  final http.Client _client;
  final bool _ownsClient;

  static const _cacheLimit = 100;

  /// URL → 取得済みバイト列（失敗は null）。挿入順を保つ LinkedHashMap で簡易LRU
  /// にする（先頭が最も古い。参照時に末尾へ移す）
  final LinkedHashMap<String, Uint8List?> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inflight = {};

  /// 気象庁タイル等（偶数ズームのみ生成。properties.xml の `zoomUse="even"`）用。
  /// 奇数ズームの (z, x, y) → 取得元の親タイル (z-1, x>>1, y>>1) と、その中の
  /// 位置 (qx, qy)（0 または 1）。偶数ズームなら null
  /// （旧 lib/data/even_zoom_tile_provider.dart から移設。GoogleMap移行 第3段階
  /// で flutter_map 依存を切るため）
  static ({int z, int x, int y, int qx, int qy})? parentFor(int z, int x, int y) {
    if (z.isEven) return null;
    return (z: z - 1, x: x >> 1, y: y >> 1, qx: x & 1, qy: y & 1);
  }

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) return TileProvider.noTile;
    if (minZoom != null && zoom < minZoom!) return TileProvider.noTile;
    // 配信元の最大ズームより拡大したときは、最大ズーム（偶数ズーム限定なら
    // それ以下の偶数）の祖先タイルの該当部分を拡大して返す（旧 flutter_map の
    // maxNativeZoom 相当。無いとズームインした瞬間にレイヤーが消えていた）
    var srcZ = zoom;
    if (maxZoom != null && zoom > maxZoom!) srcZ = maxZoom!;
    if (evenZoomOnly && srcZ.isOdd) srcZ -= 1;
    final d = zoom - srcZ;
    if (d > 6) return TileProvider.noTile; // 64倍超は粗すぎるので出さない
    Uint8List? bytes;
    if (d == 0) {
      bytes = await _fetch(zoom, x, y);
    } else {
      final src = await _fetch(srcZ, x >> d, y >> d);
      if (src != null) {
        final mask = (1 << d) - 1;
        try {
          bytes = await _extractPart(src, 1 << d, x & mask, y & mask);
        } catch (_) {
          bytes = null; // 破損データ等は透明タイル
        }
      }
    }
    if (bytes == null || bytes.isEmpty) return TileProvider.noTile;
    return Tile(256, 256, bytes);
  }

  /// 祖先PNGを [div]×[div] に分けた (sx, sy) 番目を [size]px 四方に拡大したPNG（補間なし）
  Future<Uint8List> _extractPart(Uint8List parentPng, int div, int sx, int sy,
      {int size = 256}) async {
    final codec = await ui.instantiateImageCodec(parentPng);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    try {
      final w = img.width / div;
      final h = img.height / div;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(sx * w, sy * h, w, h),
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.none,
      );
      final out = await recorder.endRecording().toImage(size, size);
      try {
        final data = await out.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      } finally {
        out.dispose();
      }
    } finally {
      img.dispose();
    }
  }

  String _urlFor(int z, int x, int y) {
    // TMS（今昔マップ）は y が南西始点
    final ty = tms ? ((1 << z) - 1 - y) : y;
    return template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$ty');
  }

  Future<Uint8List?> _fetch(int z, int x, int y) {
    final url = _urlFor(z, x, y);
    if (_cache.containsKey(url)) {
      // LRU: 参照したら末尾（最新）に移す
      final v = _cache.remove(url);
      _cache[url] = v;
      return Future.value(v);
    }
    final pending = _inflight[url];
    if (pending != null) return pending;
    final future = _fetchNetwork(url);
    _inflight[url] = future;
    return future.whenComplete(() => _inflight.remove(url));
  }

  Future<Uint8List?> _fetchNetwork(String url) async {
    Uint8List? bytes;
    try {
      final res = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        bytes = res.bodyBytes;
      }
    } catch (_) {
      bytes = null;
    }
    _cache[url] = bytes;
    if (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    return bytes;
  }

  /// レイヤーを外す等で不要になったら呼ぶ（自前で作った http.Client を閉じる。
  /// 呼び出し側から渡された client は閉じない）
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
