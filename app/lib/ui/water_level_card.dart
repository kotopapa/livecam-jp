import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/water_level.dart';
import '../l10n/l10n.dart';
import '../models/camera.dart';
import '../util/jst.dart';

/// 基準水位の色（川の防災情報の段階色に合わせる。氾濫危険＝紫は危険警報と同じ）
const waterLevelColors = <String, Color>{
  'rsrv': Color(0xFF2E7D32), // 水防団待機
  'warn': Color(0xFFF9A825), // 氾濫注意
  'spcl': Color(0xFFE65100), // 避難判断
  'dng': Color(0xFF8E24AA), // 氾濫危険
};

typedef WaterLevelLoader = Future<(WaterStation?, WaterLevelSeries?)> Function(WaterLevelRef ref);

Future<(WaterStation?, WaterLevelSeries?)> _defaultLoader(WaterLevelRef ref) async {
  final station = await WaterStations.find(ref.obs);
  final series = await WaterLevel.fetch(ref.obs);
  return (station, series);
}

/// 河川カメラ詳細の水位グラフ（直近48時間＋基準水位）
class WaterLevelCard extends StatefulWidget {
  const WaterLevelCard({super.key, required this.camera, this.loader = _defaultLoader});

  final Camera camera;
  final WaterLevelLoader loader;

  @override
  State<WaterLevelCard> createState() => _WaterLevelCardState();
}

class _WaterLevelCardState extends State<WaterLevelCard> {
  late Future<(WaterStation?, WaterLevelSeries?)> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(widget.camera.waterLevel!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ref = widget.camera.waterLevel!;
    final muted = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        final station = snap.data?.$1;
        final series = snap.data?.$2;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.water, size: 20, color: Color(0xFF1E6FD9)),
            const SizedBox(width: 6),
            Text(l10n.waterLevelTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          if (station != null) ...[
            const SizedBox(height: 4),
            Text(l10n.waterLevelStation(station.name, ref.distM), style: muted),
          ],
          const SizedBox(height: 8),
          if (snap.connectionState != ConnectionState.done)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(children: [
                const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(l10n.waterLevelLoading, style: muted),
              ]),
            )
          else if (series == null || series.isEmpty)
            Text(l10n.waterLevelNoData, style: muted)
          else ...[
            if (series.latest != null)
              Text(
                l10n.waterLevelLatest(
                    series.latest!.stage.toStringAsFixed(2), _fmtTime(series.latest!.time)),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 6),
            Text(l10n.waterLevelLast48h, style: muted),
            const SizedBox(height: 4),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: WaterLevelChartPainter(
                  points: series.points,
                  forecast: series.forecast,
                  levels: station?.levels ?? const {},
                  nowJst: jstNow(),
                  textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  gridColor: Theme.of(context).dividerColor,
                ),
              ),
            ),
            if (station != null && station.levels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 4, children: [
                for (final key in const ['rsrv', 'warn', 'spcl', 'dng'])
                  if (station.levels[key] != null)
                    _LevelLegend(
                      color: waterLevelColors[key]!,
                      label: _levelLabel(l10n, key),
                      value: station.levels[key]!,
                    ),
              ]),
            ],
          ],
          const SizedBox(height: 8),
          Text(l10n.waterLevelNote, style: muted),
          const SizedBox(height: 4),
          Text(l10n.waterLevelSource, style: muted),
          if (station != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () => launchUrl(station.siteUrl, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l10n.waterLevelOpenSite),
            ),
        ]);
      },
    );
  }

  static String _fmtTime(DateTime t) =>
      '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _levelLabel(AppLocalizations l10n, String key) => switch (key) {
        'rsrv' => l10n.waterLevelRsrv,
        'warn' => l10n.waterLevelWarn,
        'spcl' => l10n.waterLevelSpcl,
        _ => l10n.waterLevelDng,
      };
}

class _LevelLegend extends StatelessWidget {
  const _LevelLegend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 3, color: color),
      const SizedBox(width: 4),
      Text('$label ${value.toStringAsFixed(2)}m',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

/// 折れ線グラフ。横軸は直近48時間（右端が現在）、縦軸は水位。基準水位を横線で引く
class WaterLevelChartPainter extends CustomPainter {
  WaterLevelChartPainter({
    required this.points,
    required this.levels,
    required this.nowJst,
    required this.textColor,
    required this.gridColor,
    this.forecast = const [],
  });

  final List<WaterLevelPoint> points;
  final List<WaterLevelPoint> forecast;
  final Map<String, double> levels;
  final DateTime nowJst;
  final Color textColor;
  final Color gridColor;

  static const _left = 40.0;
  static const _bottom = 22.0;
  static const _top = 8.0;

  /// 縦軸の範囲。観測値の範囲に、その上にある最初の基準水位までを含める
  (double, double) yRange() {
    final all = [...points, ...forecast];
    if (all.isEmpty) return (0, 1);
    var lo = all.map((p) => p.stage).reduce((a, b) => a < b ? a : b);
    var hi = all.map((p) => p.stage).reduce((a, b) => a > b ? a : b);
    final above = levels.values.where((v) => v > hi).toList()..sort();
    if (above.isNotEmpty) hi = above.first;
    final below = levels.values.where((v) => v <= hi && v >= lo).toList();
    if (below.isNotEmpty) lo = [lo, ...below].reduce((a, b) => a < b ? a : b);
    final pad = (hi - lo) * 0.15;
    return (lo - (pad == 0 ? 0.5 : pad), hi + (pad == 0 ? 0.5 : pad));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _left;
    final chartH = size.height - _bottom - _top;
    if (chartW <= 0 || chartH <= 0) return;
    final (yLo, yHi) = yRange();
    // 横軸: 直近48時間。予測があればその先まで延ばし、現在時刻に縦線を引く
    final tStart = nowJst.subtract(WaterLevel.window);
    var tEnd = nowJst;
    if (forecast.isNotEmpty && forecast.last.time.isAfter(tEnd)) tEnd = forecast.last.time;
    final total = tEnd.difference(tStart).inMinutes.toDouble();
    double x(DateTime t) => _left + chartW * (t.difference(tStart).inMinutes / total).clamp(0.0, 1.0);
    double y(double v) => _top + chartH * (1 - (v - yLo) / (yHi - yLo));

    final grid = Paint()..color = gridColor..strokeWidth = 1;
    void tp(String s, Offset at, {TextAlign align = TextAlign.left}) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: textColor)),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      final dx = align == TextAlign.right ? at.dx - painter.width
          : align == TextAlign.center ? at.dx - painter.width / 2 : at.dx;
      painter.paint(canvas, Offset(dx, at.dy));
    }

    // 縦軸: 4本の目盛り
    for (var i = 0; i <= 4; i++) {
      final v = yLo + (yHi - yLo) * i / 4;
      final yy = y(v);
      canvas.drawLine(Offset(_left, yy), Offset(size.width, yy), grid);
      tp(v.toStringAsFixed(1), Offset(_left - 4, yy - 6), align: TextAlign.right);
    }
    // 横軸: 12時間ごと
    for (var h = 0; h <= 48; h += 12) {
      final t = tStart.add(Duration(hours: h));
      final xx = x(t);
      canvas.drawLine(Offset(xx, _top), Offset(xx, _top + chartH), grid);
      final label = '${t.month}/${t.day} ${t.hour}:00';
      tp(label, Offset(xx, size.height - _bottom + 4),
          align: h == 0 ? TextAlign.left : (h == 48 && tEnd == nowJst ? TextAlign.right : TextAlign.center));
    }
    if (tEnd != nowJst) {
      final xx = x(nowJst);
      canvas.drawLine(Offset(xx, _top), Offset(xx, _top + chartH),
          Paint()..color = textColor.withValues(alpha: 0.5)..strokeWidth = 1);
    }
    // 基準水位
    for (final e in levels.entries) {
      final color = waterLevelColors[e.key];
      if (color == null || e.value < yLo || e.value > yHi) continue;
      final yy = y(e.value);
      canvas.drawLine(Offset(_left, yy), Offset(size.width, yy),
          Paint()..color = color..strokeWidth = 1.5);
    }
    // 観測値
    if (points.isNotEmpty) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final o = Offset(x(points[i].time), y(points[i].stage));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF1E6FD9)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);
      final last = points.last;
      canvas.drawCircle(Offset(x(last.time), y(last.stage)), 3.5, Paint()..color = const Color(0xFF1E6FD9));
    }
    // 予測（破線の代わりに薄い線）
    if (forecast.isNotEmpty) {
      final path = Path();
      final start = points.isEmpty ? forecast.first : points.last;
      path.moveTo(x(start.time), y(start.stage));
      for (final p in forecast) {
        path.lineTo(x(p.time), y(p.stage));
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0x881E6FD9)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant WaterLevelChartPainter old) =>
      old.points != points || old.levels != levels || old.nowJst != nowJst || old.forecast != forecast;
}
