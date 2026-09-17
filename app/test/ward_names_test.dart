import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/ward_names.dart';

void main() {
  test('政令指定都市の区名（地震情報の区コード → 名前）', () {
    // 2026-09-17 不具合報告: 横浜市神奈川区が「市区町村 14102」と出ていた
    expect(wardNames['14102'], '横浜市神奈川区');
    expect(wardNames['01101'], '札幌市中央区');
    expect(wardNames['43104'], '熊本市南区');
    expect(wardNames['22138'], '浜松市中央区'); // 2024年の再編後
    // 20政令市すべて（東京23区は area.json で引けるので含めない）
    final prefs = wardNames.keys.map((k) => k.substring(0, 2)).toSet();
    expect(prefs, {
      '01', '04', '11', '12', '14', '15', '22', '23', '26', '27', '28', '33', '34', '40', '43',
    });
    expect(wardNames.containsKey('13101'), isFalse);
    expect(wardNames.length, greaterThanOrEqualTo(170));
    for (final e in wardNames.entries) {
      expect(e.key, matches(RegExp(r'^\d{5}$')));
      expect(e.value, endsWith('区'));
      expect(e.value, contains('市'));
    }
  });
}
