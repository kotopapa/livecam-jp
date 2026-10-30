import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../util/jst.dart';
import 'amedas_snow.dart';

/// 積雪観測点の集約配信（災害速報タブ「積雪」でアメダスと合算する）。
///
/// 配信サイトの `snow_points.json`（tools が30分おきに国交省 道路情報提供システムと
/// 県の道路管理者の公開情報から積雪深を集約）を読む。配信には数値の積雪深があり、
/// 観測から24時間以内の地点だけが載る（欠測の概念はアプリに持ち込まない）。
class SnowPointSource {
  const SnowPointSource({
    required this.id,
    required this.name,
    required this.short,
    required this.attribution,
    required this.url,
    required this.points,
  });

  final String id;

  /// 出典の正式名（出典表記に並べる）
  final String name;

  /// 行に添える短い出典名（「国交省」など）
  final String short;
  final String attribution;
  final String url;
  final List<SnowPoint> points;
}

/// 外部の1観測点（観測点＋積雪深 cm）
class SnowPoint {
  const SnowPoint({required this.station, required this.depth});

  final SnowStation station;
  final int depth;
}

class SnowPointsDoc {
  const SnowPointsDoc({required this.version, required this.sources});

  /// 配信の版（UTC の ISO 8601）
  final String version;
  final List<SnowPointSource> sources;

  /// 配信にあるすべての点（積雪深 0 を含む）
  List<SnowStation> get stations =>
      [for (final s in sources) for (final p in s.points) p.station];
}

class SnowPoints {
  const SnowPoints._();

  static const url = '${apiBaseUrl}snow_points.json';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  static SnowPointsDoc? _cache;
  static DateTime? _cachedAt;

  /// 取得（10分メモリ控え）。失敗時は控え、無ければ null
  static Future<SnowPointsDoc?> fetch(
      {http.Client? client, bool force = false}) async {
    final c = _cache;
    if (!force &&
        c != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 10)) {
      return c;
    }
    final cl = client ?? http.Client();
    try {
      final r = await cl
          .get(Uri.parse(url), headers: _ua)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return c;
      final parsed = parse(jsonDecode(utf8.decode(r.bodyBytes)));
      if (parsed == null) return c;
      _cache = parsed;
      _cachedAt = DateTime.now();
      return parsed;
    } catch (_) {
      return c;
    } finally {
      if (client == null) cl.close();
    }
  }

  /// テスト用に控えを捨てる
  static void clearCache() {
    _cache = null;
    _cachedAt = null;
  }

  /// 配信 JSON の解析（純粋関数）。形が違えば null、壊れた点は読み飛ばす。
  /// 点の id は情報源をまたいで衝突しないよう `<sourceId>:<id>` にする
  static SnowPointsDoc? parse(Object? json) {
    if (json is! Map) return null;
    final list = json['sources'];
    if (list is! List) return null;
    final sources = <SnowPointSource>[];
    for (final e in list) {
      if (e is! Map) continue;
      final sid = e['id'], name = e['name'], pts = e['points'];
      if (sid is! String || name is! String || pts is! List) continue;
      final short = e['short'] is String ? e['short'] as String : name;
      final points = <SnowPoint>[];
      for (final p in pts) {
        if (p is! Map) continue;
        final id = p['id'], n = p['n'], lat = p['lat'], lng = p['lng'];
        final d = p['d'];
        if (id == null || n is! String || lat is! num || lng is! num) continue;
        if (d is! num || d < 0) continue;
        final m = p['m'];
        points.add(SnowPoint(
          depth: d.round(),
          station: SnowStation(
            id: '$sid:$id',
            name: n,
            lat: lat.toDouble(),
            lng: lng.toDouble(),
            municipality: m is String && m.length == 5 ? m : null,
            source: short,
            sourceId: sid,
          ),
        ));
      }
      sources.add(SnowPointSource(
        id: sid,
        name: name,
        short: short,
        attribution: e['attribution']?.toString() ?? name,
        url: e['url']?.toString() ?? '',
        points: points,
      ));
    }
    return SnowPointsDoc(
        version: json['version']?.toString() ?? '', sources: sources);
  }

  /// アメダスと外部点を合算する。どちらも無ければ null。
  /// observations はアメダス分＋外部点のうち積雪深 1cm 以上のもの。
  /// 観測時刻はアメダスのもの（無ければ配信の版を JST 壁時計に直したもの）
  static SnowReport? merge(SnowReport? amedas, SnowPointsDoc? ext) {
    final used = <SnowPointSource>[
      for (final s in ext?.sources ?? const <SnowPointSource>[])
        if (s.points.isNotEmpty) s
    ];
    if (amedas == null && used.isEmpty) return null;
    final obs = <SnowObs>[
      ...?amedas?.observations,
      for (final s in used)
        for (final p in s.points)
          if (p.depth >= 1) SnowObs(station: p.station, depth: p.depth),
    ]..sort((a, b) => b.depth.compareTo(a.depth));
    DateTime at;
    if (amedas != null) {
      at = amedas.observedAt;
    } else {
      try {
        at = toJstWallClock(DateTime.parse(ext!.version));
      } catch (_) {
        at = toJstWallClock(DateTime.now().toUtc());
      }
    }
    return SnowReport(
        observedAt: at, observations: obs, externalSources: used);
  }

  /// 近くの観測点の候補（アメダス観測点＋配信にある外部点すべて）
  static List<SnowStation> allStations(
          List<SnowStation> amedas, SnowPointsDoc? ext) =>
      [...amedas, ...?ext?.stations];

  /// 出典表記：アメダスに続けて外部の情報源名を「、」で並べる
  static String attributionText(Iterable<SnowPointSource> sources) {
    final names = [for (final s in sources) s.name];
    return names.isEmpty
        ? AmedasSnow.attribution
        : '${AmedasSnow.attribution}、${names.join('、')}';
  }
}
