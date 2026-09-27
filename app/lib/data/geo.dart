import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// 緯度経度の矩形（GoogleMap移行 第3段階。docs/google_maps_migration.md）。
///
/// map_screen.dart は表示範囲の保持・「地図を寄せる」計算にだけ矩形を使い、
/// 地図描画そのものは gmaps.LatLngBounds（境界で変換）に任せている。
/// 以前は flutter_map の `LatLngBounds` をそのまま使っていたが、地図画面から
/// flutter_map を外すためここに最小限のサブセット（コンストラクタ2種・
/// south/north/west/east）だけを持つ軽量な自前実装を置く。
class LatLngBounds {
  /// 対角の2点（順不同）から矩形を作る（flutter_map の `LatLngBounds(a, b)` 相当）
  LatLngBounds(LatLng corner1, LatLng corner2)
      : south = math.min(corner1.latitude, corner2.latitude),
        north = math.max(corner1.latitude, corner2.latitude),
        west = math.min(corner1.longitude, corner2.longitude),
        east = math.max(corner1.longitude, corner2.longitude);

  LatLngBounds._(this.south, this.north, this.west, this.east);

  /// 複数地点の外接矩形（flutter_map の `LatLngBounds.fromPoints` 相当）。
  /// [points] は1点以上必須
  factory LatLngBounds.fromPoints(List<LatLng> points) {
    assert(points.isNotEmpty);
    var south = points.first.latitude, north = points.first.latitude;
    var west = points.first.longitude, east = points.first.longitude;
    for (final p in points.skip(1)) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    return LatLngBounds._(south, north, west, east);
  }

  final double south;
  final double north;
  final double west;
  final double east;
}
