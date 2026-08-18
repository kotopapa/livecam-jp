import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../models/camera.dart';
import '../models/status.dart';
import '../util/clustering.dart';
import 'pin_style.dart';

/// 地図画面（SPEC 9.2②）。
/// 地理院タイル + カテゴリ色ピン + 位置未確定の黄縁取り + クラスタリング。
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
  Camera? _selected;

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

  @override
  Widget build(BuildContext context) {
    final items = clusterCameras(widget.app.displayableCameras, _zoom);
    return Stack(children: [
      FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: _initialZoom,
          minZoom: 4,
          maxZoom: 18,
          onTap: (_, _) => setState(() => _selected = null),
          onPositionChanged: (camera, _) {
            if ((camera.zoom - _zoom).abs() >= 0.5) {
              setState(() => _zoom = camera.zoom);
            }
          },
        ),
        children: [
          TileLayer(
            // 地理院タイル(淡色)。出典表示は必須（SPEC 9.5）
            urlTemplate: 'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
            userAgentPackageName: 'jp.livecam.livecam_jp',
          ),
          MarkerLayer(markers: [
            for (final item in items)
              if (item.isCluster)
                Marker(
                  point: LatLng(item.latitude, item.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _controller.move(
                        LatLng(item.latitude, item.longitude), _zoom + 2),
                    child: ClusterPin(count: item.count),
                  ),
                )
              else
                Marker(
                  point: LatLng(item.latitude, item.longitude),
                  width: 26,
                  height: 26,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = item.camera),
                    child: CameraPin(
                      camera: item.camera!,
                      state: widget.app.stateOf(item.camera!),
                      selected: identical(_selected, item.camera),
                    ),
                  ),
                ),
          ]),
          const Align(
            alignment: Alignment.bottomLeft,
            child: _GsiAttribution(),
          ),
        ],
      ),
      if (widget.app.notice != null) _NoticeBanner(text: widget.app.notice!),
      if (_selected != null)
        Align(
          alignment: Alignment.bottomCenter,
          child: _PreviewCard(
            camera: _selected!,
            app: widget.app,
            onClose: () => setState(() => _selected = null),
          ),
        ),
    ]);
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

/// ピンタップ時の下部プレビューカード（サムネイル+名前+運営者+取得時刻）。
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.camera,
    required this.app,
    required this.onClose,
  });

  final Camera camera;
  final AppState app;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final imageUrl = app.imageUrlFor(camera);
    final time = app.imageTimeFor(camera);
    final state = app.stateOf(camera);
    return SafeArea(
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 96,
                height: 64,
                child: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _ThumbFallback())
                    : const _ThumbFallback(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(camera.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(camera.operator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  if (time != null)
                    Text(time, style: const TextStyle(fontSize: 12)),
                  Row(children: [
                    if (camera.coordAccuracy.isUncertain)
                      const _Badge(text: '位置未確定', color: uncertainBorderColor),
                    if (state == CameraState.frozen)
                      const _Badge(text: '更新が遅い', color: Colors.grey),
                  ]),
                ],
              ),
            ),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
          ]),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) =>
      Container(color: Colors.grey[300], child: const Icon(Icons.videocam_off));
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }
}
