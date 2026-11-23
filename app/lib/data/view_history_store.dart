import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// カメラ閲覧履歴（端末内のみ。SPEC C1: サーバーを持たないため統計はローカル）。
/// 詳細画面を開いた時刻を記録し、閲覧履歴の画面（ui/view_history_screen.dart。1.7.6）と
/// レビュー訴求のタイミング判定に使う。
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

  /// 最後に見た時刻（履歴が無ければ null）
  DateTime? lastViewedAt(String cameraId) {
    final list = _views[cameraId];
    if (list == null || list.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(list.first);
  }

  /// 最後に見た時刻が新しい順のカメラID
  List<String> get recentIds {
    final ids = _views.keys.where((id) => _views[id]!.isNotEmpty).toList();
    ids.sort((a, b) => _views[b]!.first.compareTo(_views[a]!.first));
    return ids;
  }

  /// 1台分の履歴を消す
  Future<void> remove(String cameraId) async {
    if (_views.remove(cameraId) == null) return;
    await _prefs?.setString(_key, jsonEncode(_views));
  }

  /// 履歴をすべて消す
  Future<void> clear() async {
    _views.clear();
    await _prefs?.remove(_key);
  }

  /// 閲覧のあるカメラID一覧
  Iterable<String> get viewedIds => _views.keys;

  /// 全カメラ合計の閲覧回数（レビュー訴求のタイミング判定に使う）
  int get totalEvents =>
      _views.values.fold(0, (sum, times) => sum + times.length);
}
