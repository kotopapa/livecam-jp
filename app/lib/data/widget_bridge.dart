import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/camera.dart';
import '../util/geo.dart';
import 'viewer_area.dart';

/// iOSホーム画面ウィジェット（app/ios/LiveCamWidget）との橋渡し。
///
/// App Group の UserDefaults に JSON 文字列を書き、WidgetKit のタイムラインを
/// 再読込させる。キー名・JSON形状は Swift 側（SharedStore.swift /
/// FavoriteCamerasWidget.swift / BosaiWidget.swift）と一致させること。
/// 純粋関数（JSON生成・URL解析）はテスト対象なのでプラグイン呼び出しと分離する。
const String widgetAppGroupId = 'group.jp.livecam.livecamJp';
const String favoritesWidgetKind = 'FavoriteCamerasWidget';
const String bosaiWidgetKind = 'BosaiWidget';
const String favoritesWidgetDataKey = 'favorites_widget_json';
const String bosaiWidgetSettingsKey = 'bosai_widget_settings_json';

/// 利用者の最後の位置（lat/lng/pref/at）。両ウィジェットが「現在地を先頭」に
/// 並べ替えるのに使う（2026-11-04 ユーザー決定: 方式B＝本体が書く。ウィジェット
/// 自身は位置情報を取らないので NSWidgetWantsLocation は付けない）
const String viewerLocationKey = 'viewer_location_json';
/// 本体側の控え（SharedPreferences）。前回解決した座標と県
const String viewerLocationCacheKey = 'widget_viewer_location';

/// 前回解決した座標からこの距離以内なら県の再解決（逆ジオコーダ）をしない
const double viewerPrefectureReuseMeters = 3000;
/// 県が同じでこの距離以内の移動なら App Group への書き直しをしない
const double viewerLocationRewriteMeters = 1000;

/// ウィジェットタップで本体を開くURLスキーム（Info.plist の CFBundleURLTypes）
const String widgetUrlScheme = 'livecamjp';

/// ウィジェットに載せる最大台数（large=4台。ウィジェット側が現在地に近い順へ
/// 並べ替えるので、候補として多めに書き出す。画像を取るのは表示分だけ）
const int favoritesWidgetMaxCameras = 24;

/// お気に入りが変わったことをウィジェットに知らせるまでの猶予（連打の集約）
const Duration widgetSyncDebounce = Duration(milliseconds: 800);

final RegExp _watchIdRe = RegExp(r'[?&]v=([\w-]{11})');

/// ウィジェット用の静止画URL。
/// YouTube系は公式サムネイルCDN（映像はIFrame Player経由のみ=C6遵守）、
/// 静止画・都度解決型は [repositoryImageUrl]（feed.url / status.image_url）
String? widgetImageUrlFor(Camera c, String? Function(Camera) repositoryImageUrl) {
  if (c.feed.type == FeedType.youtubeVideo) {
    return 'https://i.ytimg.com/vi/${c.feed.url}/hqdefault.jpg';
  }
  if (c.feed.type == FeedType.webPage) {
    final m = _watchIdRe.firstMatch(c.feed.url);
    if (m != null) return 'https://i.ytimg.com/vi/${m.group(1)}/hqdefault.jpg';
    return null;
  }
  return repositoryImageUrl(c);
}

/// 画像取得時に付けるHTTPヘッダ（詳細画面と同じ: requires_referer なら出典ページ）
Map<String, String> widgetImageHeadersFor(Camera c) {
  final h = Map<String, String>.from(c.feed.headers);
  if (c.feed.requiresReferer &&
      c.sourcePageUrl != null &&
      !h.keys.any((k) => k.toLowerCase() == 'referer')) {
    h['Referer'] = c.sourcePageUrl!;
  }
  return h;
}

/// お気に入りカメラ一覧のウィジェット用JSON（Map）。
/// [favorites] は表示順（先頭が small の1台目）。座標の無いカメラも載せる
Map<String, dynamic> buildFavoritesWidgetData({
  required List<Camera> favorites,
  required String? Function(Camera) imageUrlFor,
  String? Function(Camera)? imageTimeFor,
  DateTime? now,
  int limit = favoritesWidgetMaxCameras,
}) {
  final at = (now ?? DateTime.now()).toUtc();
  return {
    'generated_at': at.toIso8601String(),
    'cameras': [
      for (final c in favorites.take(limit))
        {
          'id': c.id,
          'name': c.name,
          'image_url': widgetImageUrlFor(c, imageUrlFor),
          'category': c.category,
          'prefecture': c.prefecture,
          'operator': c.operator,
          'updated_at': imageTimeFor?.call(c),
          'headers': widgetImageHeadersFor(c),
          if (c.hasLocation) 'lat': c.lat,
          if (c.hasLocation) 'lng': c.lng,
        },
    ],
  };
}

/// 利用者の最後の位置のウィジェット用JSON。[pref] は JIS 2桁（海上・国外・
/// 解決失敗は null。座標だけでもお気に入りの並べ替えには使える）
Map<String, dynamic> buildViewerLocationData({
  required double lat,
  required double lng,
  required String? pref,
  DateTime? at,
}) =>
    {
      'lat': double.parse(lat.toStringAsFixed(4)),
      'lng': double.parse(lng.toStringAsFixed(4)),
      'pref': ?pref,
      'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
    };

/// 本体側の控え（前回解決した座標と県）
class ViewerLocationCache {
  const ViewerLocationCache({required this.lat, required this.lng, this.pref});

  final double lat;
  final double lng;
  final String? pref;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'pref': ?pref};

  static ViewerLocationCache? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'], lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    return ViewerLocationCache(
        lat: lat.toDouble(), lng: lng.toDouble(), pref: json['pref'] as String?);
  }

  double distanceTo(double lat2, double lng2) =>
      distanceMeters(lat, lng, lat2, lng2);
}

/// 前回の控えから県を再利用できるか（3km 以内なら逆ジオコーダを呼ばない。
/// 前回が海上・国外（pref 無し）でも同じ場所なら呼び直さない）
bool canReusePrefecture(ViewerLocationCache? cached, double lat, double lng) =>
    cached != null && cached.distanceTo(lat, lng) <= viewerPrefectureReuseMeters;

/// App Group へ書き直す必要があるか（県が変わったか 1km 以上動いたとき）
bool shouldRewriteViewerLocation(
        ViewerLocationCache? written, double lat, double lng, String? pref) =>
    written == null ||
    written.pref != pref ||
    written.distanceTo(lat, lng) > viewerLocationRewriteMeters;

/// 災害速報ウィジェットの設定JSON。prefs=対象都道府県JISコード（空=全国）
Map<String, dynamic> buildBosaiWidgetSettings(Set<String> warningPrefs) => {
      'prefs': warningPrefs.toList()..sort(),
    };

/// ウィジェットのディープリンクを [AppState.navigationRequest] の値に変換する。
/// `livecamjp://camera/<id>` → `camera/<id>`、`livecamjp://bosai` → `bosai`、
/// `livecamjp://map` → `map`。home_widget が付ける `?homeWidget` は無視する。
/// 対象外のURLは null
String? parseWidgetDeepLink(Uri? uri) {
  if (uri == null || uri.scheme != widgetUrlScheme) return null;
  final host = uri.host;
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  switch (host) {
    case 'camera':
      if (segs.isEmpty) return null;
      final id = Uri.decodeComponent(segs.first);
      return id.isEmpty ? null : 'camera/$id';
    case 'bosai':
      return segs.isEmpty ? 'bosai' : 'bosai/${segs.first}';
    case 'map':
      return 'map';
    default:
      return null;
  }
}

/// プラグイン呼び出し側。iOS以外・テスト環境では何もしない
class WidgetBridge {
  WidgetBridge._();

  static bool get supported => !kIsWeb && Platform.isIOS;
  static bool _groupSet = false;
  static Timer? _debounce;

  static Future<bool> _ensureGroup() async {
    if (!supported) return false;
    if (_groupSet) return true;
    try {
      await HomeWidget.setAppGroupId(widgetAppGroupId);
      _groupSet = true;
    } catch (_) {
      // プラグイン未登録（テスト等）
    }
    return _groupSet;
  }

  /// 起動時に1回。App Group を設定し、ウィジェット起動URLの購読を始める
  static Future<void> init({required void Function(String route) onRoute}) async {
    if (!await _ensureGroup()) return;
    try {
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      final r = parseWidgetDeepLink(initial);
      if (r != null) onRoute(r);
    } catch (_) {}
    try {
      HomeWidget.widgetClicked.listen((uri) {
        final r = parseWidgetDeepLink(uri);
        if (r != null) onRoute(r);
      }, onError: (_) {});
    } catch (_) {}
  }

  /// お気に入り一覧を書き出してウィジェットを更新する（短時間の連続呼び出しは集約）
  static void syncFavorites(Map<String, dynamic> data) {
    if (!supported) return;
    _debounce?.cancel();
    _debounce = Timer(widgetSyncDebounce, () => _writeFavorites(data));
  }

  static Future<void> _writeFavorites(Map<String, dynamic> data) async {
    if (!await _ensureGroup()) return;
    try {
      await HomeWidget.saveWidgetData<String>(
          favoritesWidgetDataKey, jsonEncode(data));
      await HomeWidget.updateWidget(iOSName: favoritesWidgetKind);
    } catch (_) {}
  }

  /// 現在地の取得と県の解決（テストで差し替える）。位置情報は**新たに許可を
  /// 求めず**、許可済みのときの最後の既知位置だけを使う（viewer_area.dart と同じ）
  static Future<(double, double)?> Function() positionProvider = () async {
    final p = await ViewerArea.lastKnownPosition();
    return p == null ? null : (p.latitude, p.longitude);
  };
  static final ViewerArea _viewerArea = ViewerArea();
  static Future<String?> Function(double lat, double lng) prefectureResolver =
      (lat, lng) => _viewerArea.prefectureOf(lat, lng);

  /// 前回 App Group に書いた内容（起動中の重複書き込みを避ける）
  static ViewerLocationCache? _written;
  static bool _locating = false;

  /// 利用者の最後の位置と県を App Group に書き、両ウィジェットを更新する。
  /// 県の解決は前回の座標から 3km 以上動いたときだけ逆ジオコーダを呼ぶ
  static Future<void> syncViewerLocation() async {
    if (!await _ensureGroup() || _locating) return;
    _locating = true;
    try {
      final pos = await positionProvider();
      if (pos == null) return;
      final (lat, lng) = pos;
      final prefs = await SharedPreferences.getInstance();
      final cached = ViewerLocationCache.fromJson(
          _decode(prefs.getString(viewerLocationCacheKey)));
      String? pref;
      if (canReusePrefecture(cached, lat, lng)) {
        pref = cached!.pref;
      } else {
        pref = await prefectureResolver(lat, lng);
        await prefs.setString(
            viewerLocationCacheKey,
            jsonEncode(
                ViewerLocationCache(lat: lat, lng: lng, pref: pref).toJson()));
      }
      final written = _written ??
          ViewerLocationCache.fromJson(
              _decode(await HomeWidget.getWidgetData<String>(viewerLocationKey)));
      if (!shouldRewriteViewerLocation(written, lat, lng, pref)) return;
      await HomeWidget.saveWidgetData<String>(viewerLocationKey,
          jsonEncode(buildViewerLocationData(lat: lat, lng: lng, pref: pref)));
      _written = ViewerLocationCache(lat: lat, lng: lng, pref: pref);
      await HomeWidget.updateWidget(iOSName: favoritesWidgetKind);
      await HomeWidget.updateWidget(iOSName: bosaiWidgetKind);
    } catch (_) {
      // 位置情報プラグイン未登録・通信失敗などは無視（次回の同期で再試行）
    } finally {
      _locating = false;
    }
  }

  static Object? _decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// 災害速報ウィジェットの対象都道府県を書き出す。
  /// [prefs] 省略時は通知設定の保存値（notify_warning_prefs）を読む
  static Future<void> syncBosaiSettings({Set<String>? prefs}) async {
    if (!await _ensureGroup()) return;
    try {
      final p = prefs ??
          ((await SharedPreferences.getInstance())
                  .getStringList('notify_warning_prefs') ??
              const [])
              .toSet();
      await HomeWidget.saveWidgetData<String>(
          bosaiWidgetSettingsKey, jsonEncode(buildBosaiWidgetSettings(p)));
      await HomeWidget.updateWidget(iOSName: bosaiWidgetKind);
    } catch (_) {}
  }
}
