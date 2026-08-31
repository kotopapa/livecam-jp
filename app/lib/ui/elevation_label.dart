import 'package:flutter/material.dart';

import '../data/elevation.dart';
import '../l10n/l10n.dart';

/// 「標高 3.4m（国土地理院）」の1行。
///
/// 表示のたびに国土地理院の標高APIを**1回だけ**呼ぶ（同じ座標は
/// [Elevation] のメモリキャッシュから返るためリクエストは発生しない）。
/// 取得中は控えめなプレースホルダ、データ無し・取得失敗は行ごと消える。
class ElevationLabel extends StatefulWidget {
  const ElevationLabel({
    super.key,
    required this.lat,
    required this.lng,
    this.fontSize = 12,
    this.color,
  });

  final double lat;
  final double lng;
  final double fontSize;
  final Color? color;

  @override
  State<ElevationLabel> createState() => _ElevationLabelState();
}

class _ElevationLabelState extends State<ElevationLabel> {
  double? _m;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final cached = Elevation.cached(widget.lat, widget.lng);
    if (Elevation.isCached(widget.lat, widget.lng)) {
      _m = cached;
      _done = true;
      return;
    }
    Elevation.fetch(widget.lat, widget.lng).then((v) {
      if (!mounted) return;
      setState(() {
        _m = v;
        _done = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.grey[700];
    if (!_done) {
      // 取得中：確定後と同じ高さで控えめに置いておく（行のガタつきを避ける）
      return Text(context.l10n.elevationLoading,
          style: TextStyle(fontSize: widget.fontSize, color: Colors.grey[400]));
    }
    final m = _m;
    if (m == null) return const SizedBox.shrink(); // データ無し・失敗は出さない
    // 出典表記（Elevation.attribution）は原語のまま（SPEC C5 / 政府標準利用規約）
    return Text(
        context.l10n.elevationValue(Elevation.format(m), Elevation.attribution),
        style: TextStyle(fontSize: widget.fontSize, color: color));
  }
}
