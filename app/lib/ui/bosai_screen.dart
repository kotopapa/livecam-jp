import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../data/heat_alert.dart';
import '../data/wbgt.dart';
import '../data/jma_layers.dart';
import '../data/quake_intensity.dart';
import '../models/camera.dart';
import '../util/geo.dart';
import '../util/prefectures.dart';
import 'ad_banner.dart';
import 'detail_screen.dart';

/// 気象庁の公開JSONから直近の地震を表示し、震源周辺のカメラへ誘導する。
/// 無料・認証不要のエンドポイントのみ使用（SPEC C2）。取得はこの画面を
/// 開いたときだけ（ポーリングしない）。
class BosaiScreen extends StatefulWidget {
  const BosaiScreen({super.key, required this.app, this.visible});

  /// 親タブがこの画面を表示中かどうか（IndexedStackで常駐するため、
  /// タブ切替時と表示中の定期更新に使う）。null なら常に表示中とみなす
  final ValueListenable<bool>? visible;

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
    this.munis = const [],
  });

  final String place;
  final String magnitude;
  final String maxIntensity;
  final DateTime at;
  final double lat;
  final double lng;
  final bool isTsunami;

  /// 揺れた市区町村（震度の大きい順）。震度速報のみで `int` が無い報では空
  final List<MuniIntensity> munis;
}

/// 気象庁 area.json のキャッシュ（class10の親官署 / class20の市区町村名）。
///
/// 警報の市区町村詳細と、地震の市区町村別震度の表示名で同じファイルを使う。
/// アプリの起動中に**1回だけ**取得して両方で共有する（地震側の機能追加で
/// ネットワークアクセスを増やさないため）。取得に失敗しても空のまま続行し、
/// 名前が引けない市区町村はコード表記にフォールバックする。
class JmaAreaNames {
  static const url = 'https://www.jma.go.jp/bosai/common/const/area.json';

  static Map<String, String> _class10Office = const {};
  static Map<String, String> _class20Name = const {};
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
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final c10 = data['class10s'] as Map<String, dynamic>? ?? const {};
    final c20 = data['class20s'] as Map<String, dynamic>? ?? const {};
    _class10Office = {
      for (final e in c10.entries)
        e.key: ((e.value as Map<String, dynamic>)['parent'] as String? ?? '')
    };
    _class20Name = {
      for (final e in c20.entries)
        e.key: ((e.value as Map<String, dynamic>)['name'] as String? ?? '')
    };
    _loaded = true;
  }
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

class _BosaiScreenState extends State<BosaiScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  /// この時間より古ければタブを開いたとき・復帰時に自動で更新する
  static const _staleAfter = Duration(minutes: 2);
  /// 表示中は定期的に更新する（気象庁の更新頻度に合わせ5分）
  static const _autoRefreshEvery = Duration(minutes: 5);
  Timer? _autoRefresh;

  bool get _isVisible => widget.visible?.value ?? true;

  void _refreshIfStale() {
    final t = _fetchedAt;
    if (t == null || DateTime.now().difference(t) >= _staleAfter) {
      _load();
      _loadWarnings();
      _loadHeat();
    }
  }

  void _onVisibilityChanged() {
    if (!mounted) return;
    if (_isVisible) {
      _refreshIfStale();
      _startAutoRefresh();
    } else {
      _autoRefresh?.cancel();
      _autoRefresh = null;
    }
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(_autoRefreshEvery, (_) {
      if (mounted && _isVisible) {
        _load();
        _loadWarnings();
        _loadHeat();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンドから戻ったとき、表示中なら最新に更新する
    if (state == AppLifecycleState.resumed && _isVisible) _refreshIfStale();
  }

  /// 通知タップの要求（'bosai/quake'→地震・津波, 'bosai/warning'→気象警報）
  void _onNavigationRequest() {
    final r = widget.app.navigationRequest.value ?? '';
    if (!mounted || !r.startsWith('bosai')) return;
    if (r.endsWith('/warning')) {
      _tabs.animateTo(1);
    } else if (r.endsWith('/heat')) {
      _tabs.animateTo(2);
    } else if (r.endsWith('/quake')) {
      _tabs.animateTo(0);
    }
    // 通知経由で開いたときは最新情報に更新する
    _load();
    _loadWarnings();
    _loadHeat();
  }

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
  /// 警報の最終取得時刻（成功時のみ更新）と、取得に失敗して前回値を表示中かどうか
  DateTime? _warningsAt;
  bool _warningStale = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWarnings();
    _loadHeat();
    _tabs.addListener(_onTabChanged);
    widget.app.navigationRequest.addListener(_onNavigationRequest);
    widget.visible?.addListener(_onVisibilityChanged);
    WidgetsBinding.instance.addObserver(this);
    if (_isVisible) _startAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNavigationRequest());
  }

  @override
  void dispose() {
    widget.app.navigationRequest.removeListener(_onNavigationRequest);
    widget.visible?.removeListener(_onVisibilityChanged);
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  /// class10区域コード → 親官署コード（市区町村詳細ファイル名の解決用）。
  /// 「先頭3桁+000」の推定は北海道(014010→014100)や鹿児島(460010→460100)で
  /// 外れて404になるため、気象庁のarea.jsonから正しい対応を引く
  static Future<Map<String, String>> _loadClass10Offices() async {
    await JmaAreaNames.load();
    return JmaAreaNames.class10Office;
  }

  Future<void> _loadWarnings() async {
    // 取得中に既存の表示を消さない（消すと、失敗・低速時に「警報が無い」ように
    // 見えてしまう。2026-08-31 富山の土砂災害危険警報で実発生）
    if (mounted && _warningError != null) setState(() => _warningError = null);
    // 区域名(area.json)の取得は警報本体と並行に行う。取れなくても
    // 従来の推定(先頭3桁+000)で続行できるため、待ってから始めない
    final officeFuture = _loadClass10Offices()
        .catchError((_) => const <String, String>{});
    try {
      final resp = await _getWarningMap();
      final class10Office = await officeFuture;
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
          _warningsAt = DateTime.now();
          _warningStale = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // 前回取得できていれば、その内容を残したまま「更新できず」を知らせる
      setState(() {
        if (_warnings == null) {
          _warningError = '取得に失敗しました（引き下げてやり直せます）';
        } else {
          _warningStale = true;
        }
      });
    }
  }

  /// 警報マップの取得（キャッシュ無効化つき。1回だけ再試行する）
  Future<http.Response> _getWarningMap() async {
    Object? lastError;
    for (var i = 0; i < 2; i++) {
      try {
        final resp = await http.get(
          Uri.parse('${BosaiScreen.warningMapUrl}'
              '?_=${DateTime.now().millisecondsSinceEpoch}'),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 20));
        if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
        return resp;
      } catch (e) {
        // 待たずに1回だけ即再試行する（タイムアウト時点で十分な時間が経っており、
        // ここで待つと画面破棄後にタイマーが残る）
        lastError = e;
      }
    }
    throw Exception(lastError);
  }

  /// 環境省の熱中症警戒アラート（最新の発表回）。運用期間外・取得失敗は null
  HeatAlertReport? _heat;

  /// 当日・翌日いずれかで発表中の都道府県（重い順）
  List<HeatAlertPref> _heatPrefs = const [];

  /// 熱中症タブを開いたとき、近くの地点の暑さ指数を取りに行く
  void _onTabChanged() {
    if (_tabs.index == 2 && !_tabs.indexIsChanging) _loadWbgt();
  }

  /// 現在地に近い暑さ指数の地点（距離順）と取得結果。null は未取得
  List<(WbgtPoint, double, WbgtPointData)>? _wbgtNearby;

  /// 現在地が取れなかった（位置情報未許可・最終既知位置なし）
  bool _wbgtNoLocation = false;

  /// 地点マスタまたは全地点の取得に失敗した
  bool _wbgtFailed = false;
  bool _wbgtLoading = false;

  /// 位置情報の権限が既にあるときだけ、OSが保持する最終既知位置を返す。
  /// **ここでは新たに許可ダイアログを出さない**（地図画面の権限フローに任せる）
  static Future<(double, double)?> _lastKnownLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      if (!last.latitude.isFinite || !last.longitude.isFinite) return null;
      return (last.latitude, last.longitude);
    } catch (_) {
      return null;
    }
  }

  /// 近くの地点の暑さ指数（環境省）。運用期間外は取得しない。
  /// 地点マスタは1セッション1回＋端末キャッシュ、実況・予測は同じ正時内は
  /// 再取得しない（Wbgt側）。失敗は静かにカード内の文言で示す
  Future<void> _loadWbgt() async {
    final now = HeatAlerts.nowJst();
    if (!HeatAlerts.isInSeason(now) || _wbgtLoading) return;
    _wbgtLoading = true;
    try {
      final here = await _lastKnownLocation();
      if (!mounted) return;
      if (here == null) {
        setState(() {
          _wbgtNoLocation = true;
          _wbgtFailed = false;
        });
        return;
      }
      final master = await Wbgt.loadMaster(now: now);
      final near = Wbgt.nearest(master, here.$1, here.$2);
      if (near.isEmpty) {
        if (mounted) {
          setState(() {
            _wbgtNoLocation = false;
            _wbgtFailed = true;
          });
        }
        return;
      }
      final datas = await Future.wait(
          near.map((e) => Wbgt.fetchPoint(e.$1, now: now)));
      if (!mounted) return;
      setState(() {
        _wbgtNoLocation = false;
        _wbgtFailed = false;
        _wbgtNearby = [
          for (var i = 0; i < near.length; i++)
            (near[i].$1, near[i].$2, datas[i]),
        ];
      });
    } catch (_) {
      if (mounted && _wbgtNearby == null) {
        setState(() {
          _wbgtNoLocation = false;
          _wbgtFailed = true;
        });
      }
    } finally {
      _wbgtLoading = false;
    }
  }

  /// 熱中症警戒情報を取得する。運用期間（4/22〜10/21）外は取得もしない。
  /// 取得失敗は前回の内容を残して静かに諦める（気象警報の表示は妨げない）
  Future<void> _loadHeat() async {
    final now = HeatAlerts.nowJst();
    if (!HeatAlerts.isInSeason(now)) {
      if (mounted && (_heat != null || _heatPrefs.isNotEmpty)) {
        setState(() {
          _heat = null;
          _heatPrefs = const [];
        });
      }
      return;
    }
    // 熱中症タブを表示中なら近くの暑さ指数も同じタイミングで更新する
    if (_tabs.index == 2) unawaited(_loadWbgt());
    final report = await HeatAlerts.fetch(now: now);
    if (!mounted || report == null) return;
    final list = HeatAlerts.byPrefecture(report,
        today: DateTime(now.year, now.month, now.day),
        prefNames: prefectureNames);
    setState(() {
      _heat = report;
      _heatPrefs = list;
    });
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
      final entries = (jsonDecode(utf8.decode(resp.bodyBytes)) as List)
          .cast<Map<String, dynamic>>();
      // 市区町村別震度（int配列）。同一eidの複数報は市区町村ごとに最大震度を採る。
      // 追加のネットワークアクセスは無し（この list.json の未使用フィールド）
      final muniByEid = buildQuakeMuniIntensities(entries);
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
      for (final e in entries) {
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
          munis: sortMuniIntensities(muniByEid[eid] ?? const {}),
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
    return Scaffold(
        appBar: AppBar(
          title: const Text('災害速報'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _load();
                  _loadWarnings();
                  _loadHeat();
                }),
          ],
          bottom: TabBar(controller: _tabs, tabs: const [
            Tab(text: '地震・津波'),
            Tab(text: '気象警報'),
            Tab(text: '熱中症'),
          ]),
        ),
        body: TabBarView(controller: _tabs, children: [
          _buildQuakeTab(),
          _buildWarningTab(),
          _buildHeatTab(),
        ]),
    );
  }

  /// 地震をタップしたときの遷移。市区町村別震度があり、かつコードに
  /// 一致するカメラが1台でもあれば市区町村一覧へ。無ければ（震度速報のみ／
  /// 市町村合併等でコードがずれている）従来どおり震源周辺の距離検索へ。
  void _openQuake(BuildContext context, _Quake q) {
    final route = canUseMuniNavigation(
            widget.app.repository.displayableCameras(), q.munis)
        ? MaterialPageRoute<void>(
            builder: (_) => QuakeMuniListScreen(
              app: widget.app,
              title: '${q.place}の震度',
              place: q.place,
              munis: q.munis,
              lat: q.lat,
              lng: q.lng,
            ),
          )
        : MaterialPageRoute<void>(
            builder: (_) => NearbyCamerasScreen(
              app: widget.app,
              title: '${q.place}周辺のカメラ',
              lat: q.lat,
              lng: q.lng,
            ),
          );
    Navigator.of(context).push(route);
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
                              '出典：気象庁 地震情報（直近72時間）$ts。タップすると揺れた市区町村の'
                              'ライブカメラ一覧（市区町村別震度が無い場合は震源周辺）を表示します。',
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
                              [
                                'M${q.magnitude}',
                                _when(q.at),
                                if (q.munis.isNotEmpty) '${q.munis.length}市区町村で観測',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openQuake(context, q),
                        );
                      },
                    );
  }

  /// 最終取得時刻と、更新できなかったときの注記（前回値を表示中の目印）
  Widget? _warningFreshnessBar() {
    final t = _warningsAt;
    if (t == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    final at = t.toLocal();
    return Container(
      width: double.infinity,
      color: _warningStale ? const Color(0xFFFFF3CD) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        _warningStale
            ? '最新の情報を取得できませんでした（${two(at.hour)}:${two(at.minute)} 時点の情報を表示中）'
            : '${two(at.hour)}:${two(at.minute)} 時点',
        style: TextStyle(
            fontSize: 11,
            color: _warningStale ? const Color(0xFF8A6D3B) : Colors.grey[600]),
      ),
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
          final bar = _warningFreshnessBar();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ?bar,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                _warnings!.isEmpty
                    ? '出典：気象庁。現在、警報・特別警報の発表はありません。注意報のみの地域は下の一覧から確認できます。'
                    : '出典：気象庁 気象警報・注意報。タップするとその都道府県のカメラ一覧を表示します。',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ]);
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

  /// 熱中症警戒情報（環境省）の都道府県一覧。運用期間外・発表無しは何も出さない。
  /// 規約により「出典：環境省熱中症予防情報サイト」と参考情報である旨を必ず併記する
  /// 熱中症タブ（環境省 熱中症警戒情報）。運用期間（4/22〜10/21）外はその旨を表示
  Widget _buildHeatTab() {
    final now = HeatAlerts.nowJst();
    if (!HeatAlerts.isInSeason(now)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('熱中症警戒情報の運用期間外です（毎年4月下旬〜10月下旬に発表されます）',
              textAlign: TextAlign.center),
        ),
      );
    }
    final list = _heatPrefs;
    final at = _heat?.reportAt;
    final when = at == null
        ? ''
        : '（${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}時発表）';
    final header = Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        '${HeatAlerts.attribution}$when\n${HeatAlerts.disclaimer}。'
        '${list.isEmpty ? '' : 'タップするとその都道府県のカメラ一覧を表示します。'}',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
    );
    // 出典ヘッダの下に「近くの地点の暑さ指数」カードを置く
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [header, _buildWbgtCard(now)],
    );
    if (list.isEmpty) {
      return ListView(children: [
        top,
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('現在、熱中症警戒情報は発表されていません')),
        ),
      ]);
    }
    return ListView.separated(
      itemCount: list.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) return top;
        final p = list[i - 1];
        return ListTile(
          leading: Icon(Icons.thermostat, color: heatLevelColor(p.top)),
          title: Text(p.prefName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(spacing: 4, runSpacing: 2, children: [
                if (p.today.isAlert) _heatBadge('今日', p.today),
                if (p.tomorrow.isAlert) _heatBadge('明日', p.tomorrow),
              ]),
              if (p.areas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(p.areas.join('・'),
                      style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PrefCamerasScreen(
                  app: widget.app,
                  pref: p.prefCode,
                  title: '${p.prefName}のカメラ（熱中症警戒情報）'))),
        );
      },
    );
  }

  /// 近くの地点の暑さ指数（WBGT）カード。現在地が取れる場合は最寄り3地点
  Widget _buildWbgtCard(DateTime now) {
    final grey = TextStyle(fontSize: 11, color: Colors.grey[600]);
    Widget body;
    if (_wbgtNoLocation) {
      body = Text('現在地を取得できませんでした', style: grey);
    } else if (_wbgtNearby == null) {
      body = _wbgtFailed
          ? Text('取得できませんでした', style: grey)
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, e) in _wbgtNearby!.indexed) ...[
            if (i > 0) const Divider(height: 12),
            _wbgtPointTile(e.$1, e.$2, e.$3, now),
          ],
        ],
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.device_thermostat,
                  size: 18, color: Colors.grey[700]),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('近くの地点の暑さ指数（WBGT）',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 6),
            body,
            const SizedBox(height: 6),
            Text(Wbgt.attribution, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  /// 1地点分（観測所名・所在地・距離／現在の実況値／今後の予測チップ）
  Widget _wbgtPointTile(
      WbgtPoint p, double distance, WbgtPointData d, DateTime now) {
    final cur = d.current;
    final upcoming = Wbgt.upcoming(d.forecast, now);
    final grey = TextStyle(fontSize: 11, color: Colors.grey[600]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(p.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('約${Wbgt.formatDistance(distance)}', style: grey),
            const SizedBox(width: 6),
            Expanded(
                child: Text(p.address,
                    style: grey, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 4),
        if (d.failed)
          Text('取得できませんでした', style: grey)
        else ...[
          Row(children: [
            Text('現在', style: grey),
            const SizedBox(width: 6),
            if (cur == null)
              Text('実況値なし', style: grey)
            else ...[
              _wbgtChip(cur, big: true),
              const SizedBox(width: 6),
              Text('${cur.level.label}（${_wbgtTimeLabel(cur.at, now)}）',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800])),
            ],
          ]),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('予測', style: grey),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final (i, v) in upcoming.indexed) ...[
                      if (i > 0) const SizedBox(width: 3),
                      _wbgtChip(v, label: _wbgtTimeLabel(v.at, now)),
                    ],
                  ]),
                ),
              ),
            ]),
          ],
        ],
      ],
    );
  }

  /// 値を段階色で塗ったチップ。[label] があれば上段に時刻を出す
  Widget _wbgtChip(WbgtValue v, {String? label, bool big = false}) {
    final lv = v.level;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 8 : 5, vertical: 2),
      decoration: BoxDecoration(
        color: lv.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (label != null)
          Text(label, style: TextStyle(fontSize: 9, color: lv.textColor)),
        Text(v.value.toStringAsFixed(1),
            style: TextStyle(
                fontSize: big ? 16 : 12,
                fontWeight: FontWeight.bold,
                color: lv.textColor)),
      ]),
    );
  }

  /// 予測コマの時刻表示。当日は「15時」、翌日は「翌3時」、それ以外は「9/2 12時」
  static String _wbgtTimeLabel(DateTime t, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return '${t.hour}時';
    if (diff == 1) return '翌${t.hour}時';
    return '${t.month}/${t.day} ${t.hour}時';
  }

  /// 「今日 熱中症警戒」等のバッジ（警報一覧のチップと同じ様式）
  Widget _heatBadge(String day, HeatAlertLevel level) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: heatLevelColor(level),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$day ${level.label}',
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      );
}

/// 「横浜市北部」→「横浜市」のように気象庁の分割区域名を市名に丸める
String jmaCityName(String name) =>
    name.replaceFirst(RegExp(r'(北東|北西|南東|南西|中央|北|南|東|西)部$'), '');

/// 震度バッジの文字色。震度4・5-の配色は明るいため黒文字にする
Color intensityTextColor(String intensity) =>
    (intensity == '4' || intensity == '5-')
        ? const Color(0xFF202124)
        : Colors.white;

/// 揺れた市区町村の一覧（地震タップ後の中間画面）。
///
/// 気象庁 list.json の `int` 配列（市区町村別の観測震度）を震度の大きい順に
/// 並べ、タップするとその市区町村のカメラ一覧を開く。市区町村コードに一致する
/// カメラが無い場合（市町村合併等でコードがずれる）は、従来どおり震源からの
/// 距離検索にフォールバックする。追加のネットワーク取得は行わない
/// （市区町村名は警報タブと共有の area.json キャッシュから引く）。
class QuakeMuniListScreen extends StatefulWidget {
  const QuakeMuniListScreen({
    super.key,
    required this.app,
    required this.title,
    required this.place,
    required this.munis,
    required this.lat,
    required this.lng,
  });

  final AppState app;
  final String title;

  /// 震源地名（フォールバック時の画面名に使う）
  final String place;

  /// 震度の大きい順に並んだ市区町村
  final List<MuniIntensity> munis;
  final double lat;
  final double lng;

  @override
  State<QuakeMuniListScreen> createState() => _QuakeMuniListScreenState();
}

class _QuakeMuniListScreenState extends State<QuakeMuniListScreen> {
  /// 5桁市区町村コード → 表示名
  Map<String, String> _names = const {};

  @override
  void initState() {
    super.initState();
    _applyNames();
    if (!JmaAreaNames.isLoaded) {
      // 警報タブが既に取得済みならネットワークアクセスは発生しない
      JmaAreaNames.load().then((_) {
        if (mounted) setState(_applyNames);
      }).catchError((_) {
        // 名前が引けなくてもコード表記で一覧は出す
      });
    }
  }

  void _applyNames() {
    _names = {
      for (final e in JmaAreaNames.class20Name.entries)
        if (e.key.length >= 5) e.key.substring(0, 5): jmaCityName(e.value)
    };
  }

  void _openNearby(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => NearbyCamerasScreen(
          app: widget.app,
          title: '${widget.place}周辺のカメラ',
          lat: widget.lat,
          lng: widget.lng,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    // 行ごとに台帳を走査しないよう、市区町村コードの索引を1回だけ作る
    final index = MuniCameraIndex(widget.app.repository.displayableCameras());
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      bottomNavigationBar: AdFooter(app: widget.app),
      body: ListView.separated(
        itemCount: widget.munis.length + 2,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '出典：気象庁 地震情報（震度の大きい順）。タップするとその市区町村のカメラ一覧を'
                '表示します。カメラがない市区町村は震源周辺のカメラを表示します。',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            );
          }
          if (i == 1) {
            return ListTile(
              leading: const Icon(Icons.my_location, color: Color(0xFF616E7C)),
              title: const Text('震源周辺のカメラ（距離順）'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openNearby(context),
            );
          }
          final m = widget.munis[i - 2];
          final name = _names[m.code] ?? '市区町村 ${m.code}';
          final count = index.count(m.code);
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: JmaLayers.intensityColor(m.intensity),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('震度\n${m.intensity}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: intensityTextColor(m.intensity),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.2)),
            ),
            title: Row(children: [
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Text(
                count > 0 ? 'カメラ$count台' : 'カメラなし',
                style: TextStyle(
                    fontSize: 12,
                    color: count > 0 ? Colors.grey[700] : Colors.grey[500]),
              ),
            ]),
            subtitle: Text(
              count > 0
                  ? (prefectureNames[m.prefecture] ?? m.prefecture)
                  : '${prefectureNames[m.prefecture] ?? m.prefecture}・震源周辺のカメラを表示します',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (count == 0) {
                _openNearby(context);
                return;
              }
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PrefCamerasScreen(
                  app: widget.app,
                  pref: m.prefecture,
                  title: '$nameのカメラ（震度${m.intensity}）',
                  municipality: m.code,
                ),
              ));
            },
          );
        },
      ),
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

  /// class20コード(7桁)→市区町村名（共有キャッシュ。取得は一度だけ）
  static Future<Map<String, String>> _loadClass20Names() async {
    await JmaAreaNames.load();
    return JmaAreaNames.class20Name;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

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
                  (jmaCityName(names[code] ?? '市区町村 $muni'), <String>{});
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
      bottomNavigationBar: AdFooter(app: widget.app),
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
      bottomNavigationBar: AdFooter(app: widget.app),
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
      bottomNavigationBar: AdFooter(app: widget.app),
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
