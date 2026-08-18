import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/util/time_format.dart';

void main() {
  test('ISO 8601（UTCオフセット付き）はローカル時刻に変換して表示する', () {
    // 端末TZに依存しない検証: 生文字列がそのまま出ないこと・「取得」で終わること
    final s = formatTakenTime('2026-08-18T12:21:18.013844+00:00');
    expect(s.contains('T'), isFalse);
    expect(s.contains('+00:00'), isFalse);
    expect(s.contains('013844'), isFalse);
    expect(s.contains('取得'), isTrue);
  });

  test('オフセットなし（提供元JST表記）はそのままの時刻で表示する', () {
    final s = formatTakenTime('2000-01-02 10:15:26');
    expect(s, startsWith('1月2日 10:15'));
    expect(s.contains('取得'), isTrue);
    // 24時間以上前なので相対表記は付かない
    expect(s.contains('前'), isFalse);
  });

  test('直近の時刻には相対表記が付く', () {
    final recent = DateTime.now().subtract(const Duration(minutes: 5));
    final raw = '${recent.year}-'
        '${recent.month.toString().padLeft(2, '0')}-'
        '${recent.day.toString().padLeft(2, '0')} '
        '${recent.hour.toString().padLeft(2, '0')}:'
        '${recent.minute.toString().padLeft(2, '0')}:00';
    final s = formatTakenTime(raw);
    expect(s.contains('分前'), isTrue);
    // 同日なので日付は出ない
    expect(s.contains('月'), isFalse);
  });

  test('解釈できない文字列は原文のまま返す', () {
    expect(formatTakenTime('unknown'), 'unknown');
  });
}
