import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// 一覧のサムネイル。読み込み中はスピナーを出し、[timeout] 待っても 1 枚も
/// 届かなければ 1 回だけ自動で取り直す。それでも出ないとき・取得に失敗したときは
/// 再読み込みアイコンにして、タップで取り直せるようにする。
///
/// 2026-11 の報告（4G の出先で一覧のサムネイルが空白のまま）への対策。
/// Image.network には時間切れが無く、接続が詰まると空白のまま待ち続けていた。
/// 取得に失敗した（HTTP エラー等）ときは自動では取り直さない（提供元への
/// リクエストを増やさないため）。
class CameraThumb extends StatefulWidget {
  const CameraThumb({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth = 216,
    this.iconSize = 20,
    this.timeout = const Duration(seconds: 10),
    this.providerBuilder,
  });

  final String url;
  final BoxFit fit;

  /// 表示サイズに合わせた縮小デコード幅（フル解像度 8MB 級のデコードを防ぐ）
  final int cacheWidth;
  final double iconSize;
  final Duration timeout;

  /// テスト用。既定は NetworkImage
  @visibleForTesting
  final ImageProvider Function(String url)? providerBuilder;

  @override
  State<CameraThumb> createState() => _CameraThumbState();
}

class _CameraThumbState extends State<CameraThumb> {
  static const _maxAutoRetry = 1;

  late ImageProvider _provider;
  Timer? _timer;
  int _attempt = 0; // Image のキー。取り直すたびに増やす
  int _autoRetries = 0;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(CameraThumb old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.cacheWidth != widget.cacheWidth) {
      _autoRetries = 0;
      _attempt++;
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final base =
        widget.providerBuilder?.call(widget.url) ?? NetworkImage(widget.url);
    _provider = ResizeImage.resizeIfNeeded(widget.cacheWidth, null, base);
    _loaded = false;
    _failed = false;
    _timer?.cancel();
    _timer = Timer(widget.timeout, _onTimeout);
  }

  void _onTimeout() {
    if (!mounted || _loaded) return;
    // 待ち続けている読み込みをキャッシュから外す（同じ URL の取り直しが、
    // 詰まったままの読み込みにぶら下がらないようにする）
    _provider.evict();
    setState(() {
      if (_autoRetries < _maxAutoRetry) {
        _autoRetries++;
        _attempt++;
        _start();
      } else {
        _failed = true;
      }
    });
  }

  void _reload() {
    _provider.evict();
    setState(() {
      _autoRetries = 0;
      _attempt++;
      _start();
    });
  }

  void _onError() {
    _timer?.cancel();
    if (_failed) return;
    // errorBuilder（build 中）から呼ばれるので、状態の更新は次のフレームへ回す
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed && !_loaded) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_failed) return _failedBox(context, scheme);
    return Image(
      key: ValueKey(_attempt),
      image: _provider,
      fit: widget.fit,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          _loaded = true;
          _timer?.cancel();
          return child;
        }
        return Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: SizedBox(
            width: widget.iconSize * 0.8,
            height: widget.iconSize * 0.8,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) {
        _onError();
        return _failedBox(context, scheme);
      },
    );
  }

  Widget _failedBox(BuildContext context, ColorScheme scheme) {
    return Semantics(
      button: true,
      label: context.l10n.commonRetry,
      child: GestureDetector(
        key: const ValueKey('camera_thumb_reload'),
        behavior: HitTestBehavior.opaque,
        onTap: _reload,
        child: Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.refresh,
            size: widget.iconSize,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
