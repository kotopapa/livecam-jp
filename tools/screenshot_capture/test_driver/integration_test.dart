// ストア用スクリーンショット撮影の driver（ホスト側）。
// アプリ側 integration_test/screenshots_test.dart の binding.takeScreenshot(name) を
// 合図に、ホストから端末の画面をそのまま保存する（CAPTURE_DIR 配下に <name>.png）。
//
//   CAPTURE_VIA=simctl:<simulator udid>  → xcrun simctl io <udid> screenshot
//   CAPTURE_VIA=adb[:<serial>]           → adb exec-out screencap -p
//   未指定                               → アプリ側 takeScreenshot の画像をそのまま保存
//
// 実行例（iOS シミュレータ）:
//   CAPTURE_DIR=store_assets/captures/ios CAPTURE_VIA=simctl:<udid> \
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <udid> \
//     --dart-define=SCREENSHOT_MODE=true
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Platform.environment['CAPTURE_DIR'] ?? 'store_assets/captures';
  final via = Platform.environment['CAPTURE_VIA'] ?? '';
  await Directory(dir).create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final f = File('$dir/$name.png');
      if (via.startsWith('simctl:')) {
        final udid = via.substring('simctl:'.length);
        final r = await Process.run(
            'xcrun', ['simctl', 'io', udid, 'screenshot', f.path]);
        stdout.writeln('simctl ${r.exitCode} ${f.path}');
        return r.exitCode == 0;
      }
      if (via.startsWith('adb')) {
        final serial = via.contains(':') ? via.split(':')[1] : '';
        final adb = Platform.environment['ADB'] ??
            '${Platform.environment['HOME']}/Library/Android/sdk/platform-tools/adb';
        final r = await Process.run(adb, [
          if (serial.isNotEmpty) ...['-s', serial],
          'exec-out', 'screencap', '-p'
        ], stdoutEncoding: null);
        await f.writeAsBytes(r.stdout as List<int>);
        stdout.writeln('adb ${r.exitCode} ${f.path}');
        return r.exitCode == 0;
      }
      await f.writeAsBytes(bytes);
      stdout.writeln('saved ${f.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
