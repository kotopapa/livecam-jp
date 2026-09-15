import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/analytics.dart';
import '../data/route_corridor.dart';
import '../l10n/l10n.dart';
import 'ad_banner.dart';
import 'detail_screen.dart';

/// ルート沿いのカメラ一覧（出発地からの経路上距離の順）
class RouteCamerasScreen extends StatefulWidget {
  const RouteCamerasScreen({super.key, required this.app, required this.cameras});

  final AppState app;
  final List<CorridorCamera> cameras;

  @override
  State<RouteCamerasScreen> createState() => _RouteCamerasScreenState();
}

class _RouteCamerasScreenState extends State<RouteCamerasScreen> {
  @override
  void initState() {
    super.initState();
    Analytics.screen('route_cameras');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeListTitle, overflow: TextOverflow.ellipsis)),
      bottomNavigationBar: AdFooter(app: app),
      body: widget.cameras.isEmpty
          ? Center(child: Text(l10n.routeNoCameras))
          : ListView.separated(
              itemCount: widget.cameras.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == widget.cameras.length) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(RouteCorridor.attribution,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  );
                }
                final cc = widget.cameras[i];
                final camera = cc.camera;
                final url = app.imageUrlFor(camera);
                final km = (cc.alongM / 1000).toStringAsFixed(1);
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72,
                      height: 48,
                      child: url != null
                          ? Image.network(url,
                              fit: BoxFit.cover,
                              cacheWidth: 216,
                              errorBuilder: (_, _, _) =>
                                  Container(color: Colors.grey[300]))
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.videocam,
                                  size: 20, color: Colors.grey[600])),
                    ),
                  ),
                  title: Text(camera.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      l10n.routeAlongKm(km),
                      if (camera.isVideo) 'LIVE',
                      camera.operator,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DetailScreen(camera: camera, app: app))),
                );
              },
            ),
    );
  }
}
