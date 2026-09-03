import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/camera_repository.dart';
import 'data/favorites_store.dart';
import 'data/global_stats.dart';
import 'data/review_prompter.dart';
import 'data/view_history_store.dart';
import 'data/viewer_area.dart';
import 'data/widget_bridge.dart';
import 'models/camera.dart';
import 'models/status.dart';

/// アプリ全体で共有するデータ状態（ChangeNotifier 構成）。
class AppState extends ChangeNotifier {
  /// プッシュ通知タップ等による画面遷移の要求（例: 'bosai/quake', 'bosai/warning'）。
  /// HomeShell がタブ切替、BosaiScreen が内部タブ切替に使う
  final ValueNotifier<String?> navigationRequest = ValueNotifier(null);

  AppState(this.repository, {FavoritesStore? favorites})
      : favorites = favorites ?? FavoritesStore();

  final CameraRepository repository;
  final FavoritesStore favorites;
  final ViewHistoryStore viewHistory = ViewHistoryStore();
  final GlobalStats globalStats = GlobalStats();
  final ReviewPrompter reviewPrompter = ReviewPrompter();

  /// 詳細画面を開いたときに呼ぶ。ローカル統計に加え、全国ランキングが
  /// 有効な場合は匿名カウント（カメラIDと回数のみ）を束ねて送信する
  Future<void> recordView(Camera c) async {
    await viewHistory.record(c.id);
    await globalStats.add(c.id);
    reviewPrompter.maybePrompt(
        totalViews: viewHistory.totalEvents,
        favoriteCount: favorites.ids.length);
  }

  bool isFavorite(Camera c) => favorites.contains(c.id);

  /// お気に入りカメラ（登録が新しい順）。ウィジェットの表示順もこれに従う
  List<Camera> favoriteCameras() {
    final byId = {for (final c in repository.cameras) c.id: c};
    return [
      for (final id in favorites.newestFirst)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// iOSホーム画面ウィジェットへ現在の状態を書き出す（お気に入り変更・
  /// 起動・復帰・台帳更新のたびに呼ぶ。iOS以外では何もしない）
  void syncWidgets() {
    if (!WidgetBridge.supported) return;
    WidgetBridge.syncFavorites(buildFavoritesWidgetData(
      favorites: favoriteCameras(),
      imageUrlFor: repository.imageUrlFor,
      imageTimeFor: (c) {
        final st = repository.status[c.id];
        return st?.imageTime ?? st?.lastOkAt;
      },
    ));
    unawaited(WidgetBridge.syncBosaiSettings());
  }

  Future<void> toggleFavorite(Camera c) async {
    final added = await favorites.toggle(c.id);
    notifyListeners();
    syncWidgets();
    await globalStats.addFavorite(c.id, added);
    if (added) {
      reviewPrompter.maybePrompt(
          totalViews: viewHistory.totalEvents,
          favoriteCount: favorites.ids.length);
    }
  }

  // --- 強制アップデート（HANDOFF 2-8-1。manifest.min_app_version と比較） ---
  bool updateRequired = false;
  String? storeUrl;
  String _appVersion = '';

  /// "1.2.3" 形式の比較。current < minimum のとき true
  @visibleForTesting
  static bool isVersionBelow(String current, String minimum) {
    List<int> parse(String v) => v
        .split('+')[0]
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final cur = parse(current);
    final min = parse(minimum);
    for (var i = 0; i < 3; i++) {
      final c = i < cur.length ? cur[i] : 0;
      final m = i < min.length ? min[i] : 0;
      if (c != m) return c < m;
    }
    return false;
  }

  void _checkUpdateRequired() {
    final min = repository.manifest?.minAppVersion;
    storeUrl = repository.manifest?.storeUrl;
    if (min == null || _appVersion.isEmpty) return;
    final required = isVersionBelow(_appVersion, min);
    if (required != updateRequired) {
      updateRequired = required;
      notifyListeners();
    }
  }

  bool initialized = false;
  bool refreshing = false;
  String? notice;

  /// 地図のフィルタ（カテゴリ・動画のみ）
  final Set<String> enabledCategories = {
    'river', 'road', 'volcano', 'dam', 'coast', 'port', 'scenic', 'healing', 'other'
  };
  bool videoOnly = false;
  bool showWorld = true; // 世界(海外)カメラの表示
  bool hideUncertain = false; // 位置情報が曖昧なカメラを非表示
  bool favoritesOnly = false;
  bool okOnly = false; // 現在映っている（state=ok）もののみ
  String searchQuery = '';

  void toggleCategory(String category) {
    if (!enabledCategories.remove(category)) enabledCategories.add(category);
    notifyListeners();
  }

  void setVideoOnly(bool value) {
    videoOnly = value;
    notifyListeners();
  }

  void setShowWorld(bool value) {
    showWorld = value;
    notifyListeners();
  }

  void setHideUncertain(bool value) {
    hideUncertain = value;
    notifyListeners();
  }

  // --- フィルタ初期値（設定画面から構成。起動時に適用） ---
  static const filterDefaultKeys = {
    'showWorld': 'filter_default_show_world',
    'videoOnly': 'filter_default_video_only',
    'hideUncertain': 'filter_default_hide_uncertain',
  };

  Future<void> saveFilterDefault(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(filterDefaultKeys[key]!, value);
  }

  Future<void> _loadFilterDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    showWorld = prefs.getBool(filterDefaultKeys['showWorld']!) ?? true;
    videoOnly = prefs.getBool(filterDefaultKeys['videoOnly']!) ?? false;
    hideUncertain =
        prefs.getBool(filterDefaultKeys['hideUncertain']!) ?? false;
  }

  void setFavoritesOnly(bool value) {
    favoritesOnly = value;
    notifyListeners();
  }

  void setOkOnly(bool value) {
    okOnly = value;
    notifyListeners();
  }

  /// カテゴリ以外も含め、何らかの絞り込みが効いているか（地図の件数バッジ用）
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      videoOnly ||
      !showWorld ||
      hideUncertain ||
      favoritesOnly ||
      okOnly ||
      enabledCategories.length != 9;

  /// カテゴリ以外の共通フィルタ（一覧・地図・件数集計で共用）
  bool _matchesCommonFilters(Camera c) =>
      (showWorld || !c.isWorld) &&
      (!hideUncertain || !(c.coordAccuracy.isUncertain)) &&
      (!videoOnly || c.isVideo) &&
      (!favoritesOnly || favorites.contains(c.id)) &&
      (!okOnly || stateOf(c) == CameraState.ok) &&
      _matchesQuery(c);

  void setSearchQuery(String query) {
    searchQuery = query.trim();
    notifyListeners();
  }

  bool _matchesQuery(Camera c) {
    if (searchQuery.isEmpty) return true;
    final q = searchQuery.toLowerCase();
    return c.name.toLowerCase().contains(q) ||
        c.operator.toLowerCase().contains(q) ||
        (c.riverOrRoute ?? '').toLowerCase().contains(q);
  }

  List<Camera> get displayableCameras => repository
      .displayableCameras()
      .where((c) =>
          enabledCategories.contains(c.category) && _matchesCommonFilters(c))
      .toList();

  /// カテゴリ別の件数（凡例チップに表示）。カテゴリ以外のフィルタは適用後
  Map<String, int> categoryCounts() {
    final counts = <String, int>{};
    for (final c in repository.displayableCameras()) {
      if (_matchesCommonFilters(c)) {
        counts[c.category] = (counts[c.category] ?? 0) + 1;
      }
    }
    return counts;
  }

  CameraState stateOf(Camera c) =>
      repository.status[c.id]?.state ?? CameraState.unknown;

  // --- データ通信設定（Wi-Fiのみで画像取得。SPEC 9.2⑥） ---
  static const _wifiOnlyKey = 'wifi_only_images';
  bool wifiOnly = false;
  bool _onWifi = true; // 接続不明時は取得を止めない
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Wi-Fiのみ設定が原因で画像取得を止めている状態か（プレースホルダ文言用）
  bool get imagesBlockedByWifiSetting => wifiOnly && !_onWifi;

  Future<void> setWifiOnly(bool value) async {
    wifiOnly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final onWifi = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    if (onWifi != _onWifi) {
      _onWifi = onWifi;
      notifyListeners();
    }
  }

  /// キャッシュを全削除して再取得する（設定画面用）
  Future<void> clearCacheAndReload() async {
    await repository.cache.clear();
    await refresh();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  static final _watchIdRe = RegExp(r'[?&]v=([\w-]{11})');

  String? imageUrlFor(Camera c) {
    if (imagesBlockedByWifiSetting) return null;
    // YouTube系は公式サムネイルCDN（映像そのものはIFrame Playerのみ。C6遵守）
    if (c.feed.type == FeedType.youtubeVideo) {
      return 'https://i.ytimg.com/vi/${c.feed.url}/mqdefault.jpg';
    }
    if (c.feed.type == FeedType.webPage) {
      final m = _watchIdRe.firstMatch(c.feed.url);
      if (m != null) return 'https://i.ytimg.com/vi/${m.group(1)}/mqdefault.jpg';
    }
    return repository.imageUrlFor(c);
  }

  String? imageTimeFor(Camera c) {
    // 静止画はアプリが表示のたびに配信元から直接取得するため、監視システムの
    // 確認時刻(最大5時間前)を「取得時刻」として出すと誤解を招く。一覧では出さない
    if (c.feed.type == FeedType.stillImage) return null;
    final st = repository.status[c.id];
    return st?.imageTime ?? st?.lastOkAt;
  }

  /// 起動時: キャッシュ即時復元 → バックグラウンドで更新（SPEC 8.2）
  Future<void> init() async {
    await repository.loadCached();
    await favorites.load();
    await viewHistory.load();
    await globalStats.load();
    await reviewPrompter.load();
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // テスト環境等で取れない場合は強制アップデート判定をスキップ
    }
    await _loadFilterDefaults();
    // 実装前から登録済みのお気に入りを全国集計へ一度だけ反映
    await globalStats.backfillFavorites(favorites.ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      wifiOnly = prefs.getBool(_wifiOnlyKey) ?? false;
      final conn = Connectivity();
      _updateConnectivity(await conn.checkConnectivity());
      _connSub = conn.onConnectivityChanged.listen(_updateConnectivity);
    } catch (_) {
      // 接続状態が取れない環境（テスト等）では常時取得可として扱う
    }
    initialized = true;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      await repository.refresh();
      notice = repository.manifest?.notice;
      _checkUpdateRequired();
    } finally {
      refreshing = false;
      notifyListeners();
    }
    // 災害速報タブのバッジ用（失敗しても本体機能に影響させない）
    unawaited(checkSpecialWarnings());
    // 台帳・status更新後の最新URLをウィジェットへ（都度解決型の image_url 等）
    syncWidgets();
  }

  // --- 特別警報バッジ（災害速報タブに赤バッジを出す） ---
  bool specialWarningActive = false;
  static const _specialCodes = {'32', '33', '34', '35', '36', '37', '38', '39'};

  /// 特別警報（レベル5）が出ている都道府県（JIS 2桁）
  Set<String> specialWarningPrefectures = const {};

  /// 利用者がいま居る都道府県（JIS 2桁）。特別警報の発表中にだけ現在地から求める。
  /// 位置情報が使えない・海上・国外なら null
  String? viewerPrefecture;

  /// 現在地→都道府県の解決（テストで差し替える）。HTTPクライアントは使い回す
  static final ViewerArea _viewerArea = ViewerArea();
  Future<String?> Function() viewerPrefectureResolver =
      () => _viewerArea.currentPrefecture();

  /// **利用者が特別警報の発表エリアに居る**か。広告と「この付近の宿を探す」を
  /// 伏せる条件（1.5.0・2026-09-03 ユーザー決定）。
  ///
  /// カメラの所在地では判定しない: 県外の人が警報エリアのカメラを見るのは普通で、
  /// 復旧期には宿を出した方が支援につながる。**現在地が分からない人（位置情報オフ・
  /// 海上・国外・取得失敗）には無条件で出す**（警報時ほどアクセスが増えるため。
  /// 2026-09-03 ユーザー決定）。伏せるのは位置が取れていて発表エリアに居る人だけ
  bool get viewerInSpecialWarningArea {
    if (!specialWarningActive) return false;
    final pref = viewerPrefecture;
    if (pref == null) return false;
    return specialWarningPrefectures.contains(pref);
  }

  /// r8 map.json（報の一覧）から、特別警報の有無と発表中の都道府県を取り出す。
  ///
  /// - 報は**官署×報種別（dataTypeCode）**ごとに最新1報を採る。官署だけで絞ると
  ///   気象警報（VPWW55）に土砂災害（VPWW56）が上書きされて落ちる（CLAUDE.md）
  /// - 一次細分区域は `class10Items[].areaCode`（6桁。先頭2桁が都道府県）
  @visibleForTesting
  static ({bool active, Set<String> prefs}) parseSpecialWarnings(
      List<dynamic> reports) {
    final latest = <String, Map<String, dynamic>>{};
    for (final rep in reports.cast<Map<String, dynamic>>()) {
      final key = '${rep['publishingOffice'] ?? ''}/${rep['dataTypeCode'] ?? ''}';
      final dt = rep['reportDatetime'] as String? ?? '';
      final cur = latest[key];
      if (cur == null ||
          dt.compareTo(cur['reportDatetime'] as String? ?? '') > 0) {
        latest[key] = rep;
      }
    }
    var active = false;
    final prefs = <String>{};
    for (final rep in latest.values) {
      final warning = rep['warning'] as Map<String, dynamic>? ?? const {};
      for (final area in (warning['class10Items'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final areaCode = (area['areaCode'] ?? area['code'])?.toString() ?? '';
        for (final w in (area['kinds'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          final status = w['status'] as String? ?? '';
          if (status == '解除' || status.contains('なし')) continue;
          if (!_specialCodes.contains(w['code']?.toString() ?? '')) continue;
          active = true;
          if (areaCode.length >= 2) prefs.add(areaCode.substring(0, 2));
        }
      }
    }
    return (active: active, prefs: prefs);
  }

  Future<void> checkSpecialWarnings() async {
    try {
      final resp = await http
          .get(Uri.parse('https://www.jma.go.jp/bosai/warning/data/r8/'
              'map.json?_=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return;
      final reports = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final (:active, :prefs) = parseSpecialWarnings(reports);
      // 発表中だけ現在地の県を求める（平時は位置情報も逆ジオコーダも使わない）
      String? viewer;
      if (active) {
        try {
          viewer = await viewerPrefectureResolver();
        } catch (_) {
          viewer = null;
        }
      }
      final changed = active != specialWarningActive ||
          viewer != viewerPrefecture ||
          !_setEquals(prefs, specialWarningPrefectures);
      specialWarningActive = active;
      specialWarningPrefectures = Set.unmodifiable(prefs);
      viewerPrefecture = viewer;
      if (changed) notifyListeners();
    } catch (_) {
      // 取得失敗時はバッジ状態を維持
    }
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
