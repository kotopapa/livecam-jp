import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/camera.dart';

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

/// ウィジェットタップで本体を開くURLスキーム（Info.plist の CFBundleURLTypes）
const String widgetUrlScheme = 'livecamjp';

/// ウィジェットに載せる最大台数（large=4台。予備を含めて8台まで書き出す）
const int favoritesWidgetMaxCameras = 8;

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
        },
    ],
  };
}

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
