import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/config.dart';

/// config.dart の appVersion と pubspec.yaml の version（+ビルド番号の前）が一致すること。
/// 1.5.3 のリリースで定数の更新が漏れ、設定画面に 1.5.1 と表示された（2026-09-25）
void main() {
  test('appVersion は pubspec.yaml の version と一致する', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9.]+)\+\d+', multiLine: true).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec.yaml の version 行が読めない');
    expect(appVersion, m!.group(1));
  });
}
