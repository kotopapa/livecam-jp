import 'dart:convert';

import 'package:http/http.dart' as http;

/// 気象庁 area.json のキャッシュ（class10の親官署 / class20の市区町村名 / 階層）。
///
/// 警報の市区町村詳細・地震の市区町村別震度の表示名・波の予報の区域解決で
/// 同じファイルを使う。アプリの起動中に**1回だけ**取得して共有する
/// （機能追加でネットワークアクセスを増やさないため）。取得に失敗しても
/// 空のまま続行し、名前が引けない市区町村はコード表記にフォールバックする。
class JmaAreaNames {
  static const url = 'https://www.jma.go.jp/bosai/common/const/area.json';

  static Map<String, String> _class10Office = const {};
  static Map<String, String> _class20Name = const {};
  static Map<String, String> _class20Parent = const {};
  static Map<String, String> _class15Parent = const {};
  static Map<String, ({String name, String enName})> _class10Name = const {};
  static bool _loaded = false;
  static Future<void>? _inflight;

  static Map<String, String> get class10Office => _class10Office;
  static Map<String, String> get class20Name => _class20Name;
  static bool get isLoaded => _loaded;

  static Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _inflight ??= _fetch().whenComplete(() => _inflight = null);
  }

  static Future<void> _fetch() async {
    final resp =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    parse(jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  static Map<String, dynamic> _sec(Map<String, dynamic> d, String k) =>
      d[k] as Map<String, dynamic>? ?? const {};
  static String _str(Object? v, String k) =>
      (v as Map<String, dynamic>)[k] as String? ?? '';

  /// area.json を読み込む（テストからも使う）
  static void parse(Map<String, dynamic> data) {
    final c10 = _sec(data, 'class10s');
    final c15 = _sec(data, 'class15s');
    final c20 = _sec(data, 'class20s');
    _class10Office = {for (final e in c10.entries) e.key: _str(e.value, 'parent')};
    _class10Name = {
      for (final e in c10.entries)
        e.key: (name: _str(e.value, 'name'), enName: _str(e.value, 'enName'))
    };
    _class15Parent = {for (final e in c15.entries) e.key: _str(e.value, 'parent')};
    _class20Name = {for (final e in c20.entries) e.key: _str(e.value, 'name')};
    _class20Parent = {for (final e in c20.entries) e.key: _str(e.value, 'parent')};
    _loaded = true;
  }

  /// テスト用
  static void reset() {
    _class10Office = const {};
    _class20Name = const {};
    _class20Parent = const {};
    _class15Parent = const {};
    _class10Name = const {};
    _loaded = false;
    _inflight = null;
  }

  /// JIS市区町村コード（5桁）→ 一次細分区域（class10）。
  /// class20 のキーは 5桁＋"00"。政令市は区単位のキーなので、市コードだけのときは
  /// 先頭が同じ最初の class20 を使う。引けなければ null
  static ({String code, String office, String name, String enName})? class10Of(
      String? municipality) {
    if (municipality == null || municipality.length != 5) return null;
    var key = '${municipality}00';
    if (!_class20Parent.containsKey(key)) {
      // 区コード（例 01103）→ 市コード（01100）にも寄せる。area.json は政令市を
      // 区ごと（1410011 等）か市単位（0110000）で持つ
      final cityLevel = '${municipality.substring(0, 3)}00';
      String? found;
      for (final prefix in [municipality, cityLevel]) {
        final ks = _class20Parent.keys.where((k) => k.startsWith(prefix)).toList()..sort();
        if (ks.isNotEmpty) {
          found = ks.first;
          break;
        }
      }
      if (found == null) return null;
      key = found;
    }
    final c15 = _class20Parent[key];
    final c10 = c15 == null ? null : _class15Parent[c15];
    final info = c10 == null ? null : _class10Name[c10];
    final office = c10 == null ? null : _class10Office[c10];
    if (c10 == null || info == null || office == null || office.isEmpty) return null;
    return (code: c10, office: office, name: info.name, enName: info.enName);
  }
}
