import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// 今昔マップ on the web（時系列地形図閲覧サイト。埼玉大学 谷謙二氏／今昔マップ運営委員会）の
/// 旧版地形図タイル。地図レイヤー「昔の地図」で、今の地図と新旧を比べるのに使う。
///
/// - 地域・時期・範囲の表は同梱アセット `assets/data/kjmap_regions.json`
///   （`tools/kjmap_regions.py` が配信元の kjmapdata.js から生成）
/// - タイルは配信元を直接読む（複製配信は禁止）。TMS（y は南西始点）
/// - 利用条件: 画面に「今昔マップ on the web」の文字を入れる（[attribution]）
/// - 古い地図は三角点整備前の測量で、場所によって位置が数十m以上ずれる
class KjmapEra {
  const KjmapEra({
    required this.folder,
    required this.start,
    required this.end,
    required this.north,
    required this.west,
    required this.south,
    required this.east,
  });

  final String folder;
  final int start;
  final int end;
  final double north, west, south, east;

  bool contains(LatLng p) =>
      p.latitude <= north && p.latitude >= south && p.longitude >= west && p.longitude <= east;
}

class KjmapRegion {
  const KjmapRegion({
    required this.id,
    required this.name,
    required this.maxZoom,
    required this.north,
    required this.west,
    required this.south,
    required this.east,
    required this.eras,
  });

  final String id;
  final String name;
  final int maxZoom;
  final double north, west, south, east;

  /// 古い順
  final List<KjmapEra> eras;

  bool contains(LatLng p) =>
      p.latitude <= north && p.latitude >= south && p.longitude >= west && p.longitude <= east;

  KjmapEra? era(String folder) {
    for (final e in eras) {
      if (e.folder == folder) return e;
    }
    return null;
  }
}

class Kjmap {
  const Kjmap._();

  static const siteName = '今昔マップ on the web';
  static const siteUrl = 'https://ktgis.net/kjmapw/';

  /// 使用上の注意ページの「正式版」の表記
  static const attribution = '「今昔マップ on the web」（(C)谷 謙二）';
  static const minZoom = 8;

  static List<KjmapRegion>? _regions;
  static Future<List<KjmapRegion>>? _loading;

  static Future<List<KjmapRegion>> load() => _loading ??= _load();

  static Future<List<KjmapRegion>> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/kjmap_regions.json');
      return _regions = parse(jsonDecode(raw));
    } catch (_) {
      return _regions = const [];
    }
  }

  /// 読み込み済みなら同期で返す（未読込は空）
  static List<KjmapRegion> get regions => _regions ?? const [];

  /// テスト用
  static void setRegions(List<KjmapRegion>? regions) {
    _regions = regions;
    _loading = regions == null ? null : Future.value(regions);
  }

  static List<KjmapRegion> parse(Object? json) {
    if (json is! Map) return const [];
    final list = json['regions'];
    if (list is! List) return const [];
    final out = <KjmapRegion>[];
    for (final r in list) {
      if (r is! Map) continue;
      final eras = <KjmapEra>[];
      for (final e in (r['eras'] as List? ?? const [])) {
        if (e is! Map) continue;
        eras.add(KjmapEra(
          folder: '${e['f']}',
          start: (e['start'] as num).toInt(),
          end: (e['end'] as num).toInt(),
          north: (e['n'] as num).toDouble(),
          west: (e['w'] as num).toDouble(),
          south: (e['s'] as num).toDouble(),
          east: (e['e'] as num).toDouble(),
        ));
      }
      if (eras.isEmpty) continue;
      out.add(KjmapRegion(
        id: '${r['id']}',
        name: '${r['name']}',
        maxZoom: (r['zmax'] as num?)?.toInt() ?? 16,
        north: (r['n'] as num).toDouble(),
        west: (r['w'] as num).toDouble(),
        south: (r['s'] as num).toDouble(),
        east: (r['e'] as num).toDouble(),
        eras: eras,
      ));
    }
    return out;
  }

  /// 地点を含む地域（範囲が重なる地域は狭い方を先に）
  static List<KjmapRegion> regionsAt(List<KjmapRegion> regions, LatLng p) {
    final hits = regions.where((r) => r.contains(p)).toList()
      ..sort((a, b) => _area(a).compareTo(_area(b)));
    return hits;
  }

  static double _area(KjmapRegion r) => (r.north - r.south) * (r.east - r.west);

  /// タイル URL（flutter_map の `tms: true` で読む）
  static String tileTemplate(String regionId, String eraFolder) =>
      'https://ktgis.net/kjmapw/kjtilemap/$regionId/$eraFolder/{z}/{x}/{y}.png';

  /// 時期の表示（同じ年なら「1916年」、範囲なら「1896〜1909年」）
  static String eraLabel(KjmapEra e, {String yearSuffix = '年', String range = '〜'}) =>
      e.start == e.end ? '${e.start}$yearSuffix' : '${e.start}$range${e.end}$yearSuffix';
}
