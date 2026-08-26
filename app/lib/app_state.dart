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

  Future<void> toggleFavorite(Camera c) async {
    final added = await favorites.toggle(c.id);
    notifyListeners();
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
  }

  // --- 特別警報バッジ（災害速報タブに赤バッジを出す） ---
  bool specialWarningActive = false;
  static const _specialCodes = {'32', '33', '34', '35', '36', '37', '38', '39'};

  Future<void> checkSpecialWarnings() async {
    try {
      final resp = await http
          .get(Uri.parse('https://www.jma.go.jp/bosai/warning/data/r8/'
              'map.json?_=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return;
      final reports = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final latestByOffice = <String, Map<String, dynamic>>{};
      for (final rep in reports.cast<Map<String, dynamic>>()) {
        final office = rep['publishingOffice'] as String? ?? '';
        final dt = rep['reportDatetime'] as String? ?? '';
        final cur = latestByOffice[office];
        if (cur == null ||
            dt.compareTo(cur['reportDatetime'] as String? ?? '') > 0) {
          latestByOffice[office] = rep;
        }
      }
      var active = false;
      outer:
      for (final rep in latestByOffice.values) {
        final warning = rep['warning'] as Map<String, dynamic>? ?? const {};
        for (final area in (warning['class10Items'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          for (final w in (area['kinds'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final status = w['status'] as String? ?? '';
            if (status == '解除' || status.contains('なし')) continue;
            if (_specialCodes.contains(w['code'] as String? ?? '')) {
              active = true;
              break outer;
            }
          }
        }
      }
      if (active != specialWarningActive) {
        specialWarningActive = active;
        notifyListeners();
      }
    } catch (_) {
      // 取得失敗時はバッジ状態を維持
    }
  }
}
