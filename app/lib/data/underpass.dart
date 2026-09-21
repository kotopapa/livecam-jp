import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';

/// 地下道（アンダーパス）の冠水状況（1.5.1）。
///
/// 自治体がセンサーで公開している通行状況（通行可 / 通行注意 / 通行止め）を、
/// 配信サイトの `underpass_status.json`（tools/underpass.py が5分おきに更新、
/// 段階が変わったときだけ publish）から読む。2026-09-21 時点の情報源は
/// 千葉市地下道冠水情報システム（14か所）・静岡市「しずみちinfo」（19か所）・
/// さいたま市水位情報システム（道路22か所）・たかまつマイセーフティマップ（18か所）・
/// 兵庫県道路総合管理システム 冠水情報（25か所）。映像ではなく状態表示。
class UnderpassPoint {
  const UnderpassPoint({
    required this.id,
    required this.name,
    required this.pos,
    required this.level,
    required this.label,
    required this.at,
  });

  final String id;
  final String name;
  final LatLng pos;

  /// 0=通行可 / 1=通行注意 / 2=通行止め / -1=不明（観測停止・取得失敗）
  final int level;

  /// 情報源の表示文字列（「通行可能」など）
  final String label;

  /// 情報源の更新時刻表記（"9/21 09:00" のような文字列。そのまま出す）
  final String at;

  bool get isAlert => level >= 1;

  Color get color => switch (level) {
        2 => const Color(0xFFD32F2F),
        1 => const Color(0xFFF9A825),
        0 => const Color(0xFF1E88E5),
        _ => const Color(0xFF9E9E9E),
      };

  static UnderpassPoint? fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final name = j['name']?.toString() ?? '';
    if (lat == null || lng == null || name.isEmpty) return null;
    return UnderpassPoint(
      id: j['id']?.toString() ?? name,
      name: name,
      pos: LatLng(lat, lng),
      level: (j['level'] as num?)?.toInt() ?? -1,
      label: j['label']?.toString() ?? '',
      at: j['at']?.toString() ?? '',
    );
  }
}

/// 情報源（自治体のシステム）単位
class UnderpassSource {
  const UnderpassSource({
    required this.id,
    required this.name,
    required this.operator,
    required this.prefecture,
    required this.url,
    required this.attribution,
    required this.points,
  });

  final String id;
  final String name;
  final String operator;
  final String prefecture;
  final String url;
  final String attribution;
  final List<UnderpassPoint> points;

  List<UnderpassPoint> get alerts => [for (final p in points) if (p.isAlert) p];

  static UnderpassSource? fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final pts = <UnderpassPoint>[];
    final rawPts = j['points'];
    for (final p in (rawPts is List ? rawPts : const [])) {
      if (p is Map<String, dynamic>) {
        final u = UnderpassPoint.fromJson(p);
        if (u != null) pts.add(u);
      }
    }
    return UnderpassSource(
      id: id,
      name: j['name']?.toString() ?? '',
      operator: j['operator']?.toString() ?? '',
      prefecture: j['prefecture']?.toString() ?? '',
      url: j['url']?.toString() ?? '',
      attribution: j['attribution']?.toString() ?? '',
      points: pts,
    );
  }
}

class UnderpassStatus {
  const UnderpassStatus({required this.version, required this.sources});

  final String version;
  final List<UnderpassSource> sources;

  static const empty = UnderpassStatus(version: '', sources: []);

  List<UnderpassPoint> get allPoints => [for (final s in sources) ...s.points];
  List<UnderpassPoint> get alerts => [for (final s in sources) ...s.alerts];

  /// 通行注意・通行止めがある情報源
  List<UnderpassSource> get alertSources =>
      [for (final s in sources) if (s.alerts.isNotEmpty) s];

  static UnderpassStatus parse(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    final out = <UnderpassSource>[];
    final rawSources = json['sources'];
    for (final s in (rawSources is List ? rawSources : const [])) {
      if (s is Map<String, dynamic>) {
        final u = UnderpassSource.fromJson(s);
        if (u != null) out.add(u);
      }
    }
    return UnderpassStatus(version: json['version']?.toString() ?? '', sources: out);
  }
}

class Underpass {
  Underpass._();

  static const url = '${apiBaseUrl}underpass_status.json';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  static UnderpassStatus? _cache;
  static DateTime? _cachedAt;

  /// 取得（5分メモリ控え）。失敗時は控えがあればそれ、無ければ空
  static Future<UnderpassStatus> fetch({http.Client? client, bool force = false}) async {
    final c = _cache;
    if (!force && c != null && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 5)) {
      return c;
    }
    final cl = client ?? http.Client();
    try {
      final r = await cl.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return c ?? UnderpassStatus.empty;
      final parsed = UnderpassStatus.parse(jsonDecode(utf8.decode(r.bodyBytes)));
      _cache = parsed;
      _cachedAt = DateTime.now();
      return parsed;
    } catch (_) {
      return c ?? UnderpassStatus.empty;
    } finally {
      if (client == null) cl.close();
    }
  }
}
