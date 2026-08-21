import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_state.dart';
import '../models/camera.dart';
import '../util/geo.dart';
import 'detail_screen.dart';
import 'pin_style.dart';
import 'ranking_screen.dart';

/// 一覧タブ（SPEC 9.2④）。
/// 検索は地図と共通のフィルタ（AppState.searchQuery）を使い、
/// 現在地が取れれば近い順・取れなければ北から順に並べる。
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.app});

  final AppState app;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  // IME対策: コントローラは画面と同寿命で保持する（毎buildで作らない）
  late final TextEditingController _searchController;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.app.searchQuery);
    widget.app.addListener(_onChanged);
    // 一覧は常に現在地から近い順で表示する（初回に許可を確認。
    // 拒否された場合は北から順で表示し、案内行は出さない）
    _loadPosition(request: true);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// [request] が false のときは許可済みの場合のみ取得する。
  /// 起動直後に許可ダイアログを出さないため、要求はユーザー操作時に限る
  Future<void> _loadPosition({bool request = false}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.low));
      if (mounted) setState(() => _position = pos);
    } catch (_) {
      // 位置が取れなくても一覧は使える（距離なし表示）
    }
  }

  List<(Camera, double?)> _sortedCameras() {
    final cams = widget.app.displayableCameras;
    if (_position == null) {
      // 現在地なし: 北から順（緯度降順）で安定した並びにする
      final list = [for (final c in cams) (c, null as double?)];
      list.sort((a, b) => (b.$1.lat ?? 0).compareTo(a.$1.lat ?? 0));
      return list;
    }
    final list = [
      for (final c in cams)
        (
          c,
          c.hasLocation
              ? distanceMeters(
                  _position!.latitude, _position!.longitude, c.lat!, c.lng!)
              : null,
        )
    ];
    list.sort((a, b) => (a.$2 ?? double.infinity)
        .compareTo(b.$2 ?? double.infinity));
    return list;
  }

  String _distanceLabel(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)}km';
  }

  @override
  Widget build(BuildContext context) {
    final cams = _sortedCameras();
    return Scaffold(
      appBar: AppBar(
        title: Text('一覧（${cams.length}）'),
        actions: [
          IconButton(
            tooltip: 'ランキング',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RankingScreen(app: widget.app))),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'カメラ名・河川名・路線名で検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: widget.app.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          widget.app.setSearchQuery('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
              ),
              onChanged: widget.app.setSearchQuery,
            ),
          ),
        ),
      ),
      body: cams.isEmpty
          ? const Center(child: Text('条件に合うカメラがありません'))
          : ListView.separated(
              itemCount: cams.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final (camera, dist) = cams[i];
                return _CameraTile(
                  camera: camera,
                  app: widget.app,
                  distanceLabel: _distanceLabel(dist),
                );
              },
            ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile(
      {required this.camera, required this.app, required this.distanceLabel});

  final Camera camera;
  final AppState app;
  final String distanceLabel;

  @override
  Widget build(BuildContext context) {
    final url = app.imageUrlFor(camera);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 72,
          height: 48,
          child: url != null
              ? Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder())
              : _placeholder(),
        ),
      ),
      title: Text(camera.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [if (camera.isVideo) 'LIVE', camera.operator].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: categoryColor(camera.category),
                shape: BoxShape.circle),
          ),
          if (distanceLabel.isNotEmpty)
            Text(distanceLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DetailScreen(camera: camera, app: app))),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey[300],
        alignment: Alignment.center,
        child: Icon(
            camera.isVideo ? Icons.play_circle_outline : Icons.photo_camera,
            size: 20,
            color: Colors.grey[600]),
      );
}
