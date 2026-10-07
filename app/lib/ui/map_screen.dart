import 'dart:async';
import 'dart:io' show Directory;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../data/analytics.dart';
import '../data/data_saver.dart';
import '../data/facility_layers.dart';
import '../data/geo.dart';
import '../data/gmaps_tile_provider.dart';
import '../data/hazard_layers.dart';
import '../data/jma_layers.dart';
import '../data/jma_typhoon.dart';
import '../data/kjmap.dart';
import '../data/map_dark_style.dart';
import '../data/native_config.dart';
import '../data/places_search.dart';
import '../data/route_corridor.dart';
import '../data/situation.dart';
import '../data/shelter_layers.dart';
import '../data/road_closures.dart';
import '../data/road_regulation.dart';
import '../data/underpass.dart';
import '../models/camera.dart';
import '../models/status.dart' show CameraState;
import '../util/clustering.dart';
import '../util/geo.dart';
import 'bosai_screen.dart' show NearbyCamerasScreen, tintedSurface;
import 'detail_screen.dart';
import 'favorites_screen.dart';
import 'map_bottom_panel.dart';
import 'route_cameras_screen.dart';
import 'situation_card.dart';
import 'elevation_label.dart';
import 'pin_bitmaps.dart';
import 'pin_style.dart';
import 'place_search_screen.dart';

/// 地図画面（SPEC 9.2②）。
/// 地理院タイル + カテゴリ色ピン + 位置未確定の黄縁取り + クラスタリング。
/// ピンをタップすると詳細画面へ直接遷移する。
/// 防災拠点レイヤーを選択肢に出すか（配信データのカバーが広がるまで false）
const bool showFacilitiesLayer = false;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.app});

  final AppState app;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCenter = LatLng(36.2, 138.25); // 本州中心
  static const _initialZoom = 5.0;

  // GoogleMap 移行（第1段階。docs/google_maps_migration.md）。
  // 内部の座標型は latlong2 の LatLng のまま扱い、境界（GoogleMap への
  // 出入り）だけ _g/_l で gmaps.LatLng に変換する
  gmaps.GoogleMapController? _gmapController;
  LatLng _center = _initialCenter; // 現在のカメラ中心（onCameraMove/Idle で追従）
  double _zoom = _initialZoom;
  /// Google Maps 用キー（ネイティブ側）がルート検索に使えるか。NativeConfig の
  /// 取得は非同期のため initState で先読みして bool に落とす（ルートボタンの
  /// 表示条件は「Google キーがある or ORS キーがある」）
  bool _hasGoogleRouteKey = false;
  /// 直近の可視領域（onCameraIdle で getVisibleRegion() を取り直す。flutter_map の
  /// LatLngBounds 型をそのまま再利用している。初回レイアウト前は null）
  LatLngBounds? _visibleBounds;

  /// 地図をドラッグ中か（下部パネルを沈めるための状態。onCameraMoveStarted で
  /// 立て、onCameraIdle で戻す。ピンのタップ等の単なるタップでは
  /// onCameraMoveStarted 自体が呼ばれないため沈まない）
  bool _mapDragging = false;
  /// アプリ側からのカメラ移動中（animateCamera 等）。GoogleMap の onCameraMoveStarted は
  /// ジェスチャーとプログラム移動を区別しないので、これが true の間は「追従解除・
  /// パネルを沈める・状況カードを閉じる」の利用者操作向けの処理をしない
  bool _programmaticMove = false;
  /// 上部の検索で選んだ場所（地図に赤いピンと「ここへのルート」カードを出す）
  ({String label, LatLng point})? _pickedPlace;
  /// 今昔マップのスワイプ比較で、どちらの地図が操作の起点か。2枚とも操作を受け、
  /// 起点になった側がもう一方をアニメーション無しで追従させる（2026-09-27 実機で
  /// 上の地図が操作不可だと、その下の地図にもタッチが届かずピンチできなかった）
  bool _kjTopDriving = false;
  bool _kjBottomDriving = false;
  /// 出典帯の「今昔マップ on the web」リンク（build ごとに作らず使い回す）
  late final TapGestureRecognizer _kjmapTap = TapGestureRecognizer()
    ..onTap = () => launchUrl(Uri.parse(Kjmap.siteUrl), mode: LaunchMode.externalApplication);
  // ジェスチャー終了イベントを取り逃した場合のフェイルセーフ
  Timer? _mapDraggingFailsafe;
  /// 位置情報の権限が既に許可されているか（myLocationEnabled のゲート。
  /// GoogleMap 自身の青い現在地ドットに任せるので自前のマーカーは持たない）
  bool _locationPermissionGranted = false;
  bool _locating = false;
  bool _following = false; // 現在地追従モード
  StreamSubscription<Position>? _posSub;

  gmaps.LatLng _g(LatLng p) => gmaps.LatLng(p.latitude, p.longitude);
  LatLng _l(gmaps.LatLng p) => LatLng(p.latitude, p.longitude);

  void _onMapCreated(gmaps.GoogleMapController controller) {
    _gmapController = controller;
    // _restorePosition 等が onMapCreated より先に解決して _center/_zoom を
    // 書き換えていた場合に備え、現在値へ一度だけ同期する（無駄なら no-op）
    controller.moveCamera(gmaps.CameraUpdate.newLatLngZoom(_g(_center), _zoom));
    _syncVisibleBounds();
  }

  Future<void> _syncVisibleBounds() async {
    final c = _gmapController;
    if (c == null) return;
    try {
      final r = await c.getVisibleRegion();
      if (!mounted) return;
      setState(() {
        _visibleBounds = LatLngBounds(
          LatLng(r.southwest.latitude, r.southwest.longitude),
          LatLng(r.northeast.latitude, r.northeast.longitude),
        );
      });
    } catch (_) {}
  }

  /// 指定地点へアニメーション移動（flutter_map の `MapController.move` 相当）。
  /// `_center`/`_zoom` は同期的に更新するので、直後に `_savePosition()` 等を
  /// 呼んでも最新値が読める
  Future<void> _moveCamera(LatLng center, double zoom) async {
    if (mounted) {
      setState(() {
        _center = center;
        _zoom = zoom;
      });
    } else {
      _center = center;
      _zoom = zoom;
    }
    final c = _gmapController;
    if (c == null) return;
    _programmaticMove = true;
    try {
      await c.animateCamera(gmaps.CameraUpdate.newLatLngZoom(_g(center), zoom));
    } catch (_) {}
  }

  /// 複数地点が収まるように地図を寄せる（flutter_map の `CameraFit.bounds` 相当）。
  /// google_maps_flutter の `newLatLngBounds` は上下左右一律の padding(px) しか
  /// 取れないため、4辺のうち最大値を使う（非対称の余白は近似になる）
  Future<void> _fitBounds(List<LatLng> points,
      {EdgeInsets padding = const EdgeInsets.all(60)}) async {
    if (points.length < 2) return;
    final c = _gmapController;
    if (c == null) return;
    final b = LatLngBounds.fromPoints(points);
    // google_maps_flutter の newLatLngBounds は4辺一律の余白しか取れず、旧実装の
    // 160px をそのまま渡すと幅390の画面で320px分が余白になり大きくズームアウトする。
    // 下部の操作板・上部の検索ピルは GoogleMap.padding で既に避けているので、
    // ここは小さめの余白で足りる
    final pad = math.min(
        [padding.left, padding.top, padding.right, padding.bottom].reduce(math.max), 40.0);
    _programmaticMove = true;
    try {
      await c.animateCamera(gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: _g(LatLng(b.south, b.west)),
          northeast: _g(LatLng(b.north, b.east)),
        ),
        pad,
      ));
    } catch (_) {}
  }

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
        if (mounted) _showMessage(context.l10n.mapLocationDenied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium))
          .timeout(const Duration(seconds: 10));
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _locationPermissionGranted = true;
        _following = true;
      });
      _moveCamera(here, 13);
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, distanceFilter: 10),
      ).listen((p) {
        if (!mounted) return;
        if (_following) _moveCamera(LatLng(p.latitude, p.longitude), _zoom);
      }, onError: (Object _) {
        // 追従中に位置情報が取れなくなった（設定でオフにした・権限を取り消した等）。
        // ストリームのエラーは未処理だと Crashlytics に致命的エラーとして記録される
        // （1.6.0 で geolocator_apple.dart:188 の報告）ので、追従を止めて知らせる
        _stopFollowing();
        if (mounted) _showMessage(context.l10n.mapLocationFailed);
      });
    } catch (_) {
      if (mounted) _showMessage(context.l10n.mapLocationFailed);
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
    _loadDismissedNotice();
    _loadFacilityKinds();
    widget.app.addListener(_onDataChanged);
    // 初回フレーム後に前回位置へ移動（MapControllerはレイアウト後に有効）
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
    widget.app.navigationRequest.addListener(_onNavigationRequest);
    _loadSituation();
    _saverApplied = widget.app.dataSaverActive;
    _restartSituationTimer();
    _loadPanelPrefs();
    NativeConfig.instance.getGoogleMapsApiKey().then((k) {
      if (mounted && k != null && k.isNotEmpty) {
        setState(() => _hasGoogleRouteKey = true);
      }
    });
  }

  Future<void> _loadPanelPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final e = prefs.getBool(_controllerExpandedKey);
      if (!mounted) return;
      // シートは起動直後は開いた状態にする（前回の開閉は引き継がない。2026-09-27 要望）
      setState(() => _controllerExpandedPref = e);
    } catch (_) {}
  }

  Future<void> _setControllerExpanded(bool expanded) async {
    setState(() => _controllerExpandedPref = expanded);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_controllerExpandedKey, expanded);
    } catch (_) {}
  }

  void _setSheetExpanded(bool expanded) {
    setState(() => _sheetExpandedPref = expanded);
  }

  void _toggleSheet() => _setSheetExpanded(!_sheetExpanded);

  Future<void> _loadSituation() async {
    if (_dismissedSituation == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _dismissedSituation = prefs.getString(_dismissedSituationKey) ?? '';
      } catch (_) {
        _dismissedSituation = '';
      }
    }
    final s = await SituationLoader.load();
    if (!mounted) return;
    // 前回読み込みと signature が変わっていれば「新着」（ボタンのリング脈動の起動条件）
    final isNewContent = s.isNotable && s.signature != _lastSituationSignature;
    _lastSituationSignature = s.signature;
    setState(() {
      _situation = s;
      _situationJustChanged = isNewContent;
    });
  }

  Future<void> _dismissSituation() async {
    final sig = _situation?.signature ?? '';
    setState(() => _dismissedSituation = sig);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedSituationKey, sig);
    } catch (_) {}
  }

  /// 展開状態は内容の識別子で決める（新しい内容なら自動展開、閉じた内容と同じなら
  /// 閉じたまま）。「！」ボタンをタップして再展開する場合はここで dismissed を
  /// クリアする（永続化はしない。次に閉じたときに現在の signature で上書きされる）
  bool get _situationExpanded {
    final s = _situation;
    if (s == null || !s.isNotable) return false;
    return s.signature != (_dismissedSituation ?? '');
  }

  void _reopenSituation() => setState(() => _dismissedSituation = '');

  /// 詳細画面の「地図で見る」等からの移動要求（`map/lat,lng` 形式）
  void _onNavigationRequest() {
    final r = widget.app.navigationRequest.value ?? '';
    if (!r.startsWith('map/')) return;
    // 災害速報の台風カード「地図で進路を見る」（'map/typhoon' または 'map/typhoon/<TC番号>'）
    if (r == 'map/typhoon' || r.startsWith('map/typhoon/')) {
      final id = r.length > 'map/typhoon/'.length ? r.substring('map/typhoon/'.length) : null;
      if (mounted) _setLayer(MapLayerKind.typhoon, typhoonId: id);
      return;
    }
    final parts = r.substring(4).split(',');
    if (parts.length < 2) return;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null || !mounted) return;
    _stopFollowing();
    _moveCamera(LatLng(lat, lng), 15);
    _savePosition();
    _requestLayerDataForView();
  }

  @override
  void dispose() {
    _kjmapTap.dispose();
    _layerTimer?.cancel();
    _situationTimer?.cancel();
    _mapDraggingFailsafe?.cancel();
    _shelters?.removeListener(_onDataChanged);
    _shelters?.dispose();
    _facilities?.removeListener(_onDataChanged);
    _facilities?.dispose();
    widget.app.navigationRequest.removeListener(_onNavigationRequest);
    widget.app.removeListener(_onDataChanged);
    _searchController.dispose();
    _posSub?.cancel();
    for (final p in _tileProviders.values) {
      p.dispose();
    }
    super.dispose();
  }

  void _onDataChanged() {
    // 通信節約モードの入り切りで定期取得を切り替える（節約中はレイヤーの自動更新を止め、
    // 「いま起きていること」は30分間隔にする）
    final saver = widget.app.dataSaverActive;
    if (saver != _saverApplied) {
      _saverApplied = saver;
      _restartSituationTimer();
      _layerTimer?.cancel();
      _layerTimer = null;
      _startLayerTimer();
    }
    setState(() {});
  }

  /// 最後に定期取得へ反映した通信節約モードの状態
  bool _saverApplied = false;

  void _restartSituationTimer() {
    _situationTimer?.cancel();
    _situationTimer = Timer.periodic(
        situationInterval(_saverApplied), (_) => _loadSituation());
  }

  /// 定期更新が要るレイヤー（ハザード・避難場所・防災拠点・昔の地図は静的なので不要）
  bool get _layerNeedsTimer =>
      _layer != MapLayerKind.none &&
      !HazardLayers.isHazard(_layer) &&
      _layer != MapLayerKind.shelters &&
      _layer != MapLayerKind.facilities &&
      _layer != MapLayerKind.oldMap;

  /// レイヤーON中だけ定期更新（雨雲5分・震源/雨量/キキクル10分）。
  /// 通信節約中は自動更新しない（レイヤーを切り替え直せば取り直す）
  void _startLayerTimer() {
    _layerTimer?.cancel();
    _layerTimer = null;
    if (widget.app.dataSaverActive || !_layerNeedsTimer) return;
    _layerTimer = Timer.periodic(
        Duration(minutes: _layer == MapLayerKind.rainRadar ? 5 : 10),
        (_) => _refreshLayer());
  }

  // --- 地図レイヤー（雨雲レーダー / 震源 / 24時間雨量 / キキクル / ハザードマップ / 避難場所。排他表示） ---
  MapLayerKind _layer = MapLayerKind.none;
  QuakePeriod _quakePeriod = QuakePeriod.week;
  NowcastTime? _nowcast;
  List<NowcastTime> _nowcastTimes = const [];
  int _nowcastIdx = 0;
  bool _nowcastUserMoved = false; // ユーザーがスライダーを動かしたら自動更新で最新へ戻さない
  List<QuakePoint> _quakes = const [];
  List<RainPoint> _rain = const [];
  NowcastTime? _rain24hTile;
  RiskTime? _risk;
  List<Typhoon> _typhoons = const [];
  /// 台風レイヤーで表示する台風の TC番号。null なら発表中の全台風
  String? _typhoonId;
  /// 地下道の冠水状況（自治体センサー。data/underpass.dart）
  UnderpassStatus _underpass = UnderpassStatus.empty;

  /// 道路の通行規制（国交省 道路情報提供システム。data/road_regulation.dart）
  RoadRegulationStatus _roadReg = RoadRegulationStatus.empty;

  /// 統合レイヤー「道路の通行止め・規制」の原因での絞り込み（null=すべて）
  ClosureCause? _closureFilter;

  List<ClosureItem> get _closureItems {
    final all = RoadClosures.merge(_underpass, _roadReg);
    final f = _closureFilter;
    return f == null ? all : [for (final i in all) if (i.cause == f) i];
  }
  SnowTime? _snowTime;
  /// 「いま起きていること」（起動時と10分ごとに更新。閉じた内容は再表示しない）
  Situation? _situation;
  String? _dismissedSituation;
  Timer? _situationTimer;
  static const _dismissedSituationKey = 'situation_dismissed';

  /// 前回読み込みの signature（新着判定・リング脈動の起動条件に使う）
  String? _lastSituationSignature;

  /// 直前の読み込みで内容が変わった（新着）か。ボタンの脈動は false→true の
  /// 変化時だけ起動するので、同じ内容が続く間は再発火しない
  bool _situationJustChanged = false;

  /// レイヤー操作板カードの展開状態（既定は圧縮）
  bool? _controllerExpandedPref;
  bool get _controllerExpanded => _controllerExpandedPref ?? false;
  static const _controllerExpandedKey = 'map_controller_expanded';

  /// 下部シート（Googleマップ風の折りたたみシート）の展開状態（既定は圧縮）。
  /// 地図ドラッグ中は強制的に畳み、離したらこの値に戻す（2026-09-27）
  bool? _sheetExpandedPref;
  bool get _sheetExpanded => _sheetExpandedPref ?? true;
  /// ルート沿いカメラ（RouteCorridor）。null なら通常表示
  RouteResult? _route;
  List<CorridorCamera> _routeCameras = const [];
  Set<String> _routeCameraIds = const {};
  double _routeWidthM = 3000;
  bool _layerLoading = false;
  bool _layerFailed = false;
  Timer? _layerTimer;

  // ---- 昔の地図（今昔マップ）----
  /// 地図の中心を含む地域（無ければ null＝未収録）
  KjmapRegion? _kjRegion;
  /// 選択中の時期（地域の eras の folder）
  String? _kjEra;
  /// 比較の方法。既定は縦線のスワイプ（2026-09-25 ユーザー決定）
  _KjCompare _kjCompare = _KjCompare.vertical;
  /// 境界の位置（0〜1。縦線なら左からの割合、横線なら上からの割合）。
  /// `_KjDivider` の取っ手のドラッグで更新する
  double _kjSplit = 0.5;
  /// 透過比較のときの昔の地図の不透明度
  double _kjOpacity = 0.7;
  static const _kjNoticeKey = 'kjmap_notice_seen';

  /// 新旧スワイプ（縦線／横線）用に重ねる2枚目の GoogleMap のコントローラ。
  /// 透過比較モードでは使わない（1枚の地図に TileOverlay を重ねるだけ）
  gmaps.GoogleMapController? _kjOverlayController;

  /// 今、2枚目の GoogleMap（スワイプ比較の昔の地図）を出す必要があるか
  bool get _kjSwipeActive =>
      _layer == MapLayerKind.oldMap &&
      _kjCompare != _KjCompare.opacity &&
      _kjRegion != null &&
      _kjEra != null;

  // ---- 気象庁タイル・ハザードマップ・今昔マップ（TileOverlay）----
  /// レイヤー種別ごとに固定の TileOverlayId を持つ UrlTileProvider を保持する。
  /// 時刻更新・レイヤー切替のたびに作り直すと clearTileCache が効かず一瞬消えるため、
  /// 既存があれば template だけ書き換えて再利用する（_tileProvider）
  final Map<String, UrlTileProvider> _tileProviders = {};
  static const _tileHeaders = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)',
  };

  Future<void> _setLayer(MapLayerKind kind,
      {QuakePeriod? period, String? typhoonId}) async {
    _layerTimer?.cancel();
    setState(() {
      _layer = kind;
      _nowcastUserMoved = false;
      if (period != null) {
        _quakePeriod = period;
      }
      // 台風: 指定があればその1つだけ、無ければ全台風を表示する
      if (kind == MapLayerKind.typhoon) _typhoonId = typhoonId;
      _layerFailed = false;
    });
    // レイヤーを ON にしたらシートは畳む（操作板カードが出るので地図を広く見せる。2026-09-27 要望）
    if (kind != MapLayerKind.none && _sheetExpanded) _setSheetExpanded(false);
    if (kind == MapLayerKind.shelters) {
      await _showShelterNoticeOnce();
      _requestLayerDataForView();
      return;
    }
    if (kind == MapLayerKind.facilities) {
      await _showFacilityNoticeOnce();
      _requestLayerDataForView();
      return;
    }
    if (kind == MapLayerKind.oldMap) {
      await Kjmap.load();
      await _showKjNoticeOnce();
      _updateKjRegion();
      return;
    }
    if (kind == MapLayerKind.none || HazardLayers.isHazard(kind)) return;
    await _refreshLayer();
    // 台風: 表示対象の経路と予報円が収まるように地図を寄せる（無ければそのまま）
    if (kind == MapLayerKind.typhoon && _typhoons.isNotEmpty && mounted) {
      _fitToTyphoons(_selectedTyphoons);
    }
    _startLayerTimer();
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
      case MapLayerKind.riskLand:
      case MapLayerKind.riskInund:
      case MapLayerKind.riskFlood:
        final t = await JmaLayers.fetchLatestRisk();
        if (t != null) _risk = t;
        ok = t != null;
      case MapLayerKind.typhoon:
        // 発表中の台風が無いのは正常（凡例に「ありません」と出す）
        _typhoons = await JmaTyphoon.fetchAll();
        // 選択中の台風が一覧から消えた（温帯低気圧化など）ら全表示に戻す
        if (_typhoonId != null && !_typhoons.any((t) => t.id == _typhoonId)) {
          _typhoonId = null;
        }
      case MapLayerKind.snowDepth:
      case MapLayerKind.snowfall24h:
        final st = await JmaLayers.fetchLatestSnow();
        if (st != null) _snowTime = st;
        ok = st != null;
      case MapLayerKind.underpass:
        _underpass = await Underpass.fetch();
        ok = _underpass.sources.isNotEmpty;
      case MapLayerKind.roadRegulation:
        _roadReg = await RoadRegulation.fetch();
        ok = _roadReg.sources.isNotEmpty;
      case MapLayerKind.roadClosures:
        final results = await Future.wait([Underpass.fetch(), RoadRegulation.fetch()]);
        _underpass = results[0] as UnderpassStatus;
        _roadReg = results[1] as RoadRegulationStatus;
        ok = _underpass.sources.isNotEmpty || _roadReg.sources.isNotEmpty;
      case MapLayerKind.none:
      case MapLayerKind.hazardFlood:
      case MapLayerKind.hazardLandslide:
      case MapLayerKind.hazardTsunami:
      case MapLayerKind.hazardHightide:
      case MapLayerKind.shelters:
      case MapLayerKind.facilities:
      case MapLayerKind.oldMap:
        break;
    }
    if (mounted) {
      setState(() {
        _layerLoading = false;
        _layerFailed = !ok;
      });
    }
  }

  /// レイヤー選択シートのタイル1個（2列グリッド）。サブタイトルは長押しで
  /// Tooltip表示にする（タイルに文言を出すと縦に長くなりすぎるため）
  Widget _layerGridTile(
    BuildContext ctx, {
    required MapLayerKind kind,
    String? tooltip,
    bool fullWidth = false,
    VoidCallback? onTap,
  }) {
    final selected = _layer == kind;
    final scheme = Theme.of(ctx).colorScheme;
    final body = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : null,
        border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(_layerIcon(kind),
            size: 18, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_layerTitle(kind),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurface)),
        ),
        if (selected) Icon(Icons.check, size: 16, color: scheme.primary),
      ]),
    );
    final tapped = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () { Navigator.pop(ctx); _setLayer(kind); },
        child: body,
      ),
    );
    final withTooltip = tooltip == null || tooltip.isEmpty
        ? tapped
        : Tooltip(message: tooltip, child: tapped);
    if (fullWidth) return withTooltip;
    return SizedBox(width: (MediaQuery.sizeOf(ctx).width - 56) / 2, child: withTooltip);
  }

  void _showLayerPicker(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: _sheetConstraints(context),
      builder: (ctx) {
        Widget sectionHeading(String title, Widget subtitle) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DefaultTextStyle.merge(
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant), child: subtitle),
              ]),
            );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Text(l10n.mapLayersTooltip,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonClose,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l10n.mapLayerPanelSubtitle,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
              _layerGridTile(ctx, kind: MapLayerKind.none, fullWidth: true),
              sectionHeading(l10n.mapLayerSectionWeather, const Text(JmaLayers.attribution)),
              Wrap(spacing: 16, runSpacing: 8, children: [
                _layerGridTile(ctx, kind: MapLayerKind.rainRadar, tooltip: l10n.mapLayerRainRadarSubtitle),
                _layerGridTile(ctx, kind: MapLayerKind.quakes),
                _layerGridTile(ctx, kind: MapLayerKind.rain24h, tooltip: l10n.mapLayerRain24hSubtitle),
                _layerGridTile(ctx, kind: MapLayerKind.typhoon, tooltip: l10n.mapLayerTyphoonSubtitle),
                _layerGridTile(ctx, kind: MapLayerKind.snowDepth, tooltip: l10n.mapLayerSnowDepthSubtitle),
                _layerGridTile(ctx, kind: MapLayerKind.snowfall24h, tooltip: l10n.mapLayerSnowfall24hSubtitle),
                for (final k in const [
                  MapLayerKind.riskLand,
                  MapLayerKind.riskInund,
                  MapLayerKind.riskFlood,
                ])
                  _layerGridTile(ctx, kind: k, tooltip: riskLayerSubtitleOf(l10n, RiskLayers.titleKey(k))),
              ]),
              sectionHeading(l10n.mapLayerSectionHazard, const Text(HazardLayers.attribution)),
              Wrap(spacing: 16, runSpacing: 8, children: [
                for (final k in const [
                  MapLayerKind.hazardFlood,
                  MapLayerKind.hazardLandslide,
                  MapLayerKind.hazardTsunami,
                  MapLayerKind.hazardHightide,
                ])
                  _layerGridTile(ctx,
                      kind: k,
                      tooltip: k == MapLayerKind.hazardLandslide
                          ? l10n.mapHazardLandslideSubtitle
                          : l10n.mapHazardDepthSubtitle),
              ]),
              sectionHeading(l10n.mapShelterTitle, const Text(ShelterLayers.attribution)),
              Wrap(spacing: 16, runSpacing: 8, children: [
                _layerGridTile(ctx, kind: MapLayerKind.shelters, tooltip: l10n.mapLayerShelterSubtitle),
                // 道路の通行止め・規制（自治体の冠水センサー＋国交省の規制情報を統合。色＝原因。1.5.2）
                // 旧「地下道の冠水状況」「道路の通行規制」の描画コードは残してあるが選択肢には出さない
                _layerGridTile(ctx, kind: MapLayerKind.roadClosures, tooltip: l10n.mapLayerRoadClosuresSubtitle),
                _layerGridTile(ctx, kind: MapLayerKind.oldMap, tooltip: l10n.mapLayerOldMapSubtitle),
              ]),
              // 防災拠点（給水拠点・防災備蓄倉庫）は公開自治体が4都県8自治体と少ないため
              // 1.2.0 では選択肢に出さない（2026-08-31 ユーザー判断）。実装は残してあり、
              // 配信データのカバーが広がったら showFacilitiesLayer を true にする
              if (showFacilitiesLayer) ...[
                // 出典表記は翻訳しない（SPEC C5）
                sectionHeading(l10n.mapFacilityTitle,
                    const Text('出典：各自治体のオープンデータ（公開している自治体のみ）')),
                Wrap(spacing: 16, runSpacing: 8, children: [
                  _layerGridTile(ctx, kind: MapLayerKind.facilities, tooltip: l10n.mapLayerFacilitySubtitle),
                ]),
              ],
            ]),
          ),
        );
      },
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
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
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
                  child: Text(l10n.mapQuakeNearbyTitle(group.length),
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
                      title: Text(
                          q.place.isEmpty ? l10n.mapQuakeUnknownPlace : q.place),
                      subtitle: Builder(builder: (_) {
                        final t = q.at.toLocal();
                        return Text('${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}'
                            '${q.magnitude.isNotEmpty ? '　M${q.magnitude}' : ''}'
                            '${q.maxIntensity.isNotEmpty ? '　${l10n.mapQuakeMaxIntensity(q.maxIntensity)}' : ''}');
                      }),
                      trailing: const Icon(Icons.videocam),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => NearbyCamerasScreen(
                                app: widget.app,
                                title: l10n.mapNearbyCamerasTitle(q.place.isEmpty
                                    ? l10n.mapLayerQuakesTitle
                                    : q.place),
                                lat: q.pos!.latitude,
                                lng: q.pos!.longitude)));
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.mapQuakeTapHint,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          ]),
        ),
      ),
    );
  }

  // --- 避難場所レイヤー（国土地理院 指定緊急避難場所。県ファイルを表示範囲に応じて取得） ---
  ShelterStore? _shelters;
  int? _shelterHazard; // null=すべて
  Set<String> _shelterPrefs = const {};
  static const _shelterNoticeKey = 'shelter_notice_seen';

  Future<ShelterStore> _shelterStore() async {
    if (_shelters != null) return _shelters!;
    Directory? dir;
    try {
      dir = await getTemporaryDirectory();
    } catch (_) {
      dir = null; // 保存できなくてもメモリキャッシュだけで動く
    }
    return _shelters ??= ShelterStore(cacheDir: dir)..addListener(_onDataChanged);
  }

  /// 初回ONのときだけ利用上の注意（index.notice の要点）を1回表示する
  Future<void> _showShelterNoticeOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shelterNoticeKey) ?? false) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mapShelterNoticeTitle),
        content: SingleChildScrollView(
          child: Text(
            '${ctx.l10n.mapShelterNoticeBody}\n\n${ShelterLayers.attribution}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    await prefs.setBool(_shelterNoticeKey, true);
  }

  /// 昔の地図を初めてONにしたときの注意（位置ずれ・目安であること）
  Future<void> _showKjNoticeOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kjNoticeKey) ?? false) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mapOldMapNoticeTitle),
        content: SingleChildScrollView(
          child: Text(
            '${ctx.l10n.mapOldMapNoticeBody}\n\n${Kjmap.attribution}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    await prefs.setBool(_kjNoticeKey, true);
  }

  /// 地図の中心を含む今昔マップの地域を選び直す。地域が変わっても同じ時期があれば維持し、
  /// 無ければ最も古い時期にする。範囲外なら null（凡例に「未収録」と出す）
  void _updateKjRegion() {
    if (_layer != MapLayerKind.oldMap) return;
    final center = _center;
    final regions = Kjmap.regions;
    KjmapRegion? next = _kjRegion;
    if (next == null || !next.contains(center)) {
      final hits = Kjmap.regionsAt(regions, center);
      next = hits.isEmpty ? null : hits.first;
    }
    String? era = _kjEra;
    if (next != null && (era == null || next.era(era) == null)) era = next.eras.first.folder;
    if (next == null) era = null;
    if (next?.id != _kjRegion?.id || era != _kjEra) {
      setState(() {
        _kjRegion = next;
        _kjEra = era;
      });
    }
  }

  /// 昔の地図の操作（時期のチップ／比較方法／透過スライダー）。地図左下に積む
  Widget _kjChips() {
    final l10n = context.l10n;
    final region = _kjRegion;
    Widget modeButton(_KjCompare m, IconData icon, String tooltip) => IconButton(
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          isSelected: _kjCompare == m,
          style: IconButton.styleFrom(
              backgroundColor: _kjCompare == m ? Theme.of(context).colorScheme.primaryContainer : null),
          onPressed: () => setState(() => _kjCompare = m),
        );
    // 操作板カードの展開部に置くので、以前の単独フロート用の白背景・影は持たない
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (region != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history, size: 16, color: Colors.brown),
              const SizedBox(width: 6),
              for (final e in region.eras)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_kjEraLabel(e), style: const TextStyle(fontSize: 12)),
                    selected: _kjEra == e.folder,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => setState(() => _kjEra = e.folder),
                  ),
                ),
            ]),
          ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          modeButton(_KjCompare.vertical, Icons.vertical_split, l10n.mapOldMapCompareVertical),
          modeButton(_KjCompare.horizontal, Icons.horizontal_split, l10n.mapOldMapCompareHorizontal),
          modeButton(_KjCompare.opacity, Icons.opacity, l10n.mapOldMapCompareOpacity),
          if (_kjCompare == _KjCompare.opacity)
            SizedBox(
              width: 140,
              child: Slider(
                value: _kjOpacity,
                min: 0.1,
                max: 1,
                onChanged: (v) => setState(() => _kjOpacity = v),
              ),
            ),
        ]),
      ]);
  }

  String _kjEraLabel(KjmapEra e) {
    final l10n = context.l10n;
    return e.start == e.end
        ? l10n.mapOldMapEraSingle(e.start)
        : l10n.mapOldMapEraRange(e.start, e.end);
  }

  /// 表示範囲（余白込み）。初回レイアウト前は null
  (double south, double north, double west, double east)? _viewBoundsWithMargin() {
    final b = _visibleBounds;
    if (b == null) return null;
    final latMargin = (b.north - b.south) * 0.5;
    final lngMargin = (b.east - b.west).abs() * 0.5;
    return (b.south - latMargin, b.north + latMargin, b.west - lngMargin, b.east + lngMargin);
  }

  /// 表示範囲に掛かる県ファイルを要求する（ズーム11未満では何もしない）
  Future<void> _requestSheltersForView() async {
    if (_layer != MapLayerKind.shelters || _zoom < ShelterLayers.minZoom) return;
    final v = _viewBoundsWithMargin();
    if (v == null) return;
    final prefs = ShelterLayers.prefsForBounds(
      widget.app.repository.displayableCameras(),
      south: v.$1, north: v.$2, west: v.$3, east: v.$4,
      center: _center,
    );
    final store = await _shelterStore();
    if (!mounted) return;
    if (!setEquals(prefs, _shelterPrefs)) setState(() => _shelterPrefs = prefs);
    store.request(prefs);
  }

  /// 画面内（余白込み）・災害種別フィルタ適用後の避難場所
  List<Shelter> _visibleShelters() {
    final store = _shelters;
    if (store == null || _zoom < ShelterLayers.minZoom) return const [];
    final v = _viewBoundsWithMargin();
    if (v == null) return const [];
    return ShelterLayers.filterByHazard(
      ShelterLayers.cull(store.sheltersFor(_shelterPrefs),
          south: v.$1, north: v.$2, west: v.$3, east: v.$4),
      _shelterHazard,
    );
  }

  /// 災害種別の絞り込みチップ（左下縦積みの先頭。雨雲スライダーと同じ位置）
  Widget _shelterChips() {
    if (_layer != MapLayerKind.shelters) return const SizedBox.shrink();
    final hazards = _shelters?.hazards ?? ShelterLayers.defaultHazards;
    Widget chip(String label, int? value) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: _shelterHazard == value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => setState(() => _shelterHazard = value),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.home_work_outlined, size: 16),
        const SizedBox(width: 6),
        chip(context.l10n.mapShelterHazardAll, null),
        for (var i = 0; i < hazards.length; i++)
          chip(shelterHazardLabelOf(context.l10n, hazards[i]), i),
      ]),
    );
  }

  void _showShelterInfo(Shelter s) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final hazards = _shelters?.hazards ?? ShelterLayers.defaultHazards;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 8),
                child: _ShelterPin(designated: false, size: 22),
              ),
              Expanded(
                child: Text(s.name.isEmpty ? l10n.mapShelterTitle : s.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              if (s.designated)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _ShelterPin.color,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(l10n.mapShelterDesignated,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ]),
            if (s.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(s.address, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
            // 標高（津波・高潮のときの判断材料。国土地理院の標高APIを1回だけ呼ぶ）
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevationLabel(lat: s.lat, lng: s.lng),
            ),
            const SizedBox(height: 8),
            Text(l10n.mapShelterHazardsLabel,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (var i = 0; i < hazards.length; i++)
                Chip(
                  label: Text(shelterHazardLabelOf(l10n, hazards[i]),
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: s.hazards.contains(i) ? _ShelterPin.color.withValues(alpha: 0.18) : null,
                  side: s.hazards.contains(i) ? const BorderSide(color: _ShelterPin.color) : null,
                  labelStyle: TextStyle(
                      color: s.hazards.contains(i)
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.38)),
                ),
            ]),
            const SizedBox(height: 12),
            // 2段に積む（横並びだと「周辺のライブカメラ」が途中で改行される）
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(
                  icon: const Icon(Icons.directions, size: 18),
                  label: Text(l10n.mapOpenRoute),
                  onPressed: () => launchUrl(
                      ShelterLayers.routeUri(s),
                      mode: LaunchMode.externalApplication),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  icon: const Icon(Icons.videocam, size: 18),
                  label: Text(l10n.mapNearbyCamerasButton),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NearbyCamerasScreen(
                            app: widget.app,
                            title: l10n.mapNearbyCamerasTitle(
                                s.name.isEmpty ? l10n.mapShelterTitle : s.name),
                            lat: s.lat,
                            lng: s.lng)));
                  },
                ),
            ]),
            const SizedBox(height: 8),
            Text('${ShelterLayers.attribution}　${l10n.shelterDisclaimer}',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  /// 避難場所のマーカー（カメラピンより下に描く。400件超はクラスタ）
  Set<gmaps.Marker> _shelterMarkers(PinBitmaps pins) {
    if (_zoom < ShelterLayers.minZoom) return const {};
    final list = _visibleShelters();
    if (list.isEmpty) return const {};
    final markers = <gmaps.Marker>{};
    if (list.length > ShelterLayers.clusterThreshold) {
      final groups = clusterPoints(list, _zoom, (s) => s.lat, (s) => s.lng);
      for (final g in groups) {
        if (g.count == 1) {
          markers.add(_shelterMarker(g.items.first, pins));
        } else {
          final icon = pins.dotGlyph(
                fillColor: _ShelterPin.color.withValues(alpha: 0.85),
                borderColor: Colors.white,
                borderWidth: 2,
                diameter: 36,
                text: '${g.count}',
                textStyle: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                onReady: _onPinReady,
              ) ??
              gmaps.BitmapDescriptor.defaultMarker;
          markers.add(gmaps.Marker(
            markerId: gmaps.MarkerId(
                'shelter-cluster-${g.lat.toStringAsFixed(4)}-${g.lng.toStringAsFixed(4)}-${g.count}'),
            position: _g(LatLng(g.lat, g.lng)),
            icon: icon,
            anchor: PinBitmaps.dotGlyphAnchor(diameter: 36),
            onTap: () => _moveCamera(LatLng(g.lat, g.lng), _zoom + 2),
          ));
        }
      }
    } else {
      for (final s in list) {
        markers.add(_shelterMarker(s, pins));
      }
    }
    return markers;
  }

  gmaps.Marker _shelterMarker(Shelter s, PinBitmaps pins) {
    final icon = pins.dotGlyph(
          fillColor: _ShelterPin.color.withValues(alpha: 0.9),
          borderColor: Colors.white,
          borderWidth: 1.5,
          diameter: 22,
          icon: Icons.home,
          iconScale: s.designated ? 0.5 : 0.6,
          innerRing: s.designated,
          onReady: _onPinReady,
        ) ??
        gmaps.BitmapDescriptor.defaultMarker;
    return gmaps.Marker(
      markerId: gmaps.MarkerId(
          'shelter-${s.pos.latitude.toStringAsFixed(6)},${s.pos.longitude.toStringAsFixed(6)},${s.name}'),
      position: _g(s.pos),
      icon: icon,
      anchor: PinBitmaps.dotGlyphAnchor(diameter: 22),
      onTap: () => _showShelterInfo(s),
    );
  }

  // --- 防災拠点レイヤー（給水拠点・防災備蓄倉庫・消防水利。自治体オープンデータ） ---
  FacilityStore? _facilities;

  /// 表示する種別（複数選択。既定は給水拠点＋防災備蓄倉庫）
  Set<String> _facilityKinds = {...FacilityLayers.defaultSelectedKinds};
  Set<String> _facilityPrefs = const {};
  static const _facilityKindsKey = 'facility_kinds';
  static const _facilityNoticeKey = 'facility_notice_seen';

  Future<void> _loadFacilityKinds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = FacilityLayers.decodeKinds(prefs.getString(_facilityKindsKey));
      if (!mounted) return;
      if (!setEquals(saved, _facilityKinds)) setState(() => _facilityKinds = saved);
    } catch (_) {
      // 保存値が読めなくても既定で動く
    }
  }

  Future<void> _saveFacilityKinds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_facilityKindsKey, FacilityLayers.encodeKinds(_facilityKinds));
    } catch (_) {
      // 保存できなくても表示は続く
    }
  }

  Future<FacilityStore> _facilityStore() async {
    if (_facilities != null) return _facilities!;
    Directory? dir;
    try {
      dir = await getTemporaryDirectory();
    } catch (_) {
      dir = null; // 保存できなくてもメモリキャッシュだけで動く
    }
    return _facilities ??= FacilityStore(cacheDir: dir)..addListener(_onDataChanged);
  }

  /// 初回ONのときだけ利用上の注意（index.notice の要点）を1回表示する
  Future<void> _showFacilityNoticeOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_facilityNoticeKey) ?? false) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mapFacilityNoticeTitle),
        content: SingleChildScrollView(
          child: Text(
            '${ctx.l10n.mapFacilityNoticeBody}\n\n${FacilityLayers.attribution}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    await prefs.setBool(_facilityNoticeKey, true);
  }

  /// 表示範囲に掛かる県ファイルを要求する（ズーム13未満・データの無い県では何もしない）
  Future<void> _requestFacilitiesForView() async {
    if (_layer != MapLayerKind.facilities || _zoom < FacilityLayers.minZoom) return;
    final v = _viewBoundsWithMargin();
    if (v == null) return;
    final prefs = FacilityLayers.prefsForBounds(
      widget.app.repository.displayableCameras(),
      south: v.$1, north: v.$2, west: v.$3, east: v.$4,
      center: _center,
    );
    final store = await _facilityStore();
    if (!mounted) return;
    if (!setEquals(prefs, _facilityPrefs)) setState(() => _facilityPrefs = prefs);
    // index が未取得のうちは素通しし、_load 側で対象外の県を弾く
    store.request(FacilityLayers.availablePrefs(prefs, store.index));
    await store.ensureIndex();
  }

  /// 避難場所・防災拠点の県ファイル要求（表示中のレイヤーの分だけ動く）
  void _requestLayerDataForView() {
    _requestSheltersForView();
    _requestFacilitiesForView();
  }

  /// 画面内（余白込み）・種別フィルタ適用後の防災拠点
  List<Facility> _visibleFacilities() {
    final store = _facilities;
    if (store == null || _zoom < FacilityLayers.minZoom) return const [];
    final v = _viewBoundsWithMargin();
    if (v == null) return const [];
    return FacilityLayers.filterByKinds(
      FacilityLayers.cull(store.facilitiesFor(_facilityPrefs),
          south: v.$1, north: v.$2, west: v.$3, east: v.$4),
      _facilityKinds,
    );
  }

  /// 種別の絞り込みチップ（複数選択。避難場所の災害種別チップと同じ位置・体裁）
  Widget _facilityChips() {
    if (_layer != MapLayerKind.facilities) return const SizedBox.shrink();
    Widget chip(String kind) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(facilityKindShortOf(context.l10n, kind),
                style: const TextStyle(fontSize: 12)),
            avatar: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: _FacilityPin.colorOf(kind), shape: BoxShape.circle),
            ),
            selected: _facilityKinds.contains(kind),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (on) {
              setState(() {
                final next = {..._facilityKinds};
                if (on) {
                  next.add(kind);
                } else {
                  next.remove(kind);
                }
                _facilityKinds = next;
              });
              _saveFacilityKinds();
            },
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_drink_outlined, size: 16),
        const SizedBox(width: 6),
        for (final k in FacilityLayers.kindKeys) chip(k),
      ]),
    );
  }

  void _showFacilityInfo(Facility f) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final store = _facilities;
    final src = store?.sourceOf(f);
    // 既知の種別は翻訳済みの正式名称を使い、未知のキーだけ配信JSON/既定値に落とす
    final localizedKind = facilityKindLabelOf(l10n, f.kind);
    final kindLabel = localizedKind != f.kind
        ? localizedKind
        : (store?.index?.labelOf(f.kind) ??
            FacilityLayers.defaultKinds[f.kind] ??
            f.kind);
    final title = f.name.isEmpty ? kindLabel : f.name;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: _FacilityPin(kind: f.kind, size: 22),
              ),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _FacilityPin.colorOf(f.kind),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(facilityKindShortOf(l10n, f.kind),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ]),
            if (f.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(f.address, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(kindLabel, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            if (f.owner.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l10n.mapFacilityOwner(f.owner),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            // 標高（浸水時の判断材料。国土地理院の標高APIを1回だけ呼ぶ）
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevationLabel(lat: f.lat, lng: f.lng),
            ),
            if (f.geocoded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.orange[800]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(l10n.mapFacilityGeocodedNote,
                        style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            // 2段に積む（横並びだと「周辺のライブカメラ」が途中で改行される）
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(
                  icon: const Icon(Icons.directions, size: 18),
                  label: Text(l10n.mapOpenRoute),
                  onPressed: () => launchUrl(
                      FacilityLayers.routeUri(f),
                      mode: LaunchMode.externalApplication),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  icon: const Icon(Icons.videocam, size: 18),
                  label: Text(l10n.mapNearbyCamerasButton),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NearbyCamerasScreen(
                            app: widget.app,
                            title: l10n.mapNearbyCamerasTitle(title),
                            lat: f.lat,
                            lng: f.lng)));
                  },
                ),
            ]),
            const SizedBox(height: 8),
            if (src == null)
              Text('${FacilityLayers.attribution}　${l10n.facilityDisclaimer}',
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant))
            else ...[
              Text(l10n.mapFacilitySourceDataset,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              InkWell(
                onTap: src.url.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse(src.url), mode: LaunchMode.externalApplication),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(src.label,
                      style: TextStyle(
                          fontSize: 11,
                          color: src.url.isEmpty ? scheme.onSurfaceVariant : scheme.primary,
                          decoration: src.url.isEmpty ? null : TextDecoration.underline)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l10n.facilityDisclaimer,
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  /// 防災拠点のマーカー（カメラピンより下に描く。400件超はクラスタ）
  Set<gmaps.Marker> _facilityMarkers(PinBitmaps pins) {
    if (_zoom < FacilityLayers.minZoom) return const {};
    final list = _visibleFacilities();
    if (list.isEmpty) return const {};
    final markers = <gmaps.Marker>{};
    if (list.length > FacilityLayers.clusterThreshold) {
      final groups = clusterPoints(list, _zoom, (f) => f.lat, (f) => f.lng);
      for (final g in groups) {
        if (g.count == 1) {
          markers.add(_facilityMarker(g.items.first, pins));
        } else {
          final kind = FacilityLayers.dominantKind(g.items);
          final icon = pins.dotGlyph(
                fillColor: _FacilityPin.colorOf(kind).withValues(alpha: 0.85),
                borderColor: Colors.white,
                borderWidth: 2,
                diameter: 36,
                text: '${g.count}',
                textStyle: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                onReady: _onPinReady,
              ) ??
              gmaps.BitmapDescriptor.defaultMarker;
          markers.add(gmaps.Marker(
            markerId: gmaps.MarkerId(
                'facility-cluster-${g.lat.toStringAsFixed(4)}-${g.lng.toStringAsFixed(4)}-${g.count}'),
            position: _g(LatLng(g.lat, g.lng)),
            icon: icon,
            anchor: PinBitmaps.dotGlyphAnchor(diameter: 36),
            onTap: () => _moveCamera(LatLng(g.lat, g.lng), _zoom + 2),
          ));
        }
      }
    } else {
      for (final f in list) {
        markers.add(_facilityMarker(f, pins));
      }
    }
    return markers;
  }

  gmaps.Marker _facilityMarker(Facility f, PinBitmaps pins) {
    final icon = pins.dotGlyph(
          fillColor: _FacilityPin.colorOf(f.kind).withValues(alpha: 0.9),
          borderColor: Colors.white,
          borderWidth: 1.5,
          diameter: 22,
          icon: _FacilityPin.iconOf(f.kind),
          iconScale: 0.6,
          onReady: _onPinReady,
        ) ??
        gmaps.BitmapDescriptor.defaultMarker;
    return gmaps.Marker(
      markerId: gmaps.MarkerId(
          'facility-${f.pos.latitude.toStringAsFixed(6)},${f.pos.longitude.toStringAsFixed(6)},${f.kind},${f.name}'),
      position: _g(f.pos),
      icon: icon,
      anchor: PinBitmaps.dotGlyphAnchor(diameter: 22),
      onTap: () => _showFacilityInfo(f),
    );
  }

  /// 雨雲レーダーの時刻スライダー（過去3時間の実況〜1時間先の予測）
  /// 雨雲レーダーの相対表記（「現在」「30分後（予報）」等）。ナウキャストの
  /// 詳しいスライダー・操作板カードのタイトル行の時刻表示で共通に使う
  String _nowcastRelLabel(NowcastTime n) {
    final l10n = context.l10n;
    final latestObs = _nowcastTimes.lastIndexWhere((x) => !x.isForecast);
    final diffMin = latestObs >= 0
        ? n.validAt.difference(_nowcastTimes[latestObs].validAt).inMinutes
        : 0;
    String span(int m) => m.abs() >= 60
        ? l10n.mapNowcastSpanHours(
            (m.abs() / 60).toStringAsFixed(m.abs() % 60 == 0 ? 0 : 1))
        : l10n.mapNowcastSpanMinutes(m.abs());
    return diffMin == 0
        ? l10n.mapNowcastNow
        : diffMin > 0
            ? l10n.mapNowcastAfter(
                span(diffMin),
                n.isHourly
                    ? l10n.mapNowcastForecastHourly
                    : l10n.mapNowcastForecast)
            : l10n.mapNowcastBefore(span(diffMin));
  }

  /// 圧縮表示でも雨雲の時刻だけは操作できるようにする細いスライダー（最頻の操作なので
  /// 展開必須にしない）。両端に最初と最後の時刻ラベルを小さく出す
  Widget _quakePeriodChips() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(l10n.mapQuakePeriodLabel, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        for (final p in QuakePeriod.values)
          ChoiceChip(
            label: Text(switch (p) {
              QuakePeriod.day => l10n.mapQuakePeriodDay,
              QuakePeriod.week => l10n.mapQuakePeriodWeek,
              QuakePeriod.month => l10n.mapQuakePeriodMonth,
            }),
            selected: _quakePeriod == p,
            visualDensity: VisualDensity.compact,
            onSelected: (_) {
              if (_quakePeriod != p) _setLayer(MapLayerKind.quakes, period: p);
            },
          ),
      ]),
    );
  }

  Widget _nowcastCompactSlider() {
    final n = _nowcastTimes[_nowcastIdx];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        Text(_nowcastTimes.first.label, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(trackHeight: 2),
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
        ),
        Text(_nowcastTimes.last.label, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
      ]),
    );
  }

  /// 展開表示のときに出す詳しいスライダー（「現在に戻る」ボタン含む）
  Widget _nowcastSlider() {
    if (_layer != MapLayerKind.rainRadar || _nowcastTimes.length < 2) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final n = _nowcastTimes[_nowcastIdx];
    final latestObs = _nowcastTimes.lastIndexWhere((x) => !x.isForecast);
    final rel = _nowcastRelLabel(n);
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
              child: Text(l10n.mapNowcastBackToNow,
                  style: const TextStyle(fontSize: 12)),
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
          Text(_nowcastTimes.first.label, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
          Text(l10n.mapNowcastNowMarker,
              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
          Text(l10n.mapNowcastLast(_nowcastTimes.last.label),
              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
        ]),
      ]);
  }

  /// 地図レイヤーの凡例・出典（地図左下、地理院表記の上）
  Widget _layerLegend() {
    if (_layer == MapLayerKind.none) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
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
        title = (_nowcast?.isHourly ?? false)
            ? l10n.mapLegendRainRadarKind(
                _nowcast?.label ?? '', l10n.mapNowcastForecastHourly)
            : (_nowcast?.isForecast ?? false)
                ? l10n.mapLegendRainRadarKind(
                    _nowcast?.label ?? '', l10n.mapNowcastForecast)
                : l10n.mapLegendRainRadar(_nowcast?.label ?? '');
        items.addAll([
          swatch(const Color(0xFFB3E5FC), l10n.mapLegendRainWeak),
          swatch(const Color(0xFF0041FF), '10'),
          swatch(const Color(0xFFFAF500), '30'),
          swatch(const Color(0xFFFF9900), '50'),
          swatch(const Color(0xFFFF2800), '80mm/h'),
        ]);
      case MapLayerKind.quakes:
        title = l10n.mapLegendQuakes(
            switch (_quakePeriod) {
              QuakePeriod.day => l10n.mapQuakePeriodDay,
              QuakePeriod.week => l10n.mapQuakePeriodWeek,
              QuakePeriod.month => l10n.mapQuakePeriodMonth,
            },
            _quakes.length);
        items.addAll([
          swatch(JmaLayers.intensityColor('3'), l10n.mapLegendIntensity('3')),
          swatch(JmaLayers.intensityColor('4'), '4'),
          swatch(JmaLayers.intensityColor('5-'), intensityLabelOf(l10n, '5-')),
          swatch(JmaLayers.intensityColor('6-'), l10n.mapLegendIntensity6Up),
        ]);
      case MapLayerKind.snowDepth:
        title = l10n.mapLegendSnowDepth(_snowTime?.label ?? '');
        items.addAll([for (final s in SnowLayers.depthScale) swatch(s.$1, s.$2)]);
      case MapLayerKind.snowfall24h:
        title = l10n.mapLegendSnowfall24h(_snowTime?.label ?? '');
        items.addAll([for (final s in SnowLayers.snowfall24hScale) swatch(s.$1, s.$2)]);
      case MapLayerKind.typhoon:
        if (_typhoons.isEmpty) {
          title = l10n.mapLayerTyphoonNone;
        } else {
          final sel = _selectedTyphoons;
          if (sel.length == 1) {
            final t = sel.first;
            final intensity = typhoonIntensityOf(l10n, t.analysis.intensity);
            title = [
              typhoonNameOf(l10n, t),
              if (intensity.isNotEmpty) intensity,
            ].join(' ');
          } else {
            title = sel.map((t) => typhoonNameOf(l10n, t)).join('・');
          }
          items.addAll([
            swatch(_typhoonTrackColor, l10n.mapLegendTyphoonTrack),
            swatch(_typhoonForecastColor, l10n.mapLegendTyphoonForecast),
            swatch(_typhoonCircleColor, l10n.mapLegendTyphoonCircle),
            swatch(_typhoonStormColor, l10n.mapLegendTyphoonStorm),
            swatch(_typhoonGaleColor, l10n.mapLegendTyphoonGale),
          ]);
        }
      case MapLayerKind.rain24h:
        title = _zoom >= 9
            ? l10n.mapLegendRain24h(_rain24hTile?.label ?? '')
            : l10n.mapLegendRain24hZoom(_rain24hTile?.label ?? '');
        items.addAll([
          for (final s in JmaLayers.rain24hScale) swatch(s.$2, s.$3),
        ]);
      case MapLayerKind.riskLand:
      case MapLayerKind.riskInund:
      case MapLayerKind.riskFlood:
        title =
            '${riskLayerTitleOf(l10n, RiskLayers.titleKey(_layer))} ${_risk?.label ?? ''}';
        // 「留意」は白／うすい水色で凡例の地に埋もれるため、色見本だけ細い枠を付ける
        items.addAll([
          for (final s in RiskLayers.scale(_layer))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: s.$1, border: Border.all(color: scheme.outlineVariant, width: 0.5)),
                ),
                const SizedBox(width: 2),
                Text(riskLevelLabelOf(l10n, s.$2),
                    style: const TextStyle(fontSize: 9)),
              ]),
            ),
        ]);
      case MapLayerKind.hazardFlood:
      case MapLayerKind.hazardTsunami:
      case MapLayerKind.hazardHightide:
        title = hazardLayerTitleOf(l10n, HazardLayers.titleKey(_layer));
        items.addAll([for (final s in HazardLayers.depthScale) swatch(s.$1, s.$2)]);
      case MapLayerKind.hazardLandslide:
        title = l10n.mapLegendLandslide(
            hazardLayerTitleOf(l10n, HazardLayers.titleKey(_layer)));
        items.addAll([
          for (final s in HazardLayers.landslideScale)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, color: s.$2),
                Container(width: 10, height: 10, color: s.$3),
                const SizedBox(width: 2),
                Text(landslideKindOf(l10n, s.$1),
                    style: const TextStyle(fontSize: 9)),
              ]),
            ),
        ]);
      case MapLayerKind.shelters:
        if (_zoom < ShelterLayers.minZoom) {
          title = l10n.mapLegendShelterZoomIn;
        } else {
          final n = _visibleShelters().length;
          final clustered = n > ShelterLayers.clusterThreshold;
          if (_shelterHazard == null) {
            title = clustered
                ? l10n.mapLegendShelterCluster(n)
                : l10n.mapLegendShelter(n);
          } else {
            final h = shelterHazardLabelOf(
                l10n,
                (_shelters?.hazards ??
                    ShelterLayers.defaultHazards)[_shelterHazard!]);
            title = clustered
                ? l10n.mapLegendShelterHazardCluster(h, n)
                : l10n.mapLegendShelterHazard(h, n);
          }
        }
        items.addAll([
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const _ShelterPin(designated: false, size: 12),
              const SizedBox(width: 2),
              Text(l10n.mapLegendShelterEmergency,
                  style: const TextStyle(fontSize: 9)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const _ShelterPin(designated: true, size: 12),
              const SizedBox(width: 2),
              Text(l10n.mapLegendShelterDesignated,
                  style: const TextStyle(fontSize: 9)),
            ]),
          ),
        ]);
      case MapLayerKind.facilities:
        if (_zoom < FacilityLayers.minZoom) {
          title = l10n.mapLegendFacilityZoomIn;
        } else if (_facilities?.allUnavailable(_facilityPrefs) ?? false) {
          title = l10n.mapLegendFacilityNoData(l10n.facilityNoData);
        } else {
          final n = _visibleFacilities().length;
          title = n > FacilityLayers.clusterThreshold
              ? l10n.mapLegendFacilityCluster(n)
              : l10n.mapLegendFacility(n);
        }
        items.addAll([
          for (final k in FacilityLayers.kindKeys)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Opacity(
                opacity: _facilityKinds.contains(k) ? 1 : 0.35,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _FacilityPin(kind: k, size: 12),
                  const SizedBox(width: 2),
                  Text(facilityKindShortOf(l10n, k),
                      style: const TextStyle(fontSize: 9)),
                ]),
              ),
            ),
        ]);
      case MapLayerKind.underpass:
        if (_underpass.sources.isEmpty) {
          title = l10n.mapLayerUnderpassNone;
        } else {
          title = l10n.mapLegendUnderpass(_underpass.allPoints.length);
          items.addAll([
            swatch(const Color(0xFF1E88E5), l10n.underpassLevel0),
            swatch(const Color(0xFFF9A825), l10n.underpassLevel1),
            swatch(const Color(0xFFD32F2F), l10n.underpassLevel2),
          ]);
        }
      case MapLayerKind.roadRegulation:
        if (_roadReg.sources.isEmpty) {
          title = l10n.mapLayerRoadRegulationNone;
        } else {
          title = l10n.mapLegendRoadRegulation(_roadReg.allItems.length);
          items.addAll([
            swatch(const Color(0xFFD32F2F), l10n.roadRegulationLevel2),
            swatch(const Color(0xFFF57C00), l10n.roadRegulationLevel1),
          ]);
        }
      case MapLayerKind.roadClosures:
        final items = _closureItems;
        if (_underpass.sources.isEmpty && _roadReg.sources.isEmpty) {
          title = l10n.mapLayerRoadClosuresNone;
        } else {
          title = l10n.mapLegendRoadClosures(items.where((i) => i.isAlert).length);
          items.clear();
        }
      case MapLayerKind.oldMap:
        final r = _kjRegion;
        final e = r == null || _kjEra == null ? null : r.era(_kjEra!);
        title = r == null || e == null
            ? l10n.mapOldMapNoRegion
            : l10n.mapLegendOldMap(r.name, _kjEraLabel(e));
      case MapLayerKind.none:
        title = '';
    }
    final hazard = HazardLayers.isHazard(_layer) ||
        _layer == MapLayerKind.shelters ||
        _layer == MapLayerKind.facilities ||
        _layer == MapLayerKind.underpass ||
        _layer == MapLayerKind.roadRegulation ||
        _layer == MapLayerKind.roadClosures;
    final layerLoading = _layerLoading ||
        (_layer == MapLayerKind.shelters && (_shelters?.loading ?? false)) ||
        (_layer == MapLayerKind.facilities && (_facilities?.loading ?? false));
    // 操作板カードの展開部に置くので、以前の単独フロート用の白背景は持たない。
    // 展開しているあいだは常に全部見えるので、出典行の折りたたみは不要になった
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          if (layerLoading) const Padding(
              padding: EdgeInsets.only(left: 6),
              child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))),
          if (_layerFailed) Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(l10n.mapLegendFetchFailed,
                  style: const TextStyle(fontSize: 9, color: Colors.red))),
          ]),
        if (_layer == MapLayerKind.shelters &&
            _zoom >= ShelterLayers.minZoom &&
            (_shelters?.failed.intersection(_shelterPrefs).isNotEmpty ?? false))
          InkWell(
            onTap: () => _shelters?.retry(_shelterPrefs),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 12, color: Colors.red[700]),
                const SizedBox(width: 3),
                Text(l10n.mapShelterFetchFailed,
                    style: TextStyle(fontSize: 9, color: Colors.red[700], fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        if (_layer == MapLayerKind.facilities &&
            _zoom >= FacilityLayers.minZoom &&
            (_facilities?.failed.intersection(_facilityPrefs).isNotEmpty ?? false))
          InkWell(
            onTap: () => _facilities?.retry(_facilityPrefs),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 12, color: Colors.red[700]),
                const SizedBox(width: 3),
                Text(l10n.mapFacilityFetchFailed,
                    style: TextStyle(fontSize: 9, color: Colors.red[700], fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        Row(mainAxisSize: MainAxisSize.min, children: items),
        if (_layer == MapLayerKind.roadClosures && (_underpass.sources.isNotEmpty || _roadReg.sources.isNotEmpty)) ...[
          // 色＝原因、形＝重さ
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final c in ClosureCause.values) swatch(closureCauseColor(c), closureCauseNameOf(l10n, c)),
          ]),
          Text(l10n.closureLegendNote, style: TextStyle(fontSize: 9, color: scheme.onSurface)),
        ],
        // 展開表示は常に全部見えるので、出典行も常に出す
        // 冠水状況の出典は情報源が多いので1行にまとめ、一覧ページへリンクする（各地点の詳細にも出典を出す）
        if (_layer == MapLayerKind.underpass || _layer == MapLayerKind.roadClosures)
          InkWell(
            onTap: () => launchUrl(Uri.parse(underpassSourcesPageUrl), mode: LaunchMode.externalApplication),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(l10n.mapLegendUnderpassSources(_underpass.sources.length + _roadReg.sources.length),
                  style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant, decoration: TextDecoration.underline)),
              Icon(Icons.open_in_new, size: 10, color: scheme.onSurfaceVariant),
            ]),
          ),
        if (_layer == MapLayerKind.roadRegulation)
          for (final s in _roadReg.sources)
            Text(s.attribution, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
        if (!hazard)
          Text(JmaLayers.attribution,
              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
      ]);
  }

  static const _typhoonTrackColor = Color(0xFF616E7C);
  static const _typhoonForecastColor = Color(0xFFD32F2F);
  static const _typhoonCircleColor = Color(0xFF1E88E5);
  static const _typhoonStormColor = Color(0xFFE53935);
  static const _typhoonGaleColor = Color(0xFFFFB300);

  /// 台風レイヤーの表示対象（選択中の1つ、または全台風）
  List<Typhoon> get _selectedTyphoons {
    final id = _typhoonId;
    if (id == null) return _typhoons;
    final one = _typhoons.where((t) => t.id == id).toList();
    return one.isEmpty ? _typhoons : one;
  }

  /// 台風の切替チップ（複数発生時のみ。「すべて」＋台風ごと）
  Widget _typhoonChips() {
    if (_layer != MapLayerKind.typhoon || _typhoons.length < 2) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    void select(String? id) {
      setState(() => _typhoonId = id);
      _fitToTyphoons(_selectedTyphoons);
    }
    Widget chip(String label, String? id) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: _typhoonId == id,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => select(id),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cyclone, size: 16, color: _typhoonForecastColor),
        const SizedBox(width: 6),
        chip(l10n.mapTyphoonAll, null),
        for (final t in _typhoons) chip(typhoonNameOf(l10n, t), t.id),
      ]),
    );
  }

  /// 台風の経路・予報円・暴風警戒域が収まる範囲に地図を寄せる（複数なら全部）
  void _fitToTyphoons(Iterable<Typhoon> typhoons) {
    // 実況の中心と予報の中心・予報円だけに寄せる。過去の経路と暴風域まで含めると
    // 東アジア全体が入る広域表示になってしまう（2026-09-27 要望）
    final pts = <LatLng>[];
    for (final t in typhoons) {
      pts.add(t.analysis.center);
      for (final p in t.forecasts) {
        pts.add(p.center);
        final r = p.probabilityRadiusM ?? 0;
        if (r > 0) {
          // 半径分だけ四隅を広げる（緯度1度≒111km）
          final dLat = r / 111000;
          final dLng = r / (111000 * math.cos(p.center.latitude * math.pi / 180));
          pts.add(LatLng(p.center.latitude + dLat, p.center.longitude + dLng));
          pts.add(LatLng(p.center.latitude - dLat, p.center.longitude - dLng));
        }
      }
    }
    _fitBounds(pts, padding: const EdgeInsets.fromLTRB(24, 80, 24, 160));
  }

  /// 台風の実況・予報円・暴風警戒域（気象庁の包絡線を円で近似。旧実装のまま）
  Set<gmaps.Circle> _typhoonCircles() {
    final circles = <gmaps.Circle>{};
    var i = 0;
    for (final t in _selectedTyphoons) {
      final a = t.analysis;
      if (a.galeRadiusKm != null) {
        circles.add(gmaps.Circle(
          circleId: gmaps.CircleId('typhoon-gale-${t.id}-${i++}'),
          center: _g(a.center),
          radius: a.galeRadiusKm! * 1000,
          fillColor: _typhoonGaleColor.withValues(alpha: 0.18),
          strokeColor: _typhoonGaleColor,
          strokeWidth: 1,
        ));
      }
      if (a.stormRadiusKm != null) {
        circles.add(gmaps.Circle(
          circleId: gmaps.CircleId('typhoon-storm-${t.id}-${i++}'),
          center: _g(a.center),
          radius: a.stormRadiusKm! * 1000,
          fillColor: _typhoonStormColor.withValues(alpha: 0.25),
          strokeColor: _typhoonStormColor,
          strokeWidth: 1,
        ));
      }
      for (final f in t.forecasts) {
        final pr = f.probabilityRadiusM;
        // 暴風警戒域: 予報円の半径＋暴風域の半径（気象庁の包絡線を円で近似）
        if (pr != null && f.stormRadiusKm != null) {
          circles.add(gmaps.Circle(
            circleId: gmaps.CircleId('typhoon-stormwarn-${t.id}-${i++}'),
            center: _g(f.center),
            radius: pr + f.stormRadiusKm! * 1000,
            fillColor: _typhoonStormColor.withValues(alpha: 0.10),
            strokeColor: _typhoonStormColor.withValues(alpha: 0.6),
            strokeWidth: 1,
          ));
        }
        if (pr != null) {
          circles.add(gmaps.Circle(
            circleId: gmaps.CircleId('typhoon-prob-${t.id}-${i++}'),
            center: _g(f.center),
            radius: pr,
            fillColor: Colors.transparent,
            strokeColor: _typhoonCircleColor,
            strokeWidth: 2,
          ));
        }
      }
    }
    return circles;
  }

  /// 台風の経路（実線）と予報進路（破線）
  Set<gmaps.Polyline> _typhoonPolylines() {
    final lines = <gmaps.Polyline>{};
    for (final t in _selectedTyphoons) {
      final a = t.analysis;
      if (t.track.length >= 2) {
        lines.add(gmaps.Polyline(
          polylineId: gmaps.PolylineId('typhoon-track-${t.id}'),
          points: [for (final p in t.track) _g(p)],
          color: _typhoonTrackColor,
          width: 3,
        ));
      }
      final fc = [a.center, ...t.forecasts.map((f) => f.center)];
      if (fc.length >= 2) {
        // 破線は PatternItem を使わず、自前で短い実線に分割して描く。
        // iOS の PatternItem は線の長さ÷画面上のダッシュ長ぶんのスパンを作るため、
        // 2,000km 級の予報進路を高ズームで描くとメモリが爆発して即ジェットサムされる
        // （2026-09-27 実測）
        var k = 0;
        for (final seg in _dashSegments(fc, dashKm: 25, gapKm: 15)) {
          lines.add(gmaps.Polyline(
            polylineId: gmaps.PolylineId('typhoon-forecast-${t.id}-${k++}'),
            points: [for (final p in seg) _g(p)],
            color: _typhoonForecastColor,
            width: 3,
          ));
        }
      }
    }
    return lines;
  }

  /// 折れ線を「dashKm の実線・gapKm の空白」の繰り返しに分割する（破線の自前描画）。
  /// 距離は緯度経度の近似（1度≒111km）で十分
  static List<List<LatLng>> _dashSegments(List<LatLng> pts,
      {required double dashKm, required double gapKm}) {
    final out = <List<LatLng>>[];
    if (pts.length < 2) return out;
    var drawing = true;
    var remain = dashKm;
    var cur = <LatLng>[pts.first];
    for (var i = 0; i < pts.length - 1; i++) {
      var a = pts[i];
      final b = pts[i + 1];
      final cosLat = math.cos((a.latitude + b.latitude) / 2 * math.pi / 180);
      var segKm = math.sqrt(math.pow((b.latitude - a.latitude) * 111, 2) +
          math.pow((b.longitude - a.longitude) * 111 * cosLat, 2));
      while (segKm > remain) {
        final t = remain / segKm;
        final m = LatLng(a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t);
        if (drawing) {
          cur.add(m);
          out.add(cur);
          cur = <LatLng>[];
        } else {
          cur = <LatLng>[m];
        }
        segKm -= remain;
        a = m;
        drawing = !drawing;
        remain = drawing ? dashKm : gapKm;
      }
      remain -= segKm;
      if (drawing) cur.add(b);
    }
    if (drawing && cur.length >= 2) out.add(cur);
    return out;
  }

  /// 台風の予報時間ラベルと中心（記号＋名称）
  Set<gmaps.Marker> _typhoonMarkers(PinBitmaps pins) {
    if (_typhoons.isEmpty) return const {};
    final markers = <gmaps.Marker>{};
    final l10n = context.l10n;
    for (final t in _selectedTyphoons) {
      final a = t.analysis;
      for (final f in t.forecasts) {
        final icon = pins.labelBadge(
              text: '${f.hours}h',
              textColor: _typhoonForecastColor,
              bg: Colors.white.withValues(alpha: 0.85),
              fontSize: 9,
              onReady: _onPinReady,
            ) ??
            gmaps.BitmapDescriptor.defaultMarker;
        markers.add(gmaps.Marker(
          markerId: gmaps.MarkerId('typhoon-fc-${t.id}-${f.hours}'),
          position: _g(f.center),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
        ));
      }
      final centerIcon = pins.dotGlyph(
            fillColor: Colors.transparent,
            borderColor: Colors.transparent,
            borderWidth: 0,
            diameter: 28,
            icon: Icons.cyclone,
            iconScale: 1,
            iconColor: _typhoonForecastColor,
            shadow: false,
            label: typhoonNameOf(l10n, t),
            labelColor: Colors.black87,
            onReady: _onPinReady,
          ) ??
          gmaps.BitmapDescriptor.defaultMarker;
      markers.add(gmaps.Marker(
        markerId: gmaps.MarkerId('typhoon-center-${t.id}'),
        position: _g(a.center),
        icon: centerIcon,
        anchor: PinBitmaps.dotGlyphAnchor(diameter: 28, hasLabel: true),
        zIndexInt: 2,
      ));
    }
    return markers;
  }

  // --- 地下道（アンダーパス）の冠水状況レイヤー（自治体センサーの状態表示） ---

  /// カードや通知から: レイヤーを開き、注意・止めの地下道があればそこへ寄せる
  Future<void> _openUnderpassLayer() async {
    setState(() => _closureFilter = ClosureCause.flood);
    await _setLayer(MapLayerKind.roadClosures);
    final alerts = _underpass.alerts;
    if (alerts.isEmpty || !mounted) return;
    if (alerts.length == 1) {
      _moveCamera(alerts.first.pos, 14);
    } else {
      _fitBounds([for (final p in alerts) p.pos],
          padding: const EdgeInsets.fromLTRB(40, 120, 40, 200));
    }
  }

  /// 冠水センサーが検知中（注意以上）のときだけ「想定される冠水範囲」を道路に沿って描く
  Set<gmaps.Polyline> _underpassPolylines() {
    final lines = <gmaps.Polyline>{};
    for (final s in _underpass.sources) {
      for (final p in s.points) {
        if (!p.isAlert) continue;
        for (var i = 0; i < p.lines.length; i++) {
          lines.add(gmaps.Polyline(
            polylineId: gmaps.PolylineId('underpass-${s.id}-${p.id}-$i'),
            points: [for (final ll in p.lines[i]) _g(ll)],
            color: p.color.withValues(alpha: 0.85),
            width: 6,
          ));
        }
      }
    }
    return lines;
  }

  Set<gmaps.Marker> _underpassMarkers(PinBitmaps pins) {
    final markers = <gmaps.Marker>{};
    for (final s in _underpass.sources) {
      for (final p in s.points) {
        final showLabel = p.isAlert || _zoom >= 13;
        final label = showLabel ? p.name : null;
        final icon = pins.dotGlyph(
              fillColor: p.color,
              borderColor: Colors.white,
              borderWidth: 2,
              diameter: 22,
              icon: p.level >= 2
                  ? Icons.block
                  : (p.level == 1 ? Icons.priority_high : Icons.check),
              iconScale: 14 / 22,
              label: label,
              labelColor: p.isAlert ? p.color : Colors.black87,
              onReady: _onPinReady,
            ) ??
            gmaps.BitmapDescriptor.defaultMarker;
        markers.add(gmaps.Marker(
          markerId: gmaps.MarkerId('underpass-${s.id}-${p.id}'),
          position: _g(p.pos),
          icon: icon,
          anchor: PinBitmaps.dotGlyphAnchor(diameter: 22, hasLabel: label != null),
          onTap: () => _showUnderpassInfo(s, p),
        ));
      }
    }
    return markers;
  }

  void _showUnderpassInfo(UnderpassSource s, UnderpassPoint p) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = switch (p.level) {
      0 => l10n.underpassLevel0,
      1 => l10n.underpassLevel1,
      2 => l10n.underpassLevel2,
      _ => l10n.underpassLevelUnknown,
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(12)),
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            if (p.at.isNotEmpty)
              Text(l10n.underpassUpdated(p.at),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(l10n.underpassNotice, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(s.attribution, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (s.url.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l10n.underpassOpenSource),
              ),
          ]),
        ),
      ),
    );
  }

  /// 道路の通行規制: 規制区間の線
  Set<gmaps.Polyline> _roadRegulationPolylines() {
    final lines = <gmaps.Polyline>{};
    for (final s in _roadReg.sources) {
      for (final it in s.items) {
        for (var i = 0; i < it.lines.length; i++) {
          lines.add(gmaps.Polyline(
            polylineId: gmaps.PolylineId('roadreg-${s.id}-${it.id}-$i'),
            points: [for (final ll in it.lines[i]) _g(ll)],
            color: it.color.withValues(alpha: 0.85),
            width: 5,
          ));
        }
      }
    }
    return lines;
  }

  /// 道路の通行規制: 起点のピン（拡大時にラベル）
  Set<gmaps.Marker> _roadRegulationMarkers(PinBitmaps pins) {
    final markers = <gmaps.Marker>{};
    for (final s in _roadReg.sources) {
      for (final it in s.items) {
        final label = _zoom >= 11 ? it.name : null;
        final icon = pins.dotGlyph(
              fillColor: it.color,
              borderColor: Colors.white,
              borderWidth: 2,
              diameter: 20,
              icon: it.level >= 2 ? Icons.block : Icons.remove_road,
              iconScale: 12 / 20,
              label: label,
              labelColor: it.color,
              onReady: _onPinReady,
            ) ??
            gmaps.BitmapDescriptor.defaultMarker;
        markers.add(gmaps.Marker(
          markerId: gmaps.MarkerId('roadreg-${s.id}-${it.id}'),
          position: _g(it.pos),
          icon: icon,
          anchor: PinBitmaps.dotGlyphAnchor(diameter: 20, hasLabel: label != null),
          onTap: () => _showRoadRegulationInfo(s, it),
        ));
      }
    }
    return markers;
  }

  void _showRoadRegulationInfo(RoadRegulationSource s, RoadRegulationItem it) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final level = it.level >= 2 ? l10n.roadRegulationLevel2 : l10n.roadRegulationLevel1;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: it.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(it.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(12)),
                child: Text(level,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            if (it.label.isNotEmpty)
              Text(it.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (it.section.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.roadRegulationSection(it.section), style: const TextStyle(fontSize: 13)),
              ),
            if (it.direction.isNotEmpty || it.kind.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text([if (it.kind.isNotEmpty) it.kind, if (it.direction.isNotEmpty) it.direction].join(' · '),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            if (it.at.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l10n.roadRegulationSince(it.at), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 6),
            Text(l10n.roadRegulationNotice, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(s.attribution, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (s.url.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l10n.roadRegulationOpenSource),
              ),
          ]),
        ),
      ),
    );
  }

  /// 統合レイヤーの原因チップ（すべて／冠水／土砂／気象／その他）
  Widget _closureChips() {
    final l10n = context.l10n;
    final all = RoadClosures.merge(_underpass, _roadReg);
    int count(ClosureCause? c) => all.where((i) => i.isAlert && (c == null || i.cause == c)).length;
    Widget chip(String label, ClosureCause? c, Color? color) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            avatar: color == null
                ? null
                : Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            label: Text('$label ${count(c)}', style: const TextStyle(fontSize: 12)),
            selected: _closureFilter == c,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => setState(() => _closureFilter = c),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip(l10n.closureFilterAll, null, null),
        for (final c in ClosureCause.values) chip(closureCauseNameOf(l10n, c), c, closureCauseColor(c)),
      ]),
    );
  }

  /// 統合レイヤー: 線（色＝原因、太さ＝重さ）
  Set<gmaps.Polyline> _roadClosuresPolylines() {
    final lines = <gmaps.Polyline>{};
    for (final it in _closureItems) {
      if (!it.isAlert) continue;
      for (var i = 0; i < it.lines.length; i++) {
        lines.add(gmaps.Polyline(
          polylineId: gmaps.PolylineId('closure-${it.id}-$i'),
          points: [for (final ll in it.lines[i]) _g(ll)],
          color: it.color.withValues(alpha: 0.85),
          width: it.level >= 2 ? 6 : 4,
        ));
      }
    }
    return lines;
  }

  /// 統合レイヤー: ピン（塗りつぶし＝通行止め／白抜き＝規制／小さい丸＝センサー正常）
  Set<gmaps.Marker> _roadClosuresMarkers(PinBitmaps pins) {
    final markers = <gmaps.Marker>{};
    for (final it in _closureItems) {
      final closed = it.level >= 2;
      final normal = it.level <= 0;
      final diameter = normal ? 10.0 : 22.0;
      // ラベルは画像化されるため低ズームでは密集する。通行止めは z8 以上、規制・注意は z11 以上で出す
      final label = normal ? null : (((closed && _zoom >= 8) || _zoom >= 11) ? it.name : null);
      final icon = pins.dotGlyph(
            fillColor: closed ? it.color : Colors.white,
            borderColor: normal
                ? it.color.withValues(alpha: 0.7)
                : (closed ? Colors.white : it.color),
            borderWidth: 2,
            diameter: diameter,
            icon: normal ? null : (closed ? Icons.block : Icons.priority_high),
            iconScale: 13 / 22,
            shadow: !normal,
            label: label,
            labelColor: it.color,
            onReady: _onPinReady,
          ) ??
          gmaps.BitmapDescriptor.defaultMarker;
      markers.add(gmaps.Marker(
        markerId: gmaps.MarkerId('closure-${it.id}'),
        position: _g(it.pos),
        icon: icon,
        anchor: PinBitmaps.dotGlyphAnchor(diameter: diameter, hasLabel: label != null),
        onTap: () => _showClosureInfo(it),
      ));
    }
    return markers;
  }

  void _showClosureInfo(ClosureItem it) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final level = switch (it.level) {
      2 => l10n.closureClosed,
      1 => l10n.closureRestricted,
      0 => l10n.closureNormal,
      _ => l10n.underpassLevelUnknown,
    };
    final badgeColor = it.level >= 1 ? it.color : Colors.grey;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: it.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(it.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                child: Text(level, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${closureCauseNameOf(l10n, it.cause)} · ${it.label}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (it.section.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.roadRegulationSection(it.section), style: const TextStyle(fontSize: 13)),
              ),
            if (it.at.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(it.isSensor ? l10n.underpassUpdated(it.at) : l10n.roadRegulationSince(it.at),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 6),
            Text(it.isSensor ? l10n.underpassNotice : l10n.roadRegulationNotice,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(it.attribution, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (it.sourceUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(it.sourceUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(it.isSensor ? l10n.underpassOpenSource : l10n.roadRegulationOpenSource),
              ),
          ]),
        ),
      ),
    );
  }

  /// 震源のマーカー（円＋最大震度の数字。タップで近傍をまとめて表示）
  Set<gmaps.Marker> _quakeMarkers(PinBitmaps pins) {
    final markers = <gmaps.Marker>{};
    for (final q in _quakesForDraw) {
      final icon = pins.dotGlyph(
            fillColor: JmaLayers.intensityColor(q.maxIntensity).withValues(alpha: 0.85),
            borderColor: Colors.white,
            borderWidth: 1.5,
            diameter: 28,
            text: q.maxIntensity.isEmpty ? '' : q.maxIntensity,
            shadow: false,
            onReady: _onPinReady,
          ) ??
          gmaps.BitmapDescriptor.defaultMarker;
      markers.add(gmaps.Marker(
        markerId: gmaps.MarkerId(
            'quake-${q.at.toIso8601String()}-${q.pos!.latitude.toStringAsFixed(4)},${q.pos!.longitude.toStringAsFixed(4)}'),
        position: _g(q.pos!),
        icon: icon,
        anchor: PinBitmaps.dotGlyphAnchor(diameter: 28),
        onTap: () => _showQuakeInfo(q),
      ));
    }
    return markers;
  }

  /// 24時間降水の観測値ラベル（市街地ズームのみ。tenki.jp方式）
  Set<gmaps.Marker> _rain24hMarkers(PinBitmaps pins) {
    if (_zoom < 9) return const {};
    final markers = <gmaps.Marker>{};
    for (final r in _rain) {
      final icon = pins.labelBadge(
            text: '${r.mm24h.round()}',
            textColor: r.mm24h >= 100 ? Colors.white : Colors.black87,
            bg: JmaLayers.rainColor(r.mm24h).withValues(alpha: 0.95),
            fontSize: 10,
            border: true,
            onReady: _onPinReady,
          ) ??
          gmaps.BitmapDescriptor.defaultMarker;
      markers.add(gmaps.Marker(
        markerId: gmaps.MarkerId('rain24h-${r.name}-${r.pos.latitude},${r.pos.longitude}'),
        position: _g(r.pos),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        // 旧実装の Tooltip(タップで表示) 相当。タップすると吹き出し(InfoWindow)で
        // 観測点名と実測値を出す
        infoWindow: gmaps.InfoWindow(
            snippet: context.l10n.mapRainTooltip(r.name, r.mm24h.toStringAsFixed(1))),
      ));
    }
    return markers;
  }

  /// 表示中のベクタ系レイヤー（台風・震源・避難場所・防災拠点・地下道冠水・
  /// 道路規制・通行止め統合・24時間雨量の観測値ラベル）のマーカー一式。
  /// タイル系（雨雲・キキクル・積雪・ハザードマップ・今昔マップ）は
  /// `_tileOverlays()` 側（GoogleMap移行 第2段階）
  Set<gmaps.Marker> _vectorMarkers(PinBitmaps pins) {
    switch (_layer) {
      case MapLayerKind.quakes:
        return _quakeMarkers(pins);
      case MapLayerKind.rain24h:
        return _rain24hMarkers(pins);
      case MapLayerKind.typhoon:
        return _typhoonMarkers(pins);
      case MapLayerKind.shelters:
        return _shelterMarkers(pins);
      case MapLayerKind.facilities:
        return _facilityMarkers(pins);
      case MapLayerKind.underpass:
        return _underpassMarkers(pins);
      case MapLayerKind.roadRegulation:
        return _roadRegulationMarkers(pins);
      case MapLayerKind.roadClosures:
        return _roadClosuresMarkers(pins);
      case MapLayerKind.rainRadar:
      case MapLayerKind.riskLand:
      case MapLayerKind.riskInund:
      case MapLayerKind.riskFlood:
      case MapLayerKind.hazardFlood:
      case MapLayerKind.hazardLandslide:
      case MapLayerKind.hazardTsunami:
      case MapLayerKind.hazardHightide:
      case MapLayerKind.snowDepth:
      case MapLayerKind.snowfall24h:
      case MapLayerKind.oldMap:
      case MapLayerKind.none:
        return const {};
    }
  }

  /// 表示中のベクタ系レイヤーの線（台風・地下道冠水・道路規制・通行止め統合）＋
  /// ルート沿いの経路線（`_layer` に関係なく表示中は常に描く）
  Set<gmaps.Polyline> _vectorPolylines() {
    final lines = <gmaps.Polyline>{};
    switch (_layer) {
      case MapLayerKind.typhoon:
        lines.addAll(_typhoonPolylines());
      case MapLayerKind.underpass:
        lines.addAll(_underpassPolylines());
      case MapLayerKind.roadRegulation:
        lines.addAll(_roadRegulationPolylines());
      case MapLayerKind.roadClosures:
        lines.addAll(_roadClosuresPolylines());
      case MapLayerKind.quakes:
      case MapLayerKind.rain24h:
      case MapLayerKind.shelters:
      case MapLayerKind.facilities:
      case MapLayerKind.rainRadar:
      case MapLayerKind.riskLand:
      case MapLayerKind.riskInund:
      case MapLayerKind.riskFlood:
      case MapLayerKind.hazardFlood:
      case MapLayerKind.hazardLandslide:
      case MapLayerKind.hazardTsunami:
      case MapLayerKind.hazardHightide:
      case MapLayerKind.snowDepth:
      case MapLayerKind.snowfall24h:
      case MapLayerKind.oldMap:
      case MapLayerKind.none:
        break;
    }
    final route = _route;
    if (route != null) {
      // 白い縁取り+青の線（旧 flutter_map 実装と同じ2本重ね）
      lines.add(gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route-halo'),
        points: [for (final p in route.points) _g(p)],
        color: Colors.white,
        width: 7,
        zIndex: 1,
      ));
      lines.add(gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route-line'),
        points: [for (final p in route.points) _g(p)],
        color: const Color(0xFF1E88E5),
        width: 4,
        zIndex: 2,
      ));
    }
    return lines;
  }

  /// 表示中のベクタ系レイヤーの円（台風の暴風警戒域・強風域・予報円のみ）
  Set<gmaps.Circle> _vectorCircles() =>
      _layer == MapLayerKind.typhoon ? _typhoonCircles() : const {};

  // 旧・地理院タイル/OSMタイルの出し分け（_useWorldTiles/_updateTileMode）は
  // GoogleMap のベース地図に一本化したため不要になり削除した
  // （2026-09-27 GoogleMap移行 第1段階）。

  /// 気象庁タイル（偶数ズームのみ生成。maxNativeZoom 10）・ハザードマップ・今昔マップ用
  /// の TileOverlay をまとめて返す（GoogleMap移行 第2段階）。同一 id の provider が
  /// あれば template だけ書き換えて再利用し、変わっていれば clearTileCache する
  /// （時刻更新・レイヤー切替のたびに作り直すと一瞬消えるため）。
  /// 今昔マップのスワイプ比較（縦線／横線）はここでは載せず、2枚目の GoogleMap
  /// （_kjSwipeOverlay）にだけ載せる
  Set<gmaps.TileOverlay> _tileOverlays() {
    final overlays = <gmaps.TileOverlay>{};
    void add(
      String id, {
      required String template,
      bool tms = false,
      int? minZoom,
      int? maxZoom,
      bool evenZoomOnly = false,
      double transparency = 0,
      int zIndex = 0,
      gmaps.GoogleMapController? controller,
    }) {
      overlays.add(gmaps.TileOverlay(
        tileOverlayId: gmaps.TileOverlayId(id),
        tileProvider: _tileProvider(
          id,
          template: template,
          tms: tms,
          minZoom: minZoom,
          maxZoom: maxZoom,
          evenZoomOnly: evenZoomOnly,
          controller: controller,
        ),
        transparency: transparency,
        zIndex: zIndex,
        fadeIn: false,
      ));
    }

    switch (_layer) {
      case MapLayerKind.rainRadar:
        final n = _nowcast;
        if (n != null) {
          add('jma-nowc',
              template: n.tileTemplate,
              minZoom: 4, maxZoom: 10, evenZoomOnly: true,
              transparency: 0.4, controller: _gmapController);
        }
      case MapLayerKind.rain24h:
        final tile = _rain24hTile;
        if (tile != null) {
          add('jma-rain24h',
              template: tile.tileTemplate,
              minZoom: 4, maxZoom: 10, evenZoomOnly: true,
              transparency: 0.35, controller: _gmapController);
        }
      case MapLayerKind.riskLand:
      case MapLayerKind.riskInund:
      case MapLayerKind.riskFlood:
        // キキクル。危険度が高まっていない範囲は透明タイル、データ領域外は404が正常
        final risk = _risk;
        if (risk != null) {
          add('jma-risk-${RiskLayers.element(_layer)}',
              template: risk.tileTemplate(_layer),
              minZoom: 4, maxZoom: 10, evenZoomOnly: true,
              transparency: 0.35, controller: _gmapController);
        }
      case MapLayerKind.snowDepth:
      case MapLayerKind.snowfall24h:
        final st = _snowTime;
        if (st != null) {
          add('jma-snow-${SnowLayers.element(_layer)}',
              template: st.tileTemplate(_layer),
              minZoom: 4, maxZoom: 10, evenZoomOnly: true,
              transparency: 0.35, controller: _gmapController);
        }
      case MapLayerKind.hazardFlood:
      case MapLayerKind.hazardLandslide:
      case MapLayerKind.hazardTsunami:
      case MapLayerKind.hazardHightide:
        // 地理院の静的タイル。データの無い範囲は404が正常
        final ids = HazardLayers.tileIds(_layer);
        for (var i = 0; i < ids.length; i++) {
          add('hazard-${ids[i]}',
              template: HazardLayers.tileTemplate(ids[i]),
              minZoom: HazardLayers.minZoom, maxZoom: HazardLayers.maxZoom,
              transparency: 0.35, zIndex: i, controller: _gmapController);
        }
      case MapLayerKind.oldMap:
        // 透過比較のときだけ、この（下の）地図に直接重ねる。スワイプ比較は
        // 2枚目の GoogleMap（_kjSwipeOverlay）にだけ載せる
        final r = _kjRegion;
        final era = _kjEra;
        if (r != null && era != null && _kjCompare == _KjCompare.opacity) {
          add('kjmap',
              template: Kjmap.tileTemplate(r.id, era),
              tms: true, minZoom: Kjmap.minZoom, maxZoom: r.maxZoom,
              transparency: 1 - _kjOpacity, controller: _gmapController);
        }
      case MapLayerKind.quakes:
      case MapLayerKind.typhoon:
      case MapLayerKind.shelters:
      case MapLayerKind.facilities:
      case MapLayerKind.underpass:
      case MapLayerKind.roadRegulation:
      case MapLayerKind.roadClosures:
      case MapLayerKind.none:
        break;
    }
    return overlays;
  }

  /// 今昔マップのスワイプ比較（縦線／横線）用に2枚目の GoogleMap に載せる
  /// TileOverlay（不透明。切り抜きは ClipRect 側で行う）
  Set<gmaps.TileOverlay> _kjSwipeOverlay() {
    final r = _kjRegion;
    final era = _kjEra;
    if (r == null || era == null) return const {};
    return {
      gmaps.TileOverlay(
        tileOverlayId: const gmaps.TileOverlayId('kjmap-swipe'),
        tileProvider: _tileProvider(
          'kjmap-swipe',
          template: Kjmap.tileTemplate(r.id, era),
          tms: true,
          minZoom: Kjmap.minZoom,
          maxZoom: r.maxZoom,
          controller: _kjOverlayController,
        ),
        fadeIn: false,
      ),
    };
  }

  /// id ごとに UrlTileProvider を再利用する。template が変わっていれば書き換え、
  /// [controller] があれば `clearTileCache` を呼ぶ（時刻更新・地域/時期変更時に、
  /// レイヤーが一瞬消えないようにするため）
  UrlTileProvider _tileProvider(
    String id, {
    required String template,
    bool tms = false,
    int? minZoom,
    int? maxZoom,
    bool evenZoomOnly = false,
    gmaps.GoogleMapController? controller,
  }) {
    final existing = _tileProviders[id];
    if (existing != null) {
      if (existing.template != template) {
        existing.template = template;
        // clearTileCache も Future を返す非同期メソッド。呼び出し元
        // （build内）は同期のため await できず、catchError で失敗を受ける
        controller?.clearTileCache(gmaps.TileOverlayId(id)).catchError((_) {});
      }
      return existing;
    }
    final p = UrlTileProvider(
      template: template,
      tms: tms,
      minZoom: minZoom,
      maxZoom: maxZoom,
      evenZoomOnly: evenZoomOnly,
      headers: _tileHeaders,
    );
    _tileProviders[id] = p;
    return p;
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
        // NaN/Infinity や範囲外の値を渡すと地図の初期化に支障が出るため検証する
        if (!lat.isFinite || !lng.isFinite || !zoom.isFinite ||
            lat.abs() > 85 || lng.abs() > 180 || zoom < 2 || zoom > 18) {
          await prefs.remove(_posKey);
          return;
        }
        if (!mounted) return;
        _moveCamera(LatLng(lat, lng), zoom);
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
      if (mounted) setState(() => _locationPermissionGranted = true);
      // まずOSが保持する最終既知位置へ即座に移動する（屋内等でGPS測位が
      // 8秒以内に終わらず、前回位置のまま起動してしまう問題の対策）
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        _moveCamera(LatLng(last.latitude, last.longitude), 13);
        _savePosition();
      }
      final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.medium))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _moveCamera(LatLng(pos.latitude, pos.longitude), 13);
      _savePosition();
    } catch (_) {
      // 取得できなければ最終既知位置または前回位置のまま
    }
  }

  Future<void> _savePosition() async {
    // 不正な値を保存すると次回起動から毎回支障が出るため、有限値のときだけ保存
    if (!_center.latitude.isFinite || !_center.longitude.isFinite || !_zoom.isFinite) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _posKey, '${_center.latitude},${_center.longitude},$_zoom');
  }

  // --- 場所検索（国土地理院ジオコーディング。無料・キー不要） ---

  /// フォールバック: Google Places が使えない/該当なしのときの住所検索
  /// （実装は places_search.dart に移設。route_cameras の候補集めからも使う）
  Future<List<(String, LatLng)>> _searchPlace(String query) =>
      PlacesSearch.addressSearch(query);

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

  /// 検索ピルの入口。Googleマップ風の全画面検索を開き、選ばれた場所/カメラへ
  /// 地図を寄せる（結果は Navigator.pop の戻り値で受け取る）
  Future<void> _openPlaceSearch(BuildContext context) async {
    final result = await Navigator.of(context).push<PlaceSearchResult>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => PlaceSearchScreen(
          app: widget.app,
          center: _center,
          searchCameras: _searchCameras,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case PlacePickResult(point: final point, label: final label):
        setState(() => _pickedPlace = (label: label, point: point));
        _stopFollowing();
        _moveCamera(point, 15);
        _savePosition();
        _requestLayerDataForView();
      case CameraPickResult(camera: final camera):
        if (camera.hasLocation) {
          _stopFollowing();
          _moveCamera(LatLng(camera.lat!, camera.lng!), 15);
          _savePosition();
          _requestLayerDataForView();
        }
        _onPinTap(camera);
    }
  }

  // 旧・flutter_map の NaN カメラ復旧ワークアラウンド(_isFiniteCamera/
  // _recoverCamera)は同パッケージ固有の不具合対策だったため、GoogleMap
  // 移行時に削除した（ネイティブ SDK の地図なので同種の不具合は起きない）。

  void _zoomBy(double delta) {
    final z = (_zoom + delta).clamp(2.0, 18.0);
    setState(() => _zoom = z);
    _programmaticMove = true; // ボタン操作ではパネルを沈めない
    _gmapController?.animateCamera(gmaps.CameraUpdate.zoomBy(delta));
    _requestLayerDataForView();
  }

  // 検索欄のコントローラは画面Stateと同寿命で保持する。
  // - 再描画のたびに作り直すとIMEの変換中テキストが破棄され日本語入力が壊れる
  // - シートの close Future 完了時に dispose すると、フリックで閉じた際の
  //   閉アニメーション中にTextFieldが破棄済みコントローラを参照して落ちる
  final _searchController = TextEditingController();

  /// 全画面まで伸びるシートの上限。画面の上 12% は必ずバリアとして残し、
  /// 外側タップで閉じられる状態を保つ（多言語で文言が長い場合の対策）
  static BoxConstraints _sheetConstraints(BuildContext context) =>
      BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88);

  /// 凡例 + カテゴリフィルタのボトムシート
  void _showLegendFilter(BuildContext context) {
    final searchController = _searchController
      ..text = widget.app.searchQuery;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // 英語などで文言が長いとシートが画面いっぱいまで伸び、外側（バリア）を
      // タップして閉じられなくなる（iOS はスワイプで戻れない）。上に余白を
      // 残して常に閉じられるようにし、見出しにも閉じるボタンを置く
      constraints: _sheetConstraints(context),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final app = widget.app;
          final scheme = Theme.of(context).colorScheme;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    child: Text(context.l10n.mapLegendTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.commonClose,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.l10n.mapFilterIntro,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: context.l10n.mapLegendSearchHint,
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
                      for (final key in categoryKeys)
                        FilterChip(
                          // 選択時のチェックマークがアイコンに重なって見分けられなかったため
                          // チェックは出さず、選択は塗りと記号の濃さで示す（2026-09-27）
                          showCheckmark: false,
                          avatar: Opacity(
                            opacity: app.enabledCategories.contains(key) ? 1 : 0.35,
                            child: CircleAvatar(
                                backgroundColor: categoryColor(key),
                                radius: 10,
                                child: CategoryGlyph(key, size: 12)),
                          ),
                          label: Text('${categoryLabelOf(context.l10n, key)} '
                              '${counts[key] ?? 0}'),
                          selected: app.enabledCategories.contains(key),
                          onSelected: (_) {
                            app.toggleCategory(key);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  );
                }),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.settingsVideoOnly),
                  value: app.videoOnly,
                  onChanged: (v) {
                    app.setVideoOnly(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.settingsShowWorld),
                  value: app.showWorld,
                  onChanged: (v) {
                    app.setShowWorld(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.settingsHideUncertain),
                  value: app.hideUncertain,
                  onChanged: (v) {
                    app.setHideUncertain(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.mapFilterFavoritesOnly),
                  value: app.favoritesOnly,
                  onChanged: (v) {
                    app.setFavoritesOnly(v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.mapFilterOkOnly),
                  value: app.okOnly,
                  onChanged: (v) {
                    app.setOkOnly(v);
                    setSheetState(() {});
                  },
                ),
                const Divider(),
                _LegendRow(
                    kind: _LegendKind.liveDot,
                    text: context.l10n.mapLegendLiveDot),
                _LegendRow(
                    kind: _LegendKind.uncertain,
                    text: context.l10n.mapLegendUncertain),
                _LegendRow(
                    kind: _LegendKind.frozen,
                    text: context.l10n.mapLegendFrozen),
                _LegendRow(
                    kind: _LegendKind.favorite,
                    text: context.l10n.mapLegendFavorite),
                _LegendRow(
                    kind: _LegendKind.cluster,
                    text: context.l10n.mapLegendCluster),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(context.l10n.mapFilterBackToMap),
                  ),
                ),
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
    // 台数が多いとシートが画面に収まらずスクロールもできなかったので、
    // 高さに上限を付けて一覧部分をスクロールさせる（2026-09-27）
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: _sheetConstraints(context),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(context.l10n.mapPointCameras(near.length),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
          for (final c in near)
            ListTile(
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: categoryColor(c.category),
                child: CategoryGlyph(c.category, size: 14),
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
            ]),
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

  static const _maxCameraMarkers = 120;
  static const _maxLayerMarkers = 120;

  /// 画面付近（上下左右に2割の余白）のマーカーだけを、地図の中心に近い順に [max] 個まで残す
  Set<gmaps.Marker> _capMarkers(Set<gmaps.Marker> markers, int max) {
    final b = _visibleBounds;
    Iterable<gmaps.Marker> list = markers;
    if (b != null && (b.east - b.west).abs() < 300) {
      final latM = (b.north - b.south) * 0.2, lngM = (b.east - b.west).abs() * 0.2;
      list = list.where((m) =>
          m.position.latitude >= b.south - latM && m.position.latitude <= b.north + latM &&
          m.position.longitude >= b.west - lngM && m.position.longitude <= b.east + lngM);
    }
    final l = list.toList();
    if (l.length <= max) return l.toSet();
    final c = _center;
    double d(gmaps.Marker m) {
      final dy = m.position.latitude - c.latitude, dx = m.position.longitude - c.longitude;
      return dx * dx + dy * dy;
    }
    l.sort((a, b) => d(a).compareTo(d(b)));
    return l.take(max).toSet();
  }

  List<MapItem> _cullToViewport(List<MapItem> items) {
    final b = _visibleBounds;
    if (b == null) return items; // 初回レイアウト前（onMapCreated後に再構築される）
    _lastCullCenter = _center;
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
  void _maybeRebuildForPan() {
    final last = _lastCullCenter;
    final b = _visibleBounds;
    if (last == null || b == null) return;
    final latSpan = b.north - b.south;
    final lngSpan = (b.east - b.west).abs();
    if ((_center.latitude - last.latitude).abs() > latSpan * 0.25 ||
        (_center.longitude - last.longitude).abs() > lngSpan * 0.25) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // お知らせバナーは地図の上に重ねず、地図の上部に積む（台数チップや
    // レイヤーボタンと重なって読めなくなるため。2026-08-30）
    final notice = widget.app.notice;
    final showNotice = notice != null && notice != _dismissedNotice;
    // お知らせもルートも無い平常時は地図だけ（Column を挟まない）
    if (!showNotice && _route == null) return _mapStack(context);
    return Column(children: [
      if (showNotice)
        _NoticeBanner(text: notice, onClose: () => _dismissNotice(notice)),
      // ルート沿い表示中の帯（台数・一覧・解除）。お知らせの有無に関係なく出す
      if (_route != null) _routeBanner(context),
      // バナーが上の安全領域を使うので、地図側では上余白を取り除く（検索窓がバナー分
      // さらに下がっていた。2026-09-27）
      Expanded(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Builder(builder: _mapStack),
        ),
      ),
    ]);
  }

  /// ルート沿い表示中の帯: 台数・距離、一覧、解除
  Widget _routeBanner(BuildContext context) {
    final l10n = context.l10n;
    final r = _route!;
    final km = (r.distanceM / 1000).toStringAsFixed(r.distanceM < 10000 ? 1 : 0);
    return Material(
      color: tintedSurface(context, const Color(0xFFE3F2FD)),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          const SizedBox(width: 12),
          const Icon(Icons.route_outlined, size: 18, color: Color(0xFF1E88E5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l10n.routeBanner(_routeCameras.length, km),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: _routeCameras.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => RouteCamerasScreen(
                        app: widget.app,
                        cameras: _routeCameras,
                        attribution: _route?.attribution ?? RouteCorridor.attribution))),
            child: const Icon(Icons.list, size: 20),
          ),
          TextButton(
            onPressed: _clearRoute,
            child: Text(l10n.routeClear, style: const TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _route = null;
      _routeCameras = const [];
      _routeCameraIds = const {};
    });
  }

  /// 出発地・目的地を入れて経路を引き、経路沿いのカメラだけを表示する
  void _showRouteSheet(BuildContext context, {String? destLabel, LatLng? destPoint}) {
    final l10n = context.l10n;
    final originCtl = TextEditingController();
    final destCtl = TextEditingController(text: destLabel ?? '');
    LatLng? originPos; // 「現在地」または候補選択で確定した座標（入力欄より優先）
    LatLng? destPos = destPoint; // 候補選択で確定した座標
    // 検索した場所から開いたときは、出発地に現在地を自動で入れる
    var autoOrigin = destPoint != null;
    var width = _routeWidthM;
    var busy = false;

    /// 地名を座標にする。候補が複数あれば選ばせる（同名の別地点の取り違え防止。
    /// 例:「赤レンガ倉庫」は横浜・函館・舞鶴にある）。null は見つからない／取消
    /// 候補: 台帳のカメラ名 → Google Places（施設名に強い）→
    /// 国土地理院の住所検索（住所向け・Google が使えないときのフォールバック）の順に集める
    // Google の候補はオートコンプリート（同一セッションで座標取得まで行えば無料）で集め、
    // 座標は選ばれた1件だけ取る（地名検索 Text Search Pro: 超過 $32/1,000 を使わない。2026-10-02）
    Future<List<_RouteHit>> candidates(String query) async {
      final out = <_RouteHit>[];
      for (final c in _searchCameras(query).take(5)) {
        if (!c.hasLocation) continue;
        final pref = c.prefecture.isEmpty ? '' : prefectureNameOf(l10n, c.prefecture);
        out.add((label: l10n.routeCandidateCamera(c.name, pref), point: LatLng(c.lat!, c.lng!), placeId: null, token: null));
      }
      final token = PlacesSearch.newSessionToken();
      final preds = await PlacesSearch.autocomplete(query,
          bias: _center, languageCode: Localizations.localeOf(context).languageCode, sessionToken: token);
      if (preds != null && preds.isNotEmpty) {
        for (final p in preds) {
          out.add((label: p.secondaryText.isEmpty ? p.mainText : '${p.mainText}（${p.secondaryText}）',
              point: null, placeId: p.placeId, token: token));
        }
      } else {
        try {
          for (final h in (await _searchPlace(query)).take(5)) {
            out.add((label: h.$1, point: h.$2, placeId: null, token: null));
          }
        } catch (_) {}
      }
      return out;
    }

    /// 選ばれた候補の座標（Google の候補はここで初めて座標を取る）。取れなければ null
    Future<LatLng?> resolve(_RouteHit h) async {
      if (h.point != null) return h.point;
      if (h.placeId == null || h.token == null) return null;
      try {
        return await PlacesSearch.details(h.placeId!, sessionToken: h.token!);
      } catch (_) {
        return null;
      }
    }

    Future<_RouteHit?> pick(
        BuildContext ctx, String query, List<_RouteHit> hits) async {
      if (!ctx.mounted) return null;
      return showDialog<_RouteHit>(
        context: ctx,
        builder: (dctx) => SimpleDialog(
          title: Text(l10n.routePickPlaceTitle(query)),
          children: [
            for (final h in hits.take(10))
              SimpleDialogOption(
                onPressed: () => Navigator.of(dctx).pop(h),
                child: Text(h.label, style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
      );
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: _sheetConstraints(context),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final scheme = Theme.of(context).colorScheme;
          Future<void> run() async {
            if (busy) return;
            final oq = originCtl.text.trim();
            final dq = destCtl.text.trim();
            if ((originPos == null && oq.isEmpty) ||
                (destPos == null && dq.isEmpty)) {
              return;
            }
            setSheetState(() => busy = true);
            String? error;
            var cancelled = false;
            try {
              LatLng? o = originPos;
              if (o == null) {
                final hits = await candidates(oq);
                if (hits.isEmpty) {
                  error = l10n.routePlaceNotFound(oq);
                } else if (!sheetContext.mounted) {
                  return;
                } else {
                  final picked = hits.length == 1
                      ? hits.first
                      : await pick(sheetContext, oq, hits);
                  final pt = picked == null ? null : await resolve(picked);
                  if (picked == null) {
                    cancelled = true;
                  } else if (pt == null) {
                    error = l10n.routePlaceNotFound(oq);
                  } else {
                    o = pt;
                    originPos = o;
                    originCtl.text = picked.label;
                  }
                }
              }
              LatLng? d = destPos;
              if (error == null && !cancelled && d == null) {
                final hits = await candidates(dq);
                if (hits.isEmpty) {
                  error = l10n.routePlaceNotFound(dq);
                } else if (!sheetContext.mounted) {
                  return;
                } else {
                  final picked = hits.length == 1
                      ? hits.first
                      : await pick(sheetContext, dq, hits);
                  final pt = picked == null ? null : await resolve(picked);
                  if (picked == null) {
                    cancelled = true;
                  } else if (pt == null) {
                    error = l10n.routePlaceNotFound(dq);
                  } else {
                    d = pt;
                    destPos = d;
                    destCtl.text = picked.label;
                  }
                }
              }
              if (error == null && !cancelled && o != null && d != null) {
                final route = await RouteCorridor.fetchRoute(o, d,
                    orsApiKey: widget.app.routeOrsKey);
                if (route == null) {
                  error = l10n.routeNotFound;
                } else {
                  final cams = RouteCorridor.camerasAlong(
                      widget.app.displayableCameras, route.points,
                      widthM: width);
                  if (!mounted) return;
                  setState(() {
                    _route = route;
                    _routeWidthM = width;
                    _routeCameras = cams;
                    _routeCameraIds = {for (final c in cams) c.camera.id};
                  });
                  _stopFollowing();
                  _fitBounds(route.points,
                      padding: const EdgeInsets.fromLTRB(32, 120, 32, 160));
                  _requestLayerDataForView();
                }
              }
            } catch (_) {
              error = l10n.routeNotFound;
            }
            if (!sheetContext.mounted) return;
            setSheetState(() => busy = false);
            if (error != null) {
              ScaffoldMessenger.of(sheetContext)
                  .showSnackBar(SnackBar(content: Text(error)));
            } else if (!cancelled) {
              Navigator.of(sheetContext).pop();
            }
          }

          Future<void> useCurrent() async {
            try {
              final last = await Geolocator.getLastKnownPosition();
              final pos = last ??
                  await Geolocator.getCurrentPosition(
                      locationSettings: const LocationSettings(
                          accuracy: LocationAccuracy.medium));
              setSheetState(() {
                originPos = LatLng(pos.latitude, pos.longitude);
                originCtl.text = l10n.routeUseCurrentLocation;
              });
            } catch (_) {}
          }

          if (autoOrigin) {
            autoOrigin = false;
            WidgetsBinding.instance.addPostFrameCallback((_) => useCurrent());
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.mapRouteTooltip,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(l10n.routeSheetSubtitle,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: originCtl,
                onChanged: (_) => originPos = null,
                decoration: InputDecoration(
                  labelText: l10n.routeOrigin,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: l10n.routeUseCurrentLocation,
                    icon: const Icon(Icons.my_location, size: 20),
                    onPressed: useCurrent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: destCtl,
                textInputAction: TextInputAction.search,
                onChanged: (_) => destPos = null,
                onSubmitted: (_) => run(),
                decoration: InputDecoration(
                  labelText: l10n.routeDestination,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Text(l10n.routeWidthLabel, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                for (final w in const [1000.0, 3000.0, 5000.0]) ...[
                  ChoiceChip(
                    label: Text('${(w / 1000).round()}km'),
                    selected: width == w,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setSheetState(() => width = w),
                  ),
                  const SizedBox(width: 4),
                ],
              ]),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: busy ? null : run,
                icon: busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.route_outlined),
                label: Text(l10n.routeSearch),
              ),
              const SizedBox(height: 6),
              Text(l10n.routeDisclaimer,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              Text(RouteCorridor.attributionNotice,
                  style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
            ]),
          );
        },
      ),
    );
  }

  static const _dismissedNoticeKey = 'notice_dismissed';
  String? _dismissedNotice;

  Future<void> _loadDismissedNotice() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _dismissedNotice = prefs.getString(_dismissedNoticeKey));
  }

  /// 閉じたお知らせは同じ文言のあいだ再表示しない（文言が変われば再び出る）
  Future<void> _dismissNotice(String text) async {
    setState(() => _dismissedNotice = text);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedNoticeKey, text);
  }

  Widget _mapStack(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // レイアウト途中や非表示で幅・高さが0/無限のときに GoogleMap を組み立てると
      // 初期カメラ位置の計算等で例外になりうるため、その間は何も描かない
      if (!constraints.maxWidth.isFinite || !constraints.maxHeight.isFinite ||
          constraints.maxWidth < 1 || constraints.maxHeight < 1) {
        return const SizedBox.shrink();
      }
      return _mapStackSized(context);
    });
  }

  /// ピン画像のキャッシュ（dpr が確定してから作る。MediaQuery は build 内でしか
  /// 読めないため、初回の _mapStackSized で一度だけ生成する）
  PinBitmaps? _pinBitmapsCache;
  bool _pinsPreloaded = false;

  PinBitmaps _pinBitmapsFor(BuildContext context) =>
      _pinBitmapsCache ??= PinBitmaps(MediaQuery.devicePixelRatioOf(context));

  void _onPinReady() {
    if (mounted) setState(() {});
  }

  /// カメラ・クラスタの Marker 一式（GoogleMap の markers に渡す）。
  /// ピン画像が未生成のキーは defaultMarker を仮に使い、生成完了時に
  /// _onPinReady が setState して差し替える
  Set<gmaps.Marker> _buildCameraMarkers(List<MapItem> items, PinBitmaps pins) {
    final markers = <gmaps.Marker>{};
    for (final item in items) {
      if (item.isCluster) {
        final label =
            item.count >= 1000 ? '${item.count ~/ 1000}k' : '${item.count}';
        final icon = pins.clusterPin(label, onReady: _onPinReady) ??
            gmaps.BitmapDescriptor.defaultMarker;
        markers.add(gmaps.Marker(
          markerId: gmaps.MarkerId(
              'cluster-${item.latitude.toStringAsFixed(4)}-${item.longitude.toStringAsFixed(4)}-${item.count}'),
          position: _g(LatLng(item.latitude, item.longitude)),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _moveCamera(LatLng(item.latitude, item.longitude), _zoom + 2),
        ));
      } else {
        final camera = item.camera!;
        final icon = pins.cameraPin(
              category: camera.category,
              isVideo: camera.isVideo,
              favorite: widget.app.isFavorite(camera),
              uncertain: camera.coordAccuracy.isUncertain,
              frozen: widget.app.stateOf(camera) == CameraState.frozen,
              onReady: _onPinReady,
            ) ??
            gmaps.BitmapDescriptor.defaultMarker;
        markers.add(gmaps.Marker(
          markerId: gmaps.MarkerId(camera.id),
          position: _g(LatLng(camera.lat!, camera.lng!)),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _onPinTap(camera),
        ));
      }
    }
    return markers;
  }

  /// GoogleMap の下から測った現在の下部オーバーレイの高さ（padding に使う）
  final GlobalKey _bottomAreaKey = GlobalKey();
  double? _bottomPadding;

  void _measureBottomArea() {
    final h = _bottomAreaKey.currentContext?.size?.height;
    if (h != null && h != _bottomPadding && mounted) {
      setState(() => _bottomPadding = h);
    }
  }

  /// 利用者が地図を動かし始めた（追従解除・状況カードを閉じる・シートを沈める）
  void _onUserGestureStart() {
    if (_following) _stopFollowing();
    if (_situationExpanded) _dismissSituation();
    if (!_mapDragging) setState(() => _mapDragging = true);
    // 地図を動かしたらシートは畳み、止まっても開き直さない（畳んだら畳んだまま。2026-09-27 要望）
    if (_sheetExpanded) _setSheetExpanded(false);
    // 操作終了イベントを取り逃した場合のフェイルセーフ
    _mapDraggingFailsafe?.cancel();
    _mapDraggingFailsafe = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _mapDragging = false);
    });
  }

  Future<void> _onCameraIdle() async {
    _kjBottomDriving = false;
    final wasProgrammatic = _programmaticMove;
    _programmaticMove = false;
    _mapDraggingFailsafe?.cancel();
    final c = _gmapController;
    LatLngBounds? bounds;
    double? zoom;
    if (c != null) {
      try {
        final r = await c.getVisibleRegion();
        bounds = LatLngBounds(
          LatLng(r.southwest.latitude, r.southwest.longitude),
          LatLng(r.northeast.latitude, r.northeast.longitude),
        );
      } catch (_) {}
      try {
        zoom = await c.getZoomLevel();
      } catch (_) {}
    }
    if (!mounted) return;
    // onCameraMove は2段以上のズーム変化だけ反映するので、ここで実際の値に確定させる
    final zoomJumped = zoom != null && zoom.isFinite && (zoom - _zoom).abs() >= 0.25;
    setState(() {
      _mapDragging = false;
      if (bounds != null) _visibleBounds = bounds;
      if (zoomJumped) _zoom = zoom!;
    });
    if (!zoomJumped) _maybeRebuildForPan();
    // 台風の寄せ等アプリ側の移動で止まった位置は保存しない（次回起動が広域になってしまう）
    if (!wasProgrammatic) _savePosition();
    _requestLayerDataForView();
    _updateKjRegion();
  }

  Widget _mapStackSized(BuildContext context) {
    final pins = _pinBitmapsFor(context);
    if (!_pinsPreloaded) {
      _pinsPreloaded = true;
      pins.preloadCommon(onReady: _onPinReady);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureBottomArea();
    });
    var cams = widget.app.displayableCameras;
    if (_route != null) {
      cams = cams.where((c) => _routeCameraIds.contains(c.id)).toList();
    }
    final items = _cullToViewport(clusterCameras(cams, _zoom));
    // iOS の Google Maps SDK はマーカーを1つ足すたびに全マーカーのアクセシビリティ
    // 情報を作り直す（-[GMSVectorMapView buildVisibleAccessibilityItems]）ため、
    // 一度に数百個を足すと主スレッドが10秒以上止まりウォッチドッグで強制終了される
    // （2026-09-27 実機の 0x8BADF00D で確認）。画面付近・中心に近い順に上限を設ける
    final markers = _capMarkers(_buildCameraMarkers(items, pins), _maxCameraMarkers)
      ..addAll(_capMarkers(_vectorMarkers(pins), _maxLayerMarkers));
    if (_pickedPlace != null) {
      markers.add(gmaps.Marker(
        markerId: const gmaps.MarkerId('picked_place'),
        position: _g(_pickedPlace!.point),
        zIndexInt: 10,
      ));
    }
    // 今昔マップのスワイプ比較中は2枚目の GoogleMap を重ねる（このフレームでの
    // 判定を固定しておく。build途中で _kjRegion 等が変わっても揃えるため）
    final kjSwipeActive = _kjSwipeActive;
    if (!kjSwipeActive) _kjOverlayController = null;
    // 上部の検索ピル（高さ48・上12px）の分だけ地図内部コントロールを下げる
    // （Googleマップ風レイアウト。2026-09-27）
    final topPad = MediaQuery.of(context).padding.top + 60;
    return Stack(
      children: [
        gmaps.GoogleMap(
          initialCameraPosition: gmaps.CameraPosition(
              target: _g(_initialCenter), zoom: _initialZoom),
          // iOS は端末の外観設定で自動的に暗くなる。Android は追従しないので
          // アプリがダーク表示のときだけ夜間スタイルを当てる
          style: defaultTargetPlatform == TargetPlatform.android &&
                  Theme.of(context).brightness == Brightness.dark
              ? kAndroidMapDarkStyle
              : null,
          minMaxZoomPreference: const gmaps.MinMaxZoomPreference(2, 18),
          // 二本指ひねりの回転・チルトは無効化（北固定の方針）
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          buildingsEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: _locationPermissionGranted,
          padding: EdgeInsets.only(top: topPad, bottom: _bottomPadding ?? 0),
          markers: markers,
          tileOverlays: _tileOverlays(),
          polylines: _vectorPolylines(),
          circles: _vectorCircles(),
          onMapCreated: _onMapCreated,
          onCameraMoveStarted: () {
            if (_programmaticMove || _kjTopDriving) return; // アプリ側の移動・上の地図からの追従
            _onUserGestureStart();
          },
          onCameraMove: (pos) {
            _center = _l(pos.target);
            // 今昔マップのスワイプ比較中は2枚目の GoogleMap（操作不可）を毎フレーム
            // 追従させる（setState は不要。表示だけ同期する）
            if (kjSwipeActive && !_kjTopDriving) {
              _kjBottomDriving = true;
              // moveCamera は Future を返す非同期メソッドで、この
              // コールバック自体は同期のため await できない。同期例外だけでなく
              // Future の失敗も拾えるよう catchError で受ける（例外を投げない
              // フェイクの controller でも無害）
              _kjOverlayController
                  ?.moveCamera(gmaps.CameraUpdate.newCameraPosition(pos))
                  .catchError((_) {});
            }
            // 長いドラッグ中にフェイルセーフが先に発火してパネルが戻らないよう延長する
            if (_mapDragging && _mapDraggingFailsafe != null) {
              _mapDraggingFailsafe!.cancel();
              _mapDraggingFailsafe = Timer(const Duration(milliseconds: 600), () {
                if (mounted) setState(() => _mapDragging = false);
              });
            }
            // ピンチ中の毎フレーム再構築はフリーズ→強制終了の原因になるため、
            // ズーム2段以上の大変化だけ間引いて反映する（細かい追従は onCameraIdle）
            if (pos.zoom.isFinite && (pos.zoom - _zoom).abs() >= 2.0) {
              setState(() => _zoom = pos.zoom);
            }
          },
          onCameraIdle: _onCameraIdle,
        ),
        // 今昔マップの新旧スワイプ（縦線／横線）: 下の地図の上に、今昔マップだけを
        // 載せた2枚目の GoogleMap を重ね、境界より片側だけを ClipRect で見せる。
        // 2枚目は操作不可（IgnorePointer）で、下の地図の onCameraMove に同期する
        if (kjSwipeActive)
          Positioned.fill(
            child: _NoClipHitTest(
              child: ClipRect(
                clipper: _SplitClipper(
                    vertical: _kjCompare == _KjCompare.vertical, split: _kjSplit),
                child: gmaps.GoogleMap(
                  key: const ValueKey('kjOverlayMap'),
                  // 2枚目はベース地図を描かない（今昔マップのタイルだけ。実機のメモリ・GPU 負荷を抑える）
                  mapType: gmaps.MapType.none,
                  initialCameraPosition:
                      gmaps.CameraPosition(target: _g(_center), zoom: _zoom),
                  minMaxZoomPreference: const gmaps.MinMaxZoomPreference(2, 18),
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  myLocationEnabled: _locationPermissionGranted,
                  myLocationButtonEnabled: false,
                  buildingsEnabled: false,
                  liteModeEnabled: false,
                  padding: EdgeInsets.only(top: topPad, bottom: _bottomPadding ?? 0),
                  tileOverlays: _kjSwipeOverlay(),
                  // 昔の地図側にもカメラ・現在地を出す（下の地図のピンは上の地図に隠れるため）
                  markers: markers,
                  onCameraMoveStarted: () {
                    if (_kjBottomDriving || _programmaticMove) return;
                    _kjTopDriving = true;
                    _onUserGestureStart();
                  },
                  onCameraMove: (pos) {
                    if (!_kjTopDriving) return;
                    _center = _l(pos.target);
                    _programmaticMove = true;
                    _gmapController
                        ?.moveCamera(gmaps.CameraUpdate.newCameraPosition(pos))
                        .catchError((_) {});
                  },
                  onCameraIdle: () {
                    if (!_kjTopDriving) return;
                    _kjTopDriving = false;
                    _savePosition();
                  },
                  onMapCreated: (c) {
                    _kjOverlayController = c;
                    c
                        .moveCamera(gmaps.CameraUpdate.newLatLngZoom(_g(_center), _zoom))
                        .catchError((_) {});
                  },
                ),
              ),
            ),
          ),
        if (kjSwipeActive)
          Positioned.fill(
            child: _KjDivider(
              vertical: _kjCompare == _KjCompare.vertical,
              split: _kjSplit,
              oldLabel: context.l10n.mapOldMapOldSide,
              newLabel: context.l10n.mapOldMapNewSide,
              onChanged: (v) => setState(() => _kjSplit = v),
            ),
          ),
        // 下部の固定パネル・出典帯・操作板・ズーム/現在地（design/map_ui/PROPOSAL.md 第1段階）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _bottomArea(context, cams),
        ),
        // 検索ピル（Googleマップ風。上12px・左右12px・高さ48）
        Positioned(
          left: 12,
          right: 12,
          top: MediaQuery.of(context).padding.top + 12,
          child: MapSearchPill(
            hint: context.l10n.mapPanelSearchHint,
            onTap: () => _openPlaceSearch(context),
          ),
        ),
        // 「いま起きていること」（発生時だけ検索ピルの下・右端に丸いボタン）。展開中も
        // 地図は触れるままにし、地図を動かしたらボタンに戻す（透明バリアで地図を塞ぐと
        // 「カードが出ている間は地図が触れない」不具合になる。2026-09-27 報告）
        if (_situation != null && _situation!.isNotable) ...[
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 12 + 48 + 8,
            child: SituationOverlay(
              situation: _situation!,
              expanded: _situationExpanded,
              isNew: _situationJustChanged,
              onOpen: _reopenSituation,
              onClose: _dismissSituation,
              onOpenWarning: () {
                Analytics.event('situation_open', params: const {'kind': 'warning'});
                widget.app.navigationRequest.value = null;
                widget.app.navigationRequest.value = 'bosai/warning';
              },
              onOpenQuake: () {
                Analytics.event('situation_open', params: const {'kind': 'quake'});
                widget.app.navigationRequest.value = null;
                widget.app.navigationRequest.value = 'bosai/quake';
              },
              onOpenTyphoon: (id) {
                Analytics.event('situation_open', params: const {'kind': 'typhoon'});
                _setLayer(MapLayerKind.typhoon, typhoonId: id);
              },
              onOpenUnderpass: () {
                Analytics.event('situation_open', params: const {'kind': 'underpass'});
                _openUnderpassLayer();
              },
            ),
          ),
        ],
      ],
    );
  }

  /// 下部の固定領域（下から順に: 折りたたみシート → 操作板 → ズーム/現在地）。
  /// Googleマップ風レイアウト（2026-09-27）。検索は上部ピルへ移したのでここには無い。
  /// 地図の Stack 内で bottom 固定にする。
  /// 検索で選んだ場所のカード（名称・「ここへのルート」・閉じる）
  Widget _pickedPlaceCard(BuildContext context) {
    final l10n = context.l10n;
    final p = _pickedPlace!;
    final canRoute = _hasGoogleRouteKey || widget.app.routeOrsKey.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
          child: Row(children: [
            const Icon(Icons.place, color: Color(0xFFD93025)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(p.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            if (canRoute)
              FilledButton.icon(
                key: const Key('picked_place_route'),
                onPressed: () {
                  final pp = _pickedPlace!;
                  setState(() => _pickedPlace = null);
                  _showRouteSheet(context, destLabel: pp.label, destPoint: pp.point);
                },
                icon: const Icon(Icons.directions, size: 18),
                label: Text(l10n.routeToHere),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            IconButton(
              tooltip: l10n.commonClose,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _pickedPlace = null),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _bottomArea(BuildContext context, List<Camera> cams) {
    // stretch で各段を全幅にする（ズーム/現在地だけ内部で右寄せにする）。
    // _bottomAreaKey は高さを測って GoogleMap の padding（Googleロゴが隠れないように）
    // に使う（_measureBottomArea）
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _zoomAndLocation(),
      const SizedBox(height: 12),
      // ズーム/現在地ボタンは含めず、地図を覆う帯の高さだけを GoogleMap の padding にする
      // シートの開閉アニメーション（AnimatedSize）の途中・終了でも高さを測り直し、
      // GoogleMap の padding（左下の Google ロゴの位置）を追従させる
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _measureBottomArea();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(
        child: Column(key: _bottomAreaKey, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_pickedPlace != null) _pickedPlaceCard(context),
        _controlPanel(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: _bottomSheetPanel(context, cams),
        ),
      ]),
      ),
      ),
    ]);
  }

  /// 下部の折りたたみシート（Googleマップの「エリアの注目情報」風。2026-09-27）。
  /// 畳み: 取っ手＋見出し行（レイヤー名・絞り込み件数・台数）のみ、高さ約44。
  /// 展開: 上記に加えてボタン行（レイヤー／絞り込み／…）。
  /// 出典（気象庁・ハザードマップ・今昔マップ等。現在のレイヤーに紐づく1件だけ）は
  /// 畳み・展開どちらでも見えるよう見出し行の下に常時1行足す（今昔マップは利用条件で
  /// 画面表示が必須で、展開時だけにすると畳んだときに消えてしまうため。折り込み方は
  /// 「畳み行の下に1行足す」案を採用した。2026-09-27 判断）
  /// 地図ドラッグ中は強制的に畳んで表示し、離したら [_sheetExpanded] の値に戻す
  Widget _bottomSheetPanel(BuildContext context, List<Camera> cams) {
    final effectiveExpanded = _sheetExpanded;
    final attributions = _sheetAttributionSpans(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          key: const Key('map_sheet_handle'),
          behavior: HitTestBehavior.opaque,
          onTap: _toggleSheet,
          onVerticalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -200 && !_sheetExpanded) {
              _setSheetExpanded(true);
            } else if (v > 200 && _sheetExpanded) {
              _setSheetExpanded(false);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // 灰色のバーだけでは持ち上げられることが分かりにくいので、上向きの矢印を
              // ぴょこぴょこ動かして示す（開いているときは下向き・静止。2026-09-27 要望）
              Center(child: _SheetChevron(expanded: effectiveExpanded)),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Text(
                    _sheetHeaderText(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                // 台数は右端に内容幅で置く（Flexible にすると左の文字と幅を折半して
                // レイヤー名が切れる）。0件案内は長いので次の行に出す
                _sheetCountArea(context, cams),
              ]),
              if (_sheetNoMatch(cams)) _sheetNoMatchRow(context),
            ]),
          ),
        ),
        if (attributions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text.rich(
              TextSpan(
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface),
                  children: attributions),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: effectiveExpanded
              ? MapBottomPanel(
                  layerActive: _layer != MapLayerKind.none,
                  filterActive: widget.app.hasActiveFilters,
                  filterCount: widget.app.activeFilterCount,
                  onLayers: () => _showLayerPicker(context),
                  onFilter: () => _showLegendFilter(context),
                  onFavorites: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => FavoritesScreen(app: widget.app))),
                  onRoute: (_hasGoogleRouteKey || widget.app.routeOrsKey.isNotEmpty)
                      ? () => _showRouteSheet(context)
                      : null,
                  routeActive: _route != null,
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  /// シート見出し行の左側テキスト。レイヤーOFF・絞り込み無しなら「レイヤー・絞り込み」、
  /// レイヤーONなら「レイヤー: {名前}」、絞り込み中ならそれも併記する
  String _sheetHeaderText(BuildContext context) {
    final l10n = context.l10n;
    final parts = <String>[];
    if (_layer != MapLayerKind.none) {
      parts.add(l10n.mapSheetLayerPrefix(_layerTitle(_layer)));
    }
    if (widget.app.hasActiveFilters) {
      final n = widget.app.activeFilterCount;
      parts.add(n > 0 ? l10n.mapPanelFilterCount(n) : l10n.mapPanelFilter);
    }
    if (parts.isEmpty) return l10n.mapSheetTitle;
    return parts.join('・');
  }

  /// 現在のレイヤーに紐づく出典（気象庁・ハザードマップ・今昔マップ等。GoogleMap移行後は
  /// ベース地図の出典は不要＝Googleロゴ・帰属はSDKが地図左下に出す）
  List<InlineSpan> _sheetAttributionSpans(BuildContext context) {
    return <InlineSpan>[
      if (HazardLayers.isHazard(_layer)) const TextSpan(text: HazardLayers.attribution),
      if (_layer == MapLayerKind.shelters) const TextSpan(text: ShelterLayers.attribution),
      if (_layer == MapLayerKind.facilities)
        TextSpan(
            text: _facilities?.index?.attribution.isNotEmpty == true
                ? _facilities!.index!.attribution
                : FacilityLayers.attribution),
      if (_layer == MapLayerKind.oldMap)
        TextSpan(
          text: Kjmap.attribution,
          style: const TextStyle(decoration: TextDecoration.underline),
          recognizer: _kjmapTap,
        ),
    ];
  }

  /// シート見出し行の右側（台数）。台帳が未取得なら「読み込み中…」、絞り込みで0件なら
  /// 案内＋「解除」を出す
  Widget _sheetCountArea(BuildContext context, List<Camera> cams) {
    final countStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface);
    final loaded = widget.app.repository.cameras.isNotEmpty;
    if (_sheetNoMatch(cams)) return const SizedBox.shrink();
    return Text(
      !loaded
          ? context.l10n.mapCountLoading
          : widget.app.hasActiveFilters
              ? context.l10n.mapFilteredCount(cams.length)
              : context.l10n.mapTotalCount(cams.length),
      style: countStyle,
      textAlign: TextAlign.right,
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
    );
  }

  bool _sheetNoMatch(List<Camera> cams) =>
      widget.app.repository.cameras.isNotEmpty && cams.isEmpty && widget.app.hasActiveFilters;

  /// 絞り込みで0件のときの案内＋「解除」（見出し行の下に右寄せで1行）
  Widget _sheetNoMatchRow(BuildContext context) {
    final countStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface);
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Flexible(
        child: Text(context.l10n.mapCountNoMatch,
            textAlign: TextAlign.right, style: countStyle, maxLines: 2),
      ),
      TextButton(
        key: const Key('map_clear_filters'),
        onPressed: widget.app.clearFilters,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: countStyle.copyWith(decoration: TextDecoration.underline),
        ),
        child: Text(context.l10n.mapClearFilters),
      ),
    ]);
  }

  /// レイヤー名（`_showLayerPicker` の各項目タイトルと同じ文字列）。
  /// 操作板カードのタイトル行・レイヤー選択シートのタイル見出しで共通に使う
  String _layerTitle(MapLayerKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      MapLayerKind.none => l10n.mapLayerNone,
      MapLayerKind.rainRadar => l10n.mapLayerRainRadarTitle,
      MapLayerKind.quakes => l10n.mapLayerQuakesTitle,
      MapLayerKind.rain24h => l10n.mapLayerRain24hTitle,
      MapLayerKind.riskLand ||
      MapLayerKind.riskInund ||
      MapLayerKind.riskFlood =>
        riskLayerTitleOf(l10n, RiskLayers.titleKey(kind)),
      MapLayerKind.hazardFlood ||
      MapLayerKind.hazardLandslide ||
      MapLayerKind.hazardTsunami ||
      MapLayerKind.hazardHightide =>
        hazardLayerTitleOf(l10n, HazardLayers.titleKey(kind)),
      MapLayerKind.shelters => l10n.mapLayerShelterTitle,
      MapLayerKind.facilities => l10n.mapLayerFacilityTitle,
      MapLayerKind.typhoon => l10n.mapLayerTyphoonTitle,
      MapLayerKind.snowDepth => l10n.mapLayerSnowDepthTitle,
      MapLayerKind.snowfall24h => l10n.mapLayerSnowfall24hTitle,
      MapLayerKind.underpass => l10n.mapLayerUnderpassTitle,
      MapLayerKind.roadRegulation => l10n.mapLayerRoadRegulationTitle,
      MapLayerKind.roadClosures => l10n.mapLayerRoadClosuresTitle,
      MapLayerKind.oldMap => l10n.mapLayerOldMapTitle,
    };
  }

  /// レイヤーのアイコン。操作板カードのタイトル行・レイヤー選択シートのタイルで使う
  IconData _layerIcon(MapLayerKind kind) => switch (kind) {
        MapLayerKind.none => Icons.layers_outlined,
        MapLayerKind.rainRadar => Icons.cloud_outlined,
        MapLayerKind.quakes => Icons.vibration,
        MapLayerKind.rain24h => Icons.water_drop_outlined,
        MapLayerKind.riskLand ||
        MapLayerKind.riskInund ||
        MapLayerKind.riskFlood =>
          Icons.warning_amber_outlined,
        MapLayerKind.hazardFlood ||
        MapLayerKind.hazardLandslide ||
        MapLayerKind.hazardTsunami ||
        MapLayerKind.hazardHightide =>
          Icons.map_outlined,
        MapLayerKind.shelters => Icons.home_work_outlined,
        MapLayerKind.facilities => Icons.local_drink_outlined,
        MapLayerKind.typhoon => Icons.cyclone,
        MapLayerKind.snowDepth || MapLayerKind.snowfall24h => Icons.ac_unit,
        MapLayerKind.underpass ||
        MapLayerKind.roadRegulation ||
        MapLayerKind.roadClosures =>
          Icons.block,
        MapLayerKind.oldMap => Icons.history,
      };

  /// 操作板カードのタイトル行に出す「時刻」（雨雲・24時間降水量・キキクル・積雪。
  /// state に無ければ null＝省略）。雨雲は選択中の時刻＋現在/予測の相対表記も付ける
  String? _layerTimeText() {
    switch (_layer) {
      case MapLayerKind.rainRadar:
        if (_nowcastTimes.isEmpty) return null;
        final n = _nowcastTimes[_nowcastIdx];
        return '${n.label}　${_nowcastRelLabel(n)}';
      case MapLayerKind.rain24h:
        return _rain24hTile?.label;
      case MapLayerKind.riskLand:
      case MapLayerKind.riskInund:
      case MapLayerKind.riskFlood:
        return _risk?.label;
      case MapLayerKind.snowDepth:
      case MapLayerKind.snowfall24h:
        return _snowTime?.label;
      default:
        return null;
    }
  }

  /// レイヤー操作板（1枚のカード。タイトル行のタップで展開／圧縮）。
  /// レイヤーOFFのときは何も出さない
  Widget _controlPanel() {
    if (_layer == MapLayerKind.none) return const SizedBox.shrink();
    final expanded = _controllerExpanded;
    final showCompactSlider =
        !expanded && _layer == MapLayerKind.rainRadar && _nowcastTimes.length >= 2;
    final timeText = _layerTimeText();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: scheme.surface,
        elevation: 3,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            key: const Key('map_control_panel_title'),
            onTap: () => _setControllerExpanded(!expanded),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(_layerIcon(_layer), size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_layerTitle(_layer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  if (timeText != null && timeText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: expanded
                        ? context.l10n.mapControllerCollapse
                        : context.l10n.mapControllerExpand,
                    child: Icon(expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20, color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
            ),
          ),
          // 雨雲の時刻操作は最頻の操作なので、圧縮中でも細いスライダーだけ残す
          if (showCompactSlider) _nowcastCompactSlider(),
          // 震源の期間（24時間／7日／30日）。レイヤー選択画面ではなく、震源を表示中の
          // カードで切り替える（2026-09-27 要望）
          if (_layer == MapLayerKind.quakes) _quakePeriodChips(),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_layer == MapLayerKind.rainRadar)
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: _nowcastSlider()),
                if (_layer == MapLayerKind.shelters)
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: _shelterChips()),
                if (_layer == MapLayerKind.facilities)
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: _facilityChips()),
                if (_layer == MapLayerKind.typhoon && _typhoons.length > 1)
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: _typhoonChips()),
                if (_layer == MapLayerKind.roadClosures)
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: _closureChips()),
                if (_layer == MapLayerKind.oldMap)
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: _kjChips()),
                _layerLegend(),
                // レイヤーの免責文（出典帯には入れず、展開したときだけ出す）
                if (_layerDisclaimer() != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_layerDisclaimer()!,
                        style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                  ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  /// 表示中レイヤーの免責文（無ければ null）
  String? _layerDisclaimer() {
    final l10n = context.l10n;
    if (HazardLayers.isHazard(_layer)) return l10n.hazardDisclaimer;
    return switch (_layer) {
      MapLayerKind.shelters => l10n.shelterDisclaimer,
      MapLayerKind.facilities => l10n.facilityDisclaimer,
      MapLayerKind.oldMap => l10n.oldMapDisclaimer,
      _ => null,
    };
  }

  /// 地図上に残す現在地・ズーム（右寄せ。操作板の上端から12px上に追従する）。
  /// 親の Column は stretch のため、Align で自分だけ右寄せにする
  Widget _zoomAndLocation() {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          // ＋／−（各40×40の見た目、48×48のタップ領域を持つ縦型ピル）。
          // Divider が横に無限に広がるので幅を 48 に固定する
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 3,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(width: 48, child: Column(mainAxisSize: MainAxisSize.min, children: [
              _zoomPillButton(
                key: const Key('map_zoom_in'),
                icon: Icons.add,
                label: l10n.mapZoomIn,
                onTap: () => _zoomBy(1),
              ),
              const Divider(height: 1),
              _zoomPillButton(
                key: const Key('map_zoom_out'),
                icon: Icons.remove,
                label: l10n.mapZoomOut,
                onTap: () => _zoomBy(-1),
              ),
            ])),
          ),
          const SizedBox(height: 8),
          // 現在地（48×48の丸。追従中は塗りつぶし＋白アイコン）
          Material(
            color: _following ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              key: const Key('map_my_location'),
              onTap: _goToMyLocation,
              customBorder: const CircleBorder(),
              child: Semantics(
                button: true,
                label: l10n.mapMyLocation,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: _locating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _following ? Colors.white : null),
                          )
                        : Icon(
                            _following ? Icons.my_location : Icons.location_searching,
                            color: _following ? Colors.white : null,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// ＋／−の1個。見た目は40×40、タップ領域は48×48（Semantics でも操作名を伝える）
  Widget _zoomPillButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Icon(icon, size: 20)),
        ),
      ),
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

// 現在地の青い点（旧 _MyLocationDot）は GoogleMap 標準の myLocationEnabled が
// 同等のドットを描くため、GoogleMap移行時に削除した（2026-09-27 第1段階）。

/// 避難場所ピン（緑の丸＋家アイコン。指定避難所は二重枠）。カメラピンとは色・形で区別する
class _ShelterPin extends StatelessWidget {
  const _ShelterPin({required this.designated, this.size = 22});

  static const color = Color(0xFF2E7D32);
  final bool designated;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size >= 16 ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: designated
          ? Container(
              margin: EdgeInsets.all(size >= 16 ? 2 : 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size >= 16 ? 1.2 : 1),
              ),
              child: Icon(Icons.home, size: size * 0.5, color: Colors.white),
            )
          : Icon(Icons.home, size: size * 0.6, color: Colors.white),
    );
  }
}

// 避難場所のクラスタ（旧 _ShelterCluster）は地図のマーカーが PinBitmaps.dotGlyph
// で画像化されたため不要になり削除した（2026-09-27 GoogleMap移行 第3段階）。

/// 防災拠点ピン（種別で色分け。給水=青 / 備蓄=茶 / 消防水利=赤）。
/// 避難場所の緑・カメラピンとは色で区別する
class _FacilityPin extends StatelessWidget {
  const _FacilityPin({required this.kind, this.size = 22});

  static const waterColor = Color(0xFF1565C0);
  static const stockColor = Color(0xFF795548);
  static const fireWaterColor = Color(0xFFC62828);

  static Color colorOf(String? kind) => switch (kind) {
        'water' => waterColor,
        'stock' => stockColor,
        'fire_water' => fireWaterColor,
        _ => const Color(0xFF546E7A),
      };

  static IconData iconOf(String? kind) => switch (kind) {
        'water' => Icons.water_drop,
        'stock' => Icons.inventory_2,
        'fire_water' => Icons.local_fire_department,
        _ => Icons.place,
      };

  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorOf(kind).withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size >= 16 ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Icon(iconOf(kind), size: size * 0.6, color: Colors.white),
    );
  }
}

// 防災拠点のクラスタ（旧 _FacilityCluster）も同様に削除した。

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text, this.onClose});

  final String text;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: tintedSurface(context, const Color(0xFFFFF3CD)),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(text.trim(), style: const TextStyle(fontSize: 13))),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: context.l10n.commonClose,
              onPressed: onClose,
            ),
        ]),
      ),
    );
  }
}

/// 統合レイヤーの原因名（冠水／土砂／気象／その他）
String closureCauseNameOf(AppLocalizations l10n, ClosureCause c) => switch (c) {
      ClosureCause.flood => l10n.closureCauseFlood,
      ClosureCause.landslide => l10n.closureCauseLandslide,
      ClosureCause.weather => l10n.closureCauseWeather,
      ClosureCause.other => l10n.closureCauseOther,
    };


/// 昔の地図の比較方法
enum _KjCompare { vertical, horizontal, opacity }

/// 新旧スワイプ用: 境界より左（上）だけを描く
class _SplitClipper extends CustomClipper<Rect> {
  const _SplitClipper({required this.vertical, required this.split});

  final bool vertical;
  final double split;

  @override
  Rect getClip(Size size) => vertical
      ? Rect.fromLTWH(0, 0, size.width * split, size.height)
      : Rect.fromLTWH(0, 0, size.width, size.height * split);

  @override
  bool shouldReclip(_SplitClipper old) => old.vertical != vertical || old.split != split;
}

/// 新旧スワイプの境界線と取っ手。線に沿った細い帯だけがドラッグを受け、地図の操作は妨げない。
class _KjDivider extends StatelessWidget {
  const _KjDivider({
    required this.vertical,
    required this.split,
    required this.oldLabel,
    required this.newLabel,
    required this.onChanged,
  });

  final bool vertical;
  final double split;
  final String oldLabel;
  final String newLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final pos = (vertical ? w : h) * split;
      const band = 36.0;
      Widget label(String t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
            child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          );
      final handle = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
        child: Icon(Icons.unfold_more, size: 22, color: Theme.of(context).colorScheme.onSurface),
      );
      // 境界線（白い線に薄い影。Positioned は Stack の直下に置く）
      final line = IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
          ),
        ),
      );
      return Stack(children: [
        if (vertical)
          Positioned(left: pos - 1.5, top: 0, bottom: 0, width: 3, child: line)
        else
          Positioned(top: pos - 1.5, left: 0, right: 0, height: 3, child: line),
        // 昔／今のラベル（境界の両側）
        if (vertical)
          Positioned(
            left: pos - 60, top: MediaQuery.of(context).padding.top + 64, width: 120,
            child: IgnorePointer(
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [label(oldLabel), label(newLabel)])),
          )
        else
          Positioned(
            left: 12, top: pos - 30, height: 60,
            child: IgnorePointer(
                child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [label(oldLabel), label(newLabel)])),
          ),
        // ドラッグ帯（線に沿った細い帯）＋取っ手
        if (vertical)
          Positioned(
            left: pos - band / 2, top: 0, bottom: 0, width: band,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => onChanged(((pos + d.delta.dx) / w).clamp(0.05, 0.95)),
              child: Center(child: RotatedBox(quarterTurns: 1, child: handle)),
            ),
          )
        else
          Positioned(
            top: pos - band / 2, left: 0, right: 0, height: band,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => onChanged(((pos + d.delta.dy) / h).clamp(0.05, 0.95)),
              child: Center(child: handle),
            ),
          ),
      ]);
    });
  }
}

/// 子を ClipRect で切り抜いても、タッチは切り抜き外でも子に届ける（今昔マップの
/// 2枚目の地図用）。iOS のネイティブ地図は画面全体を覆うので、切り抜き外で
/// タッチを捨てると下の地図にも届かず操作できなくなる
class _NoClipHitTest extends SingleChildRenderObjectWidget {
  const _NoClipHitTest({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoClipHitTest();
}

class _RenderNoClipHitTest extends RenderProxyBox {
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    // ClipRect（RenderClipRect）の切り抜き判定を飛ばし、その子を直接当てる
    if (c is RenderClipRect && c.child != null) {
      return result.addWithPaintOffset(
          offset: null, position: position, hitTest: (r, p) => c.child!.hitTest(r, position: p));
    }
    return c.hitTest(result, position: position);
  }
}

/// シートの取っ手の矢印。畳んでいるときは上向きで、表示されるたびに3回はねる
/// （無限には動かさない）。開いているときは下向きで静止
class _SheetChevron extends StatefulWidget {
  const _SheetChevron({required this.expanded});
  final bool expanded;

  @override
  State<_SheetChevron> createState() => _SheetChevronState();
}

class _SheetChevronState extends State<_SheetChevron> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  Timer? _again;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bounce());
  }

  @override
  void didUpdateWidget(_SheetChevron old) {
    super.didUpdateWidget(old);
    if (old.expanded && !widget.expanded) _bounce();
  }

  /// 3回はねたあと、20秒おきにもう一度だけ知らせる（畳んでいる間）
  Future<void> _bounce() async {
    _again?.cancel();
    if (!mounted || widget.expanded || MediaQuery.disableAnimationsOf(context)) return;
    for (var i = 0; i < 3 && mounted && !widget.expanded; i++) {
      await _c.forward(from: 0);
    }
    if (!mounted) return;
    _again = Timer(const Duration(seconds: 20), _bounce);
  }

  @override
  void dispose() {
    _again?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // 0→1 で上に4px跳ねて戻る（sin の半周）
        final dy = widget.expanded ? 0.0 : -4 * math.sin(_c.value * math.pi);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Icon(
        widget.expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
        size: 22,
        color: color,
      ),
    );
  }
}


/// ルート欄の地名候補。Google の候補は座標を持たず、選ばれたときに [placeId] で取る
typedef _RouteHit = ({String label, LatLng? point, String? placeId, String? token});
