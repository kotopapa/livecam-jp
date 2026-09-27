import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/native_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('livecam/native_config');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    NativeConfig.instance.resetForTest();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('getGoogleMapsApiKey: ネイティブの値を返し、以後はキャッシュする', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      if (call.method == 'getGoogleMapsApiKey') return 'KEY123';
      return null;
    });
    expect(await NativeConfig.instance.getGoogleMapsApiKey(), 'KEY123');
    expect(await NativeConfig.instance.getGoogleMapsApiKey(), 'KEY123');
    expect(calls, 1); // 2回目はキャッシュを返すのでチャンネルは呼ばない
  });

  test('getGoogleMapsApiKey: 空文字は null（未設定として扱う）', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => '');
    expect(await NativeConfig.instance.getGoogleMapsApiKey(), isNull);
  });

  test('getAppRestrictionHeaders: ネイティブの Map を文字列の Map にする', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAppRestrictionHeaders') {
        return {'X-Android-Package': 'jp.livecam.livecam_jp', 'X-Android-Cert': 'ABCD'};
      }
      return null;
    });
    final h = await NativeConfig.instance.getAppRestrictionHeaders();
    expect(h, {'X-Android-Package': 'jp.livecam.livecam_jp', 'X-Android-Cert': 'ABCD'});
  });

  test('チャンネル未実装（プラグイン無し）でも例外を投げずフォールバック値を返す', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(await NativeConfig.instance.getGoogleMapsApiKey(), isNull);
    expect(await NativeConfig.instance.getAppRestrictionHeaders(), <String, String>{});
  });
}
