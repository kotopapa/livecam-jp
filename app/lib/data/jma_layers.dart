import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../util/jst.dart';

/// 地図レイヤー用の気象庁公開データ（無料・認証不要。SPEC C2）。
/// - 雨雲レーダー: 高解像度降水ナウキャストのタイル（5分更新）
/// - 震源: 地震リスト（約30日分）
/// - 24時間雨量: アメダス全国JSON（10分更新）
/// いずれもアプリが直接取得し、当方サーバーには保存しない。
/// 気象庁サイト内部の公開ファイルのため、構造変更時は静かに失敗させる。

/// 地図に重ねるレイヤー（排他）。risk* は気象庁のキキクル（危険度分布。RiskLayers）、
/// hazard* は国土地理院の重ねるハザードマップ（hazard_layers.dart）、
/// shelters は指定緊急避難場所（shelter_layers.dart）
enum MapLayerKind {
  none,
  rainRadar,
  quakes,
  rain24h,
  riskLand,
  riskInund,
  riskFlood,
  hazardFlood,
  hazardLandslide,
  hazardTsunami,
  hazardHightide,
  shelters,
  facilities,
}

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

  /// 気象庁の時刻表記はUTC。その**絶対時刻**（UTCフラグ付き）
  DateTime get validAt => jmaTimeToUtc(validtime);

  /// 日本時間(JST=UTC+9)の**壁時計**（素のDateTime）。表示・日付判定にだけ使う。
  /// 絶対時刻ではないので `DateTime.now()` と引き算しないこと
  DateTime get validAtJst => jmaTimeToJst(validtime);

  /// 表示用 HH:MM（JST）
  String get label => jmaTimeLabel(validtime);
}

/// 気象庁タイルの時刻表記（UTCの yyyyMMddHHmmss）を**絶対時刻**（UTCフラグ付き）に直す。
/// 時刻の引き算・大小比較にはこちらを使う
DateTime jmaTimeToUtc(String t) => DateTime.utc(
      int.parse(t.substring(0, 4)),
      int.parse(t.substring(4, 6)),
      int.parse(t.substring(6, 8)),
      int.parse(t.substring(8, 10)),
      int.parse(t.substring(10, 12)),
    );

/// 気象庁タイルの時刻表記（UTC）を日本時間(JST=UTC+9)の**壁時計**（素のDateTime）に直す。
/// 端末のタイムゾーンに依存しない。year/hour 等がJSTの値になるだけで絶対時刻では
/// ないため、`DateTime.now()` や UTC由来の値と `difference` してはいけない
/// （引き算したいときは [jmaTimeToUtc] を使う）
DateTime jmaTimeToJst(String t) => toJstWallClock(jmaTimeToUtc(t));

/// 表示用 HH:MM（JST）
String jmaTimeLabel(String t) {
  final d = jmaTimeToJst(t);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// キキクル（危険度分布）の時刻。targetTimes.json は10分刻みで過去約6時間分が並び、
/// すべて basetime == validtime の実況（予測のエントリは無い）。最新3件だけ member が
/// immed0/immed1/immed2 で、それ以前は none。member はエントリの値をそのまま
/// URLに入れないと404になる（実測 2026-08-31）
class RiskTime {
  const RiskTime(this.basetime, this.validtime, this.member);
  final String basetime;
  final String validtime;
  final String member;

  /// 絶対時刻（UTCフラグ付き）。引き算・大小比較用
  DateTime get validAt => jmaTimeToUtc(validtime);

  /// JSTの壁時計（素のDateTime）。表示用
  DateTime get validAtJst => jmaTimeToJst(validtime);
  String get label => jmaTimeLabel(validtime);

  /// flutter_map の urlTemplate（kind が risk* 以外なら空文字）
  String tileTemplate(MapLayerKind kind) {
    final el = RiskLayers.element(kind);
    if (el.isEmpty) return '';
    return '${RiskLayers.tileBase}/$basetime/$member/$validtime/surf/$el/{z}/{x}/{y}.png';
  }
}

/// 気象庁「キキクル（危険度分布）」のタイル（無料・認証不要。SPEC C2）。
/// 大雨で「今どこが危ないか」を1kmメッシュ／河川区間ごとに示す実況。10分更新。
/// 出典：気象庁ホームページ https://www.jma.go.jp/bosai/risk/
class RiskLayers {
  static const tileBase = 'https://www.jma.go.jp/bosai/jmatile/data/risk';
  static const timesUrl = '$tileBase/targetTimes.json';

  /// 気象庁自身の表示範囲（risk.properties の imageType land/inund/flood の minZoom/maxZoom）。
  /// 範囲外・データ無しは404（透明タイルは200で334バイト）
  static const minZoom = 4;
  static const maxZoom = 14;

  static bool isRisk(MapLayerKind k) => switch (k) {
        MapLayerKind.riskLand ||
        MapLayerKind.riskInund ||
        MapLayerKind.riskFlood =>
          true,
        _ => false,
      };

  /// レイヤー種別 → タイルURLの element
  static String element(MapLayerKind k) => switch (k) {
        MapLayerKind.riskLand => 'land',
        MapLayerKind.riskInund => 'inund',
        MapLayerKind.riskFlood => 'flood',
        _ => '',
      };

  /// レイヤー種別 → 表示名の l10n キー（表示名の解決は `lib/l10n/l10n.dart` の
  /// `riskLayerTitleOf()` / `riskLayerSubtitleOf()`）
  static String titleKey(MapLayerKind k) => switch (k) {
        MapLayerKind.riskLand => 'land',
        MapLayerKind.riskInund => 'inund',
        MapLayerKind.riskFlood => 'flood',
        _ => '',
      };

  /// 危険度の配色（低→高）。気象庁の4段階＋「今後の情報等に留意」。
  /// 根拠（2026-08-31採取）:
  /// (a) 実タイルの画素 …… land の実データ入りタイル
  ///     .../risk/20260831034000/immed0/20260831034000/surf/land/6/56/25.png は
  ///     8色パレットPNGで PLTE = ffffff,ffffff,ffffff,ffffff,f2e700,ff2800,aa00aa,0c000c
  ///     （tRNS = 00,00,00,00,ff,ff,ff,ff ＝ 前半4色は透明）
  /// (b) 気象庁公式凡例SVG …… https://www.jma.go.jp/bosai/risk/images/legend_jp_normal_land.svg
  ///     （inund/flood も同じ値）に
  ///     rgb(242,231,000)=注意【警戒レベル２相当】/ rgb(255,040,000)=警戒【３相当】/
  ///     rgb(170,000,170)=危険【４相当】/ rgb(012,000,012)=災害切迫【５相当】、
  ///     最下段は白（land・inund）＝「今後の情報等に留意」
  /// (c) 洪水キキクルだけ最下段が rgb(060,255,255)=#3CFFFF（河川を線で描くため白では見えない）。
  ///     legend_jp_flood_risk.svg の実値
  /// ※「うす紫」は2022年6月の改正で廃止済み。現行は上記4段階
  /// 第2要素は表示名ではなく l10n キー（`riskLevelLabelOf()` で解決する）
  static const _levels = <(Color, String)>[
    (Color(0xFFF2E700), 'caution'),
    (Color(0xFFFF2800), 'warning'),
    (Color(0xFFAA00AA), 'danger'),
    (Color(0xFF0C000C), 'critical'),
  ];

  /// 「今後の情報等に留意」の色。土砂・浸水は白（タイル上は透明）、洪水は水色の線
  static Color baseColor(MapLayerKind k) => k == MapLayerKind.riskFlood
      ? const Color(0xFF3CFFFF)
      : const Color(0xFFFFFFFF);

  /// 凡例の5段階（低→高）
  static List<(Color, String)> scale(MapLayerKind k) =>
      [(baseColor(k), 'watch'), ..._levels];

  /// 出典表記は翻訳しない
  static const attribution = JmaLayers.attribution;
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
  /// 震度速報のみの段階では null（表示対象外）
  final LatLng? pos;
}

class RainPoint {
  const RainPoint({required this.name, required this.pos, required this.mm24h});
  final String name;
  final LatLng pos;
  final double mm24h;
}

class JmaLayers {
  /// 出典表記は翻訳しない（SPEC C5）。気象庁由来のレイヤー共通
  static const attribution = '出典：気象庁';

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

  /// キキクルの時刻一覧（古い順）。実況のみ（basetime == validtime）。取得失敗は空リスト
  static Future<List<RiskTime>> fetchRiskTimes() async {
    try {
      final r = await http
          .get(Uri.parse(RiskLayers.timesUrl), headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return const [];
      final list = (jsonDecode(r.body) as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['basetime'] == e['validtime'])
          .map((e) => RiskTime(e['basetime'] as String, e['validtime'] as String,
              e['member'] as String? ?? 'none'))
          .toList()
        ..sort((a, b) => a.validtime.compareTo(b.validtime));
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// キキクルの最新実況
  static Future<RiskTime?> fetchLatestRisk() async {
    final list = await fetchRiskTimes();
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
      return mergeQuakeReports(
          (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map<String, dynamic>>(),
          since: since);
    } catch (_) {
      return const [];
    }
  }

  /// cod("+36.0+140.1-70000/")を緯度経度に変換。「顕著な地震の震源要素更新」報は
  /// 度分形式("+3559.9+14005.7")で入るため、範囲外の値は度分として解釈する
  static LatLng? parseCod(String cod) {
    final m = _codRe.firstMatch(cod);
    if (m == null) return null;
    double? conv(String v, double limit) {
      final d = double.tryParse(v);
      if (d == null) return null;
      if (d.abs() <= limit) return d;
      final sign = d < 0 ? -1 : 1;
      final abs = d.abs();
      final deg = (abs / 100).floor();
      final min = abs - deg * 100;
      final out = sign * (deg + min / 60);
      return out.abs() <= limit ? out : null;
    }
    final lat = conv(m.group(1)!, 90);
    final lng = conv(m.group(2)!, 180);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static int _intensityRank(String maxi) => switch (maxi) {
        '1' => 1, '2' => 2, '3' => 3, '4' => 4, '5-' => 5, '5+' => 6, '6-' => 7, '6+' => 8, '7' => 9, _ => 0,
      };

  /// list.json は同一地震(eid)が震度速報(震源・M空)・震源に関する情報(震度空)・
  /// 震源震度情報などで複数並ぶ。eidごとに各項目の埋まっている値を合成し、
  /// 最大震度は報の中で最も大きいものを採る
  static List<QuakePoint> mergeQuakeReports(List<Map<String, dynamic>> entries,
      {required DateTime since}) {
    final byEid = <String, QuakePoint>{};
    for (final e in entries) {
      final at = DateTime.tryParse(e['at'] as String? ?? '');
      if (at == null || at.isBefore(since)) continue;
      final pos = parseCod(e['cod'] as String? ?? '');
      final eid = e['eid']?.toString() ?? '';
      if (eid.isEmpty && pos == null) continue;
      final place = (e['anm'] as String?) ?? '';
      final mag = (e['mag'] as String?) ?? '';
      final maxi = (e['maxi'] as String?) ?? '';
      final key = eid.isEmpty ? '${e['cod']}' : eid;
      final cur = byEid[key];
      if (cur == null) {
        // 座標のない震度速報だけの段階は pos=null で保留し、後続の報で補う
        byEid[key] = QuakePoint(at: at, place: place, magnitude: mag, maxIntensity: maxi, pos: pos);
        continue;
      }
      byEid[key] = QuakePoint(
        at: cur.at,
        place: cur.place.isNotEmpty ? cur.place : place,
        magnitude: cur.magnitude.isNotEmpty ? cur.magnitude : mag,
        maxIntensity: _intensityRank(maxi) > _intensityRank(cur.maxIntensity) ? maxi : cur.maxIntensity,
        pos: cur.pos ?? pos,
      );
    }
    final out = byEid.values.where((q) => q.pos != null).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return out;
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
