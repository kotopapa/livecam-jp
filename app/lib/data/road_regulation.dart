import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';

/// 道路の通行規制（災害・気象由来。1.5.2）。
///
/// 配信サイトの `road_regulation.json`（tools/road_regulation.py が30分おきに国交省
/// 道路情報提供システムの「現在の通行規制」から工事・冬期を除いて集約）を読む。
/// 直轄国道のほか高速道路会社・都道府県から提供された規制も含まれる。
class RoadRegulationItem {
  const RoadRegulationItem({
    required this.id,
    required this.name,
    required this.section,
    required this.kind,
    required this.direction,
    required this.cause,
    required this.content,
    required this.pos,
    required this.level,
    required this.label,
    required this.at,
    required this.lines,
  });

  final String id;

  /// 路線名（例: 国道1号）
  final String name;

  /// 規制区間（開始地点～終了地点）
  final String section;

  /// 情報源の区分（通行止（都道府県道） など）
  final String kind;
  final String direction;
  final String cause;
  final String content;
  final LatLng pos;

  /// 2=通行止め / 1=車線規制・片側交互通行など / -1=不明
  final int level;

  /// 表示文字列（例: 通行止（災害等））
  final String label;

  /// 規制開始日時（情報源の表記そのまま）
  final String at;

  /// 規制区間の線（[lat,lng] の列）
  final List<List<LatLng>> lines;

  Color get color => level >= 2 ? const Color(0xFFD32F2F) : const Color(0xFFF57C00);

  static RoadRegulationItem? fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final name = j['name']?.toString() ?? '';
    if (lat == null || lng == null || name.isEmpty) return null;
    final lines = <List<LatLng>>[];
    if (j['lines'] is List) {
      for (final line in j['lines'] as List) {
        if (line is! List) continue;
        final pts = <LatLng>[];
        for (final c in line) {
          if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
            pts.add(LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()));
          }
        }
        if (pts.length >= 2) lines.add(pts);
      }
    }
    return RoadRegulationItem(
      id: j['id']?.toString() ?? name,
      name: name,
      section: j['section']?.toString() ?? '',
      kind: j['kind']?.toString() ?? '',
      direction: j['direction']?.toString() ?? '',
      cause: j['cause']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      pos: LatLng(lat, lng),
      level: (j['level'] as num?)?.toInt() ?? -1,
      label: j['label']?.toString() ?? '',
      at: j['at']?.toString() ?? '',
      lines: lines,
    );
  }
}

class RoadRegulationSource {
  const RoadRegulationSource({
    required this.id,
    required this.name,
    required this.url,
    required this.attribution,
    required this.items,
  });

  final String id;
  final String name;
  final String url;
  final String attribution;
  final List<RoadRegulationItem> items;

  static RoadRegulationSource? fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final items = <RoadRegulationItem>[];
    final raw = j['items'];
    for (final p in (raw is List ? raw : const [])) {
      if (p is Map<String, dynamic>) {
        final it = RoadRegulationItem.fromJson(p);
        if (it != null) items.add(it);
      }
    }
    return RoadRegulationSource(
      id: id,
      name: j['name']?.toString() ?? '',
      url: j['url']?.toString() ?? '',
      attribution: j['attribution']?.toString() ?? '',
      items: items,
    );
  }
}

class RoadRegulationStatus {
  const RoadRegulationStatus({required this.version, required this.sources});

  final String version;
  final List<RoadRegulationSource> sources;

  static const empty = RoadRegulationStatus(version: '', sources: []);

  List<RoadRegulationItem> get allItems => [for (final s in sources) ...s.items];
  int get closedCount => allItems.where((i) => i.level >= 2).length;

  static RoadRegulationStatus parse(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    final out = <RoadRegulationSource>[];
    final raw = json['sources'];
    for (final s in (raw is List ? raw : const [])) {
      if (s is Map<String, dynamic>) {
        final src = RoadRegulationSource.fromJson(s);
        if (src != null) out.add(src);
      }
    }
    return RoadRegulationStatus(version: json['version']?.toString() ?? '', sources: out);
  }
}

class RoadRegulation {
  RoadRegulation._();

  static const url = '${apiBaseUrl}road_regulation.json';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  static RoadRegulationStatus? _cache;
  static DateTime? _cachedAt;

  /// 取得（10分メモリ控え）。失敗時は控えがあればそれ、無ければ空
  static Future<RoadRegulationStatus> fetch({http.Client? client, bool force = false}) async {
    final c = _cache;
    if (!force && c != null && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 10)) {
      return c;
    }
    final cl = client ?? http.Client();
    try {
      final r = await cl.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return c ?? RoadRegulationStatus.empty;
      final parsed = RoadRegulationStatus.parse(jsonDecode(utf8.decode(r.bodyBytes)));
      _cache = parsed;
      _cachedAt = DateTime.now();
      return parsed;
    } catch (_) {
      return c ?? RoadRegulationStatus.empty;
    } finally {
      if (client == null) cl.close();
    }
  }
}
