import '../models/camera.dart';

/// 地図用の軽量グリッドクラスタリング。
///
/// ズームレベルに応じた格子にカメラを割り当て、同一セルの複数台を
/// 1つのクラスタにまとめる（SPEC 9.2②の件数バッジ）。外部依存なし。
class MapItem {
  const MapItem.single(Camera this.camera)
      : cameras = const [],
        lat = 0,
        lng = 0;
  const MapItem.cluster(this.cameras, this.lat, this.lng) : camera = null;

  final Camera? camera;
  final List<Camera> cameras;
  final double lat;
  final double lng;

  bool get isCluster => camera == null;
  int get count => isCluster ? cameras.length : 1;
  double get latitude => isCluster ? lat : camera!.lat!;
  double get longitude => isCluster ? lng : camera!.lng!;
}

/// [zoom] における1セルの大きさ（度）。約96px相当のセルで区切る。
double cellSizeForZoom(double zoom) {
  // タイル1枚=256px=360/2^z 度 → 96px セル
  const cellPx = 96.0;
  return 360.0 / (1 << zoom.clamp(0, 22).round()) * (cellPx / 256.0);
}

/// カメラ群をズームに応じてクラスタリングする。
/// [maxSingleZoom] 以上のズームではクラスタリングを行わない（全て個別ピン）。
List<MapItem> clusterCameras(List<Camera> cameras, double zoom,
    {double maxSingleZoom = 13}) {
  final located = cameras.where((c) => c.hasLocation).toList();
  if (zoom >= maxSingleZoom) {
    return [for (final c in located) MapItem.single(c)];
  }
  return [
    for (final g in clusterPoints(located, zoom, (c) => c.lat!, (c) => c.lng!))
      g.items.length == 1
          ? MapItem.single(g.items.first)
          : MapItem.cluster(g.items, g.lat, g.lng)
  ];
}

/// 任意の点群のグリッドクラスタ（避難場所レイヤー等でも流用する）。
/// 1件だけのセルも [PointCluster] として返す（items.length == 1）
class PointCluster<T> {
  const PointCluster(this.items, this.lat, this.lng);
  final List<T> items;
  final double lat;
  final double lng;
  int get count => items.length;
}

List<PointCluster<T>> clusterPoints<T>(List<T> points, double zoom,
    double Function(T) latOf, double Function(T) lngOf) {
  final cell = cellSizeForZoom(zoom);
  final buckets = <(int, int), List<T>>{};
  for (final p in points) {
    final key = ((latOf(p) / cell).floor(), (lngOf(p) / cell).floor());
    (buckets[key] ??= []).add(p);
  }
  return [
    for (final group in buckets.values)
      if (group.length == 1)
        PointCluster(group, latOf(group.first), lngOf(group.first))
      else
        PointCluster(
          group,
          group.map(latOf).reduce((a, b) => a + b) / group.length,
          group.map(lngOf).reduce((a, b) => a + b) / group.length,
        )
  ];
}
