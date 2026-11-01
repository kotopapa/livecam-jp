import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/camera.dart';
import '../util/geo.dart';
import '../util/jst.dart';
import 'jma_area.dart';
import 'wave_forecast.dart';

/// カメラ詳細「この地点の天気」。3つの情報源を合わせる（出典はすべて気象庁）。
///
/// 1. 点の予報（天気分布予報。5km メッシュ・3時間ごと・約2日分）: 自サイト配信の
///    `v1/wdist/index.json` と 2度四方のブロック `v1/wdist/<lat0>_<lng0>.json`
/// 2. 区域の風（地域時系列予報 VPFD。一次細分区域単位・3時間ごと）
/// 3. 実況: 最寄り（30km 以内）のアメダス
///
/// 時刻は「絶対時刻（UTC の instant）」で持ち、表示するときだけ
/// [toJstWallClock] で壁時計にする（jst.dart の原則）。
/// 時間枠は [valid, valid+3h) として扱う（VPFD の timeDefines+duration PT3H と同じ）。

/// 点の予報の1枠
class PointStep {
  const PointStep(
      {required this.validUtc, this.temp, this.weather = 0, this.rain = 0, this.snow = 0});

  /// 枠の開始（UTC の instant）
  final DateTime validUtc;

  /// 気温 ℃（整数）。無ければ null
  final int? temp;

  /// 0=なし 1=晴れ 2=くもり 3=雨 4=雨または雪 5=雪
  final int weather;

  /// 降水量の階級（mm/3h）: 0=1未満 1=1–5 2=5–10 3=10–15 4=15–20 5=20以上
  final int rain;

  /// 降雪量の階級（cm/3h）: 0=1未満 1=1–3 2=3–6 3=6以上
  final int snow;
}

/// 区域の風の1枠
class WindStep {
  const WindStep(
      {required this.validUtc, this.dir, this.minMs, this.maxMs, this.weatherCode});
  final DateTime validUtc;

  /// 区域の天気（VPFD の天気文字列から。気象庁の天気コード）
  final String? weatherCode;

  /// 風向 1〜16（1=北北東 … 16=北）。0=静穏。不明は null
  final int? dir;

  /// 風速の範囲 m/s（下端・上端）。1つだけなら同じ値。不明は null
  final int? minMs;
  final int? maxMs;
}

/// 区域の風と代表地点の気温（VPFD）
class AreaWind {
  const AreaWind({
    required this.areaName,
    required this.areaEnName,
    required this.steps,
    this.repName,
    this.repEnName,
    this.repTemps = const {},
    this.reportedAt,
  });
  final String areaName;
  final String areaEnName;
  final List<WindStep> steps;

  /// 代表地点名（pointTimeSeries）。点の予報が無いときの気温の代替
  final String? repName;
  final String? repEnName;
  final Map<DateTime, int> repTemps;

  /// 発表時刻（instant）
  final DateTime? reportedAt;
}

/// 最寄りのアメダスの実況
class AmedasNow {
  const AmedasNow({
    required this.name,
    required this.distanceKm,
    required this.at,
    this.temp,
    this.humidity,
    this.windMs,
    this.windDir,
    this.precip1h,
  });
  final String name;

  /// 小数1桁に丸めた距離 km
  final double distanceKm;

  /// 観測時刻（JST 壁時計）
  final DateTime at;
  final double? temp;
  final int? humidity;
  final double? windMs;

  /// 1〜16、0=静穏
  final int? windDir;
  final double? precip1h;

  bool get hasAny =>
      temp != null || humidity != null || windMs != null || precip1h != null;
}

/// 表の1列
class PointColumn {
  const PointColumn(
      {required this.validUtc,
      this.weather,
      this.temp,
      this.rain,
      this.snow,
      this.wind,
      this.weatherCode,
      this.pop});
  final DateTime validUtc;
  final int? weather;

  /// 気象庁の天気コード（点の予報の w を割り当てたもの。無ければ区域の天気）
  final String? weatherCode;

  /// 降水確率 %（6時間ごとの枠の先頭の列だけ）
  final int? pop;
  final int? temp;
  final int? rain;
  final int? snow;
  final WindStep? wind;
}

/// 週間予報の1日
class WeekDay {
  const WeekDay({required this.day, this.code, this.pop, this.tempMax, this.tempMin});

  /// その日の 0 時（JST 壁時計）
  final DateTime day;
  final String? code;
  final int? pop;
  final int? tempMax;
  final int? tempMin;
}

/// 週間予報（府県予報 [1]）
class WeekForecast {
  const WeekForecast({required this.areaName, this.stationName, required this.days});
  final String areaName;

  /// 気温の代表地点（横浜 など）
  final String? stationName;
  final List<WeekDay> days;
}

/// 点の予報の w（1〜5）→ 気象庁の天気コード
String? weatherCodeOfW(int w) => switch (w) {
      1 => '100',
      2 => '200',
      3 => '300',
      4 => '303',
      5 => '400',
      _ => null,
    };

/// 区域の天気文字列（「くもり」「雨」等）→ 天気コード。分からなければ null
String? weatherCodeOfText(Object? text) {
  if (text is! String) return null;
  final t = text.replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return null;
  if (t.contains('雨または雪') || t.contains('みぞれ')) return '303';
  if (t.contains('雪')) return '400';
  if (t.contains('雨')) return '300';
  if (t.contains('くもり') || t.contains('曇')) return '200';
  if (t.contains('晴')) return '100';
  return null;
}

/// 天気コード → Meteocons（Bas Milius, MIT）のマーク名。「のち」は (前半, 後半) の2枚、
/// それ以外は主マークだけ。昼夜は区別しない（気象庁の予報コードが区別しないため）。
/// 「時々・一時」は partly-cloudy 系か主マークに寄せる。割り当ては気象庁の天気コード表
/// （forecast ページの TELOPS。各コードが使う基本アイコン 100/101/102/104/110/112/115/
/// 200〜215/300〜314/400〜414）に従い、名前に「雷」があれば雷雨、「雨か雪・みぞれ」が
/// あればみぞれのマークに置き換えた（2026-11-02 に正式表で照合済み）。無いコードは null
({String main, String? then})? weatherIconSpec(String code) {
  const table = <String, (String, String?)>{
    '100': ('clear-day', null),
    '101': ('partly-cloudy-day', null),
    '102': ('partly-cloudy-day-rain', null),
    '103': ('partly-cloudy-day-rain', null),
    '104': ('partly-cloudy-day-snow', null),
    '105': ('partly-cloudy-day-snow', null),
    '106': ('partly-cloudy-day-sleet', null),
    '107': ('partly-cloudy-day-sleet', null),
    '108': ('thunderstorms-rain', null),
    '110': ('clear-day', 'overcast'),
    '111': ('clear-day', 'overcast'),
    '112': ('clear-day', 'rain'),
    '113': ('clear-day', 'rain'),
    '114': ('clear-day', 'rain'),
    '115': ('clear-day', 'snow'),
    '116': ('clear-day', 'snow'),
    '117': ('clear-day', 'snow'),
    '118': ('clear-day', 'sleet'),
    '119': ('clear-day', 'thunderstorms-rain'),
    '120': ('partly-cloudy-day-rain', null),
    '121': ('partly-cloudy-day-rain', null),
    '122': ('clear-day', 'rain'),
    '123': ('clear-day', null),
    '124': ('clear-day', null),
    '125': ('clear-day', 'thunderstorms-rain'),
    '126': ('clear-day', 'rain'),
    '127': ('clear-day', 'rain'),
    '128': ('clear-day', 'rain'),
    '130': ('clear-day', null),
    '131': ('clear-day', null),
    '132': ('partly-cloudy-day', null),
    '140': ('thunderstorms-rain', null),
    '160': ('partly-cloudy-day-sleet', null),
    '170': ('partly-cloudy-day-sleet', null),
    '181': ('clear-day', 'sleet'),
    '200': ('overcast', null),
    '201': ('overcast-day', null),
    '202': ('overcast-rain', null),
    '203': ('overcast-rain', null),
    '204': ('overcast-snow', null),
    '205': ('overcast-snow', null),
    '206': ('sleet', null),
    '207': ('sleet', null),
    '208': ('thunderstorms-rain', null),
    '209': ('overcast', null),
    '210': ('overcast', 'clear-day'),
    '211': ('overcast', 'clear-day'),
    '212': ('overcast', 'rain'),
    '213': ('overcast', 'rain'),
    '214': ('overcast', 'rain'),
    '215': ('overcast', 'snow'),
    '216': ('overcast', 'snow'),
    '217': ('overcast', 'snow'),
    '218': ('overcast', 'sleet'),
    '219': ('overcast', 'thunderstorms-rain'),
    '220': ('overcast-rain', null),
    '221': ('overcast-rain', null),
    '222': ('overcast', 'rain'),
    '223': ('overcast-day', null),
    '224': ('overcast', 'rain'),
    '225': ('overcast', 'rain'),
    '226': ('overcast', 'rain'),
    '228': ('overcast', 'snow'),
    '229': ('overcast', 'snow'),
    '230': ('overcast', 'snow'),
    '231': ('overcast', null),
    '240': ('thunderstorms-rain', null),
    '250': ('overcast-snow', null),
    '260': ('sleet', null),
    '270': ('sleet', null),
    '281': ('overcast', 'sleet'),
    '300': ('rain', null),
    '301': ('partly-cloudy-day-rain', null),
    '302': ('overcast-rain', null),
    '303': ('sleet', null),
    '304': ('sleet', null),
    '306': ('rain', null),
    '308': ('rain', null),
    '309': ('sleet', null),
    '311': ('rain', 'clear-day'),
    '313': ('rain', 'overcast'),
    '314': ('rain', 'snow'),
    '315': ('rain', 'snow'),
    '316': ('sleet', 'clear-day'),
    '317': ('sleet', 'overcast'),
    '320': ('rain', 'clear-day'),
    '321': ('rain', 'overcast'),
    '322': ('sleet', null),
    '323': ('rain', 'clear-day'),
    '324': ('rain', 'clear-day'),
    '325': ('rain', 'clear-day'),
    '326': ('rain', 'snow'),
    '327': ('rain', 'snow'),
    '328': ('rain', null),
    '329': ('sleet', null),
    '340': ('sleet', null),
    '350': ('thunderstorms-rain', null),
    '361': ('sleet', 'clear-day'),
    '371': ('sleet', 'overcast'),
    '400': ('snow', null),
    '401': ('partly-cloudy-day-snow', null),
    '402': ('overcast-snow', null),
    '403': ('sleet', null),
    '405': ('snow', null),
    '406': ('snow', null),
    '407': ('snow', null),
    '409': ('sleet', null),
    '411': ('snow', 'clear-day'),
    '413': ('snow', 'overcast'),
    '414': ('snow', 'rain'),
    '420': ('snow', 'clear-day'),
    '421': ('snow', 'overcast'),
    '422': ('snow', 'rain'),
    '423': ('snow', 'rain'),
    '425': ('snow', null),
    '426': ('snow', 'sleet'),
    '427': ('sleet', null),
    '450': ('snow', null),
  };
  final e = table[code];
  return e == null ? null : (main: e.$1, then: e.$2);
}

class PointWeather {
  const PointWeather(
      {this.steps = const [],
      this.wind,
      this.amedas,
      this.baseUtc,
      this.week,
      this.pops = const {}});

  /// 区域の降水確率（6時間ごとの枠の開始 instant → %）
  final Map<DateTime, int> pops;

  /// 3時間の列 [t] が属する 6 時間枠の降水確率。気象庁の降水確率は 6 時間枠
  /// （0-6 / 6-12 / 12-18 / 18-24 時）の区域値しか無いので、枠内の 2 列に同じ値を出す
  static int? popAt(Map<DateTime, int> pops, DateTime t) {
    for (final e in pops.entries) {
      final d = t.difference(e.key);
      if (!d.isNegative && d < const Duration(hours: 6)) return e.value;
    }
    return null;
  }
  final WeekForecast? week;

  /// 点の予報（無ければ空）
  final List<PointStep> steps;
  final AreaWind? wind;
  final AmedasNow? amedas;
  final DateTime? baseUtc;

  bool get hasPoint => steps.isNotEmpty;

  /// 表に出す気温が代表地点（区域）のものか
  bool get tempIsRepresentative => !hasPoint && (wind?.repTemps.isNotEmpty ?? false);

  bool get isEmpty =>
      steps.isEmpty &&
      (wind == null || wind!.steps.isEmpty) &&
      amedas == null &&
      (week == null || week!.days.isEmpty);

  /// 表の列。枠の終わりが [now] より後のものだけ（過ぎた枠は出さない）
  List<PointColumn> columns(DateTime now, {int limit = 16}) {
    final byTime = <DateTime, PointColumn>{};
    final windBy = {for (final w in wind?.steps ?? const <WindStep>[]) w.validUtc: w};
    final rep = wind?.repTemps ?? const <DateTime, int>{};
    for (final s in steps) {
      final w = windBy[s.validUtc];
      byTime[s.validUtc] = PointColumn(
        validUtc: s.validUtc,
        weather: s.weather == 0 ? null : s.weather,
        weatherCode: weatherCodeOfW(s.weather) ?? w?.weatherCode,
        temp: s.temp,
        rain: s.rain,
        snow: s.snow,
        wind: w,
        pop: popAt(pops, s.validUtc),
      );
    }
    if (!hasPoint) {
      final times = {...windBy.keys, ...rep.keys};
      for (final t in times) {
        byTime[t] = PointColumn(
            validUtc: t,
            temp: rep[t],
            wind: windBy[t],
            weatherCode: windBy[t]?.weatherCode,
            pop: popAt(pops, t));
      }
    }
    final keys = byTime.keys
        .where((t) => t.add(const Duration(hours: 3)).isAfter(now))
        .toList()
      ..sort();
    return [for (final k in keys.take(limit)) byTime[k]!];
  }
}

class PointWeathers {
  PointWeathers._();

  static const _wdistBase = '${apiBaseUrl}wdist/';
  static const _vpfdBase = 'https://www.jma.go.jp/bosai/jmatile/data/wdist/VPFD/';
  static const _amedasBase = 'https://www.jma.go.jp/bosai/amedas';
  static const _ttl = Duration(minutes: 30);
  static const maxAmedasKm = 30.0;
  static const _ua = {
    'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)',
  };

  /// 風向 1〜16 の日本語名（アメダスの windDirection と同じ並び）
  static const dirNames = [
    '北北東', '北東', '東北東', '東', '東南東', '南東', '南南東', '南',
    '南南西', '南西', '西南西', '西', '西北西', '北西', '北北西', '北',
  ];

  /// 国内の座標を持つカメラか
  static bool appliesTo(Camera c) =>
      !c.isWorld &&
      c.hasLocation &&
      c.lat! >= 20 &&
      c.lat! <= 46.5 &&
      c.lng! >= 122 &&
      c.lng! <= 154;

  // ---- 純粋関数 -------------------------------------------------------

  /// ブロックの南西隅（偶数度）
  static (int, int) blockOrigin(double lat, double lng) =>
      ((lat / 2).floor() * 2, (lng / 2).floor() * 2);

  static String blockName(double lat, double lng) {
    final o = blockOrigin(lat, lng);
    return '${o.$1}_${o.$2}';
  }

  /// 格子番号（i=緯度方向 0.05 度刻み・j=経度方向 0.0625 度刻み）
  static (int, int) gridIndex(double lat, double lng, int lat0, int lng0) => (
        ((lat - lat0 - 0.025) / 0.05).round(),
        ((lng - lng0 - 0.03125) / 0.0625).round(),
      );

  /// "20261101120000"（UTC）→ instant
  static DateTime? parseUtc(Object? s) {
    if (s is! String || s.length < 14) return null;
    final y = int.tryParse(s.substring(0, 4)),
        mo = int.tryParse(s.substring(4, 6)),
        d = int.tryParse(s.substring(6, 8)),
        h = int.tryParse(s.substring(8, 10)),
        mi = int.tryParse(s.substring(10, 12)),
        se = int.tryParse(s.substring(12, 14));
    if (y == null || mo == null || d == null || h == null || mi == null || se == null) {
      return null;
    }
    return DateTime.utc(y, mo, d, h, mi, se);
  }

  /// ブロック JSON から (lat,lng) に最も近い格子点（本体→8近傍の近い順）を選ぶ
  static Map<String, dynamic>? findPoint(Object? block, double lat, double lng) {
    if (block is! Map) return null;
    final lat0 = block['lat0'], lng0 = block['lng0'];
    final pts = block['points'];
    if (lat0 is! num || lng0 is! num || pts is! List) return null;
    final (i, j) = gridIndex(lat, lng, lat0.toInt(), lng0.toInt());
    Map<String, dynamic>? best;
    var bestD = double.infinity;
    for (final p in pts) {
      if (p is! Map) continue;
      final pi = p['i'], pj = p['j'];
      if (pi is! int || pj is! int) continue;
      if ((pi - i).abs() > 1 || (pj - j).abs() > 1) continue;
      // 同点なら 0、斜めなら大きい。実距離の近い順
      final d = distanceMeters(lat, lng, lat0 + 0.025 + 0.05 * pi, lng0 + 0.03125 + 0.0625 * pj);
      if (d < bestD) {
        bestD = d;
        best = Map<String, dynamic>.from(p);
      }
    }
    return best;
  }

  static int? _int(Object? v) => v is num ? v.round() : null;

  /// ブロック JSON → 点の予報の枠。点が無ければ空
  static List<PointStep> parsePoint(Object? block, double lat, double lng) {
    final p = findPoint(block, lat, lng);
    if (p == null || block is! Map) return const [];
    final times = block['validtimes'];
    if (times is! List) return const [];
    List<dynamic> arr(String k) => p[k] is List ? p[k] as List : const [];
    final t = arr('t'), w = arr('w'), r = arr('r'), s = arr('s');
    final out = <PointStep>[];
    for (var k = 0; k < times.length; k++) {
      final at = parseUtc(times[k]);
      if (at == null) continue;
      out.add(PointStep(
        validUtc: at,
        temp: k < t.length ? _int(t[k]) : null,
        weather: k < w.length ? (_int(w[k]) ?? 0).clamp(0, 5) : 0,
        rain: k < r.length ? (_int(r[k]) ?? 0).clamp(0, 5) : 0,
        snow: k < s.length ? (_int(s[k]) ?? 0).clamp(0, 3) : 0,
      ));
    }
    return out;
  }

  /// 風向の日本語名 → 1〜16、静穏 → 0、不明 → null
  static int? dirFromName(Object? name) {
    if (name is! String) return null;
    final n = name.trim();
    if (n == '静穏') return 0;
    final i = dirNames.indexOf(n);
    return i < 0 ? null : i + 1;
  }

  /// "3 5" → (3, 5)、"4" → (4, 4)、空 → null
  static (int, int)? parseRange(Object? range) {
    if (range is! String) return null;
    final m = RegExp(r'\d+').allMatches(range).map((e) => int.parse(e[0]!)).toList();
    if (m.isEmpty) return null;
    return (m.first, m.length > 1 ? m[1] : m.first);
  }

  /// VPFD の JSON → 区域の風・代表地点の気温
  static AreaWind? parseVpfd(Object? json,
      {required String areaName, required String areaEnName}) {
    if (json is! Map) return null;
    DateTime? at(Object? d) {
      if (d is! Map || d['dateTime'] is! String) return null;
      final t = DateTime.tryParse(d['dateTime'] as String);
      return t?.toUtc();
    }

    final ats = json['areaTimeSeries'];
    final steps = <WindStep>[];
    if (ats is Map && ats['timeDefines'] is List && ats['wind'] is List) {
      final defs = ats['timeDefines'] as List, winds = ats['wind'] as List;
      final wx = ats['weather'] is List ? ats['weather'] as List : const [];
      for (var k = 0; k < defs.length && k < winds.length; k++) {
        final t = at(defs[k]);
        final w = winds[k];
        if (t == null || w is! Map) continue;
        final range = parseRange(w['range']);
        final speed = _int(w['speed']);
        steps.add(WindStep(
          validUtc: t,
          dir: dirFromName(w['direction']),
          minMs: range?.$1 ?? speed,
          maxMs: range?.$2 ?? speed,
          weatherCode: k < wx.length ? weatherCodeOfText(wx[k]) : null,
        ));
      }
    }
    final pts = json['pointTimeSeries'];
    final reps = <DateTime, int>{};
    String? repName, repEn;
    if (pts is Map) {
      repName = pts['pointNameJP'] as String?;
      repEn = pts['pointNameEN'] as String?;
      final defs = pts['timeDefines'], temps = pts['temperature'];
      if (defs is List && temps is List) {
        for (var k = 0; k < defs.length && k < temps.length; k++) {
          final t = at(defs[k]);
          final v = _int(temps[k]);
          if (t != null && v != null) reps[t] = v;
        }
      }
    }
    if (steps.isEmpty && reps.isEmpty) return null;
    final rep = json['reportDateTime'];
    return AreaWind(
      areaName: areaName,
      areaEnName: areaEnName,
      steps: steps,
      repName: repName,
      repEnName: repEn,
      repTemps: reps,
      reportedAt: rep is String ? DateTime.tryParse(rep)?.toUtc() : null,
    );
  }

  static String? _code(Object? v) => v is String && v.isNotEmpty ? v : null;
  static int? _intStr(Object? v) => v is String ? int.tryParse(v) : _int(v);

  /// 府県予報 JSON の週間（[1]）。[class10] は一次細分区域コード
  static WeekForecast? parseWeek(List<dynamic> json, String class10, DateTime nowJst) {
    if (json.length < 2 || json[1] is! Map) return null;
    final series = (json[1] as Map)['timeSeries'];
    if (series is! List || series.length < 2) return null;
    final s0 = series[0] as Map, s1 = series[1] as Map;
    final areas0 = (s0['areas'] as List?) ?? const [];
    if (areas0.isEmpty) return null;
    var idx = areas0.indexWhere((a) => (a as Map)['area']?['code'] == class10);
    final found = idx >= 0;
    if (!found) idx = 0;
    final a0 = areas0[idx] as Map;
    final areas1 = (s1['areas'] as List?) ?? const [];
    if (areas1.isEmpty) return null;
    // 代表地点: 週間の区域数と同じなら同じ並び、そうでなければ先頭
    final a1 = (found && areas1.length == areas0.length ? areas1[idx] : areas1.first) as Map;
    final defs = (s0['timeDefines'] as List?) ?? const [];
    final codes = (a0['weatherCodes'] as List?) ?? const [];
    final pops = (a0['pops'] as List?) ?? const [];
    final defs1 = ((s1['timeDefines'] as List?) ?? const []).cast<String>();
    final tmax = (a1['tempsMax'] as List?) ?? const [];
    final tmin = (a1['tempsMin'] as List?) ?? const [];
    final today = startOfDay(nowJst);
    final days = <WeekDay>[];
    for (var k = 0; k < defs.length; k++) {
      final t = DateTime.tryParse('${defs[k]}');
      if (t == null) continue;
      final day = startOfDay(toJstWallClock(t));
      if (day.isBefore(today)) continue;
      var k1 = -1;
      for (var m = 0; m < defs1.length; m++) {
        final t1 = DateTime.tryParse(defs1[m]);
        if (t1 != null && startOfDay(toJstWallClock(t1)) == day) {
          k1 = m;
          break;
        }
      }
      days.add(WeekDay(
        day: day,
        code: k < codes.length ? _code(codes[k]) : null,
        pop: k < pops.length ? _intStr(pops[k]) : null,
        tempMax: k1 >= 0 && k1 < tmax.length ? _intStr(tmax[k1]) : null,
        tempMin: k1 >= 0 && k1 < tmin.length ? _intStr(tmin[k1]) : null,
      ));
    }
    if (days.isEmpty) return null;
    // 降水確率が空の日（週間の初日）は [0] の6時間ごとの確率のうち、その日（JST）に
    // 開始する枠の最大値で補う
    final p6 = parsePops(json, class10);
    for (var i = 0; i < days.length; i++) {
      if (days[i].pop != null) continue;
      int? mx;
      for (final e in p6.entries) {
        if (startOfDay(toJstWallClock(e.key)) != days[i].day) continue;
        if (mx == null || e.value > mx) mx = e.value;
      }
      if (mx != null) {
        days[i] = WeekDay(
            day: days[i].day,
            code: days[i].code,
            pop: mx,
            tempMax: days[i].tempMax,
            tempMin: days[i].tempMin);
      }
    }
    // 気温が空の日は [0] の今日明日の最高・最低（00時=最低・09時=最高）で補う
    final st = json[0] is Map ? ((json[0] as Map)['timeSeries'] as List?) : null;
    if (st != null && st.length > 2 && st[2] is Map) {
      final s2 = st[2] as Map;
      final ar = (s2['areas'] as List?) ?? const [];
      final name = (a1['area'] as Map?)?['name'];
      Map? m2;
      for (final a in ar) {
        if ((a as Map)['area']?['name'] == name) m2 = a;
      }
      m2 ??= ar.isNotEmpty ? ar.first as Map : null;
      final d2 = ((s2['timeDefines'] as List?) ?? const []).cast<String>();
      final temps = (m2?['temps'] as List?) ?? const [];
      for (var i = 0; i < days.length; i++) {
        int? mx = days[i].tempMax, mn = days[i].tempMin;
        for (var m = 0; m < d2.length && m < temps.length; m++) {
          final t = DateTime.tryParse(d2[m]);
          if (t == null) continue;
          final w = toJstWallClock(t);
          if (startOfDay(w) != days[i].day) continue;
          final v = _intStr(temps[m]);
          if (w.hour < 9) {
            mn ??= v;
          } else {
            mx ??= v;
          }
        }
        if (mx != days[i].tempMax || mn != days[i].tempMin) {
          days[i] = WeekDay(
              day: days[i].day,
              code: days[i].code,
              pop: days[i].pop,
              tempMax: mx,
              tempMin: mn);
        }
      }
    }
    return WeekForecast(
        areaName: (a0['area'] as Map?)?['name'] as String? ?? '',
        stationName: (a1['area'] as Map?)?['name'] as String?,
        days: days);
  }

  /// 府県予報 [0] timeSeries[1] の6時間降水確率（枠の開始 instant → %）
  static Map<DateTime, int> parsePops(List<dynamic> json, String class10) {
    if (json.isEmpty || json[0] is! Map) return const {};
    final series = (json[0] as Map)['timeSeries'];
    if (series is! List || series.length < 2 || series[1] is! Map) return const {};
    final s = series[1] as Map;
    final areas = (s['areas'] as List?) ?? const [];
    Map? a;
    for (final x in areas) {
      if ((x as Map)['area']?['code'] == class10) a = x;
    }
    a ??= areas.isNotEmpty ? areas.first as Map : null;
    final pops = (a?['pops'] as List?) ?? const [];
    final defs = (s['timeDefines'] as List?) ?? const [];
    final out = <DateTime, int>{};
    for (var k = 0; k < defs.length && k < pops.length; k++) {
      final t = DateTime.tryParse('${defs[k]}');
      final v = _intStr(pops[k]);
      if (t != null && v != null) out[t.toUtc()] = v;
    }
    return out;
  }

  /// アメダスの観測点表（assets/data/amedas_stations.json）
  static List<AmedasStation> parseStations(Object? json) {
    if (json is! Map || json['stations'] is! List) return const [];
    final out = <AmedasStation>[];
    for (final e in json['stations'] as List) {
      if (e is! Map) continue;
      final id = e['id'], n = e['n'], lat = e['lat'], lng = e['lng'];
      if (id is! String || n is! String || lat is! num || lng is! num) continue;
      out.add(AmedasStation(id, n, lat.toDouble(), lng.toDouble()));
    }
    return out;
  }

  /// 品質フラグ 0 の値だけ。`[値, フラグ]`
  static num? good(Object? v) {
    if (v is! List || v.length < 2) return null;
    final x = v[0], f = v[1];
    return x is num && f == 0 ? x : null;
  }

  /// 10分値 JSON と観測点表から最寄り（[maxKm] 以内）の実況を選ぶ。
  /// 気温のある観測点を優先し、無ければ何か取れる最寄りを使う
  static AmedasNow? nearestAmedas(
    Object? map,
    List<AmedasStation> stations,
    double lat,
    double lng,
    DateTime observedAt, {
    double maxKm = maxAmedasKm,
  }) {
    if (map is! Map) return null;
    final cand = <(AmedasStation, double)>[];
    for (final s in stations) {
      final d = distanceMeters(lat, lng, s.lat, s.lng) / 1000;
      if (d <= maxKm) cand.add((s, d));
    }
    cand.sort((a, b) => a.$2.compareTo(b.$2));
    AmedasNow? fallback;
    for (final (s, d) in cand) {
      final v = map[s.id];
      if (v is! Map) continue;
      final temp = good(v['temp']);
      final hum = good(v['humidity']);
      final wind = good(v['wind']);
      final dir = good(v['windDirection']);
      final pre = good(v['precipitation1h']);
      final o = AmedasNow(
        name: s.name,
        distanceKm: (d * 10).round() / 10,
        at: observedAt,
        temp: temp?.toDouble(),
        humidity: hum?.round(),
        windMs: wind?.toDouble(),
        windDir: wind == null ? null : dir?.round(),
        precip1h: pre?.toDouble(),
      );
      if (!o.hasAny) continue;
      if (temp != null) return o;
      fallback ??= o;
    }
    return fallback;
  }

  // ---- 取得 ----------------------------------------------------------

  static (DateTime, Map<String, dynamic>)? _index;
  static final Map<String, (String, Object?)> _blocks = {};
  static final Map<String, (DateTime, Object?)> _vpfd = {};
  static (String, Object?)? _amedasMap;
  static Future<List<AmedasStation>>? _stations;

  /// 復帰時に控えを捨てる
  static void invalidate() {
    WaveForecasts.invalidate();
    _index = null;
    _blocks.clear();
    _vpfd.clear();
    _amedasMap = null;
  }

  static void resetCache() {
    invalidate();
    _stations = null;
  }

  /// テスト用に観測点表を差し替える
  static void setStations(List<AmedasStation>? s) =>
      _stations = s == null ? null : Future.value(s);

  static Future<List<AmedasStation>> _loadStations() =>
      _stations ??= () async {
        try {
          final raw = await rootBundle.loadString('assets/data/amedas_stations.json');
          return parseStations(jsonDecode(raw));
        } catch (_) {
          return const <AmedasStation>[];
        }
      }();

  static Future<Object?> _getJson(String url, http.Client cl) async {
    final r = await cl.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<String?> _getText(String url, http.Client cl) async {
    final r = await cl.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 15));
    return r.statusCode == 200 ? utf8.decode(r.bodyBytes) : null;
  }

  static Future<List<PointStep>> _fetchPoint(Camera c, http.Client cl) async {
    var idx = _index;
    if (idx == null || DateTime.now().difference(idx.$1) >= _ttl) {
      final j = await _getJson('${_wdistBase}index.json', cl);
      if (j is! Map<String, dynamic>) return const [];
      idx = (DateTime.now(), j);
      _index = idx;
    }
    final index = idx.$2;
    final name = blockName(c.lat!, c.lng!);
    final blocks = index['blocks'];
    if (blocks is List && !blocks.contains(name)) return const [];
    final base = '${index['basetime']}';
    var b = _blocks[name];
    if (b == null || b.$1 != base) {
      final j = await _getJson('$_wdistBase$name.json', cl);
      if (j == null) return const [];
      b = (base, j);
      _blocks[name] = b;
    }
    return parsePoint(b.$2, c.lat!, c.lng!);
  }

  static Future<AreaWind?> _fetchWind(Camera c, http.Client cl) async {
    try {
      await JmaAreaNames.load();
    } catch (_) {
      return null;
    }
    final area = JmaAreaNames.class10Of(c.municipality);
    if (area == null) return null;
    var cached = _vpfd[area.code];
    if (cached == null || DateTime.now().difference(cached.$1) >= _ttl) {
      final j = await _getJson('$_vpfdBase${area.code}.json', cl);
      if (j == null) return null;
      cached = (DateTime.now(), j);
      _vpfd[area.code] = cached;
    }
    // 「東部」だけでは分かりにくいので府県名を前に付ける（週間の注記と同じ語）
    final off = JmaAreaNames.officeNameOf(area.office);
    return parseVpfd(cached.$2,
        areaName: off == null ? area.name : '${off.name} ${area.name}',
        areaEnName: off == null || area.enName.isEmpty
            ? area.enName
            : '${off.enName.isEmpty ? off.name : off.enName} ${area.enName}');
  }

  static Future<(WeekForecast?, Map<DateTime, int>)> _fetchWeek(
      Camera c, http.Client cl, DateTime nowJst) async {
    try {
      await JmaAreaNames.load();
    } catch (_) {
      return (null, const <DateTime, int>{});
    }
    final area = JmaAreaNames.class10Of(c.municipality);
    if (area == null) return (null, const <DateTime, int>{});
    final json = await WaveForecasts.forecastJson(area.office, client: cl);
    if (json == null) return (null, const <DateTime, int>{});
    return (parseWeek(json, area.code, nowJst), parsePops(json, area.code));
  }

  static Future<AmedasNow?> _fetchAmedas(Camera c, http.Client cl) async {
    final stations = await _loadStations();
    if (stations.isEmpty) return null;
    final lt = await _getText('$_amedasBase/data/latest_time.txt', cl);
    if (lt == null) return null;
    // "+09:00" 付き。DateTime.parse は UTC に直すので壁時計へ戻してファイル名を組む
    final at = toJstWallClock(DateTime.parse(lt.trim()));
    String two(int v) => v.toString().padLeft(2, '0');
    final key = '${at.year}${two(at.month)}${two(at.day)}${two(at.hour)}${two(at.minute)}00';
    var m = _amedasMap;
    if (m == null || m.$1 != key) {
      final j = await _getJson('$_amedasBase/data/map/$key.json', cl);
      if (j == null) return null;
      m = (key, j);
      _amedasMap = m;
    }
    return nearestAmedas(m.$2, stations, c.lat!, c.lng!, at);
  }

  /// 3つの情報源を並列に取る。1つでも取れれば返し、全部無ければ null
  static Future<PointWeather?> fetch(Camera camera, {http.Client? client}) async {
    if (!appliesTo(camera)) return null;
    final cl = client ?? http.Client();
    try {
      Future<Object?> safe(Future<Object?> f) => f.then<Object?>((v) => v).catchError((_) => null);
      final r = await Future.wait<Object?>([
        safe(_fetchPoint(camera, cl)),
        safe(_fetchWind(camera, cl)),
        safe(_fetchAmedas(camera, cl)),
        safe(_fetchWeek(camera, cl, jstNow())),
      ]);
      final wk = r[3] as (WeekForecast?, Map<DateTime, int>)?;
      final steps = (r[0] as List<PointStep>?) ?? const <PointStep>[];
      final pw = PointWeather(
        steps: steps,
        wind: r[1] as AreaWind?,
        amedas: r[2] as AmedasNow?,
        baseUtc: parseUtc(_index?.$2['basetime']),
        week: wk?.$1,
        pops: wk?.$2 ?? const {},
      );
      return pw.isEmpty ? null : pw;
    } finally {
      if (client == null) cl.close();
    }
  }
}

class AmedasStation {
  const AmedasStation(this.id, this.name, this.lat, this.lng);
  final String id;
  final String name;
  final double lat;
  final double lng;
}
