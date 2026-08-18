import 'dart:convert';
import 'dart:io';

/// 配信JSONのディスクキャッシュ（オフライン動作の要。SPEC 8.2）。
///
/// 本文（`<name>.json`）と メタ（ETag・保存時刻）を分けて保存する。
/// ディレクトリはテスト容易性のため注入する（本番は path_provider の
/// ApplicationSupportDirectory を渡す）。
class CacheStore {
  CacheStore(this.dir, {DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc());

  final Directory dir;
  final DateTime Function() _now;

  File _body(String name) => File('${dir.path}/$name.json');
  File _meta(String name) => File('${dir.path}/$name.meta.json');

  Future<Map<String, dynamic>?> readJson(String name) async {
    try {
      final f = _body(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null; // 壊れたキャッシュは無いものとして扱う
    }
  }

  Future<CacheMeta?> readMeta(String name) async {
    try {
      final f = _meta(name);
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return CacheMeta(
        etag: m['etag'] as String?,
        savedAt: DateTime.tryParse(m['saved_at'] as String? ?? ''),
        version: m['version'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String name, String rawJson,
      {String? etag, String? version}) async {
    await dir.create(recursive: true);
    await _body(name).writeAsString(rawJson);
    await _meta(name).writeAsString(jsonEncode({
      'etag': etag,
      'saved_at': _now().toIso8601String(),
      'version': version,
    }));
  }
}

class CacheMeta {
  const CacheMeta({this.etag, this.savedAt, this.version});
  final String? etag;
  final DateTime? savedAt;
  final String? version;
}
