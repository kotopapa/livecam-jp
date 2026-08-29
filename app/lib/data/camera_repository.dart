import 'dart:convert';

import '../models/camera.dart';
import '../models/manifest.dart';
import '../models/status.dart';
import 'api_client.dart';
import 'cache_store.dart';

/// 配信データの取得・キャッシュを司る（SPEC 8.2 の取得戦略を実装）。
///
/// - 起動時: manifest.json のみ取得（軽い）
/// - cameras.version が手元と違うときだけ cameras.json を取得
/// - status.json は起動時 + 前回取得から5分以上経過していれば再取得
/// - いずれも失敗したらローカルキャッシュで動作を継続（オフライン動作）
class CameraRepository {
  CameraRepository({required this.api, required this.cache, DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc());

  static const _statusMaxAge = Duration(minutes: 5);

  final ApiClient api;
  final CacheStore cache;
  final DateTime Function() _now;

  Manifest? manifest;
  List<Camera> cameras = const [];
  StatusFile status = const StatusFile(generatedAt: null, statuses: {});

  /// 起動直後にキャッシュから即座に前回状態を復元する（ネットワーク不要）
  Future<void> loadCached() async {
    final m = await cache.readJson('manifest');
    if (m != null) manifest = Manifest.fromJson(m);
    final c = await cache.readJson('cameras');
    if (c != null) cameras = Camera.listFromJson(c);
    final s = await cache.readJson('status');
    if (s != null) status = StatusFile.fromJson(s);
  }

  /// SPEC 8.2 の戦略で更新する。オフライン時は既存データを維持して false を返す
  Future<bool> refresh() async {
    var updated = false;

    // 1) manifest（常に取得。ETagで304なら転送なし）
    final mMeta = await cache.readMeta('manifest');
    final mResp = await api.getJson('manifest.json', etag: mMeta?.etag);
    if (mResp.result == ApiResult.success) {
      manifest = Manifest.fromJson(mResp.json);
      await cache.write('manifest', mResp.body!,
          etag: mResp.etag, version: manifest!.camerasVersion);
      updated = true;
    } else if (mResp.result == ApiResult.failure && manifest == null) {
      return false; // 完全オフライン初回起動: キャッシュもなければ何もできない
    }

    // 2) cameras（バージョンが変わったときだけ）
    final currentVersion = (await cache.readMeta('cameras'))?.version;
    final wantVersion = manifest?.camerasVersion;
    if (manifest != null && (cameras.isEmpty || currentVersion != wantVersion)) {
      final cResp = await api.getJson(manifest!.camerasUrl,
          etag: (await cache.readMeta('cameras'))?.etag);
      if (cResp.result == ApiResult.success) {
        cameras = Camera.listFromJson(cResp.json);
        await cache.write('cameras', cResp.body!,
            etag: cResp.etag, version: wantVersion);
        updated = true;
      }
    }

    // 3) status（5分以上経過していれば）
    final sMeta = await cache.readMeta('status');
    final stale = sMeta?.savedAt == null ||
        _now().difference(sMeta!.savedAt!) >= _statusMaxAge;
    if (manifest != null && stale) {
      final sResp = await api.getJson(manifest!.statusUrl, etag: sMeta?.etag);
      if (sResp.result == ApiResult.success) {
        status = StatusFile.fromJson(sResp.json);
        await cache.write('status', sResp.body!, etag: sResp.etag);
        updated = true;
      } else if (sResp.result == ApiResult.notModified) {
        // 内容は同じだが取得時刻は更新する（5分間の再問い合わせ抑制）
        final body = await cache.readJson('status');
        if (body != null) {
          await cache.write('status', _reencode(body), etag: sMeta?.etag);
        }
      }
    }
    return updated;
  }

  /// 地図に表示すべきカメラ（SPEC 5.2: error は出さない。座標のないものも出せない）
  List<Camera> displayableCameras() => cameras
      .where((c) => c.isDisplayable && (status[c.id]?.state != CameraState.error))
      .toList();

  /// カメラの静止画URL。都度解決型は status.json の image_url を使う
  String? imageUrlFor(Camera c) {
    if (c.feed.type == FeedType.mlitRoadinfo ||
        c.feed.type == FeedType.jmaVolcam ||
        c.feed.type == FeedType.thrCamxml ||
        c.feed.type == FeedType.camidxLatest ||
        c.feed.type == FeedType.saitamaFlood ||
        c.feed.type == FeedType.kochiSuibo ||
        c.feed.type == FeedType.sizenken ||
        c.feed.type == FeedType.shimantoKasen ||
        c.feed.type == FeedType.takashimaRiver ||
        c.feed.type == FeedType.higashiomiRiver ||
        c.feed.type == FeedType.yamaguchiRomen ||
        c.feed.type == FeedType.yamaguchiKasen ||
        c.feed.type == FeedType.shimaneSuibo ||
        c.feed.type == FeedType.fukuokaKasen) {
      return status[c.id]?.imageUrl;
    }
    if (c.feed.type == FeedType.stillImage) return c.feed.url;
    return null;
  }

  static String _reencode(Map<String, dynamic> json) => jsonEncode(json);
}
