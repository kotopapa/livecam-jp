import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/ui/camera_thumb.dart';

import 'l10n_test_app.dart';

/// 読み込みの完了をテストから操れる画像。load のたびに新しい Completer を作る。
class _ControlledImage extends ImageProvider<_ControlledImage> {
  _ControlledImage(this.log);
  final List<Completer<ImageInfo>> log;

  @override
  Future<_ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ControlledImage>(this);

  @override
  ImageStreamCompleter loadImage(_ControlledImage key, ImageDecoderCallback decode) {
    final c = Completer<ImageInfo>();
    log.add(c);
    return OneFrameImageStreamCompleter(c.future);
  }
}

Future<ui.Image> _pixel(WidgetTester tester) async =>
    (await tester.runAsync(() => createTestImage(width: 1, height: 1)))!;

Widget _host(List<Completer<ImageInfo>> log) {
  final provider = _ControlledImage(log);
  return testApp(Scaffold(
    body: Center(
      child: SizedBox(
        width: 72,
        height: 48,
        // cacheWidth: 0 は縮小デコードを挟まない（テスト用の画像をそのまま流す）
        child: CameraThumb(
            url: 'https://example.invalid/a.jpg',
            cacheWidth: 0,
            providerBuilder: (_) => provider),
      ),
    ),
  ));
}

void main() {
  setUp(() => PaintingBinding.instance.imageCache.clear());

  testWidgets('読み込み中はスピナー、届いたら画像を出す', (tester) async {
    final log = <Completer<ImageInfo>>[];
    final image = await _pixel(tester);
    await tester.pumpWidget(_host(log));
    expect(log, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    log.single.complete(ImageInfo(image: image));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);

    // 届いたあとは時間切れにならない
    await tester.pump(const Duration(seconds: 30));
    expect(log, hasLength(1));
    expect(find.byIcon(Icons.refresh), findsNothing);
  });

  testWidgets('10 秒届かなければ 1 回だけ取り直し、それでも駄目なら再読み込みアイコン', (tester) async {
    final log = <Completer<ImageInfo>>[];
    await tester.pumpWidget(_host(log));
    expect(log, hasLength(1));

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(log, hasLength(2), reason: '自動の取り直しは 1 回');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(log, hasLength(2), reason: '2 回目の時間切れでは取り直さない');
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('再読み込みアイコンのタップで取り直す', (tester) async {
    final log = <Completer<ImageInfo>>[];
    final image = await _pixel(tester);
    await tester.pumpWidget(_host(log));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('camera_thumb_reload')));
    await tester.pump();
    expect(log, hasLength(3));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    log.last.complete(ImageInfo(image: image));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('取得に失敗したら自動では取り直さず、再読み込みアイコンにする', (tester) async {
    final log = <Completer<ImageInfo>>[];
    await tester.pumpWidget(_host(log));
    log.single.completeError(Exception('HTTP 503'));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(log, hasLength(1));
    tester.takeException();
  });
}
