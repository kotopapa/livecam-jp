import '../models/camera.dart';

/// 気象庁 地震情報 list.json の `int` 配列（市区町村別の観測震度）を扱う。
///
/// list.json は既に災害速報タブが取得しているため、この機能で
/// **追加のネットワークアクセスは発生しない**（SPEC C2 / 既存データの再利用）。
///
/// 各報のレコード例:
/// ```json
/// {"eid":"20260831032944","anm":"福島県会津","maxi":"1",
///  "int":[{"code":"07","maxi":"1","city":[{"code":"0736700","maxi":"1"}]}]}
/// ```
/// `city[].code` は7桁で、**先頭5桁が台帳の `municipality`（JIS X 0402）と一致する**
/// （実測確認: 1311100=大田区 / 0110000=札幌市 / 0736700=只見町）。

/// 市区町村ごとの観測震度
class MuniIntensity {
  const MuniIntensity({required this.code, required this.intensity, this.name});

  /// JIS X 0402 の5桁市区町村コード
  final String code;

  /// 観測震度（'1'〜'4','5-','5+','6-','6+','7'）
  final String intensity;

  /// 表示名（気象庁 area.json の class20s より。未取得なら null）
  final String? name;

  /// 都道府県コード（2桁）
  String get prefecture => code.length >= 2 ? code.substring(0, 2) : '';

  MuniIntensity withName(String? n) =>
      MuniIntensity(code: code, intensity: intensity, name: n);

  @override
  String toString() => 'MuniIntensity($code,$intensity)';
}

/// 震度の強さ順位（比較用。未知は0）
int quakeIntensityRank(String v) => switch (v) {
      '7' => 9,
      '6+' || '6強' => 8,
      '6-' || '6弱' => 7,
      '5+' || '5強' => 6,
      '5-' || '5弱' => 5,
      '4' => 4,
      '3' => 3,
      '2' => 2,
      '1' => 1,
      _ => 0,
    };

/// 震度表記を気象庁の標準形（'5-' 等）に正規化する
String normalizeIntensity(String v) => switch (v.trim()) {
      '6強' => '6+',
      '6弱' => '6-',
      '5強' => '5+',
      '5弱' => '5-',
      final s => s,
    };

/// 1報の `int` フィールド → 市区町村コード(5桁) → 震度。
/// 構造が想定と違っても落とさず、取れた分だけ返す。
Map<String, String> parseQuakeIntCities(Object? intField) {
  final out = <String, String>{};
  if (intField is! List) return out;
  for (final area in intField) {
    if (area is! Map) continue;
    final cities = area['city'];
    if (cities is! List) continue;
    for (final c in cities) {
      if (c is! Map) continue;
      final code = c['code']?.toString() ?? '';
      final maxi = normalizeIntensity(c['maxi']?.toString() ?? '');
      // 7桁コードの先頭5桁が台帳の municipality。5桁未満は捨てる
      if (code.length < 5 || quakeIntensityRank(maxi) == 0) continue;
      final muni = code.substring(0, 5);
      if (int.tryParse(muni) == null) continue;
      final cur = out[muni];
      if (cur == null || quakeIntensityRank(maxi) > quakeIntensityRank(cur)) {
        out[muni] = maxi;
      }
    }
  }
  return out;
}

/// list.json の全報 → eid → (市区町村コード5桁 → 最大震度)。
/// 同一eidの複数報（震度速報・震源震度情報・続報）は市区町村ごとに
/// 最大震度を採って合成する（JmaLayers.mergeQuakeReports と同じ考え方）。
Map<String, Map<String, String>> buildQuakeMuniIntensities(
    List<Map<String, dynamic>> entries) {
  final out = <String, Map<String, String>>{};
  for (final e in entries) {
    final eid = e['eid']?.toString() ?? '';
    if (eid.isEmpty) continue;
    final cities = parseQuakeIntCities(e['int']);
    if (cities.isEmpty) continue;
    final dst = out.putIfAbsent(eid, () => <String, String>{});
    for (final c in cities.entries) {
      final cur = dst[c.key];
      if (cur == null ||
          quakeIntensityRank(c.value) > quakeIntensityRank(cur)) {
        dst[c.key] = c.value;
      }
    }
  }
  return out;
}

/// 震度の大きい順（同震度はコード昇順）に並べる
List<MuniIntensity> sortMuniIntensities(Map<String, String> byCode) {
  final list = [
    for (final e in byCode.entries)
      MuniIntensity(code: e.key, intensity: e.value)
  ];
  list.sort((a, b) {
    final r = quakeIntensityRank(b.intensity) - quakeIntensityRank(a.intensity);
    return r != 0 ? r : a.code.compareTo(b.code);
  });
  return list;
}

/// [muni]（5桁）のカメラ台数。PrefCamerasScreen の絞り込みと同じ条件で数える
/// （都道府県一致 + Camera.inMunicipality。政令市は配下の区を含む）
int countCamerasInMunicipality(Iterable<Camera> cameras, String muni) {
  if (muni.length < 2) return 0;
  final pref = muni.substring(0, 2);
  var n = 0;
  for (final c in cameras) {
    if (c.prefecture == pref && c.inMunicipality(muni)) n++;
  }
  return n;
}

/// 市区町村コード → カメラの索引。台帳は2万件超あるため、市区町村ごとに
/// 全件走査すると大きな地震（数百市区町村）で描画が詰まる。
/// コード先頭3桁でグループ化して1回の走査で作り、以後は定数時間で引く。
/// 判定結果は [countCamerasInMunicipality] と一致する。
class MuniCameraIndex {
  MuniCameraIndex(Iterable<Camera> cameras) {
    for (final c in cameras) {
      final m = c.municipality;
      // 台帳の都道府県と食い違うコードは PrefCamerasScreen でも出ないため除く
      if (m == null || m.length < 3 || c.prefecture != m.substring(0, 2)) {
        continue;
      }
      (_byPrefix.putIfAbsent(m.substring(0, 3), () => {})
              .putIfAbsent(m, () => []))
          .add(c);
    }
  }

  final Map<String, Map<String, List<Camera>>> _byPrefix = {};

  /// [muni]（5桁）のカメラ台数（政令市コードなら配下の区を含む）
  int count(String muni) {
    if (muni.length < 3) return 0;
    final group = _byPrefix[muni.substring(0, 3)];
    if (group == null) return 0;
    var n = 0;
    for (final e in group.entries) {
      // 同一コードのカメラは判定結果が同じなので代表1台で判定する
      if (e.value.first.inMunicipality(muni)) n += e.value.length;
    }
    return n;
  }

  /// いずれかの市区町村にカメラがあるか
  bool hasAny(Iterable<MuniIntensity> munis) {
    for (final m in munis) {
      if (count(m.code) > 0) return true;
    }
    return false;
  }
}

/// 市区町村別の導線を出せるか。`int` が無い（震度速報のみ）、または
/// どの市区町村コードにもカメラが1台も無い（市町村合併等でコードがずれる）
/// 場合は false → 従来どおり震源からの距離検索にフォールバックする。
bool canUseMuniNavigation(
    Iterable<Camera> cameras, Iterable<MuniIntensity> munis) {
  if (munis.isEmpty) return false;
  return MuniCameraIndex(cameras).hasAny(munis);
}
