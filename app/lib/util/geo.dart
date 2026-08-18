import 'dart:math';

import '../models/camera.dart';

/// 2点間の距離（メートル、ハーバサイン）。
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180.0;

/// [origin] の近くのカメラを距離順に返す（半径10km以内。SPEC 9.2③）。
List<(Camera, double)> nearbyCameras(Camera origin, List<Camera> all,
    {double radiusMeters = 10000, int limit = 10}) {
  if (!origin.hasLocation) return const [];
  final result = <(Camera, double)>[];
  for (final c in all) {
    if (c.id == origin.id || !c.hasLocation) continue;
    final d = distanceMeters(origin.lat!, origin.lng!, c.lat!, c.lng!);
    if (d <= radiusMeters) result.add((c, d));
  }
  result.sort((a, b) => a.$2.compareTo(b.$2));
  return result.take(limit).toList();
}
