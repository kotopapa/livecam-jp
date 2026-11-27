import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/camera.dart';
import 'jma_area.dart';
import 'warning_levels.dart';

/// カメラの市区町村に発表中の警報・注意報（気象庁 `warning/data/r8/<官署>.json`）
class MuniWarnings {
  const MuniWarnings({required this.codes, required this.cityName, this.issuedAt});

  /// 発表中の警報・注意報コード（警戒レベルの高い順）
  final List<String> codes;
  final String cityName;

  /// 用いた報のうち最新の発表時刻（instant）
  final DateTime? issuedAt;

  /// 最上位の警戒レベル（無ければ 0）
  int get topLevel => codes.isEmpty ? 0 : warningLevelOf(codes.first);

  /// 報の配列から [municipality]（JIS 5桁）の発表中の警報・注意報を取り出す。
  /// 報種別（dataTypeCode）ごとに最新の報を採って合算する（気象警報 VPWW55 と
  /// 土砂災害 VPWW56 などが別報のため）。「解除」「なし」は除く。
  /// 区コードのカメラは区のまま、市コード（下2桁 00）で区域が無ければ同じ市の区を合算する
  ///
  /// [areaCodes]（気象庁の市町村等コード 7桁の集合）を渡すと、その区域だけを合算する
  /// （[areaCodesOf] で求める。政令市の区や「横浜市北部／南部」のような分割に対応）
  static MuniWarnings parse(List<dynamic> reports, String municipality,
      {String cityName = '', Set<String>? areaCodes}) {
    final latest = <String, Map<String, dynamic>>{};
    for (final r in reports) {
      if (r is! Map<String, dynamic>) continue;
      final type = r['dataTypeCode'] as String? ?? '';
      final dt = r['reportDatetime'] as String? ?? '';
      final cur = latest[type];
      if (cur == null || dt.compareTo(cur['reportDatetime'] as String? ?? '') > 0) {
        latest[type] = r;
      }
    }
    final exact = '${municipality}00';
    final cityPrefix = municipality.substring(0, 3);
    bool hasExact = false;
    for (final r in latest.values) {
      for (final a in _areas(r)) {
        if (a['areaCode'] == exact) hasExact = true;
      }
    }
    final useCity = !hasExact && municipality.endsWith('00');
    final byCodes = areaCodes != null && areaCodes.isNotEmpty;
    final codes = <String>{};
    DateTime? issued;
    for (final r in latest.values) {
      var used = false;
      for (final a in _areas(r)) {
        final ac = a['areaCode'] as String? ?? '';
        if (byCodes) {
          if (!areaCodes.contains(ac)) continue;
        } else if (useCity ? !ac.startsWith(cityPrefix) : ac != exact) {
          continue;
        }
        for (final k in (a['kinds'] as List? ?? const [])) {
          if (k is! Map) continue;
          final status = k['status'] as String? ?? '';
          if (status.contains('解除') || status.contains('なし')) continue;
          final code = k['code'] as String? ?? '';
          if (warningLevelOf(code) == 0) continue;
          codes.add(code);
          used = true;
        }
      }
      if (used) {
        final t = DateTime.tryParse(r['reportDatetime'] as String? ?? '');
        if (t != null && (issued == null || t.isAfter(issued))) issued = t;
      }
    }
    final sorted = codes.toList()
      ..sort((a, b) {
        final c = warningLevelOf(b).compareTo(warningLevelOf(a));
        return c != 0 ? c : a.compareTo(b);
      });
    return MuniWarnings(codes: sorted, cityName: cityName, issuedAt: issued);
  }

  static Iterable<Map<String, dynamic>> _areas(Map<String, dynamic> report) sync* {
    final w = report['warning'];
    if (w is! Map) return;
    for (final a in (w['class20Items'] as List? ?? const [])) {
      if (a is Map<String, dynamic>) yield a;
    }
  }

  /// JIS 市区町村コード（5桁）に当たる気象庁の市町村等コード（7桁）。[class20Keys] は area.json の
  /// class20 のキー。気象庁は市町村を次のどれかで持つ:
  /// - そのまま（`1310100` 千代田区）
  /// - 市町村を分割（`0920601` 日光市今市 …。どの区域かは座標から分からないので全部を合算する）
  /// - 政令市を市単位（`0110000` 札幌市）または市を分割（`1410011` 横浜市北部 …）。区コードは市へ寄せる
  static Set<String> areaCodesOf(String municipality, Iterable<String> class20Keys) {
    if (municipality.length != 5) return const {};
    final keys = class20Keys is Set<String> ? class20Keys : class20Keys.toSet();
    final exact = '${municipality}00';
    if (keys.contains(exact)) return {exact};
    final own = keys.where((k) => k.startsWith(municipality)).toSet();
    if (own.isNotEmpty) return own;
    final city = '${municipality.substring(0, 3)}00';
    if (city == municipality) return const {};
    if (keys.contains('${city}00')) return {'${city}00'};
    return keys.where((k) => k.startsWith(city)).toSet();
  }

  /// 区域名の共通部分（「横浜市北部」「横浜市南部」→「横浜市」）
  static String _commonName(Iterable<String> names) {
    final list = names.where((n) => n.isNotEmpty).toList();
    if (list.isEmpty) return '';
    var p = list.first;
    for (final n in list.skip(1)) {
      var i = 0;
      while (i < p.length && i < n.length && p[i] == n[i]) {
        i++;
      }
      p = p.substring(0, i);
    }
    final paren = p.indexOf('（');
    return paren > 0 ? p.substring(0, paren) : p;
  }

  static const _ttl = Duration(minutes: 5);
  static final Map<String, (DateTime, List<dynamic>)> _mem = {};

  static void invalidate() => _mem.clear();

  /// 発表中の警報・注意報。無ければ null（取得失敗も null）
  static Future<MuniWarnings?> fetch(Camera camera, {http.Client? client}) async {
    final muni = camera.municipality;
    if (camera.isWorld || muni == null || muni.length != 5) return null;
    final w = await fetchForMunicipality(muni, client: client);
    return w == null || w.codes.isEmpty ? null : w;
  }

  /// 市区町村（JIS 5桁）に発表中の警報・注意報。発表が無ければ codes が空、取得失敗は null。
  /// [maxAge] より新しい取得結果があれば使い回す
  static Future<MuniWarnings?> fetchForMunicipality(String muni,
      {http.Client? client, Duration maxAge = _ttl}) async {
    if (muni.length != 5) return null;
    try {
      await JmaAreaNames.load();
    } catch (_) {
      return null;
    }
    final area = JmaAreaNames.class10Of(muni);
    if (area == null) return null;
    var cached = _mem[area.office];
    if (cached == null || DateTime.now().difference(cached.$1) >= maxAge) {
      final cl = client ?? http.Client();
      try {
        final r = await cl.get(
          Uri.parse('https://www.jma.go.jp/bosai/warning/data/r8/${area.office}.json'
              '?_=${DateTime.now().millisecondsSinceEpoch}'),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) return null;
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is! List) return null;
        cached = (DateTime.now(), j);
        _mem[area.office] = cached;
      } catch (_) {
        return null;
      } finally {
        if (client == null) cl.close();
      }
    }
    final names = JmaAreaNames.class20Name;
    final codes = areaCodesOf(muni, names.keys);
    final name = _commonName(codes.map((c) => names[c] ?? ''));
    return parse(cached.$2, muni, cityName: name, areaCodes: codes);
  }
}
