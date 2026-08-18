import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../models/camera.dart';
import '../util/clustering.dart';
import 'detail_screen.dart';
import 'pin_style.dart';

/// 地図画面（SPEC 9.2②）。
/// 地理院タイル + カテゴリ色ピン + 位置未確定の黄縁取り + クラスタリング。
/// ピンをタップすると詳細画面へ直接遷移する。
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.app});

  final AppState app;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCenter = LatLng(36.2, 138.25); // 本州中心
  static const _initialZoom = 5.0;

  final MapController _controller = MapController();
  double _zoom = _initialZoom;
  LatLng? _myLocation;
  bool _locating = false;

  /// 現在地ボタン（SPEC 9.2②）。権限を確認して現在地へ移動する
  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('位置情報の利用が許可されていません（設定から変更できます）');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium))
          .timeout(const Duration(seconds: 10));
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = here);
      _controller.move(here, 12);
      setState(() => _zoom = 12);
    } catch (_) {
      _showMessage('現在地を取得できませんでした');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  void _zoomBy(double delta) {
    final z = (_controller.camera.zoom + delta).clamp(4.0, 18.0);
    _controller.move(_controller.camera.center, z);
    setState(() => _zoom = z);
  }

  /// 凡例 + カテゴリフィルタのボトムシート
  void _showLegendFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final app = widget.app;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('凡例・絞り込み',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in categoryLabels.entries)
                      FilterChip(
                        avatar: CircleAvatar(
                            backgroundColor: categoryColor(entry.key),
                            radius: 6),
                        label: Text(entry.value),
                        selected: app.enabledCategories.contains(entry.key),
                        onSelected: (_) {
                          app.toggleCategory(entry.key);
                          setSheetState(() {});
                        },
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('動画カメラのみ'),
                  value: app.videoOnly,
                  onChanged: (v) {
                    app.setVideoOnly(v);
                    setSheetState(() {});
                  },
                ),
                const Divider(),
                const _LegendRow(
                    kind: _LegendKind.liveDot, text: '赤ドット = 動画（ライブ配信）'),
                const _LegendRow(
                    kind: _LegendKind.uncertain, text: '黄色の縁 = 位置未確定（おおよそ/代表点）'),
                const _LegendRow(
                    kind: _LegendKind.frozen, text: '半透明 = 画像が長時間更新されていない'),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _openDetail(Camera camera) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(camera: camera, app: widget.app),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = clusterCameras(widget.app.displayableCameras, _zoom);
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            minZoom: 4,
            maxZoom: 18,
            onPositionChanged: (camera, _) {
              if ((camera.zoom - _zoom).abs() >= 0.5) {
                setState(() => _zoom = camera.zoom);
              }
            },
          ),
          children: [
            TileLayer(
              // 地理院タイル(淡色)。出典表示は必須（SPEC 9.5）
              urlTemplate:
                  'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
              userAgentPackageName: 'jp.livecam.livecam_jp',
            ),
            MarkerLayer(
              markers: [
                for (final item in items)
                  if (item.isCluster)
                    Marker(
                      point: LatLng(item.latitude, item.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _controller.move(
                          LatLng(item.latitude, item.longitude),
                          _zoom + 2,
                        ),
                        child: ClusterPin(count: item.count),
                      ),
                    )
                  else
                    Marker(
                      point: LatLng(item.latitude, item.longitude),
                      width: 26,
                      height: 26,
                      child: GestureDetector(
                        onTap: () => _openDetail(item.camera!),
                        child: CameraPin(
                          camera: item.camera!,
                          state: widget.app.stateOf(item.camera!),
                        ),
                      ),
                    ),
              ],
            ),
            if (_myLocation != null)
              MarkerLayer(markers: [
                Marker(
                  point: _myLocation!,
                  width: 20,
                  height: 20,
                  child: const _MyLocationDot(),
                ),
              ]),
            const Align(
              alignment: Alignment.bottomLeft,
              child: _GsiAttribution(),
            ),
          ],
        ),
        if (widget.app.notice != null) _NoticeBanner(text: widget.app.notice!),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 12,
          child: FloatingActionButton.small(
            heroTag: 'legend_filter',
            onPressed: () => _showLegendFilter(context),
            child: const Icon(Icons.layers_outlined),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FloatingActionButton.small(
              heroTag: 'zoom_in',
              onPressed: () => _zoomBy(1),
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'zoom_out',
              onPressed: () => _zoomBy(-1),
              child: const Icon(Icons.remove),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'my_location',
              onPressed: _goToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ]),
        ),
      ],
    );
  }
}

enum _LegendKind { liveDot, uncertain, frozen }

/// 凡例の1行（マーカー例 + 説明）。
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.kind, required this.text});

  final _LegendKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Widget sample = switch (kind) {
      _LegendKind.liveDot => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: liveDotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5))),
      _LegendKind.uncertain => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: uncertainBorderColor, width: 3))),
      _LegendKind.frozen => Opacity(
          opacity: 0.45,
          child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                  color: Color(0xFF1E6FD9), shape: BoxShape.circle))),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 20, child: Center(child: sample)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}

/// 現在地の青い点。
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
    );
  }
}

class _GsiAttribution extends StatelessWidget {
  const _GsiAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.white70,
      child: const Text('地理院タイル', style: TextStyle(fontSize: 10)),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFFF3CD),
        padding: const EdgeInsets.all(8),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
