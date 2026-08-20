import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/app_state.dart';

void main() {
  group('isVersionBelow（強制アップデート判定）', () {
    test('同一バージョンは更新不要', () {
      expect(AppState.isVersionBelow('1.0.0', '1.0.0'), isFalse);
    });
    test('下回ると更新必要', () {
      expect(AppState.isVersionBelow('1.0.0', '1.0.1'), isTrue);
      expect(AppState.isVersionBelow('1.0.9', '1.1.0'), isTrue);
      expect(AppState.isVersionBelow('1.9.9', '2.0.0'), isTrue);
    });
    test('上回ると更新不要', () {
      expect(AppState.isVersionBelow('1.0.1', '1.0.0'), isFalse);
      expect(AppState.isVersionBelow('2.0.0', '1.9.9'), isFalse);
    });
    test('ビルド番号(+n)は無視して比較する', () {
      expect(AppState.isVersionBelow('1.0.0+6', '1.0.0'), isFalse);
    });
    test('桁数が違っても比較できる', () {
      expect(AppState.isVersionBelow('1.0', '1.0.1'), isTrue);
      expect(AppState.isVersionBelow('1.0.10', '1.0.2'), isFalse);
    });
  });
}
