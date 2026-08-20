import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../models/camera.dart';
import '../util/clustering.dart';
import '../util/prefectures.dart';
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
  bool _following = false; // 現在地追従モード
  StreamSubscription<Position>? _posSub;

  /// 現在地ボタン（SPEC 9.2②）。タップで追従モードをトグルする。
  /// 追従中は位置の更新に合わせて地図が動き、手で地図を動かすと解除される
  Future<void> _goToMyLocation() async {
    if (_following) {
      _stopFollowing();
      return;
    }
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
      setState(() {
        _myLocation = here;
        _following = true;
        _zoom = 13;
      });
      _controller.move(here, 13);
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, distanceFilter: 10),
      ).listen((p) {
        final here = LatLng(p.latitude, p.longitude);
        if (!mounted) return;
        setState(() => _myLocation = here);
        if (_following) _controller.move(here, _controller.camera.zoom);
      });
    } catch (_) {
      _showMessage('現在地を取得できませんでした');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _stopFollowing() {
    _posSub?.cancel();
    _posSub = null;
    if (mounted) setState(() => _following = false);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onDataChanged);
    // 初回フレーム後に前回位置へ移動（MapControllerはレイアウト後に有効）
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  @override
  void dispose() {
    widget.app.removeListener(_onDataChanged);
    _searchController.dispose();
    _posSub?.cancel();
    _placeController.dispose();
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  // 日本域外・広域表示ではOSMタイルへ切替（地理院タイルは日本のみ提供のため）
  bool _useWorldTiles = false;

  static bool _outsideJapan(double lat, double lng) =>
      lat < 20 || lat > 46 || lng < 122 || lng > 154;

  void _updateTileMode() {
    final c = _controller.camera;
    final world = c.zoom < 4.5 ||
        _outsideJapan(c.center.latitude, c.center.longitude);
    if (world != _useWorldTiles) {
      setState(() => _useWorldTiles = world);
    }
  }

  // --- 地図位置の記憶（前回表示していた場所から再開する） ---
  static const _posKey = 'map_position'; // "lat,lng,zoom"

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parts = (prefs.getString(_posKey) ?? '').split(',');
      if (parts.length != 3) return;
      final lat = double.parse(parts[0]);
      final lng = double.parse(parts[1]);
      final zoom = double.parse(parts[2]);
      if (!mounted) return;
      _controller.move(LatLng(lat, lng), zoom);
      setState(() => _zoom = zoom);
    } catch (_) {
      // 記憶がない/壊れている場合は既定位置のまま
    }
  }

  Future<void> _savePosition() async {
    final c = _controller.camera;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_posKey,
        '${c.center.latitude},${c.center.longitude},${c.zoom}');
  }

  /// 都道府県ジャンプ（SPEC 9.2②）。承認済みカメラの重心へ移動する
  void _showPrefectureJump(BuildContext context) {
    final cams = widget.app.repository.displayableCameras();
    final sums = <String, (double, double, int)>{};
    for (final c in cams) {
      if (!c.hasLocation) continue;
      final cur = sums[c.prefecture] ?? (0.0, 0.0, 0);
      sums[c.prefecture] = (cur.$1 + c.lat!, cur.$2 + c.lng!, cur.$3 + 1);
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            for (final e in prefectureNames.entries)
              if (sums.containsKey(e.key))
                OutlinedButton(
                  onPressed: () {
                    final s = sums[e.key]!;
                    Navigator.of(context).pop();
                    _controller.move(
                        LatLng(s.$1 / s.$3, s.$2 / s.$3), 9.5);
                    setState(() => _zoom = 9.5);
                    _savePosition();
                  },
                  style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact),
                  child: Text(e.value,
                      style: const TextStyle(fontSize: 12)),
                ),
          ],
        ),
      ),
    );
  }

  // --- 場所検索（国土地理院ジオコーディング。無料・キー不要） ---
  final _placeController = TextEditingController();

  Future<List<(String, LatLng)>> _searchPlace(String query) async {
    final uri = Uri.parse(
        'https://msearch.gsi.go.jp/address-search/AddressSearch'
        '?q=${Uri.encodeQueryComponent(query)}');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
    final hits = [
      for (final e in list.cast<Map<String, dynamic>>())
        (
          (e['properties'] as Map<String, dynamic>)['title'] as String? ?? '',
          LatLng(
            ((e['geometry'] as Map<String, dynamic>)['coordinates']
                as List)[1] as double,
            ((e['geometry'] as Map<String, dynamic>)['coordinates']
                as List)[0] as double,
          ),
        ),
    ];
    // 地理院APIは部分一致の住所も多く返すため、クエリ全体を含む候補を優先する
    hits.sort((a, b) {
      final am = a.$1.contains(query) ? 0 : 1;
      final bm = b.$1.contains(query) ? 0 : 1;
      return am.compareTo(bm);
    });
    return hits.take(15).toList();
  }

  /// 登録済みカメラ名からの検索（地理院が施設名に弱いのを補完する）
  List<Camera> _searchCameras(String query) {
    final q = query.toLowerCase();
    return widget.app.repository
        .displayableCameras()
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.operator.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  void _showPlaceSearch(BuildContext context) {
    List<(String, LatLng)> results = const [];
    List<Camera> cameraHits = const [];
    bool searching = false;
    bool searched = false;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> run() async {
            final q = _placeController.text.trim();
            if (q.isEmpty) return;
            setSheetState(() => searching = true);
            cameraHits = _searchCameras(q);
            try {
              results = await _searchPlace(q);
            } catch (_) {
              results = const [];
            }
            searched = true;
            setSheetState(() => searching = false);
          }

          void goTo(LatLng point, double zoom) {
            Navigator.of(sheetContext).pop();
            _stopFollowing();
            _controller.move(point, zoom);
            setState(() => _zoom = zoom);
            _savePosition();
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('場所を検索',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                  controller: _placeController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    hintText: '地名・住所（例: 渋谷、金沢市広坂）',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.search), onPressed: run),
                  ),
                  onSubmitted: (_) => run(),
                ),
                const SizedBox(height: 8),
                if (searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )
                else if (searched && results.isEmpty && cameraHits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('見つかりませんでした。地名・住所・カメラ名でお試しください',
                        style: TextStyle(color: Colors.grey[600])),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(shrinkWrap: true, children: [
                      if (cameraHits.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Text('カメラ',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600])),
                        ),
                      for (final c in cameraHits)
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.videocam,
                              size: 18, color: categoryColor(c.category)),
                          title: Text(c.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.operator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => goTo(LatLng(c.lat!, c.lng!), 14),
                        ),
                      if (results.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Text('場所',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600])),
                        ),
                      for (final r in results)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.place, size: 18),
                          title: Text(r.$1),
                          onTap: () => goTo(r.$2, 13),
                        ),
                    ]),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _zoomBy(double delta) {
    final z = (_controller.camera.zoom + delta).clamp(2.0, 18.0);
    _controller.move(_controller.camera.center, z);
    setState(() => _zoom = z);
  }

  // 検索欄のコントローラは画面Stateと同寿命で保持する。
  // - 再描画のたびに作り直すとIMEの変換中テキストが破棄され日本語入力が壊れる
  // - シートの close Future 完了時に dispose すると、フリックで閉じた際の
  //   閉アニメーション中にTextFieldが破棄済みコントローラを参照して落ちる
  final _searchController = TextEditingController();

  /// 凡例 + カテゴリフィルタのボトムシート
  void _showLegendFilter(BuildContext context) {
    final searchController = _searchController
      ..text = widget.app.searchQuery;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final app = widget.app;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('凡例・絞り込み',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'カメラ名・運営者・河川/路線名で検索',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    suffixIcon: app.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              app.setSearchQuery('');
                              setSheetState(() {});
                            },
                          ),
                  ),
                  onChanged: (v) {
                    app.setSearchQuery(v);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final counts = app.categoryCounts();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in categoryLabels.entries)
                        FilterChip(
                          avatar: CircleAvatar(
                              backgroundColor: categoryColor(entry.key),
                              radius: 6),
                          label: Text(
                              '${entry.value} ${counts[entry.key] ?? 0}'),
                          selected: app.enabledCategories.contains(entry.key),
                          onSelected: (_) {
                            app.toggleCategory(entry.key);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  );
                }),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('動画カメラのみ'),
                  value: app.videoOnly,
                  onChanged: (v) {
                    app.setVideoOnly(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('世界のカメラを表示'),
                  value: app.showWorld,
                  onChanged: (v) {
                    app.setShowWorld(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('位置が曖昧なカメラを非表示'),
                  value: app.hideUncertain,
                  onChanged: (v) {
                    app.setHideUncertain(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('お気に入りのみ'),
                  value: app.favoritesOnly,
                  onChanged: (v) {
                    app.setFavoritesOnly(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('現在映っているもののみ'),
                  value: app.okOnly,
                  onChanged: (v) {
                    app.setOkOnly(v);
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
                const _LegendRow(
                    kind: _LegendKind.favorite, text: '金の星 = お気に入り登録済み'),
                const _LegendRow(
                    kind: _LegendKind.cluster,
                    text: '数字の丸 = 周辺カメラのまとまり（タップでズーム）'),
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
            minZoom: 2,
            maxZoom: 18,
            // ピンチズーム等は既定で有効。二本指ひねりの回転だけ無効化（北固定）
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _following) _stopFollowing();
              if ((camera.zoom - _zoom).abs() >= 0.5) {
                setState(() => _zoom = camera.zoom);
              }
              _updateTileMode();
            },
            onMapEvent: (e) {
              if (e is MapEventMoveEnd ||
                  e is MapEventFlingAnimationEnd ||
                  e is MapEventDoubleTapZoomEnd) {
                _savePosition();
              }
            },
          ),
          children: [
            TileLayer(
              // 日本域=地理院タイル(淡色)、世界=OpenStreetMap。出典表示は必須
              urlTemplate: _useWorldTiles
                  ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                  : 'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
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
                          favorite: widget.app.isFavorite(item.camera!),
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
            Align(
              alignment: Alignment.bottomLeft,
              child: _GsiAttribution(worldTiles: _useWorldTiles),
            ),
          ],
        ),
        if (widget.app.notice != null) _NoticeBanner(text: widget.app.notice!),
        Positioned(
          left: 12,
          top: MediaQuery.of(context).padding.top + 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3)
              ],
            ),
            child: Text(
              widget.app.hasActiveFilters
                  ? '絞り込み中 ${widget.app.displayableCameras.length}台'
                  : '${widget.app.displayableCameras.length}台',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 12,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FloatingActionButton.small(
              heroTag: 'legend_filter',
              onPressed: () => _showLegendFilter(context),
              child: const Icon(Icons.layers_outlined),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'pref_jump',
              tooltip: '都道府県へ移動',
              onPressed: () => _showPrefectureJump(context),
              child: const Icon(Icons.travel_explore),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'place_search',
              tooltip: '場所を検索',
              onPressed: () => _showPlaceSearch(context),
              child: const Icon(Icons.search),
            ),
          ]),
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
                  : Icon(_following ? Icons.my_location : Icons.location_searching),
            ),
          ]),
        ),
      ],
    );
  }
}

enum _LegendKind { liveDot, uncertain, frozen, favorite, cluster }

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
      _LegendKind.favorite => const Icon(Icons.star,
          size: 14, color: Color(0xFFFFB300)),
      _LegendKind.cluster => Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: Color(0xFF1E6FD9), shape: BoxShape.circle),
          child: const Text('9',
              style: TextStyle(color: Colors.white, fontSize: 9,
                  fontWeight: FontWeight.bold))),
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
  const _GsiAttribution({this.worldTiles = false});

  final bool worldTiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.white70,
      child: Text(worldTiles ? '© OpenStreetMap contributors' : '地理院タイル',
          style: const TextStyle(fontSize: 10)),
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
