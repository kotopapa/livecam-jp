import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/notification_settings.dart';

void main() {
  Set<String> topics({
    bool warning = false,
    String level = '5',
    bool snow = false,
    Set<String> prefs = const {},
  }) => NotificationSettings.warningTopicsFor(
    warningEnabled: warning,
    warningLevel: level,
    snowEnabled: snow,
    prefs: prefs,
  );

  test('どちらも切なら購読しない', () {
    expect(topics(), isEmpty);
    expect(topics(prefs: {'15'}), isEmpty);
  });

  test('特別警報だけ: これまでと同じトピック', () {
    expect(topics(warning: true), {'special-warning'});
    expect(topics(warning: true, level: '4'), {
      'special-warning',
      'danger-warning',
    });
    expect(topics(warning: true, level: '4', prefs: {'13', '14'}), {
      'special-warning-13',
      'danger-warning-13',
      'special-warning-14',
      'danger-warning-14',
    });
  });

  test('大雪・暴風雪の警報は特別警報のスイッチと独立', () {
    expect(topics(snow: true), {'snow-warning'});
    expect(topics(snow: true, prefs: {'01', '15'}), {
      'snow-warning-01',
      'snow-warning-15',
    });
    // 危険警報のレベル設定は、特別警報が切なら効かない
    expect(topics(snow: true, level: '4', prefs: {'15'}), {'snow-warning-15'});
  });

  test('両方入: 地域は共通', () {
    expect(topics(warning: true, snow: true, prefs: {'15'}), {
      'special-warning-15',
      'snow-warning-15',
    });
  });
}
