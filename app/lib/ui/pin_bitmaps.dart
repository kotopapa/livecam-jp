import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import 'pin_style.dart';

/// GoogleMap の [gmaps.Marker] はウィジェットではなく [gmaps.BitmapDescriptor]
/// (画像)しか受け付けないため、[CameraPin] / [ClusterPin] と同じ見た目を
/// dart:ui の Canvas で描いて PNG 化する（第1段階。map_screen.dart から使う）。
///
/// キー（カテゴリ・動画・お気に入り・位置未確定・凍結・選択）ごとに生成結果を
/// メモ化する。生成は非同期のため、未生成のキーは呼び出し側が
/// [gmaps.BitmapDescriptor.defaultMarker] を仮に使い、生成完了時に [onReady] で
/// 再描画を促す。
class PinBitmaps {
  PinBitmaps(this.devicePixelRatio);

  final double devicePixelRatio;

  /// タップ領域と同じ 44×44（論理px）のキャンバスに描く。ピン本体(26)や
  /// クラスタ(40)はその中央に収まり、バッジ（LIVEドット・お気に入り星）は
  /// 論理座標のまま四隅にわずかに掛かる（CameraPin の Stack と同じ配置）
  static const double canvasSize = 44;

  final Map<String, gmaps.BitmapDescriptor> _cache = {};
  final Set<String> _pending = {};

  String _cameraKey({
    required String category,
    required bool isVideo,
    required bool favorite,
    required bool uncertain,
    required bool frozen,
    required bool selected,
  }) =>
      'cam|$category|$isVideo|$favorite|$uncertain|$frozen|$selected';

  String _clusterKey(String label) => 'cluster|$label';

  /// カメラピンの画像。未生成なら null を返し、裏で生成を始める
  /// （完了したら [onReady] を呼ぶので、呼び出し側は setState などで再描画する）
  gmaps.BitmapDescriptor? cameraPin({
    required String category,
    bool isVideo = false,
    bool favorite = false,
    bool uncertain = false,
    bool frozen = false,
    bool selected = false,
    VoidCallback? onReady,
  }) {
    final key = _cameraKey(
      category: category,
      isVideo: isVideo,
      favorite: favorite,
      uncertain: uncertain,
      frozen: frozen,
      selected: selected,
    );
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_pending.add(key)) {
      _renderCameraPin(
        category: category,
        isVideo: isVideo,
        favorite: favorite,
        uncertain: uncertain,
        frozen: frozen,
        selected: selected,
      ).then((bmp) {
        _cache[key] = bmp;
        _pending.remove(key);
        onReady?.call();
      });
    }
    return null;
  }

  /// クラスタ（件数バッジ）ピンの画像。[label] は表示文字列
  /// （1000以上は呼び出し側で "Nk" にまとめた文字列を渡す）
  gmaps.BitmapDescriptor? clusterPin(String label, {VoidCallback? onReady}) {
    final key = _clusterKey(label);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_pending.add(key)) {
      _renderClusterPin(label).then((bmp) {
        _cache[key] = bmp;
        _pending.remove(key);
        onReady?.call();
      });
    }
    return null;
  }

  /// 初期化時にありがちな組合せ（9カテゴリ×静止画/動画、お気に入り等は無し）を
  /// まとめて先読みしておく。呼ばなくても遅延生成されるが、初回表示での
  /// 「一瞬既定ピンが見える」頻度を減らせる
  Future<void> preloadCommon({VoidCallback? onReady}) async {
    for (final category in categoryKeys) {
      for (final isVideo in [false, true]) {
        cameraPin(category: category, isVideo: isVideo, onReady: onReady);
      }
    }
  }

  Future<gmaps.BitmapDescriptor> _renderCameraPin({
    required String category,
    required bool isVideo,
    required bool favorite,
    required bool uncertain,
    required bool frozen,
    required bool selected,
  }) async {
    final color = categoryColor(category);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // 以降は canvasSize(44) を単位とした論理px座標で描く。toImage は
    // devicePixelRatio 倍のピクセル数を指定するだけで自動的にはスケールしない
    // ため、ここで明示的に拡大しておく（さもないと高dprの端末で画像の左上
    // 隅にだけ小さく描かれてしまう）
    canvas.scale(devicePixelRatio);
    const c = canvasSize / 2;
    const r = pinDiameter / 2;

    // 影（BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0,1))相当）
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(const Offset(c, c + 1), r, shadowPaint);

    // 本体
    canvas.drawCircle(const Offset(c, c), r, Paint()..color = color);
    final borderColor = uncertain
        ? uncertainBorderColor
        : (selected ? Colors.black87 : Colors.white);
    final borderWidth = uncertain ? 3.0 : 2.0;
    canvas.drawCircle(
      const Offset(c, c),
      r - borderWidth / 2,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // 中央のカテゴリ記号（丸の直径の約55%。CameraPin と同じ比率）
    final glyphSize = pinDiameter * 0.55;
    canvas.save();
    canvas.translate(c - glyphSize / 2, c - glyphSize / 2);
    _paintGlyph(canvas, category, glyphSize, Colors.white);
    canvas.restore();

    // 動画のLIVEドット（右上）: Positioned(top:-2, right:-2, size:10)。
    // Positioned(top:-2,right:-2) は「ピン本体(26)の右上隅から2pxだけ外側」。
    // 本体の右上隅 = (c+r, c-r)。ドット中心はそこから (dotSize/2-2) だけ外側
    if (isVideo) {
      const dotSize = 10.0;
      // 旧 CameraPin の Positioned(top:-2, right:-2) と同じ位置＝丸の中心から右上へ (+10, -10)
      final center = Offset(c + r - 3, c - r + 3);
      canvas.drawCircle(center, dotSize / 2, Paint()..color = liveDotColor);
      canvas.drawCircle(
        center,
        dotSize / 2 - 0.75,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // お気に入りの星（左上）: Positioned(top:-5, left:-5, size:13)
    if (favorite) {
      const starSize = 13.0;
      final center = Offset(c - r + starSize / 2 - 5, c - r + starSize / 2 - 5);
      _paintStar(canvas, center, starSize);
    }

    final picture = recorder.endRecording();
    final px = (canvasSize * devicePixelRatio).round();
    final image = await picture.toImage(px, px);
    final bytes = frozen
        ? await _withOpacity(image, px, 0.45) // CameraPin の Opacity(0.45) 相当
        : await image.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  /// 描き終えた画像を alpha 掛けで再描画して半透明を焼き込む（frozen 表示用）
  Future<ByteData?> _withOpacity(ui.Image image, int px, double opacity) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final layerPaint = Paint()..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.saveLayer(Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()), layerPaint);
    canvas.drawImage(image, Offset.zero, Paint());
    canvas.restore();
    final picture = recorder.endRecording();
    final out = await picture.toImage(px, px);
    return out.toByteData(format: ui.ImageByteFormat.png);
  }

  Future<gmaps.BitmapDescriptor> _renderClusterPin(String label) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio); // 理由は _renderCameraPin のコメント参照
    const c = canvasSize / 2;
    const r = clusterPinDiameter / 2;

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(const Offset(c, c + 1), r, shadowPaint);

    canvas.drawCircle(const Offset(c, c), r, Paint()..color = const Color(0xFF1E6FD9));
    canvas.drawCircle(
      const Offset(c, c),
      r - 1,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c - tp.width / 2, c - tp.height / 2));

    final picture = recorder.endRecording();
    final px = (canvasSize * devicePixelRatio).round();
    final image = await picture.toImage(px, px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  /// カテゴリ記号を [size] 四方に描く。Material Icons はグリフをテキストとして
  /// 描き、河川・ダムは pin_style.dart の自前ペインタをそのまま流用する
  void _paintGlyph(Canvas canvas, String category, double size, Color color) {
    final icon = categoryIcon(category);
    if (icon == null) {
      final painter = category == 'dam' ? DamGlyphPainter(color) : RiverGlyphPainter(color);
      painter.paint(canvas, Size.square(size));
      return;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  }

  void _paintStar(Canvas canvas, Offset center, double size) {
    // Icons.star を塗りで直接描く（TextPainter経由。#FFB300、CameraPin と同色）
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.star.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: Icons.star.fontFamily,
          color: const Color(0xFFFFB300),
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  // ===========================================================================
  // ベクタ系レイヤー（震源・台風・避難場所・防災拠点・地下道冠水・道路規制・
  // 通行止め統合・24時間雨量の観測値ラベル）のピン画像（GoogleMap移行 第3段階）。
  // カメラピンと同じ「キーで生成結果をメモ化、未生成は null を返して裏で生成」の
  // 仕組みを [_cachedOrRender] に共通化して使う。
  // ===========================================================================

  gmaps.BitmapDescriptor? _cachedOrRender(
    String key,
    VoidCallback? onReady,
    Future<gmaps.BitmapDescriptor> Function() render,
  ) {
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_pending.add(key)) {
      render().then((bmp) {
        _cache[key] = bmp;
        _pending.remove(key);
        onReady?.call();
      });
    }
    return null;
  }

  /// 描いた Picture を PNG 化して [gmaps.BitmapDescriptor] にする（キャンバスは
  /// [width]×[height] の論理px。実ピクセル数は devicePixelRatio 倍にする）
  Future<gmaps.BitmapDescriptor> _toDescriptor(
      ui.PictureRecorder recorder, double width, double height) async {
    final picture = recorder.endRecording();
    final pw = math.max(1, (width * devicePixelRatio).round());
    final ph = math.max(1, (height * devicePixelRatio).round());
    final image = await picture.toImage(pw, ph);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  void _paintIconCentered(
      Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _paintTextCentered(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  // --- 避難場所（緑）・防災拠点（種別で色分け）・震源（震度色）・台風・
  //     地下道冠水／道路規制／通行止め統合（丸＋任意で下にラベル）共通 ---

  static const double _dotMargin = 3;
  static const double _dotLabelGap = 2;
  static const double _dotLabelBoxH = 13;
  static const double _dotLabelPadH = 4;
  static const double _dotLabelMaxTextWidth = 110;

  static double _dotCenterY(double diameter) => _dotMargin + diameter / 2;

  static double _dotCanvasHeight(double diameter, bool hasLabel) =>
      _dotMargin + diameter + (hasLabel ? _dotLabelGap + _dotLabelBoxH + _dotMargin : _dotMargin);

  /// [dotGlyph] が返す画像に対応する `Marker.anchor`。ラベルが無ければ丸は
  /// キャンバス中央（=0.5,0.5、旧 flutter_map の Marker(center基準) と同じ見た目）。
  /// ラベルがあるときは、旧実装（Marker全体の中心に実座標を合わせるため、
  /// 内容によって丸の位置と実座標がずれていた）と違い、**丸の中心を実座標に
  /// 一致させる**（ビットマップ生成を待たずに同期で求められるよう、丸の直径と
  /// ラベル有無だけで決まる式にしてある）
  static Offset dotGlyphAnchor({required double diameter, bool hasLabel = false}) {
    final h = _dotCanvasHeight(diameter, hasLabel);
    return Offset(0.5, _dotCenterY(diameter) / h);
  }

  /// 丸ドット（塗り・縁・中央のアイコンかテキスト）＋任意で下にラベル（地点名等）の
  /// 複合ピン。マーカーの anchor は [dotGlyphAnchor] を使うこと
  gmaps.BitmapDescriptor? dotGlyph({
    required Color fillColor,
    required Color borderColor,
    double borderWidth = 2,
    required double diameter,
    IconData? icon,
    double iconScale = 0.6,
    Color iconColor = Colors.white,
    String? text,
    TextStyle? textStyle,
    bool shadow = true,
    bool innerRing = false,
    String? label,
    Color labelColor = Colors.black87,
    VoidCallback? onReady,
  }) {
    final hasLabel = label != null && label.isNotEmpty;
    final key = 'dot|$fillColor|$borderColor|$borderWidth|$diameter|${icon?.codePoint}|'
        '$iconScale|$iconColor|$text|${textStyle?.fontSize}|${textStyle?.color}|'
        '$shadow|$innerRing|${hasLabel ? label : null}|$labelColor';
    return _cachedOrRender(
      key,
      onReady,
      () => _renderDotGlyph(
        fillColor: fillColor,
        borderColor: borderColor,
        borderWidth: borderWidth,
        diameter: diameter,
        icon: icon,
        iconScale: iconScale,
        iconColor: iconColor,
        text: text,
        textStyle: textStyle,
        shadow: shadow,
        innerRing: innerRing,
        label: hasLabel ? label : null,
        labelColor: labelColor,
      ),
    );
  }

  Future<gmaps.BitmapDescriptor> _renderDotGlyph({
    required Color fillColor,
    required Color borderColor,
    required double borderWidth,
    required double diameter,
    IconData? icon,
    required double iconScale,
    required Color iconColor,
    String? text,
    TextStyle? textStyle,
    required bool shadow,
    required bool innerRing,
    String? label,
    required Color labelColor,
  }) async {
    final hasLabel = label != null && label.isNotEmpty;
    TextPainter? labelTp;
    if (hasLabel) {
      labelTp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: _dotLabelMaxTextWidth);
    }
    final labelBoxW = labelTp == null ? 0.0 : labelTp.width + _dotLabelPadH * 2;
    final width = math.max(diameter + _dotMargin * 2, labelBoxW + _dotMargin * 2);
    final height = _dotCanvasHeight(diameter, hasLabel);
    final cx = width / 2;
    final dotCenterY = _dotCenterY(diameter);
    final r = diameter / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);
    if (shadow) {
      canvas.drawCircle(
        Offset(cx, dotCenterY + 1),
        r,
        Paint()
          ..color = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawCircle(Offset(cx, dotCenterY), r, Paint()..color = fillColor);
    if (borderWidth > 0) {
      canvas.drawCircle(
        Offset(cx, dotCenterY),
        math.max(r - borderWidth / 2, 0),
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
    if (innerRing) {
      // 指定避難所の内側リング（_ShelterPin の designated 相当）
      canvas.drawCircle(
        Offset(cx, dotCenterY),
        math.max(r - 3.2, 0),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    if (icon != null) {
      _paintIconCentered(canvas, icon, Offset(cx, dotCenterY), diameter * iconScale, iconColor);
    } else if (text != null && text.isNotEmpty) {
      _paintTextCentered(
        canvas,
        text,
        Offset(cx, dotCenterY),
        textStyle ?? const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
      );
    }
    if (labelTp != null) {
      final by = _dotMargin + diameter + _dotLabelGap;
      final bx = cx - labelBoxW / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, labelBoxW, _dotLabelBoxH), const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      labelTp.paint(canvas, Offset(bx + _dotLabelPadH, by + (_dotLabelBoxH - labelTp.height) / 2));
    }
    return _toDescriptor(recorder, width, height);
  }

  // --- ラベルだけの吹き出し（丸背景なし。台風の予報時間・24時間雨量の観測値） ---

  /// 常に画像の中心（anchor 0.5,0.5）が実座標になる
  gmaps.BitmapDescriptor? labelBadge({
    required String text,
    required Color textColor,
    Color bg = const Color(0xD9FFFFFF),
    double fontSize = 10,
    bool border = false,
    Color borderColor = Colors.black54,
    VoidCallback? onReady,
  }) {
    final key = 'label|$text|$textColor|$bg|$fontSize|$border|$borderColor';
    return _cachedOrRender(
      key,
      onReady,
      () => _renderLabelBadge(
        text: text,
        textColor: textColor,
        bg: bg,
        fontSize: fontSize,
        border: border,
        borderColor: borderColor,
      ),
    );
  }

  Future<gmaps.BitmapDescriptor> _renderLabelBadge({
    required String text,
    required Color textColor,
    required Color bg,
    required double fontSize,
    required bool border,
    required Color borderColor,
  }) async {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padH = 4.0, padV = 1.0;
    final width = tp.width + padH * 2;
    final height = tp.height + padV * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height), const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = bg);
    if (border) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    tp.paint(canvas, Offset(padH, padV));
    return _toDescriptor(recorder, width, height);
  }
}
