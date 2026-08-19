import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// カメラ閲覧履歴（端末内のみ。SPEC C1: サーバーを持たないため統計はローカル）。
/// 詳細画面を開いた時刻を記録し、ランキング（直近/累計）に使う。
class ViewHistoryStore {
  static const _key = 'view_history_v1';
  static const _maxTimestampsPerCamera = 50;
  static const _maxCameras = 500;

  final Map<String, List<int>> _views = {}; // cameraId -> epochMs（新しい順）
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _views
        ..clear()
        ..addAll(decoded.map(
            (k, v) => MapEntry(k, (v as List).cast<int>())));
    } catch (_) {
      _views.clear(); // 壊れた履歴は捨てる
    }
  }

  Future<void> record(String cameraId, {DateTime? at}) async {
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final list = _views.putIfAbsent(cameraId, () => []);
    list.insert(0, ts);
    if (list.length > _maxTimestampsPerCamera) {
      list.removeRange(_maxTimestampsPerCamera, list.length);
    }
    // カメラ数の上限: 最終閲覧が最も古いものから削る
    if (_views.length > _maxCameras) {
      final oldest = _views.entries
          .reduce((a, b) => a.value.first < b.value.first ? a : b);
      _views.remove(oldest.key);
    }
    await _prefs?.setString(_key, jsonEncode(_views));
  }

  /// 総閲覧回数
  int totalCount(String cameraId) => _views[cameraId]?.length ?? 0;

  /// [days] 日以内の閲覧回数
  int recentCount(String cameraId, {int days = 3}) {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    return _views[cameraId]?.where((t) => t >= since).length ?? 0;
  }

  /// 閲覧のあるカメラID一覧
  Iterable<String> get viewedIds => _views.keys;
}
