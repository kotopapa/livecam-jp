/// 気象庁の台風情報（無料・認証不要の公開JSON。SPEC C2）。
///
/// - `https://www.jma.go.jp/bosai/typhoon/data/targetTc.json`
///     … 現在情報を発表中の熱帯低気圧の一覧（tropicalCyclone=TC番号、typhoonNumber=台風番号。
///       台風になる見込みの熱帯低気圧は "a"〜 の英字）
/// - `.../data/<TC>/specifications.json`
///     … 実況と予報（12/24/48/72/96/120時間後）の位置・中心気圧・最大風速・予報円半径・
///       暴風警戒域（stormWarning.range）・強風域（galeWarning.range）
/// - `.../data/<TC>/forecast.json`
///     … 経路（track.preTyphoon / track.typhoon）と予報円半径(m)
///
/// 気象庁サイト内部の公開ファイルのため、構造変更時は静かに失敗させる（空を返す）。
/// 出典：気象庁ホームページ https://www.jma.go.jp/bosai/typhoon/
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// 実況または予報の1時点
class TyphoonPoint {
  const TyphoonPoint({
    required this.hours,
    required this.validAt,
    required this.center,
    this.probabilityRadiusM,
    this.stormRadiusKm,
    this.galeRadiusKm,
    this.categoryEn = '',
    this.categoryJp = '',
    this.intensity = '',
    this.pressureHpa,
    this.maxWindMs,
    this.location = '',
    this.course = '',
    this.speedKmh,
  });

  /// 実況=0、予報は 12/24/48/72/96/120
  final int hours;

  /// 絶対時刻（UTCフラグ付き）
  final DateTime validAt;
  final LatLng center;

  /// 予報円の半径（m）。実況は null
  final double? probabilityRadiusM;

  /// 暴風域（実況）／暴風警戒域（予報）の半径（km）。最大値。無ければ null
  final double? stormRadiusKm;

  /// 強風域の半径（km）。実況のみ
  final double? galeRadiusKm;

  /// 気象庁の階級コード（TD/TS/STS/TY）と日本語名（熱帯低気圧／台風）
  final String categoryEn;
  final String categoryJp;

  /// 強さ（強い／非常に強い／猛烈な。無ければ空）
  final String intensity;
  final int? pressureHpa;
  final double? maxWindMs;

  /// 位置の説明（マリアナ諸島 など。日本語のみ）
  final String location;
  final String course;
  final double? speedKmh;

  bool get isAnalysis => hours == 0;
}

/// 熱帯低気圧1つ分
class Typhoon {
  const Typhoon({
    required this.id,
    required this.typhoonNumber,
    required this.issuedAt,
    required this.analysis,
    required this.forecasts,
    required this.track,
  });

  /// TC番号（例: TC2630）
  final String id;

  /// 台風番号（"2618" のような4桁、または台風になる見込みの熱帯低気圧は英字）
  final String typhoonNumber;
  final DateTime issuedAt;
  final TyphoonPoint analysis;

  /// 予報（時間順）
  final List<TyphoonPoint> forecasts;

  /// 過去の経路（古い順。最後が現在位置）
  final List<LatLng> track;

  /// 台風番号（号）。熱帯低気圧の段階では null
  int? get number {
    final n = int.tryParse(typhoonNumber);
    if (n == null) return null;
    // 4桁 "2618" → 18号。2桁以下ならそのまま
    return n >= 100 ? n % 100 : n;
  }

  /// 台風名（気象庁の呼称は「台風第N号」）。熱帯低気圧の段階では null
  bool get isTyphoonNow =>
      analysis.categoryEn.isNotEmpty && analysis.categoryEn != 'TD';

  /// 実況を含めた全時点（時間順）
  List<TyphoonPoint> get points => [analysis, ...forecasts];
}

class JmaTyphoon {
  JmaTyphoon._();

  static const listUrl = 'https://www.jma.go.jp/bosai/typhoon/data/targetTc.json';
  static const attribution = '出典：気象庁';
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'
  };

  static List<Typhoon>? _memory;
  static DateTime? _memoryAt;
  static const _ttl = Duration(minutes: 5);

  /// 発表中の熱帯低気圧をすべて返す（無ければ空）。5分はメモリの控えを返す
  static Future<List<Typhoon>> fetchAll({http.Client? client}) async {
    final at = _memoryAt;
    if (_memory != null && at != null && DateTime.now().difference(at) < _ttl) {
      return _memory!;
    }
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(Uri.parse(listUrl), headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return _memory ?? const [];
      final list = (jsonDecode(utf8.decode(r.bodyBytes)) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final out = <Typhoon>[];
      for (final e in list) {
        final id = e['tropicalCyclone'] as String? ?? '';
        if (id.isEmpty) continue;
        final t = await fetchOne(id, client: c);
        if (t != null) out.add(t);
      }
      _memory = out;
      _memoryAt = DateTime.now();
      return out;
    } catch (_) {
      return _memory ?? const [];
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<Typhoon?> fetchOne(String id, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final base = 'https://www.jma.go.jp/bosai/typhoon/data/$id';
      final rs = await Future.wait([
        c.get(Uri.parse('$base/specifications.json'), headers: _ua),
        c.get(Uri.parse('$base/forecast.json'), headers: _ua),
      ]).timeout(const Duration(seconds: 15));
      if (rs[0].statusCode != 200) return null;
      final spec = jsonDecode(utf8.decode(rs[0].bodyBytes));
      final fc = rs[1].statusCode == 200
          ? jsonDecode(utf8.decode(rs[1].bodyBytes))
          : null;
      return parse(id, spec, fc);
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// テスト用: メモリの控えを捨てる
  static void resetMemory() {
    _memory = null;
    _memoryAt = null;
  }

  /// specifications.json と forecast.json（省略可）から組み立てる。壊れていれば null
  static Typhoon? parse(String id, Object? specJson, Object? forecastJson) {
    if (specJson is! List) return null;
    final parts = specJson.whereType<Map<String, dynamic>>().toList();
    if (parts.isEmpty) return null;
    final title = parts.firstWhere((p) => p['part'] == 'title',
        orElse: () => const {});
    final issued = _time(title['issue']);
    final number = title['typhoonNumber']?.toString() ?? '';

    // forecast.json: advancedHours → 予報円半径(m) / 経路
    final radiusByHours = <int, double>{};
    var track = <LatLng>[];
    if (forecastJson is List) {
      for (final p in forecastJson.whereType<Map<String, dynamic>>()) {
        final h = (p['advancedHours'] as num?)?.toInt();
        if (h == null) continue;
        final pc = p['probabilityCircle'];
        if (pc is Map && pc['radius'] is num) {
          radiusByHours[h] = (pc['radius'] as num).toDouble();
        }
        if (h == 0 && p['track'] is Map) {
          final tr = p['track'] as Map;
          track = [
            ..._latLngList(tr['preTyphoon']),
            ..._latLngList(tr['typhoon']),
          ];
        }
      }
    }

    TyphoonPoint? analysis;
    final forecasts = <TyphoonPoint>[];
    for (final p in parts) {
      final h = (p['advancedHours'] as num?)?.toInt();
      if (h == null) continue;
      final pos = p['position'];
      final deg = pos is Map ? pos['deg'] : null;
      if (deg is! List || deg.length < 2) continue;
      final lat = (deg[0] as num?)?.toDouble();
      final lng = (deg[1] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final valid = _time(p['validtime']);
      if (valid == null) continue;
      final cat = p['category'];
      final wind = p['maximumWind'];
      final sustained = wind is Map ? wind['sustained'] : null;
      final speed = p['speed'];
      final pcr = p['probabilityCircleRadius'];
      double? probM = radiusByHours[h];
      if (probM == null && pcr is Map && pcr['km'] != null) {
        probM = _num(pcr['km']) == null ? null : _num(pcr['km'])! * 1000;
      }
      final point = TyphoonPoint(
        hours: h,
        validAt: valid,
        center: LatLng(lat, lng),
        probabilityRadiusM: h == 0 ? null : probM,
        stormRadiusKm: _maxRange(p['stormWarning']),
        galeRadiusKm: _maxRange(p['galeWarning']),
        categoryEn: cat is Map ? (cat['en']?.toString() ?? '') : '',
        categoryJp: cat is Map ? (cat['jp']?.toString() ?? '') : '',
        intensity: _dash(p['intensity']),
        pressureHpa: _num(p['pressure'])?.round(),
        maxWindMs: sustained is Map ? _num(sustained['m/s']) : null,
        location: p['location']?.toString() ?? '',
        course: _dash(p['course']),
        speedKmh: speed is Map ? _num(speed['km/h']) : null,
      );
      if (h == 0) {
        analysis = point;
      } else {
        forecasts.add(point);
      }
    }
    if (analysis == null) return null;
    forecasts.sort((a, b) => a.hours.compareTo(b.hours));
    if (track.isEmpty) track = [analysis.center];
    return Typhoon(
      id: id,
      typhoonNumber: number,
      issuedAt: issued ?? analysis.validAt,
      analysis: analysis,
      forecasts: forecasts,
      track: track,
    );
  }

  static DateTime? _time(Object? v) {
    if (v is! Map) return null;
    final s = (v['UTC'] ?? v['JST'])?.toString();
    if (s == null) return null;
    return DateTime.tryParse(s)?.toUtc();
  }

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String _dash(Object? v) {
    final s = v?.toString() ?? '';
    return s == '-' ? '' : s;
  }

  /// stormWarning / galeWarning は [{area, range:{km}}] の配列。最大の km を返す
  static double? _maxRange(Object? v) {
    if (v is! List) return null;
    double? best;
    for (final e in v) {
      if (e is! Map) continue;
      final range = e['range'];
      final km = range is Map ? _num(range['km']) : null;
      if (km != null && (best == null || km > best)) best = km;
    }
    return best;
  }

  static List<LatLng> _latLngList(Object? v) {
    if (v is! List) return const [];
    final out = <LatLng>[];
    for (final e in v) {
      if (e is List && e.length >= 2) {
        final lat = _num(e[0]);
        final lng = _num(e[1]);
        if (lat != null && lng != null) out.add(LatLng(lat, lng));
      }
    }
    return out;
  }
}
