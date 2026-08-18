import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/camera.dart';
import '../models/status.dart';
import '../util/time_format.dart';
import 'detail_screen.dart';
import 'pin_style.dart';

/// お気に入り画面（SPEC 9.2⑤）。リスト表示とカード（グリッド）表示を切替できる。
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.app});

  final AppState app;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _cardView = true;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  List<Camera> get _favorites => widget.app.repository.cameras
      .where((c) => widget.app.favorites.contains(c.id))
      .toList();

  @override
  Widget build(BuildContext context) {
    final favorites = _favorites;
    return Scaffold(
      appBar: AppBar(
        title: Text('お気に入り（${favorites.length}）'),
        actions: [
          IconButton(
            tooltip: '表示切替',
            icon: Icon(_cardView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _cardView = !_cardView),
          ),
          IconButton(
            tooltip: '一括更新',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _refreshTick++),
          ),
        ],
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('お気に入りはまだありません。\n地図でカメラを開いて★を押すと追加されます。',
                    textAlign: TextAlign.center),
              ),
            )
          : _cardView
              ? GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, i) =>
                      _FavoriteCard(camera: favorites[i], app: widget.app,
                          refreshTick: _refreshTick),
                )
              : ListView.separated(
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _FavoriteTile(camera: favorites[i], app: widget.app,
                          refreshTick: _refreshTick),
                ),
    );
  }
}

void _openDetail(BuildContext context, Camera camera, AppState app) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(camera: camera, app: app)));
}

Widget _thumb(AppState app, Camera camera, int tick,
    {BoxFit fit = BoxFit.cover}) {
  final url = app.imageUrlFor(camera);
  if (url == null) {
    return Container(
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: Icon(camera.isVideo ? Icons.play_circle_outline : Icons.videocam_off,
          color: Colors.grey[600]),
    );
  }
  return Image.network(url,
      key: ValueKey('$url#$tick'),
      fit: fit,
      errorBuilder: (_, _, _) => Container(
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const Icon(Icons.videocam_off, color: Colors.grey)));
}

/// カード（グリッド）表示の1枚。
class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard(
      {required this.camera, required this.app, required this.refreshTick});

  final Camera camera;
  final AppState app;
  final int refreshTick;

  @override
  Widget build(BuildContext context) {
    final time = app.imageTimeFor(camera);
    final state = app.stateOf(camera);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context, camera, app),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              _thumb(app, camera, refreshTick),
              if (camera.isVideo)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: liveDotColor,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              if (state == CameraState.frozen)
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(Icons.pause_circle_filled,
                      size: 18, color: Colors.white70),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(camera.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(time != null ? formatTakenTime(time) : camera.operator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]),
          ),
        ]),
      ),
    );
  }
}

/// リスト表示の1行。
class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile(
      {required this.camera, required this.app, required this.refreshTick});

  final Camera camera;
  final AppState app;
  final int refreshTick;

  @override
  Widget build(BuildContext context) {
    final time = app.imageTimeFor(camera);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
            width: 72, height: 48, child: _thumb(app, camera, refreshTick)),
      ),
      title: Text(camera.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [if (camera.isVideo) 'LIVE', if (time != null) formatTakenTime(time), camera.operator].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.star, color: Colors.amber),
        onPressed: () => app.toggleFavorite(camera),
      ),
      onTap: () => _openDetail(context, camera, app),
    );
  }
}
