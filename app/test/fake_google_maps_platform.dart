import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformViewCreatedCallback;
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// GoogleMap 用テストフェイク（GoogleMap移行 第1段階。docs/google_maps_migration.md）。
///
/// `google_maps_flutter` の `GoogleMap` は実機ではネイティブの platform view を
/// 使うため、ウィジェットテストではそのままだと例外になる。
/// `buildViewWithConfiguration` が素の [SizedBox] を返すだけにし、
/// `onPlatformViewCreated` を呼ばない（＝地図画面側の `onMapCreated` は発火せず、
/// `GoogleMapController` は作られない）。カメラ操作系のメソッドは呼ばれない前提だが、
/// 念のため no-op/ダミー値を返すようにしてある。
///
/// 使い方: テストの `setUp` で
/// `GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();`
class FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    // 実際の platform view は作らない（onPlatformViewCreated は呼ばない）。
    // GoogleMap 側は onMapCreated が来ないまま初期カメラ位置で止まった状態になる。
    // 実機の platform view（AndroidView/UiKitView）は与えられた制約を必ず
    // 埋める（constraints.biggest）ため、SizedBox.shrink() だと Stack が
    // 0×0 に潰れてしまう（IndexedStack 経由で MapScreen に渡る制約は loose）。
    // それを再現するため SizedBox.expand() で埋める
    return const SizedBox.expand();
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> clearTileCache(
    TileOverlayId tileOverlayId, {
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate, {required int mapId}) async {}

  @override
  Future<void> animateCameraWithConfiguration(
    CameraUpdate cameraUpdate,
    CameraUpdateAnimationConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> moveCamera(CameraUpdate cameraUpdate, {required int mapId}) async {}

  @override
  Future<void> setMapStyle(String? mapStyle, {required int mapId}) async {}

  @override
  Future<String?> getStyleError({required int mapId}) async => null;

  @override
  Future<LatLngBounds> getVisibleRegion({required int mapId}) async =>
      LatLngBounds(
        southwest: const LatLng(-1, -1),
        northeast: const LatLng(1, 1),
      );

  @override
  Future<ScreenCoordinate> getScreenCoordinate(
    LatLng latLng, {
    required int mapId,
  }) async =>
      const ScreenCoordinate(x: 0, y: 0);

  @override
  Future<LatLng> getLatLng(
    ScreenCoordinate screenCoordinate, {
    required int mapId,
  }) async =>
      const LatLng(0, 0);

  @override
  Future<void> showMarkerInfoWindow(MarkerId markerId, {required int mapId}) async {}

  @override
  Future<void> hideMarkerInfoWindow(MarkerId markerId, {required int mapId}) async {}

  @override
  Future<bool> isMarkerInfoWindowShown(
    MarkerId markerId, {
    required int mapId,
  }) async =>
      false;

  @override
  Future<double> getZoomLevel({required int mapId}) async => 5.0;

  @override
  Future<Uint8List?> takeSnapshot({required int mapId}) async => null;

  @override
  Future<bool> isAdvancedMarkersAvailable({required int mapId}) async => false;

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) => const Stream.empty();

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) => const Stream.empty();

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) => const Stream.empty();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) => const Stream.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) => const Stream.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) => const Stream.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) => const Stream.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) => const Stream.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) => const Stream.empty();

  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      const Stream.empty();

  @override
  void dispose({required int mapId}) {}
}
