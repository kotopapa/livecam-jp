import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// 地図レイヤー用の気象庁公開データ（無料・認証不要。SPEC C2）。
/// - 雨雲レーダー: 高解像度降水ナウキャストのタイル（5分更新）
/// - 震源: 地震リスト（約30日分）
/// - 24時間雨量: アメダス全国JSON（10分更新）
/// いずれもアプリが直接取得し、当方サーバーには保存しない。
/// 気象庁サイト内部の公開ファイルのため、構造変更時は静かに失敗させる。

enum MapLayerKind { none, rainRadar, quakes, rain24h }

enum QuakePeriod { day, week, month }

class NowcastTime {
  const NowcastTime(this.basetime, this.validtime);
  final String basetime;
  final String validtime;

  /// flutter_map の urlTemplate
  String get tileTemplate =>
      'https://www.jma.go.jp/bosai/jmatile/data/nowc/$basetime/none/$validtime/surf/hrpns/{z}/{x}/{y}.png';

  /// 表示用 HH:MM（JST）
  String get label =>
      '${validtime.substring(8, 10)}:${validtime.substring(10, 12)}';
}

class QuakePoint {
  const QuakePoint({
    required this.at,
    required this.place,
    required this.magnitude,
    required this.maxIntensity,
    required this.pos,
  });
  final DateTime at;
  final String place;
  final String magnitude;
  final String maxIntensity;
  final LatLng pos;
}

class RainPoint {
  const RainPoint({required this.name, required this.pos, required this.mm24h});
  final String name;
  final LatLng pos;
  final double mm24h;
}

class JmaLayers {
  static const _ua = {'User-Agent': 'LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)'};

  /// 最新の（現在時刻の）ナウキャスト時刻。JSTの実況分のみ使う
  static Future<NowcastTime?> fetchLatestNowcast() async {
    try {
      final r = await http
          .get(Uri.parse('https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_N1.json'), headers: _ua)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final list = jsonDecode(r.body) as List;
      // basetime==validtime の実況を優先（先頭が最新）
      for (final e in list.cast<Map<String, dynamic>>()) {
        if (e['basetime'] == e['validtime']) {
          return NowcastTime(e['basetime'] as String, e['validtime'] as String);
        }
      }
      final e = list.first as Map<String, dynamic>;
      return NowcastTime(e['basetime'] as String, e['validtime'] as String);
    } catch (_) {
      return null;
    }
  }

  static final _codRe = RegExp(r'^([+-][\d.]+)([+-][\d.]+)');

  /// 震源リスト（同一地震の複数報はeidで最新1件に）
  static Future<List<QuakePoint>> fetchQuakes(QuakePeriod period) async {
    try {
      final r = await http
          .get(Uri.parse('https://www.jma.go.jp/bosai/quake/data/list.json'), headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return const [];
      final since = DateTime.now().subtract(switch (period) {
        QuakePeriod.day => const Duration(hours: 24),
        QuakePeriod.week => const Duration(days: 7),
        QuakePeriod.month => const Duration(days: 30),
      });
      final byEid = <String, QuakePoint>{};
      for (final e in (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map<String, dynamic>>()) {
        final cod = e['cod'] as String? ?? '';
        final m = _codRe.firstMatch(cod);
        if (m == null) continue;
        final at = DateTime.tryParse(e['at'] as String? ?? '');
        if (at == null || at.isBefore(since)) continue;
        final eid = e['eid']?.toString() ?? cod;
        final place = (e['anm'] as String?) ?? '';
        // 震源名・Mが埋まっている報を優先
        final cur = byEid[eid];
        if (cur != null && cur.place.isNotEmpty && place.isEmpty) continue;
        byEid[eid] = QuakePoint(
          at: at,
          place: place,
          magnitude: (e['mag'] as String?) ?? '',
          maxIntensity: (e['maxi'] as String?) ?? '',
          pos: LatLng(double.parse(m.group(1)!), double.parse(m.group(2)!)),
        );
      }
      final out = byEid.values.toList()..sort((a, b) => b.at.compareTo(a.at));
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Map<String, LatLng>? _stations;

  /// アメダス24時間雨量（観測点の座標表は初回のみ取得してキャッシュ）
  static Future<List<RainPoint>> fetchRain24h() async {
    try {
      if (_stations == null) {
        final t = await http
            .get(Uri.parse('https://www.jma.go.jp/bosai/amedas/const/amedastable.json'), headers: _ua)
            .timeout(const Duration(seconds: 15));
        if (t.statusCode != 200) return const [];
        final table = jsonDecode(utf8.decode(t.bodyBytes)) as Map<String, dynamic>;
        _stations = {
          for (final e in table.entries)
            e.key: LatLng(
              (e.value['lat'][0] as num) + (e.value['lat'][1] as num) / 60,
              (e.value['lon'][0] as num) + (e.value['lon'][1] as num) / 60,
            ),
        };
        _stationNames = {for (final e in table.entries) e.key: e.value['kjName'] as String? ?? e.key};
      }
      final lt = await http
          .get(Uri.parse('https://www.jma.go.jp/bosai/amedas/data/latest_time.txt'), headers: _ua)
          .timeout(const Duration(seconds: 10));
      if (lt.statusCode != 200) return const [];
      final ts = DateTime.parse(lt.body.trim());
      String two(int v) => v.toString().padLeft(2, '0');
      final key = '${ts.year}${two(ts.month)}${two(ts.day)}${two(ts.hour)}${two(ts.minute)}00';
      final r = await http
          .get(Uri.parse('https://www.jma.go.jp/bosai/amedas/data/map/$key.json'), headers: _ua)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return const [];
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final out = <RainPoint>[];
      for (final e in data.entries) {
        final pos = _stations![e.key];
        final p = (e.value as Map<String, dynamic>)['precipitation24h'];
        if (pos == null || p is! List || p.isEmpty || p[0] == null) continue;
        final mm = (p[0] as num).toDouble();
        if (mm <= 0) continue;
        out.add(RainPoint(name: _stationNames?[e.key] ?? e.key, pos: pos, mm24h: mm));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Map<String, String>? _stationNames;

  /// 24時間雨量の色（気象庁の解析雨量配色に準拠した段階）
  static Color rainColor(double mm) {
    if (mm >= 200) return const Color(0xFFB40068);
    if (mm >= 100) return const Color(0xFFFF2800);
    if (mm >= 50) return const Color(0xFFFF9900);
    if (mm >= 30) return const Color(0xFFFAF500);
    if (mm >= 10) return const Color(0xFF0041FF);
    return const Color(0xFF218CFF);
  }

  /// 最大震度の色（気象庁の震度配色）
  static Color intensityColor(String maxi) {
    switch (maxi) {
      case '7':
        return const Color(0xFFB40068);
      case '6+':
        return const Color(0xFFA50021);
      case '6-':
        return const Color(0xFFFF2800);
      case '5+':
        return const Color(0xFFFF9900);
      case '5-':
        return const Color(0xFFFFE600);
      case '4':
        return const Color(0xFFFAE696);
      case '3':
        return const Color(0xFF0041FF);
      case '2':
        return const Color(0xFF00AAFF);
      default:
        return const Color(0xFF8E8E8E);
    }
  }
}
