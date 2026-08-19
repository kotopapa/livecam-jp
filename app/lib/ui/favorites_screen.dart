import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../models/camera.dart';
import '../models/status.dart';
import 'detail_screen.dart';
import 'pin_style.dart';

/// お気に入り画面（SPEC 9.2⑤）。リスト表示とカード（グリッド）表示を切替できる。
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.app});

  final AppState app;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

enum _FavSort { newest, oldest, name, category }

const _favSortLabels = {
  _FavSort.newest: '登録が新しい順',
  _FavSort.oldest: '登録が古い順',
  _FavSort.name: '名前順',
  _FavSort.category: 'カテゴリ順',
};

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _cardView = true;
  bool _bulkRefreshing = false;
  _FavSort _sort = _FavSort.newest;
  final Set<String> _filterCategories = {}; // 空=全カテゴリ
  bool _videoOnly = false;
  // カメラごとの再取得キー。一括更新は3件ずつ順次進める（SPEC 9.2⑤）
  final Map<String, int> _ticks = {};

  Future<void> _bulkRefresh() async {
    if (_bulkRefreshing) return;
    setState(() => _bulkRefreshing = true);
    final favs = _favorites;
    for (var i = 0; i < favs.length; i += maxConcurrentFetches) {
      if (!mounted) break;
      setState(() {
        for (final c in favs.skip(i).take(maxConcurrentFetches)) {
          _ticks[c.id] = (_ticks[c.id] ?? 0) + 1;
        }
      });
      await Future.delayed(const Duration(milliseconds: 800));
    }
    if (mounted) setState(() => _bulkRefreshing = false);
  }

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

  /// 登録が新しい順を基準に、フィルタ→並べ替えを適用した一覧
  List<Camera> get _favorites {
    final byId = {
      for (final c in widget.app.repository.cameras) c.id: c
    };
    var list = [
      for (final id in widget.app.favorites.newestFirst)
        if (byId[id] != null) byId[id]!,
    ];
    if (_filterCategories.isNotEmpty) {
      list = list
          .where((c) => _filterCategories.contains(c.category))
          .toList();
    }
    if (_videoOnly) list = list.where((c) => c.isVideo).toList();
    switch (_sort) {
      case _FavSort.newest:
        break; // 基準順のまま
      case _FavSort.oldest:
        list = list.reversed.toList();
      case _FavSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _FavSort.category:
        list.sort((a, b) {
          final c = a.category.compareTo(b.category);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
    }
    return list;
  }

  /// お気に入り内に存在するカテゴリ（フィルタチップ表示用）
  List<String> get _presentCategories {
    final ids = widget.app.favorites.ids;
    final cats = <String>{};
    for (final c in widget.app.repository.cameras) {
      if (ids.contains(c.id)) cats.add(c.category);
    }
    return categoryLabels.keys.where(cats.contains).toList();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favorites;
    return Scaffold(
      appBar: AppBar(
        title: Text('お気に入り（${favorites.length}）'),
        actions: [
          PopupMenuButton<_FavSort>(
            tooltip: '並べ替え',
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              for (final e in _favSortLabels.entries)
                CheckedPopupMenuItem(
                  value: e.key,
                  checked: _sort == e.key,
                  child: Text(e.value),
                ),
            ],
          ),
          IconButton(
            tooltip: '表示切替',
            icon: Icon(_cardView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _cardView = !_cardView),
          ),
          IconButton(
            tooltip: '一括更新（3件ずつ順次取得）',
            icon: _bulkRefreshing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _bulkRefreshing ? null : _bulkRefresh,
          ),
        ],
      ),
      body: Column(children: [
        if (widget.app.favorites.ids.isNotEmpty && _presentCategories.length + 1 > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final cat in _presentCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(categoryLabels[cat] ?? cat,
                          style: const TextStyle(fontSize: 12)),
                      selected: _filterCategories.contains(cat),
                      selectedColor:
                          categoryColor(cat).withValues(alpha: 0.25),
                      onSelected: (_) => setState(() {
                        if (!_filterCategories.remove(cat)) {
                          _filterCategories.add(cat);
                        }
                      }),
                    ),
                  ),
                FilterChip(
                  label: const Text('動画のみ', style: TextStyle(fontSize: 12)),
                  selected: _videoOnly,
                  onSelected: (v) => setState(() => _videoOnly = v),
                ),
              ],
            ),
          ),
        Expanded(child: _buildBody(favorites)),
      ]),
    );
  }

  Widget _buildBody(List<Camera> favorites) {
    if (widget.app.favorites.ids.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('お気に入りはまだありません。\n地図でカメラを開いて★を押すと追加されます。',
              textAlign: TextAlign.center),
        ),
      );
    }
    if (favorites.isEmpty) {
      return const Center(child: Text('絞り込み条件に合うお気に入りがありません'));
    }
    return _cardView
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
                          refreshTick: _ticks[favorites[i].id] ?? 0),
                )
              : ListView.separated(
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _FavoriteTile(camera: favorites[i], app: widget.app,
                          refreshTick: _ticks[favorites[i].id] ?? 0),
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
                  Text(camera.operator,
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
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
            width: 72, height: 48, child: _thumb(app, camera, refreshTick)),
      ),
      title: Text(camera.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [if (camera.isVideo) 'LIVE', camera.operator].join(' · '),
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
