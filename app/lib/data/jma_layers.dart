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
  const NowcastTime(this.basetime, this.validtime,
      {this.product = 'nowc', this.member = 'none'});
  final String basetime;
  final String validtime;

  /// 'nowc' = 高解像度降水ナウキャスト(5分刻み・1時間先まで)
  /// 'rasrf' = 降水短時間予報(1時間刻み・6時間先まで。値は1時間雨量)
  final String product;
  final String member;

  bool get isForecast => basetime != validtime;
  bool get isHourly => product == 'rasrf';

  /// flutter_map の urlTemplate
  String get tileTemplate => switch (product) {
        'rasrf' =>
          'https://www.jma.go.jp/bosai/jmatile/data/rasrf/$basetime/$member/$validtime/surf/rasrf/{z}/{x}/{y}.png',
        'rasrf24h' =>
          'https://www.jma.go.jp/bosai/jmatile/data/rasrf/$basetime/$member/$validtime/surf/rasrf24h/{z}/{x}/{y}.png',
        _ =>
          'https://www.jma.go.jp/bosai/jmatile/data/nowc/$basetime/none/$validtime/surf/hrpns/{z}/{x}/{y}.png',
      };

  /// 気象庁の時刻表記はUTC。日本時間(JST=UTC+9)に直す
  DateTime get validAtJst => DateTime.utc(
        int.parse(validtime.substring(0, 4)),
        int.parse(validtime.substring(4, 6)),
        int.parse(validtime.substring(6, 8)),
        int.parse(validtime.substring(8, 10)),
        int.parse(validtime.substring(10, 12)),
      ).add(const Duration(hours: 9));

  /// 表示用 HH:MM（JST）
  String get label {
    final d = validAtJst;
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
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

  /// 雨雲の時間軸: 過去3時間の実況(5分刻み) + 1時間先まで(5分刻み) + 6時間先まで(1時間刻み)。
  /// 古い順に並べて返す。取得失敗は空リスト
  static Future<List<NowcastTime>> fetchNowcastTimes() async {
    try {
      final rs = await Future.wait([
        http.get(Uri.parse('https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_N1.json'), headers: _ua),
        http.get(Uri.parse('https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_N2.json'), headers: _ua),
        http.get(Uri.parse('https://www.jma.go.jp/bosai/jmatile/data/rasrf/targetTimes.json'), headers: _ua),
      ]).timeout(const Duration(seconds: 15));
      final byValid = <String, NowcastTime>{};
      void put(NowcastTime n) {
        final cur = byValid[n.validtime];
        // 同じ時刻は 実況 > ナウキャスト予測 > 短時間予報 の優先
        if (cur == null || (cur.isForecast && !n.isForecast) || (cur.isHourly && !n.isHourly)) {
          byValid[n.validtime] = n;
        }
      }
      for (final r in rs.take(2)) {
        if (r.statusCode != 200) continue;
        for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>()) {
          put(NowcastTime(e['basetime'] as String, e['validtime'] as String));
        }
      }
      // 短時間予報: 最新basetimeの予測のうち6時間先まで(immed=1〜6時間先)
      final r3 = rs[2];
      if (r3.statusCode == 200) {
        final fc = (jsonDecode(r3.body) as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e['basetime'] != e['validtime'] && e['member'] == 'immed')
            .toList();
        if (fc.isNotEmpty) {
          final latestBase = fc.map((e) => e['basetime'] as String).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
          for (final e in fc.where((e) => e['basetime'] == latestBase)) {
            final n = NowcastTime(e['basetime'] as String, e['validtime'] as String,
                product: 'rasrf', member: e['member'] as String? ?? 'immed');
            if (!byValid.containsKey(n.validtime)) byValid[n.validtime] = n;
          }
        }
      }
      final list = byValid.values.toList()..sort((a, b) => a.validtime.compareTo(b.validtime));
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// 最新の実況（後方互換）
  static Future<NowcastTime?> fetchLatestNowcast() async {
    final list = await fetchNowcastTimes();
    for (final n in list.reversed) {
      if (!n.isForecast) return n;
    }
    return list.isEmpty ? null : list.last;
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

  /// 24時間降水量の面タイル（気象庁 解析雨量の積算。実況・1時間ごと更新）
  static Future<NowcastTime?> fetchRain24hTile() async {
    try {
      final r = await http
          .get(Uri.parse('https://www.jma.go.jp/bosai/jmatile/data/rasrf/targetTimes.json'), headers: _ua)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final obs = (jsonDecode(r.body) as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['basetime'] == e['validtime'] &&
              (e['elements'] as List).contains('rasrf24h'))
          .toList()
        ..sort((a, b) => (b['basetime'] as String).compareTo(a['basetime'] as String));
      if (obs.isEmpty) return null;
      final e = obs.first;
      return NowcastTime(e['basetime'] as String, e['validtime'] as String,
          product: 'rasrf24h', member: e['member'] as String? ?? 'immed');
    } catch (_) {
      return null;
    }
  }

  /// 24時間降水量の凡例色。タイル(rasrf24h)の塗りと同じ気象庁の
  /// 24時間積算用しきい値（1時間雨量の配色とは段階が異なる）。
  /// 実タイルの画素色をアメダス観測値と照合して確認済み(2026-08-29)
  static const rain24hScale = <(double, Color, String)>[
    (0.5, Color(0xFFF2F2FF), '〜50'),
    (50, Color(0xFFA0D2FF), '50'),
    (80, Color(0xFF218CFF), '80'),
    (100, Color(0xFF0041FF), '100'),
    (150, Color(0xFFFAF500), '150'),
    (200, Color(0xFFFF9900), '200'),
    (250, Color(0xFFFF2800), '250'),
    (300, Color(0xFFB40068), '300mm〜'),
  ];

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
      // latest_time.txt は "+09:00" 付きで、DateTime.parse はUTCに変換して返す。
      // ファイル名はJST時刻なので明示的に+9hして組み立てる（端末のTZに依存しない）
      final ts = DateTime.parse(lt.body.trim()).toUtc().add(const Duration(hours: 9));
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

  /// 24時間雨量の観測値ラベル色。rain24hScale と同じ段階でタイルの塗りに合わせる
  static Color rainColor(double mm) {
    for (final s in rain24hScale.reversed) {
      if (mm >= s.$1) return s.$2;
    }
    return rain24hScale.first.$2;
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
