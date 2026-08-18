// ignore_for_file: avoid_print  — 開発用プローブ
import 'dart:io';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';

Future<void> main() async {
  final tmp = await Directory.systemTemp.createTemp('probe');
  final repo = CameraRepository(api: ApiClient(), cache: CacheStore(tmp));
  final sw = Stopwatch()..start();
  final ok = await repo.refresh();
  print('refresh=$ok elapsed=${sw.elapsedMilliseconds}ms');
  print('manifest=${repo.manifest?.camerasCount} cameras=${repo.cameras.length} '
      'displayable=${repo.displayableCameras().length} '
      'status=${repo.status.statuses.length}');
  await tmp.delete(recursive: true);
}
