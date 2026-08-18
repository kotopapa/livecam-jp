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
  final located = cameras.where((c) => c.hasLocation);
  if (zoom >= maxSingleZoom) {
    return [for (final c in located) MapItem.single(c)];
  }
  final cell = cellSizeForZoom(zoom);
  final buckets = <(int, int), List<Camera>>{};
  for (final c in located) {
    final key = ((c.lat! / cell).floor(), (c.lng! / cell).floor());
    (buckets[key] ??= []).add(c);
  }
  final items = <MapItem>[];
  for (final group in buckets.values) {
    if (group.length == 1) {
      items.add(MapItem.single(group.first));
    } else {
      final lat = group.map((c) => c.lat!).reduce((a, b) => a + b) / group.length;
      final lng = group.map((c) => c.lng!).reduce((a, b) => a + b) / group.length;
      items.add(MapItem.cluster(group, lat, lng));
    }
  }
  return items;
}
