import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../models/camera.dart';
import '../util/geo.dart';
import '../util/prefectures.dart';
import 'detail_screen.dart';

/// 気象庁の公開JSONから直近の地震を表示し、震源周辺のカメラへ誘導する。
/// 無料・認証不要のエンドポイントのみ使用（SPEC C2）。取得はこの画面を
/// 開いたときだけ（ポーリングしない）。
class BosaiScreen extends StatefulWidget {
  const BosaiScreen({super.key, required this.app});

  static const quakeListUrl =
      'https://www.jma.go.jp/bosai/quake/data/list.json';
  static const tsunamiListUrl =
      'https://www.jma.go.jp/bosai/tsunami/data/list.json';
  // 旧 /data/warning/map.json は2026-05で更新停止。r8系が現行
  static const warningMapUrl =
      'https://www.jma.go.jp/bosai/warning/data/r8/map.json';

  final AppState app;

  @override
  State<BosaiScreen> createState() => _BosaiScreenState();
}

class _Quake {
  const _Quake({
    required this.place,
    required this.magnitude,
    required this.maxIntensity,
    required this.at,
    required this.lat,
    required this.lng,
    this.isTsunami = false,
  });

  final String place;
  final String magnitude;
  final String maxIntensity;
  final DateTime at;
  final double lat;
  final double lng;
  final bool isTsunami;
}

/// 気象警報コード → 表示名
const _warningNames = {
  '02': '暴風雪警報', '03': '大雨警報', '04': '洪水警報', '05': '暴風警報',
  '06': '大雪警報', '07': '波浪警報', '08': '高潮警報', '09': '土砂災害警報',
  // 2026-05-28の新体系で追加された「危険警報」(警戒レベル4相当。コード=警報+40)
  '43': '大雨危険警報', '44': '洪水危険警報', '48': '高潮危険警報',
  '49': '土砂災害危険警報',
  '32': '暴風雪特別警報', '33': '大雨特別警報', '34': '洪水特別警報',
  '35': '暴風特別警報', '36': '大雪特別警報', '37': '波浪特別警報',
  '38': '高潮特別警報', '39': '土砂災害特別警報',
};

/// 警報名 → 表示色（特別=赤 / 危険警報=紫(レベル4) / 警報=オレンジ）
Color warningLevelColor(String name) {
  if (name.contains('特別')) return const Color(0xFFD93025);
  if (name.contains('危険警報')) return const Color(0xFF9334E6);
  return const Color(0xFFF29900);
}

/// 並び順ランク（特別→危険→警報）
int warningLevelRank(String name) {
  if (name.contains('特別')) return 0;
  if (name.contains('危険警報')) return 1;
  return 2;
}

/// 注意報コード → 表示名（折りたたみ表示用）
const _advisoryNames = {
  '10': '大雨注意報', '12': '大雪注意報', '13': '風雪注意報', '14': '雷注意報',
  '15': '強風注意報', '16': '波浪注意報', '17': '融雪注意報', '18': '洪水注意報',
  '19': '高潮注意報', '20': '濃霧注意報', '21': '乾燥注意報', '22': 'なだれ注意報',
  '23': '低温注意報', '24': '霜注意報', '25': '着氷注意報', '26': '着雪注意報',
  // 2026-05-28新体系で追加（土砂災害系が大雨から独立した）
  '29': '土砂災害注意報',
};

class _BosaiScreenState extends State<BosaiScreen> {
  List<_Quake>? _quakes;
  String? _error;
  DateTime? _fetchedAt;
  // 都道府県コード → 発表中の警報名セット（特別警報を先頭に）
  Map<String, List<String>>? _warnings;

  /// 都道府県→警報を発表中の官署コード（市区町村単位の詳細取得に使う）
  Map<String, Set<String>> _warningOffices = {};

  /// 都道府県→注意報を発表中の官署コード
  Map<String, Set<String>> _advisoryOffices = {};

  // 都道府県コード → 発表中の注意報名セット（警報がない県の参考表示）
  Map<String, List<String>>? _advisories;
  String? _warningError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWarnings();
  }

  /// class10区域コード → 親官署コード（市区町村詳細ファイル名の解決用）。
  /// 「先頭3桁+000」の推定は北海道(014010→014100)や鹿児島(460010→460100)で
  /// 外れて404になるため、気象庁のarea.jsonから正しい対応を引く
  static Map<String, String>? _class10OfficeCache;

  static Future<Map<String, String>> _loadClass10Offices() async {
    if (_class10OfficeCache != null) return _class10OfficeCache!;
    final resp = await http
        .get(Uri.parse('https://www.jma.go.jp/bosai/common/const/area.json'))
        .timeout(const Duration(seconds: 20));
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final c10 = data['class10s'] as Map<String, dynamic>? ?? const {};
    _class10OfficeCache = {
      for (final e in c10.entries)
        e.key: ((e.value as Map<String, dynamic>)['parent'] as String? ?? '')
    };
    return _class10OfficeCache!;
  }

  Future<void> _loadWarnings() async {
    setState(() {
      _warnings = null;
      _warningError = null;
    });
    Map<String, String> class10Office = const {};
    try {
      class10Office = await _loadClass10Offices();
    } catch (_) {
      // 取れなくても従来の推定(先頭3桁+000)で続行する
    }
    try {
      final resp = await http.get(
        Uri.parse('${BosaiScreen.warningMapUrl}'
            '?_=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      // r8形式: 発表報のログ配列。官署は気象警報(VPWW55)と土砂災害(VPWW56)等を
      // 別々の報として同時刻に出すため、官署×報種別(dataTypeCode)ごとに
      // 最新報を採用して合算する（官署単位だと土砂災害の報が落ちる）
      final reports = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final latestByProduct = <String, Map<String, dynamic>>{};
      for (final rep in reports.cast<Map<String, dynamic>>()) {
        final office = rep['publishingOffice'] as String? ?? '';
        final type = rep['dataTypeCode'] as String? ?? '';
        final dt = rep['reportDatetime'] as String? ?? '';
        final key = '$office/$type';
        final cur = latestByProduct[key];
        if (cur == null || dt.compareTo(cur['reportDatetime'] as String? ?? '') > 0) {
          latestByProduct[key] = rep;
        }
      }
      final byPref = <String, Set<String>>{};
      final advByPref = <String, Set<String>>{};
      final officesByPref = <String, Set<String>>{};
      final advOfficesByPref = <String, Set<String>>{};
      for (final rep in latestByProduct.values) {
        final warning = rep['warning'] as Map<String, dynamic>? ?? const {};
        for (final area in (warning['class10Items'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          final code = area['areaCode'] as String? ?? '';
          if (code.length < 6) continue;
          final pref = code.substring(0, 2);
          if (!prefectureNames.containsKey(pref)) continue;
          for (final w in (area['kinds'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final status = w['status'] as String? ?? '';
            if (status == '解除' || status.contains('なし')) continue;
            final wc = w['code'] as String? ?? '';
            final name = _warningNames[wc];
            if (name != null) {
              byPref.putIfAbsent(pref, () => {}).add(name);
              // 市区町村単位の詳細ファイルは官署コード単位（class10の先頭3桁+000）
              officesByPref
                  .putIfAbsent(pref, () => {})
                  .add(class10Office[code] ?? '${code.substring(0, 3)}000');
            } else {
              final adv = _advisoryNames[wc];
              if (adv != null) {
                advByPref.putIfAbsent(pref, () => {}).add(adv);
                advOfficesByPref
                    .putIfAbsent(pref, () => {})
                    .add(class10Office[code] ?? '${code.substring(0, 3)}000');
              }
            }
          }
        }
      }
      final result = <String, List<String>>{};
      for (final e in byPref.entries) {
        final list = e.value.toList()
          ..sort((a, b) {
            final ae = warningLevelRank(a);
            final be = warningLevelRank(b);
            return ae != be ? ae.compareTo(be) : a.compareTo(b);
          });
        result[e.key] = list;
      }
      final advResult = <String, List<String>>{};
      for (final e in advByPref.entries) {
        advResult[e.key] = e.value.toList()..sort();
      }
      if (mounted) {
        setState(() {
          _warnings = result;
          _advisories = advResult;
          _warningOffices = officesByPref;
          _advisoryOffices = advOfficesByPref;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _warningError = '取得に失敗しました');
    }
  }

  // "+37.5+137.2-10000/" 形式の震源座標をパースする
  static final _codRe = RegExp(r'^([+-][\d.]+)([+-][\d.]+)');

  Future<void> _load() async {
    setState(() {
      _quakes = null;
      _error = null;
    });
    try {
      final resp = await http.get(
        Uri.parse('${BosaiScreen.quakeListUrl}'
            '?_=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final since = DateTime.now().subtract(const Duration(hours: 72));
      final seen = <String>{};
      final quakes = <_Quake>[];
      // 津波予報・警報（直近72時間）を先に取り込む
      try {
        final tresp = await http
            .get(Uri.parse(BosaiScreen.tsunamiListUrl))
            .timeout(const Duration(seconds: 15));
        if (tresp.statusCode == 200) {
          for (final e in (jsonDecode(utf8.decode(tresp.bodyBytes)) as List)
              .cast<Map<String, dynamic>>()) {
            final at = DateTime.tryParse(e['at'] as String? ?? '');
            final cod = _codRe.firstMatch(e['cod'] as String? ?? '');
            final eid = 'tsunami-${e['eid']}';
            if (at == null || cod == null || at.isBefore(since)) continue;
            if (!seen.add(eid)) continue;
            quakes.add(_Quake(
              place: '【${e['ttl'] ?? '津波情報'}】${e['anm'] ?? ''}',
              magnitude: e['mag'] as String? ?? '-',
              maxIntensity: '津波',
              at: at,
              lat: double.parse(cod.group(1)!),
              lng: double.parse(cod.group(2)!),
              isTsunami: true,
            ));
          }
        }
      } catch (_) {
        // 津波リストが取れなくても地震は表示する
      }
      for (final e in list.cast<Map<String, dynamic>>()) {
        final at = DateTime.tryParse(e['at'] as String? ?? '');
        final cod = _codRe.firstMatch(e['cod'] as String? ?? '');
        final maxi = e['maxi'] as String? ?? '';
        final eid = e['eid'] as String? ?? '';
        if (at == null || cod == null || maxi.isEmpty) continue;
        if (at.isBefore(since)) continue;
        if (!seen.add(eid)) continue; // 同一地震の続報をまとめる
        quakes.add(_Quake(
          place: e['anm'] as String? ?? '不明',
          magnitude: e['mag'] as String? ?? '-',
          maxIntensity: maxi,
          at: at,
          lat: double.parse(cod.group(1)!),
          lng: double.parse(cod.group(2)!),
        ));
      }
      // 震度の大きい順 → 新しい順
      // 新しい順（津波情報のみ最優先）。震度の大小はバッジ色で判別できる
      quakes.sort((a, b) {
        if (a.isTsunami != b.isTsunami) return a.isTsunami ? -1 : 1;
        return b.at.compareTo(a.at);
      });
      if (mounted) {
        setState(() {
          _quakes = quakes.take(30).toList();
          _fetchedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '取得に失敗しました（$e）');
    }
  }

  static int _intensityRank(String maxi) => switch (maxi) {
        '7' => 9,
        '6+' => 8,
        '6-' => 7,
        '5+' => 6,
        '5-' => 5,
        _ => int.tryParse(maxi) ?? 0,
      };

  static Color _intensityColor(String maxi) {
    if (maxi == '津波') return const Color(0xFF1E6FD9);
    return switch (_intensityRank(maxi)) {
      >= 5 => const Color(0xFFD93025),
      >= 3 => const Color(0xFFF29900),
      _ => const Color(0xFF616E7C),
    };
  }

  String _when(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return '${d.inMinutes}分前';
    if (d.inHours < 24) return '${d.inHours}時間前';
    return '${at.month}月${at.day}日 ${at.hour}時頃';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('災害速報'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _load();
                  _loadWarnings();
                }),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: '地震・津波'),
            Tab(text: '気象警報'),
          ]),
        ),
        body: TabBarView(children: [
          _buildQuakeTab(),
          _buildWarningTab(),
        ]),
      ),
    );
  }

  Widget _buildQuakeTab() {
    return _error != null
          ? Center(child: Text(_error!))
          : _quakes == null
              ? const Center(child: CircularProgressIndicator())
              : _quakes!.isEmpty
                  ? const Center(child: Text('直近72時間の地震情報はありません'))
                  : ListView.separated(
                      itemCount: _quakes!.length + 1,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          final t = _fetchedAt;
                          final ts = t == null
                              ? ''
                              : '（${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}時点・新しい順）';
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '出典：気象庁 地震情報（直近72時間）$ts。タップすると震源周辺のライブカメラ一覧を表示します。',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                          );
                        }
                        final q = _quakes![i - 1];
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _intensityColor(q.maxIntensity),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                q.isTsunami ? '津波' : '震度\n${q.maxIntensity}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2)),
                          ),
                          title: Text(q.place),
                          subtitle: Text(
                              'M${q.magnitude} · ${_when(q.at)}',
                              style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NearbyCamerasScreen(
                                app: widget.app,
                                title: '${q.place}周辺のカメラ',
                                lat: q.lat,
                                lng: q.lng,
                              ),
                            ),
                          ),
                        );
                      },
                    );
  }

  Widget _buildWarningTab() {
    if (_warningError != null) return Center(child: Text(_warningError!));
    if (_warnings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_warnings!.isEmpty && (_advisories?.isEmpty ?? true)) {
      return const Center(child: Text('現在、発表中の警報・注意報はありません'));
    }
    final prefs = _warnings!.keys.toList()
      ..sort((a, b) {
        final ae =
            _warnings![a]!.map(warningLevelRank).reduce((x, y) => x < y ? x : y);
        final be =
            _warnings![b]!.map(warningLevelRank).reduce((x, y) => x < y ? x : y);
        return ae != be ? ae.compareTo(be) : a.compareTo(b);
      });
    final advPrefs = (_advisories ?? const {}).keys.toList()..sort();
    return ListView.separated(
      itemCount: prefs.length + 2,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _warnings!.isEmpty
                  ? '出典：気象庁。現在、警報・特別警報の発表はありません。注意報のみの地域は下の一覧から確認できます。'
                  : '出典：気象庁 気象警報・注意報。タップするとその都道府県のカメラ一覧を表示します。',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          );
        }
        if (i == prefs.length + 1) {
          if (advPrefs.isEmpty) return const SizedBox.shrink();
          return ExpansionTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF616E7C)),
            title: Text('注意報が発表中の地域（${advPrefs.length}都道府県）'),
            children: [
              for (final pref in advPrefs)
                ListTile(
                  dense: true,
                  title: Text(prefectureNames[pref] ?? pref),
                  subtitle: Text(_advisories![pref]!.join('・'),
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WarningMuniListScreen(
                          app: widget.app,
                          pref: pref,
                          title: '${prefectureNames[pref] ?? pref}の注意報発表地域',
                          offices: _advisoryOffices[pref] ?? const {},
                          codeNames: _advisoryNames))),
                ),
            ],
          );
        }
        final pref = prefs[i - 1];
        final names = _warnings![pref]!;
        final topColor = names
            .map(warningLevelColor)
            .firstWhere((_) => true, orElse: () => const Color(0xFFF29900));
        final emergency = names.any((w) => w.contains('特別'));
        return ListTile(
          leading: Icon(
            emergency ? Icons.warning : Icons.warning_amber_outlined,
            color: topColor,
          ),
          title: Text(prefectureNames[pref] ?? pref),
          subtitle: Wrap(spacing: 4, runSpacing: 2, children: [
            for (final n in names)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: warningLevelColor(n),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(n,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => WarningMuniListScreen(
                  app: widget.app,
                  pref: pref,
                  title: '${prefectureNames[pref] ?? pref}の警報発表地域',
                  offices: _warningOffices[pref] ?? const {}))),
        );
      },
    );
  }
}

/// 都道府県内のカメラ一覧（警報発表時の導線）。
/// [warningOffices] を渡すと気象庁の官署別詳細（class20=市区町村単位）を
/// 取得し、警報発表中の市区町村のカメラだけに絞り込む。
/// 警報発表中の市区町村一覧（都道府県タップ後の中間画面）。
/// 気象庁の官署別詳細(class20Items)とarea.jsonの市区町村名を突き合わせ、
/// 市区町村をタップするとそのエリアのカメラ一覧を開く。
class WarningMuniListScreen extends StatefulWidget {
  const WarningMuniListScreen(
      {super.key,
      required this.app,
      required this.pref,
      required this.title,
      required this.offices,
      this.codeNames = _warningNames});

  final AppState app;
  final String pref;
  final String title;
  final Set<String> offices;

  /// 対象コード→表示名（警報 or 注意報。既定は警報）
  final Map<String, String> codeNames;

  @override
  State<WarningMuniListScreen> createState() => _WarningMuniListScreenState();
}

class _WarningMuniListScreenState extends State<WarningMuniListScreen> {
  /// (市区町村コード5桁, 市区町村名, 警報名リスト)。null=読込中
  List<(String, String, List<String>)>? _munis;
  bool _failed = false;

  /// class20コード(7桁)→市区町村名。気象庁area.jsonから一度だけ取得
  static Map<String, String>? _class20Names;

  static Future<Map<String, String>> _loadClass20Names() async {
    if (_class20Names != null) return _class20Names!;
    final resp = await http
        .get(Uri.parse('https://www.jma.go.jp/bosai/common/const/area.json'))
        .timeout(const Duration(seconds: 20));
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final c20 = data['class20s'] as Map<String, dynamic>? ?? const {};
    _class20Names = {
      for (final e in c20.entries)
        e.key: ((e.value as Map<String, dynamic>)['name'] as String? ?? '')
    };
    return _class20Names!;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 「横浜市北部」→「横浜市」のように政令市の分割区域名を市名に丸める
  static String _cityName(String name) =>
      name.replaceFirst(RegExp(r'(北東|北西|南東|南西|中央|北|南|東|西)部$'), '');

  Future<void> _load() async {
    // 市区町村コード5桁単位で統合する（政令市の「横浜市北部/南部」等は
    // カメラが市単位で共通のため1行にまとめ、警報名は区域横断で合算する）
    final byMuni = <String, (String, Set<String>)>{};
    var anyOk = false;
    Map<String, String> names = const {};
    try {
      names = await _loadClass20Names();
    } catch (_) {}
    for (final office in widget.offices) {
      try {
        final resp = await http.get(
          Uri.parse('https://www.jma.go.jp/bosai/warning/data/r8/'
              '$office.json?_=${DateTime.now().millisecondsSinceEpoch}'),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) continue;
        final reports = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
        // 気象警報(VPWW55)と土砂災害(VPWW56)等は別報のため、
        // 報種別ごとに最新報を採用して合算する
        final latestByType = <String, Map<String, dynamic>>{};
        for (final rep in reports.cast<Map<String, dynamic>>()) {
          final type = rep['dataTypeCode'] as String? ?? '';
          final dt = rep['reportDatetime'] as String? ?? '';
          final cur = latestByType[type];
          if (cur == null ||
              dt.compareTo(cur['reportDatetime'] as String? ?? '') > 0) {
            latestByType[type] = rep;
          }
        }
        for (final latest in latestByType.values) {
          final warning =
              latest['warning'] as Map<String, dynamic>? ?? const {};
          for (final area in (warning['class20Items'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final code = area['areaCode'] as String? ?? '';
            if (code.length < 5 || !code.startsWith(widget.pref)) continue;
            for (final w in (area['kinds'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
              final status = w['status'] as String? ?? '';
              if (status == '解除' || status.contains('なし')) continue;
              final wname = widget.codeNames[w['code'] as String? ?? ''];
              if (wname == null) continue;
              final muni = code.substring(0, 5);
              final entry = byMuni[muni] ??
                  (_cityName(names[code] ?? '市区町村 $muni'), <String>{});
              entry.$2.add(wname);
              byMuni[muni] = entry;
            }
          }
        }
        anyOk = true;
      } catch (_) {
        // この官署の詳細が取れなくても他の官署は処理を続ける
      }
    }
    if (!mounted) return;
    final sortedCodes = byMuni.keys.toList()..sort();
    final list = [
      for (final muni in sortedCodes)
        (muni, byMuni[muni]!.$1, byMuni[muni]!.$2.toList()..sort())
    ]..sort((a, b) {
        final ae = a.$3.isEmpty
            ? 9
            : a.$3.map(warningLevelRank).reduce((x, y) => x < y ? x : y);
        final be = b.$3.isEmpty
            ? 9
            : b.$3.map(warningLevelRank).reduce((x, y) => x < y ? x : y);
        return ae.compareTo(be);
      });
    setState(() {
      _munis = list;
      _failed = !anyOk;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _munis == null
        ? const Center(child: CircularProgressIndicator())
        : (_munis!.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      _failed
                          ? '発表エリアの詳細を取得できませんでした'
                          : '現在、発表中の市区町村はありません',
                      textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                itemCount: _munis!.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('出典：気象庁。タップするとその市区町村のカメラ一覧を表示します',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                    );
                  }
                  final (muni, name, warns) = _munis![i - 1];
                  final camCount = widget.app.repository
                      .displayableCameras()
                      .where((c) =>
                          c.prefecture == widget.pref &&
                          c.municipality == muni)
                      .length;
                  final emergency = warns.any((w) => w.contains('特別'));
                  Color chipColor(String w) => w.contains('注意報')
                      ? const Color(0xFFF9A825)
                      : warningLevelColor(w);
                  final iconColor = warns.isEmpty
                      ? const Color(0xFFF29900)
                      : chipColor((warns.toList()
                            ..sort((a, b) => warningLevelRank(a)
                                .compareTo(warningLevelRank(b))))
                          .first);
                  return ListTile(
                    leading: Icon(
                      emergency
                          ? Icons.warning
                          : Icons.warning_amber_outlined,
                      color: iconColor,
                    ),
                    title: Row(children: [
                      Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      Text(
                        camCount > 0 ? 'カメラ$camCount台' : 'カメラなし',
                        style: TextStyle(
                            fontSize: 12,
                            color: camCount > 0
                                ? Colors.grey[700]
                                : Colors.grey[500]),
                      ),
                    ]),
                    subtitle: Wrap(spacing: 4, runSpacing: 2, children: [
                      for (final w in warns)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: chipColor(w),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(w,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                    ]),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PrefCamerasScreen(
                            app: widget.app,
                            pref: widget.pref,
                            title: '$nameのカメラ（警報発表中）',
                            municipality: muni))),
                  );
                },
              ));
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: body,
    );
  }
}

/// 災害速報の一覧共通: 上部固定の「LIVEのみ」トグルバー
class _LiveOnlyBar extends StatelessWidget {
  const _LiveOnlyBar(
      {required this.liveOnly,
      required this.liveCount,
      required this.onChanged});

  final bool liveOnly;
  final int liveCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            FilterChip(
              label: Text('LIVEのみ（$liveCount）'),
              selected: liveOnly,
              onSelected: onChanged,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class PrefCamerasScreen extends StatefulWidget {
  const PrefCamerasScreen(
      {super.key,
      required this.app,
      required this.pref,
      required this.title,
      this.municipality});

  final AppState app;
  final String pref;
  final String title;

  /// 指定時はこの市区町村コード(5桁)のカメラのみ表示する
  final String? municipality;

  @override
  State<PrefCamerasScreen> createState() => _PrefCamerasScreenState();
}

class _PrefCamerasScreenState extends State<PrefCamerasScreen> {
  bool _liveOnly = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final all = app.repository
        .displayableCameras()
        .where((c) => c.prefecture == widget.pref)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    List<Camera> base = all;
    String? note;
    if (widget.municipality != null) {
      final matched =
          all.where((c) => c.inMunicipality(widget.municipality!)).toList();
      if (matched.isNotEmpty) {
        base = matched;
      } else {
        note = 'この市区町村に対応するカメラがないため、都道府県内の全カメラを表示しています';
      }
    }
    final liveCount = base.where((c) => c.isLiveVideo).length;
    final cams = _liveOnly ? base.where((c) => c.isLiveVideo).toList() : base;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: base.isEmpty
          ? const Center(child: Text('この都道府県のカメラがありません'))
          : Column(children: [
              _LiveOnlyBar(
                liveOnly: _liveOnly,
                liveCount: liveCount,
                onChanged: (v) => setState(() => _liveOnly = v),
              ),
              Expanded(
                  child: cams.isEmpty
                      ? const Center(child: Text('LIVE配信のカメラがありません'))
                      : _buildList(cams, note)),
            ]),
    );
  }

  Widget _buildList(List<Camera> cams, String? note) {
    final app = widget.app;
    return ListView.builder(
              itemCount: cams.length + (note != null ? 1 : 0),
              itemBuilder: (context, i) {
                if (note != null && i == 0) {
                  return Container(
                    color: const Color(0xFFFFF4E5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(note,
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange[900])),
                  );
                }
                final camera = cams[note != null ? i - 1 : i];
                final url = app.imageUrlFor(camera);
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72,
                      height: 48,
                      child: url != null
                          ? Image.network(url,
                              fit: BoxFit.cover,
                              // 72×48表示への縮小デコード(メモリ削減)
                              cacheWidth: 216,
                              errorBuilder: (_, _, _) =>
                                  Container(color: Colors.grey[300]))
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.videocam,
                                  size: 20, color: Colors.grey[600])),
                    ),
                  ),
                  title: Text(camera.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [if (camera.isVideo) 'LIVE', camera.operator].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          DetailScreen(camera: camera, app: app))),
                );
              },
            );
  }
}

/// 指定地点の周辺カメラ一覧（距離順・50km以内）。
class NearbyCamerasScreen extends StatefulWidget {
  const NearbyCamerasScreen({
    super.key,
    required this.app,
    required this.title,
    required this.lat,
    required this.lng,
  });

  final AppState app;
  final String title;
  final double lat;
  final double lng;

  @override
  State<NearbyCamerasScreen> createState() => _NearbyCamerasScreenState();
}

class _NearbyCamerasScreenState extends State<NearbyCamerasScreen> {
  bool _liveOnly = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final base = <(Camera, double)>[];
    for (final c in app.repository.displayableCameras()) {
      if (!c.hasLocation) continue;
      final d = distanceMeters(widget.lat, widget.lng, c.lat!, c.lng!);
      if (d <= 50000) base.add((c, d));
    }
    base.sort((a, b) => a.$2.compareTo(b.$2));
    final liveCount = base.where((e) => e.$1.isLiveVideo).length;
    final cams =
        _liveOnly ? base.where((e) => e.$1.isLiveVideo).toList() : base;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: base.isEmpty
          ? const Center(child: Text('50km以内にカメラがありません'))
          : Column(children: [
              _LiveOnlyBar(
                liveOnly: _liveOnly,
                liveCount: liveCount,
                onChanged: (v) => setState(() => _liveOnly = v),
              ),
              Expanded(child: _buildList(cams)),
            ]),
    );
  }

  Widget _buildList(List<(Camera, double)> cams) {
    final app = widget.app;
    if (cams.isEmpty) {
      return const Center(child: Text('LIVE配信のカメラがありません'));
    }
    return ListView.separated(
              itemCount: cams.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final (camera, dist) = cams[i];
                final url = app.imageUrlFor(camera);
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72,
                      height: 48,
                      child: url != null
                          ? Image.network(url,
                              fit: BoxFit.cover,
                              // 72×48表示への縮小デコード(メモリ削減)
                              cacheWidth: 216,
                              errorBuilder: (_, _, _) =>
                                  Container(color: Colors.grey[300]))
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.videocam,
                                  size: 20, color: Colors.grey[600])),
                    ),
                  ),
                  title: Text(camera.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (camera.isVideo) 'LIVE',
                      '約${(dist / 1000).toStringAsFixed(dist < 10000 ? 1 : 0)}km',
                      camera.operator,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          DetailScreen(camera: camera, app: app))),
                );
              },
            );
  }
}
