import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/notification_settings.dart';

void main() {
  Set<String> topics({
    bool warning = false,
    String level = '5',
    bool snow = false,
    Set<String> prefs = const {},
    Set<String> snowAreas = const {},
  }) => NotificationSettings.warningTopicsFor(
    warningEnabled: warning,
    warningLevel: level,
    snowEnabled: snow,
    prefs: prefs,
    snowAreas: snowAreas,
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

  test('大雪・暴風雪の警報は特別警報のスイッチ・地域と独立', () {
    expect(topics(snow: true), {'snow-warning'});
    // 特別警報の地域（prefs）は雪には効かない
    expect(topics(snow: true, prefs: {'13'}), {'snow-warning'});
    expect(topics(snow: true, level: '4', snowAreas: {'15'}), {
      'snow-warning-15',
    });
    // 切なら地域が残っていても購読しない
    expect(topics(snowAreas: {'15', '0110000'}), isEmpty);
  });

  test('雪の地域: 県全体と市区町村を混ぜて選べる', () {
    expect(
      topics(
        warning: true,
        prefs: {'13'},
        snow: true,
        snowAreas: {'01', '1522200', '1520200'},
      ),
      {
        'special-warning-13',
        'snow-warning-01',
        'snow-warning-1522200',
        'snow-warning-1520200',
      },
    );
  });

  test('雪の地域の正規化: 県全体を選んだ県の市区町村と、形の合わないコードを落とす', () {
    expect(
      NotificationSettings.normalizeSnowAreas({
        '15',
        '1522200',
        '0110000',
        '99',
        '9912345',
        'abc',
        '152220',
      }),
      {'15', '0110000'},
    );
  });
}
