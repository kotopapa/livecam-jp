import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../data/jma_layers.dart';
import '../models/camera.dart';
import '../util/clustering.dart';
import '../util/geo.dart';
import '../util/prefectures.dart';
import 'bosai_screen.dart' show NearbyCamerasScreen;
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
    widget.app.navigationRequest.addListener(_onNavigationRequest);
  }

  /// 詳細画面の「地図で見る」等からの移動要求（`map/lat,lng` 形式）
  void _onNavigationRequest() {
    final r = widget.app.navigationRequest.value ?? '';
    if (!r.startsWith('map/')) return;
    final parts = r.substring(4).split(',');
    if (parts.length < 2) return;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null || !mounted) return;
    _stopFollowing();
    _controller.move(LatLng(lat, lng), 15);
    setState(() => _zoom = 15);
    _savePosition();
  }

  @override
  void dispose() {
    _layerTimer?.cancel();
    widget.app.navigationRequest.removeListener(_onNavigationRequest);
    widget.app.removeListener(_onDataChanged);
    _searchController.dispose();
    _posSub?.cancel();
    _placeController.dispose();
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  // --- 気象レイヤー（雨雲レーダー / 震源 / 24時間雨量。排他表示） ---
  MapLayerKind _layer = MapLayerKind.none;
  QuakePeriod _quakePeriod = QuakePeriod.week;
  NowcastTime? _nowcast;
  List<NowcastTime> _nowcastTimes = const [];
  int _nowcastIdx = 0;
  bool _nowcastUserMoved = false; // ユーザーがスライダーを動かしたら自動更新で最新へ戻さない
  List<QuakePoint> _quakes = const [];
  List<RainPoint> _rain = const [];
  NowcastTime? _rain24hTile;
  bool _layerLoading = false;
  bool _layerFailed = false;
  Timer? _layerTimer;

  Future<void> _setLayer(MapLayerKind kind, {QuakePeriod? period}) async {
    _layerTimer?.cancel();
    setState(() {
      _layer = kind;
      _nowcastUserMoved = false;
      if (period != null) {
        _quakePeriod = period;
      }
      _layerFailed = false;
    });
    if (kind == MapLayerKind.none) return;
    await _refreshLayer();
    // レイヤーON中だけ定期更新（雨雲5分・震源/雨量10分）
    _layerTimer = Timer.periodic(
        Duration(minutes: kind == MapLayerKind.rainRadar ? 5 : 10),
        (_) => _refreshLayer());
  }

  Future<void> _refreshLayer() async {
    if (!mounted || _layer == MapLayerKind.none) return;
    setState(() => _layerLoading = true);
    var ok = true;
    switch (_layer) {
      case MapLayerKind.rainRadar:
        final times = await JmaLayers.fetchNowcastTimes();
        ok = times.isNotEmpty;
        if (times.isNotEmpty) {
          final latestObs = times.lastIndexWhere((n) => !n.isForecast);
          var idx = latestObs < 0 ? times.length - 1 : latestObs;
          if (_nowcastUserMoved && _nowcast != null) {
            // 同じ時刻が残っていればそこを維持
            final keep = times.indexWhere((n) => n.validtime == _nowcast!.validtime);
            if (keep >= 0) idx = keep;
          }
          _nowcastTimes = times;
          _nowcastIdx = idx;
          _nowcast = times[idx];
        }
      case MapLayerKind.quakes:
        _quakes = await JmaLayers.fetchQuakes(_quakePeriod);
      case MapLayerKind.rain24h:
        final tile = await JmaLayers.fetchRain24hTile();
        if (tile != null) _rain24hTile = tile;
        _rain = await JmaLayers.fetchRain24h();
        ok = tile != null || _rain.isNotEmpty;
      case MapLayerKind.none:
        break;
    }
    if (mounted) {
      setState(() {
        _layerLoading = false;
        _layerFailed = !ok;
      });
    }
  }

  void _showLayerPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
              title: Text('気象レイヤー', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('出典：気象庁。地図に1種類だけ重ねて表示します')),
          ListTile(
            leading: Icon(_layer == MapLayerKind.none ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _layer == MapLayerKind.none ? Theme.of(ctx).colorScheme.primary : null),
            title: const Text('表示しない'),
            
            onTap: () { Navigator.pop(ctx); _setLayer(MapLayerKind.none); },
          ),
          ListTile(
            leading: Icon(_layer == MapLayerKind.rainRadar ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _layer == MapLayerKind.rainRadar ? Theme.of(ctx).colorScheme.primary : null),
            title: const Text('雨雲レーダー（現在）'),
            subtitle: const Text('高解像度降水ナウキャスト・5分ごとに更新'),
            onTap: () { Navigator.pop(ctx); _setLayer(MapLayerKind.rainRadar); },
          ),
          ListTile(
            leading: Icon(_layer == MapLayerKind.quakes ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _layer == MapLayerKind.quakes ? Theme.of(ctx).colorScheme.primary : null),
            title: const Text('震源'),
            subtitle: Row(children: [
              for (final p in QuakePeriod.values) ...[
                ChoiceChip(
                  label: Text(switch (p) { QuakePeriod.day => '24時間', QuakePeriod.week => '7日', QuakePeriod.month => '30日' }),
                  selected: _layer == MapLayerKind.quakes && _quakePeriod == p,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) { Navigator.pop(ctx); _setLayer(MapLayerKind.quakes, period: p); },
                ),
                const SizedBox(width: 6),
              ],
            ]),
            onTap: () { Navigator.pop(ctx); _setLayer(MapLayerKind.quakes); },
          ),
          ListTile(
            leading: Icon(_layer == MapLayerKind.rain24h ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _layer == MapLayerKind.rain24h ? Theme.of(ctx).colorScheme.primary : null),
            title: const Text('24時間降水量'),
            subtitle: const Text('気象庁の解析雨量（面）＋拡大でアメダス観測値'),
            onTap: () { Navigator.pop(ctx); _setLayer(MapLayerKind.rain24h); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  /// タップした震源と、現在のズームで同じマーカーに重なる震源をまとめて表示する
  /// （群発地震や同一震源の繰り返しで下に隠れた地震も選べるように）
  /// 描画順: 弱い/古い地震を先に、強い/新しい地震を後に描いて上に重ねる
  List<QuakePoint> get _quakesForDraw {
    int rank(String m) => const ['', '1', '2', '3', '4', '5-', '5+', '6-', '6+', '7'].indexOf(m);
    return [..._quakes]..sort((a, b) {
        final r = rank(a.maxIntensity).compareTo(rank(b.maxIntensity));
        return r != 0 ? r : a.at.compareTo(b.at);
      });
  }

  void _showQuakeInfo(QuakePoint tapped) {
    // マーカー直径28pxを緯度経度差に換算（Webメルカトル、経度は緯度で補正）
    final degPerPx = 360 / (256 * math.pow(2, _zoom));
    final tol = 28 * degPerPx;
    final cosLat = math.cos(tapped.pos!.latitude * math.pi / 180).clamp(0.2, 1.0);
    final group = _quakes.where((q) =>
        (q.pos!.latitude - tapped.pos!.latitude).abs() <= tol &&
        (q.pos!.longitude - tapped.pos!.longitude).abs() * cosLat <= tol).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    String two(int v) => v.toString().padLeft(2, '0');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: group.length > 4,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (group.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('この付近の地震 ${group.length}件',
                      style: Theme.of(ctx).textTheme.titleSmall),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final q in group)
                    ListTile(
                      leading: CircleAvatar(
                          backgroundColor: JmaLayers.intensityColor(q.maxIntensity),
                          child: Text(q.maxIntensity.isEmpty ? '-' : q.maxIntensity,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))),
                      title: Text(q.place.isEmpty ? '震源（詳細未発表）' : q.place),
                      subtitle: Builder(builder: (_) {
                        final t = q.at.toLocal();
                        return Text('${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}'
                            '${q.magnitude.isNotEmpty ? '　M${q.magnitude}' : ''}'
                            '${q.maxIntensity.isNotEmpty ? '　最大震度${q.maxIntensity}' : ''}');
                      }),
                      trailing: const Icon(Icons.videocam),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => NearbyCamerasScreen(
                                app: widget.app,
                                title: '${q.place.isEmpty ? '震源' : q.place} 周辺のカメラ',
                                lat: q.pos!.latitude,
                                lng: q.pos!.longitude)));
                      },
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('タップで周辺のライブカメラ（50km以内）を表示', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ]),
        ),
      ),
    );
  }

  /// 雨雲レーダーの時刻スライダー（過去3時間の実況〜1時間先の予測）
  Widget _nowcastSlider() {
    if (_layer != MapLayerKind.rainRadar || _nowcastTimes.length < 2) {
      return const SizedBox.shrink();
    }
    final n = _nowcastTimes[_nowcastIdx];
    final latestObs = _nowcastTimes.lastIndexWhere((x) => !x.isForecast);
    final diffMin = latestObs >= 0
        ? n.validAtJst.difference(_nowcastTimes[latestObs].validAtJst).inMinutes
        : 0;
    String span(int m) => m.abs() >= 60 ? '${(m.abs() / 60).toStringAsFixed(m.abs() % 60 == 0 ? 0 : 1)}時間' : '${m.abs()}分';
    final rel = diffMin == 0
        ? '現在（実況）'
        : diffMin > 0
            ? '${span(diffMin)}後（${n.isHourly ? '予報・1時間雨量' : '予測'}）'
            : '${span(diffMin)}前（実況）';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.cloud_outlined, size: 16),
          const SizedBox(width: 6),
          Text('${n.label}　$rel',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_nowcastUserMoved && latestObs >= 0)
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => setState(() {
                _nowcastUserMoved = false;
                _nowcastIdx = latestObs;
                _nowcast = _nowcastTimes[latestObs];
              }),
              child: const Text('現在へ', style: TextStyle(fontSize: 12)),
            ),
        ]),
        SliderTheme(
          data: const SliderThemeData(trackHeight: 3),
          child: Slider(
            min: 0,
            max: (_nowcastTimes.length - 1).toDouble(),
            divisions: _nowcastTimes.length - 1,
            value: _nowcastIdx.toDouble(),
            activeColor: n.isForecast ? Colors.orange : null,
            onChanged: (v) => setState(() {
              _nowcastUserMoved = true;
              _nowcastIdx = v.round();
              _nowcast = _nowcastTimes[_nowcastIdx];
            }),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_nowcastTimes.first.label, style: const TextStyle(fontSize: 9, color: Colors.black54)),
          const Text('▲ 現在', style: TextStyle(fontSize: 9, color: Colors.black54)),
          Text('${_nowcastTimes.last.label}（6時間先）', style: const TextStyle(fontSize: 9, color: Colors.black54)),
        ]),
      ]),
    );
  }

  /// 気象レイヤーの凡例・出典（地図左下、地理院表記の上）
  Widget _layerLegend() {
    if (_layer == MapLayerKind.none) return const SizedBox.shrink();
    Widget swatch(Color c, String label) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, color: c),
            const SizedBox(width: 2),
            Text(label, style: const TextStyle(fontSize: 9)),
          ]),
        );
    final items = <Widget>[];
    String title;
    switch (_layer) {
      case MapLayerKind.rainRadar:
        title = '雨雲レーダー ${_nowcast?.label ?? ''}${(_nowcast?.isHourly ?? false) ? '（予報・1時間雨量）' : (_nowcast?.isForecast ?? false) ? '（予測）' : ''}';
        items.addAll([
          swatch(const Color(0xFFB3E5FC), '弱'),
          swatch(const Color(0xFF0041FF), '10'),
          swatch(const Color(0xFFFAF500), '30'),
          swatch(const Color(0xFFFF9900), '50'),
          swatch(const Color(0xFFFF2800), '80mm/h'),
        ]);
      case MapLayerKind.quakes:
        title = '震源 ${switch (_quakePeriod) { QuakePeriod.day => '24時間', QuakePeriod.week => '7日', QuakePeriod.month => '30日' }}（${_quakes.length}件）';
        items.addAll([
          swatch(JmaLayers.intensityColor('3'), '震度3'),
          swatch(JmaLayers.intensityColor('4'), '4'),
          swatch(JmaLayers.intensityColor('5-'), '5弱'),
          swatch(JmaLayers.intensityColor('6-'), '6弱〜'),
        ]);
      case MapLayerKind.rain24h:
        title = '24時間降水量 ${_rain24hTile?.label ?? ''}${_zoom >= 9 ? '' : '（拡大で観測値）'}';
        items.addAll([
          for (final s in JmaLayers.rain24hScale) swatch(s.$2, s.$3),
        ]);
      case MapLayerKind.none:
        title = '';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          if (_layerLoading) const Padding(
              padding: EdgeInsets.only(left: 6),
              child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))),
          if (_layerFailed) const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text('取得できません', style: TextStyle(fontSize: 9, color: Colors.red))),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: items),
        const Text('出典：気象庁', style: TextStyle(fontSize: 9, color: Colors.black54)),
      ]),
    );
  }

  /// 気象レイヤーの地図要素（タイル/マーカー）
  List<Widget> _layerWidgets() {
    switch (_layer) {
      case MapLayerKind.rainRadar:
        final n = _nowcast;
        if (n == null) return const [];
        return [
          Opacity(
            opacity: 0.6,
            child: TileLayer(
              key: ValueKey('nowc-${n.validtime}'),
              urlTemplate: n.tileTemplate,
              maxNativeZoom: 10,
              userAgentPackageName: 'jp.livecam.livecam_jp',
              errorTileCallback: (_, _, _) {},
            ),
          ),
        ];
      case MapLayerKind.quakes:
        return [
          MarkerLayer(markers: [
            for (final q in _quakesForDraw)
              Marker(
                point: q.pos!,
                width: 28,
                height: 28,
                child: GestureDetector(
                  onTap: () => _showQuakeInfo(q),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: JmaLayers.intensityColor(q.maxIntensity).withValues(alpha: 0.85),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(q.maxIntensity.isEmpty ? '' : q.maxIntensity,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                ),
              ),
          ]),
        ];
      case MapLayerKind.rain24h:
        final tile = _rain24hTile;
        return [
          if (tile != null)
            Opacity(
              opacity: 0.65,
              child: TileLayer(
                key: ValueKey('rasrf24h-${tile.validtime}'),
                urlTemplate: tile.tileTemplate,
                maxNativeZoom: 10,
                userAgentPackageName: 'jp.livecam.livecam_jp',
                errorTileCallback: (_, _, _) {},
              ),
            ),
          // 市街地ズームでは観測点の実測値(mm)を重ねる（tenki.jp方式）
          if (_zoom >= 9)
            MarkerLayer(markers: [
              for (final r in _rain)
                Marker(
                  point: r.pos,
                  width: 46,
                  height: 20,
                  child: Tooltip(
                    message: '${r.name} 24時間 ${r.mm24h.toStringAsFixed(1)}mm',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: JmaLayers.rainColor(r.mm24h).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(4),
                        // 「〜50」の薄色はタイルの塗りと同化して見つけにくいため、
                        // 濃い縁取り+影で地図・塗りから浮かせる
                        border: Border.all(color: Colors.black54, width: 1),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1))],
                      ),
                      child: Text('${r.mm24h.round()}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: r.mm24h >= 100 ? Colors.white : Colors.black87)),
                    ),
                  ),
                ),
            ]),
        ];
      case MapLayerKind.none:
        return const [];
    }
  }

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

  // --- 起動時の初期位置 ---
  static const _posKey = 'map_position'; // "lat,lng,zoom"

  /// まず前回位置を即時復元し、現在地が取れ次第そこへ移動する。
  /// 位置情報が未許可・取得失敗の場合は前回位置のまま（起動時に許可は求めない）
  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parts = (prefs.getString(_posKey) ?? '').split(',');
      if (parts.length == 3) {
        final lat = double.parse(parts[0]);
        final lng = double.parse(parts[1]);
        final zoom = double.parse(parts[2]);
        if (!mounted) return;
        _controller.move(LatLng(lat, lng), zoom);
        setState(() => _zoom = zoom);
      }
    } catch (_) {
      // 記憶がない/壊れている場合は既定位置のまま
    }
    await _centerOnCurrentLocation();
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      // まずOSが保持する最終既知位置へ即座に移動する（屋内等でGPS測位が
      // 8秒以内に終わらず、前回位置のまま起動してしまう問題の対策）
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        final approx = LatLng(last.latitude, last.longitude);
        setState(() {
          _myLocation = approx;
          _zoom = 11;
        });
        _controller.move(approx, 11);
        _savePosition();
      }
      final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.medium))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLocation = here;
        _zoom = 11;
      });
      _controller.move(here, 11);
      _savePosition();
    } catch (_) {
      // 取得できなければ最終既知位置または前回位置のまま
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

  /// ピンのタップ。同一地点(40m以内)に複数カメラがある場合は
  /// 選択シートを出す（同じ場所の別アングル・別被写体に対応）
  void _onPinTap(Camera camera) {
    if (!camera.hasLocation) {
      _openDetail(camera);
      return;
    }
    final near = widget.app.displayableCameras
        .where((c) =>
            c.hasLocation &&
            distanceMeters(camera.lat!, camera.lng!, c.lat!, c.lng!) < 40)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (near.length <= 1) {
      _openDetail(camera);
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('この地点のカメラ（${near.length}台）',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final c in near)
            ListTile(
              leading: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: categoryColor(c.category),
                    shape: BoxShape.circle),
              ),
              title: Text(c.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [if (c.isVideo) 'LIVE', c.operator].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDetail(c);
              },
            ),
          const SizedBox(height: 8),
        ]),
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

  // --- 表示領域カリング ---
  // 全カメラ分のMarkerウィジェットを毎回生成するとズームイン時に1万個超と
  // なりUIがフリーズする（iOSのウォッチドッグ強制終了の原因になる）。
  // クラスタリングは全体で行い、描画は表示領域+余白分だけに絞る
  LatLng? _lastCullCenter;

  List<MapItem> _cullToViewport(List<MapItem> items) {
    final LatLngBounds b;
    try {
      b = _controller.camera.visibleBounds;
    } catch (_) {
      return items; // 初回レイアウト前（直後のフレームで再構築される）
    }
    _lastCullCenter = _controller.camera.center;
    final lngSpan = (b.east - b.west).abs();
    if (lngSpan >= 300) return items; // ほぼ全世界が見えている
    final latMargin = (b.north - b.south) * 0.5;
    final lngMargin = lngSpan * 0.5;
    final south = b.south - latMargin, north = b.north + latMargin;
    final west = b.west - lngMargin, east = b.east + lngMargin;
    // 経度±180跨ぎに対応（±360ずらしても範囲内なら表示対象）
    bool lngIn(double lng) =>
        (lng >= west && lng <= east) ||
        (lng + 360 >= west && lng + 360 <= east) ||
        (lng - 360 >= west && lng - 360 <= east);
    return [
      for (final it in items)
        if (it.latitude >= south && it.latitude <= north && lngIn(it.longitude))
          it
    ];
  }

  /// パンで表示領域が1/4以上動いたらマーカーを再構築する（余白を食い潰す前に）
  void _maybeRebuildForPan(MapCamera camera) {
    final last = _lastCullCenter;
    if (last == null) return;
    final b = camera.visibleBounds;
    final latSpan = b.north - b.south;
    final lngSpan = (b.east - b.west).abs();
    if ((camera.center.latitude - last.latitude).abs() > latSpan * 0.25 ||
        (camera.center.longitude - last.longitude).abs() > lngSpan * 0.25) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // お知らせバナーは地図の上に重ねず、地図の上部に積む（台数チップや
    // レイヤーボタンと重なって読めなくなるため。2026-08-30）
    final notice = widget.app.notice;
    if (notice == null) return _mapStack(context);
    return Column(children: [
      _NoticeBanner(text: notice),
      Expanded(child: _mapStack(context)),
    ]);
  }

  Widget _mapStack(BuildContext context) {
    final cams = widget.app.displayableCameras;
    final items = _cullToViewport(clusterCameras(cams, _zoom));
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
              // ピンチ中の毎フレーム再構築はフリーズ→強制終了の原因になる。
              // ジェスチャー中はズーム2段以上の大変化だけ間引いて反映し、
              // 細かい追従は操作終了イベント(onMapEvent)でまとめて行う
              if ((camera.zoom - _zoom).abs() >= 2.0) {
                setState(() => _zoom = camera.zoom);
              }
              _updateTileMode();
            },
            onMapEvent: (e) {
              if (e is MapEventMoveEnd ||
                  e is MapEventFlingAnimationEnd ||
                  e is MapEventDoubleTapZoomEnd ||
                  e is MapEventRotateEnd) {
                _savePosition();
                final z = _controller.camera.zoom;
                if ((z - _zoom).abs() >= 0.25) {
                  setState(() => _zoom = z);
                } else {
                  _maybeRebuildForPan(_controller.camera);
                }
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
            ..._layerWidgets(),
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
                        onTap: () => _onPinTap(item.camera!),
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
              // 時刻スライダー → 凡例 → 出典 の順に縦に積む（重なり防止）。
              // 右側のズーム/現在地ボタン(幅約60px)を避けて右に余白を取る
              child: Padding(
                padding: const EdgeInsets.only(right: 60),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: _nowcastSlider()),
                  Padding(padding: const EdgeInsets.only(left: 4, bottom: 2), child: _layerLegend()),
                  _GsiAttribution(worldTiles: _useWorldTiles),
                ]),
              ),
            ),
          ],
        ),
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
                  ? '絞り込み中 ${cams.length}台'
                  : '${cams.length}台',
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
              heroTag: 'weather_layer',
              tooltip: '気象レイヤー',
              backgroundColor: _layer == MapLayerKind.none ? null : Theme.of(context).colorScheme.primary,
              foregroundColor: _layer == MapLayerKind.none ? null : Colors.white,
              onPressed: () => _showLayerPicker(context),
              child: const Icon(Icons.cloud_outlined),
            ),
            const SizedBox(height: 8),
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
