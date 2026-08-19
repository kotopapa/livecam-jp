import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 全国ランキング用の匿名閲覧カウント送信（Firestore RESTへの書き込み専用）。
///
/// 無料枠に収めるための設計:
/// - 送信するのは「カメラIDと回数」だけ（ユーザー識別子・位置情報は送らない）
/// - 端末内で束ねて、条件を満たしたときだけバッチ送信（1コミット=1リクエスト）
/// - アプリはFirestoreを一切読まない（ランキングはGitHub Pagesの静的JSONを読む）
/// - firebaseProjectId が空なら全機能無効（送信もしない）
class GlobalStats {
  static const _pendingKey = 'global_stats_pending_v1';
  static const _lastFlushKey = 'global_stats_last_flush';
  static const _minFlushInterval = Duration(minutes: 15);
  static const _maxPendingAge = Duration(minutes: 30);
  static const _flushThreshold = 3; // 束ねるカメラ数がこの数以上で送信を試みる
  static const _maxWritesPerCommit = 200;

  final Map<String, int> _pending = {};
  DateTime? _oldestPending;
  DateTime? _lastFlush;
  SharedPreferences? _prefs;
  bool _flushing = false;

  bool get enabled => firebaseProjectId.isNotEmpty;

  Future<void> load() async {
    if (!enabled) return;
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(_pendingKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _pending.addAll(m.map((k, v) => MapEntry(k, v as int)));
        if (_pending.isNotEmpty) _oldestPending = DateTime.now();
      }
      final lf = _prefs!.getString(_lastFlushKey);
      if (lf != null) _lastFlush = DateTime.tryParse(lf);
    } catch (_) {
      _pending.clear();
    }
  }

  Future<void> add(String cameraId) async {
    if (!enabled) return;
    _pending[cameraId] = (_pending[cameraId] ?? 0) + 1;
    _oldestPending ??= DateTime.now();
    await _prefs?.setString(_pendingKey, jsonEncode(_pending));
    await _maybeFlush();
  }

  Future<void> _maybeFlush() async {
    if (_flushing || _pending.isEmpty) return;
    final now = DateTime.now();
    if (_lastFlush != null && now.difference(_lastFlush!) < _minFlushInterval) {
      return;
    }
    final aged = _oldestPending != null &&
        now.difference(_oldestPending!) >= _maxPendingAge;
    if (_pending.length < _flushThreshold && !aged) return;
    await flush();
  }

  /// Firestoreの `views/{JST日付}/cams/{cameraId}` の n をincrementする
  Future<void> flush() async {
    if (!enabled || _flushing || _pending.isEmpty) return;
    _flushing = true;
    try {
      final jst = DateTime.now().toUtc().add(const Duration(hours: 9));
      final day = '${jst.year}'
          '${jst.month.toString().padLeft(2, '0')}'
          '${jst.day.toString().padLeft(2, '0')}';
      final base = 'projects/$firebaseProjectId/databases/(default)/documents';
      final entries = _pending.entries.take(_maxWritesPerCommit).toList();
      final writes = [
        for (final e in entries)
          {
            'transform': {
              'document': '$base/views/$day/cams/${e.key}',
              'fieldTransforms': [
                {
                  'fieldPath': 'n',
                  'increment': {'integerValue': '${e.value}'},
                },
              ],
            },
          },
      ];
      final uri = Uri.parse(
          'https://firestore.googleapis.com/v1/$base:commit'
          '?key=$firebaseApiKey');
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'writes': writes}))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        for (final e in entries) {
          _pending.remove(e.key);
        }
        if (_pending.isEmpty) _oldestPending = null;
        _lastFlush = DateTime.now();
        await _prefs?.setString(_pendingKey, jsonEncode(_pending));
        await _prefs?.setString(
            _lastFlushKey, _lastFlush!.toIso8601String());
      }
      // 失敗時はpendingを保持して次回に持ち越す（リトライの連打はしない）
    } catch (_) {
      // オフライン等。次の機会に送る
    } finally {
      _flushing = false;
    }
  }
}
