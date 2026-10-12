import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/camera.dart';
import '../util/geo.dart';
import '../util/jst.dart';

/// 気象庁「潮位観測情報」の観測点
class TideStation {
  const TideStation(this.code, this.name, this.lat, this.lng);
  final String code;
  final String name;
  final double lat;
  final double lng;
}

enum TideTrend { rising, falling }

/// 天文潮位（予測）から求めた満潮・干潮1つ分
class TideExtreme {
  const TideExtreme(this.time, this.cm, {required this.high});

  /// JST の壁時計
  final DateTime time;
  final int cm;
  final bool high;
}

class TideInfo {
  const TideInfo({
    required this.stationName,
    required this.distanceKm,
    required this.cm,
    required this.at,
    this.trend,
    this.extremes = const [],
  });

  final String stationName;

  /// カメラから観測点までの距離（km、四捨五入。1未満は1）
  final int distanceKm;

  /// 最新の実測（TP 基準、cm）
  final int cm;

  /// 最新の実測時刻（JST の壁時計）
  final DateTime at;
  final TideTrend? trend;

  /// 今日の満潮・干潮（時刻順。天文潮位）
  final List<TideExtreme> extremes;

  List<TideExtreme> get highs => extremes.where((e) => e.high).toList();
  List<TideExtreme> get lows => extremes.where((e) => !e.high).toList();
}

/// 実測1日分の解析結果
class TideObs {
  const TideObs(this.cm, this.at, this.trend);
  final int cm;
  final DateTime at;
  final TideTrend? trend;
}

class TideLevels {
  TideLevels._();

  static const _base = 'https://www.jma.go.jp/bosai/tidelevel/';
  static const maxDistanceM = 30000.0;

  /// tide 配列の刻み。JSON の interval:15 は「秒」。要素数 4460 が
  /// 18:34:45 の更新（66885 秒 / 15 = 4459 番目）と一致する
  static const sampleSeconds = 15;
  static const _stationsTtl = Duration(hours: 24);
  static const _obsTtl = Duration(minutes: 15);

  static (DateTime, List<TideStation>)? _stations;
  static final Map<String, (DateTime, TideObs?)> _obs = {};
  static final Map<String, Map<String, dynamic>?> _astro = {};

  static void invalidate() => _obs.clear();
  static void resetCache() {
    _stations = null;
    _obs.clear();
    _astro.clear();
  }

  static bool appliesTo(Camera c) =>
      (c.category == 'coast' || c.category == 'port') && !c.isWorld && c.hasLocation;

  /// tide_area.json（市町村 → class30s → stations）から観測点を平らに集める
  static List<TideStation> parseStations(dynamic json) {
    final out = <TideStation>[];
    void walk(dynamic n) {
      if (n is Map) {
        final st = n['stations'];
        if (st is List) {
          for (final s in st) {
            if (s is! Map) continue;
            final code = s['code'];
            final lat = s['lat'];
            final lon = s['lon'];
            if (code is String && lat is num && lon is num) {
              out.add(TideStation(code, (s['name'] as String?) ?? code,
                  lat.toDouble(), lon.toDouble()));
            }
          }
        }
        for (final v in n.values) {
          if (v is Map || v is List) walk(v);
        }
      } else if (n is List) {
        for (final v in n) {
          walk(v);
        }
      }
    }

    walk(json);
    return out;
  }

  /// 30 km 以内の観測点を近い順に（最大 [limit] 件）
  static List<(TideStation, double)> nearest(
      List<TideStation> all, double lat, double lng,
      {int limit = 3}) {
    final l = [
      for (final s in all) (s, distanceMeters(lat, lng, s.lat, s.lng)),
    ].where((e) => e.$2 <= maxDistanceM).toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return l.take(limit).toList();
  }

  static String _ymd(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static double? _mean(List<dynamic> t, int from, int to) {
    if (from < 0) return null;
    var sum = 0;
    var n = 0;
    for (var i = from; i < to && i < t.length; i++) {
      final v = t[i];
      if (v is int) {
        sum += v;
        n++;
      }
    }
    return n < (to - from) ~/ 2 || n == 0 ? null : sum / n;
  }

  /// 実測（tide_obs_*.json）。tide[i] は当日 0:00 JST から i*15 秒後。
  /// 欠測（空配列・全 null）は null。上げ下げは「直近5分の平均」と
  /// 「その30分前の5分平均」の差が 1cm 以上かで判定する
  static TideObs? parseObs(Map<String, dynamic> json, DateTime day) {
    final t = json['tide'];
    if (t is! List || t.isEmpty) return null;
    var last = t.length - 1;
    while (last >= 0 && t[last] is! num) {
      last--;
    }
    if (last < 0) return null;
    final intervalSec = (json['interval'] as num?)?.toInt() ?? sampleSeconds;
    final at = DateTime(day.year, day.month, day.day).add(Duration(seconds: last * intervalSec));
    final per5min = 300 ~/ intervalSec;
    final per30 = 1800 ~/ intervalSec;
    TideTrend? trend;
    final recent = _mean(t, last - per5min + 1, last + 1);
    final before = _mean(t, last - per30 - per5min + 1, last - per30 + 1);
    if (recent != null && before != null) {
      final d = recent - before;
      if (d >= 1) trend = TideTrend.rising;
      if (d <= -1) trend = TideTrend.falling;
    }
    return TideObs((t[last] as num).round(), at, trend);
  }

  /// 天文潮位（tide_astro_<年>_<地点>.json。`tide` は "MMDD" → 毎時 0〜23 時の24値 cm）
  /// から [day] の満潮・干潮を求める。毎時値の極値を放物線で補間して時刻・高さを出す
  static List<TideExtreme> extremes(Map<String, dynamic> json, DateTime day) {
    final tide = json['tide'];
    if (tide is! Map) return const [];
    String key(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    List<num>? of(DateTime d) {
      if (d.year != day.year) return null;
      final v = tide[key(d)];
      if (v is! List || v.length != 24 || v.any((e) => e is! num)) return null;
      return v.cast<num>();
    }

    final today = of(day);
    if (today == null) return const [];
    final prev = of(day.subtract(const Duration(days: 1)));
    final next = of(DateTime(day.year, day.month, day.day + 1));
    // 前日 23 時 + 当日 24 値 + 翌日 0 時 を並べ、添字 1..24 が当日 0..23 時
    final s = <num?>[prev?.last, ...today, next?.first];
    final out = <TideExtreme>[];
    for (var i = 1; i <= 24; i++) {
      final a = s[i - 1], b = s[i]!, c = s[i + 1];
      if (a == null || c == null) continue;
      final high = b > a && b >= c;
      final low = b < a && b <= c;
      if (!high && !low) continue;
      final den = a - 2 * b + c;
      final off = den == 0 ? 0.0 : 0.5 * (a - c) / den;
      final peak = b - 0.25 * (a - c) * off;
      final minutes = ((i - 1) + off) * 60;
      if (minutes < 0 || minutes >= 24 * 60) continue;
      out.add(TideExtreme(
        DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes.round())),
        peak.round(),
        high: high,
      ));
    }
    out.sort((x, y) => x.time.compareTo(y.time));
    return out;
  }

  static Future<dynamic> _getJson(http.Client cl, String path) async {
    final r = await cl.get(Uri.parse('$_base$path')).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<List<TideStation>?> _loadStations(http.Client cl) async {
    final c = _stations;
    if (c != null && DateTime.now().difference(c.$1) < _stationsTtl) return c.$2;
    final j = await _getJson(cl, 'const/tide_area.json');
    if (j == null) return c?.$2;
    final l = parseStations(j);
    if (l.isEmpty) return c?.$2;
    _stations = (DateTime.now(), l);
    return l;
  }

  static Future<TideObs?> _loadObs(http.Client cl, String code, DateTime now) async {
    final c = _obs[code];
    if (c != null && DateTime.now().difference(c.$1) < _obsTtl) return c.$2;
    Future<TideObs?> day(DateTime d) async {
      final j = await _getJson(cl, 'data/tide/tide_obs_${_ymd(d)}_$code.json');
      return j is Map<String, dynamic> ? parseObs(j, d) : null;
    }

    final today = DateTime(now.year, now.month, now.day);
    var o = await day(today);
    // 日付をまたいだ直後は当日ファイルがまだ無い／空のことがある
    if (o == null && now.hour < 2) {
      o = await day(today.subtract(const Duration(days: 1)));
    }
    // 6 時間以上更新が無ければ欠測とみなす
    if (o != null && now.difference(o.at) > const Duration(hours: 6)) o = null;
    _obs[code] = (DateTime.now(), o);
    return o;
  }

  static Future<Map<String, dynamic>?> _loadAstro(
      http.Client cl, String code, int year) async {
    final k = '$year:$code';
    if (_astro.containsKey(k)) return _astro[k];
    try {
      final j = await _getJson(cl, 'const/tide_astro/tide_astro_${year}_$code.json');
      _astro[k] = j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
    return _astro[k];
  }

  /// カメラ最寄り（30 km 以内）の潮位。対象外・観測点なし・欠測・取得失敗は null
  static Future<TideInfo?> fetch(Camera camera,
      {http.Client? client, DateTime? nowJst}) async {
    if (!appliesTo(camera)) return null;
    final cl = client ?? http.Client();
    try {
      final all = await _loadStations(cl);
      if (all == null) return null;
      final now = nowJst ?? jstNow();
      for (final (st, d) in nearest(all, camera.lat!, camera.lng!)) {
        TideObs? obs;
        try {
          obs = await _loadObs(cl, st.code, now);
        } catch (_) {
          continue;
        }
        if (obs == null) continue;
        var ex = <TideExtreme>[];
        final today = DateTime(now.year, now.month, now.day);
        final a = await _loadAstro(cl, st.code, today.year);
        if (a != null) ex = extremes(a, today);
        return TideInfo(
          stationName: st.name,
          distanceKm: (d / 1000).round().clamp(1, 30),
          cm: obs.cm,
          at: obs.at,
          trend: obs.trend,
          extremes: ex,
        );
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) cl.close();
    }
  }
}
