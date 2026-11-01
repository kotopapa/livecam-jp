import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/point_weather.dart';
import '../l10n/l10n.dart';
import '../models/camera.dart';
import '../util/jst.dart';

typedef PointWeatherLoader = Future<PointWeather?> Function(Camera camera);

Future<PointWeather?> _defaultLoader(Camera camera) => PointWeathers.fetch(camera);

const _hotColor = Color(0xFFE53935);
const _coldColor = Color(0xFF1E88E5);

/// 気象庁の天気マーク（同梱 PNG）。ダーク背景で沈まないよう薄い丸角の下地を敷く。
/// 無いコードは Material Icons の雲で代える
class WeatherIcon extends StatelessWidget {
  const WeatherIcon(this.code, {super.key, this.width = 36});
  final String? code;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 2 / 3;
    final c = code;
    if (c == null) return SizedBox(width: width + 6, height: h + 6);
    final base = weatherIconBase(c);
    final fallback = SizedBox(
        width: width, height: h, child: Icon(Icons.cloud, size: h * 0.8, color: Colors.grey));
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: base.isEmpty
          ? fallback
          : Image.asset('assets/weather/$base.png',
              width: width, height: h, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// カメラ詳細の「この地点の天気」。現在気温（最寄りアメダス）・3時間ごとの気温グラフと
/// 天気マーク・風・降水・週間予報（出典は気象庁）。取れた情報源の分だけ出し、
/// 全部無ければ区切り線ごと何も出さない
class PointWeatherCard extends StatefulWidget {
  const PointWeatherCard(
      {super.key, required this.camera, this.loader = _defaultLoader, this.resumeTick, this.now});

  final Camera camera;
  final PointWeatherLoader loader;

  /// バックグラウンドからの復帰の合図。進んだら控えを捨てて取り直す
  final ValueListenable<int>? resumeTick;

  /// 現在の絶対時刻（テスト用。通常は DateTime.now()）
  final DateTime? now;

  @override
  State<PointWeatherCard> createState() => _PointWeatherCardState();
}

class _PointWeatherCardState extends State<PointWeatherCard> {
  late Future<PointWeather?> _future;

  Future<PointWeather?> _load() =>
      widget.loader(widget.camera).catchError((_) => null as PointWeather?);

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.resumeTick?.addListener(_onResume);
  }

  @override
  void didUpdateWidget(PointWeatherCard old) {
    super.didUpdateWidget(old);
    if (old.resumeTick != widget.resumeTick) {
      old.resumeTick?.removeListener(_onResume);
      widget.resumeTick?.addListener(_onResume);
    }
  }

  @override
  void dispose() {
    widget.resumeTick?.removeListener(_onResume);
    super.dispose();
  }

  void _onResume() {
    PointWeathers.invalidate();
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  static const colW = 52.0;
  static const _timeH = 36.0;
  static const _chartH = 92.0;
  static const _axisW = 30.0;

  static String dirName(AppLocalizations l, int d) => switch (d) {
        1 => l.pwDir1, 2 => l.pwDir2, 3 => l.pwDir3, 4 => l.pwDir4,
        5 => l.pwDir5, 6 => l.pwDir6, 7 => l.pwDir7, 8 => l.pwDir8,
        9 => l.pwDir9, 10 => l.pwDir10, 11 => l.pwDir11, 12 => l.pwDir12,
        13 => l.pwDir13, 14 => l.pwDir14, 15 => l.pwDir15, 16 => l.pwDir16,
        _ => '',
      };

  /// 各列には短い形だけ（単位は凡例に1回）
  static String rainText(int r) => switch (r) {
        1 => '1-5',
        2 => '5-10',
        3 => '10-15',
        4 => '15-20',
        5 => '20+',
        _ => '',
      };

  static String snowText(int s) => switch (s) {
        1 => '1-3',
        2 => '3-6',
        3 => '6+',
        _ => '',
      };

  static String speedText(AppLocalizations l, WindStep w) {
    final a = w.minMs, b = w.maxMs;
    if (a == null || b == null) return '';
    return a == b ? '$a' : l.pwSpeedRange('$a', '$b');
  }

  static String weekday(AppLocalizations l, int w) => switch (w) {
        1 => l.pwWeekday1, 2 => l.pwWeekday2, 3 => l.pwWeekday3, 4 => l.pwWeekday4,
        5 => l.pwWeekday5, 6 => l.pwWeekday6, _ => l.pwWeekday7,
      };

  static String _two(int v) => v.toString().padLeft(2, '0');

  Widget _current(AppLocalizations l, AmedasNow a, TextStyle muted) {
    final items = <String>[];
    if (a.windMs != null) {
      final dir = a.windDir == null
          ? ''
          : a.windDir == 0
              ? l.pwCalm
              : dirName(l, a.windDir!);
      items.add(l.pwWindNow(dir, a.windMs!.toStringAsFixed(1)).replaceAll('  ', ' '));
    }
    if (a.precip1h != null) items.add(l.pwPrecipNow(a.precip1h!.toStringAsFixed(1)));
    if (a.humidity != null) items.add(l.pwHumidityNow('${a.humidity}'));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (a.temp != null)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text('${a.temp!.toStringAsFixed(1)}℃',
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w300, height: 1.1)),
        ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.pwObsTime('${_two(a.at.hour)}:${_two(a.at.minute)}'), style: muted),
          Text(l.pwNearStation(a.name, a.distanceKm.toString()), style: muted),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 10, runSpacing: 2, children: [
                for (final t in items) Text(t, style: const TextStyle(fontSize: 12)),
              ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _hourly(BuildContext context, AppLocalizations l, PointWeather pw,
      List<PointColumn> cols, TextStyle muted) {
    final scheme = Theme.of(context).colorScheme;
    final temps = [for (final c in cols) c.temp];
    final hasTemp = temps.any((t) => t != null);
    Widget rowOf(double h, Widget Function(PointColumn c, int i) cell) => SizedBox(
          height: h,
          child: Row(children: [
            for (var i = 0; i < cols.length; i++)
              SizedBox(width: colW, child: cell(cols[i], i)),
          ]),
        );
    final hasRain = cols.any((c) => (c.rain ?? 0) >= 1);
    final hasSnow = cols.any((c) => (c.snow ?? 0) >= 1);
    final hasPop = cols.any((c) => c.pop != null);
    final hasWind = cols.any((c) => c.wind != null && c.wind!.minMs != null);
    const small = TextStyle(fontSize: 10);
    final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final range = TempChartPainter.range(temps);
    final scroll = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      rowOf(_timeH, (c, i) {
        final w = toJstWallClock(c.validUtc);
        final showDate = i == 0 || w.hour < 3;
        return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(showDate ? '${w.month}/${w.day}' : '',
              style: small.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          Text(l.pwHour('${w.hour}'), style: const TextStyle(fontSize: 12)),
        ]);
      }),
      if (hasTemp)
        SizedBox(
          width: colW * cols.length,
          height: _chartH,
          child: CustomPaint(
            painter: TempChartPainter(
              temps: temps,
              colW: colW,
              lineColor: scheme.primary,
              gridColor: scheme.outlineVariant,
              textColor: scheme.onSurface,
              fontFamily: font,
            ),
          ),
        ),
      rowOf(32, (c, _) => Center(child: WeatherIcon(c.weatherCode))),
      if (hasRain)
        rowOf(15, (c, _) => Center(
            child: Text(rainText(c.rain ?? 0),
                style: const TextStyle(fontSize: 11, color: _coldColor), maxLines: 1, overflow: TextOverflow.clip))),
      if (hasSnow)
        rowOf(15, (c, _) => Center(
            child: Text(snowText(c.snow ?? 0),
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E24AA)), maxLines: 1, overflow: TextOverflow.clip))),
      if (hasPop)
        rowOf(14, (c, _) => Center(
            child: Text(c.pop == null ? '' : '${c.pop}%',
                style: small.copyWith(color: scheme.onSurfaceVariant)))),
      if (hasWind)
        rowOf(36, (c, _) {
          final w = c.wind;
          if (w == null || w.minMs == null) return const SizedBox.shrink();
          if (w.dir == null) {
            return Center(child: Text(speedText(l, w), style: small));
          }
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (w.dir == 0)
              Text(l.pwCalm, style: small.copyWith(fontSize: 9))
            else ...[
              Transform.rotate(
                  angle: (w.dir! * 22.5 + 180) * math.pi / 180,
                  child: Icon(Icons.navigation, size: 14, color: scheme.onSurfaceVariant)),
              Text(speedText(l, w), style: small),
            ],
          ]);
        }),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: scroll),
        ),
        if (hasTemp)
          SizedBox(
            width: _axisW,
            child: Column(children: [
              const SizedBox(height: _timeH),
              SizedBox(
                height: _chartH,
                child: CustomPaint(
                    size: const Size(_axisW, _chartH),
                    painter: TempAxisPainter(
                        range: range, textColor: scheme.onSurfaceVariant, fontFamily: font)),
              ),
            ]),
          ),
      ]),
      if (hasRain || hasSnow) Text(l.pwAmountLegend, style: muted),
      if (pw.tempIsRepresentative && pw.wind != null)
        Text(
            l.pwRepTemp(Localizations.localeOf(context).languageCode == 'en' &&
                    (pw.wind!.repEnName ?? '').isNotEmpty
                ? pw.wind!.repEnName!
                : (pw.wind!.repName ?? pw.wind!.areaName)),
            style: muted),
      if (hasWind && pw.wind != null)
        Text(
            l.pwWindLegend(Localizations.localeOf(context).languageCode == 'en' &&
                    pw.wind!.areaEnName.isNotEmpty
                ? pw.wind!.areaEnName
                : pw.wind!.areaName),
            style: muted),
    ]);
  }

  Widget _week(BuildContext context, AppLocalizations l, WeekForecast w, TextStyle muted) {
    final days = w.days.take(7).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (final d in days)
          Expanded(
            child: Column(children: [
              Text(weekday(l, d.day.weekday),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: d.day.weekday == 7
                          ? _hotColor
                          : d.day.weekday == 6
                              ? _coldColor
                              : null)),
              Text('${d.day.month}/${d.day.day}', style: muted.copyWith(fontSize: 10)),
              const SizedBox(height: 2),
              WeatherIcon(d.code, width: 40),
              Text(d.tempMax == null ? '—' : '${d.tempMax}°',
                  style: const TextStyle(fontSize: 13, color: _hotColor, fontWeight: FontWeight.w600)),
              Text(d.tempMin == null ? '—' : '${d.tempMin}°',
                  style: const TextStyle(fontSize: 13, color: _coldColor, fontWeight: FontWeight.w600)),
              Text(d.pop == null ? '' : '${d.pop}%', style: const TextStyle(fontSize: 11)),
            ]),
          ),
      ]),
      const SizedBox(height: 4),
      Text(
          w.stationName == null || w.stationName!.isEmpty
              ? l.pwWeekNoteArea(w.areaName)
              : l.pwWeekNote(w.areaName, w.stationName!),
          style: muted),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return FutureBuilder<PointWeather?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // 読み込み中は細い帯だけ（アニメーションにしない: 自動更新を持たない画面のテストが
          // 「保留中のアニメーションなし」を確かめている）
          return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                  height: 2,
                  child: ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)));
        }
        final pw = snap.data;
        if (pw == null || pw.isEmpty) return const SizedBox.shrink();
        final cols = pw.columns(widget.now ?? DateTime.now());
        final issued = pw.baseUtc ?? pw.wind?.reportedAt;
        String? issuedText;
        if (issued != null) {
          final w = toJstWallClock(issued);
          issuedText = l.pwIssued('${w.month}/${w.day} ${_two(w.hour)}:${_two(w.minute)}');
        }
        final week = pw.week;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.wb_sunny_outlined, size: 20, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l.pwTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Text(l.pwSourceShort, style: muted),
          ]),
          const SizedBox(height: 8),
          if (pw.amedas != null) ...[
            _current(l, pw.amedas!, muted),
            const SizedBox(height: 12),
          ],
          if (cols.isNotEmpty) ...[
            _hourly(context, l, pw, cols, muted),
            const SizedBox(height: 12),
          ],
          if (week != null && week.days.isNotEmpty) ...[
            _week(context, l, week, muted),
            const SizedBox(height: 8),
          ],
          Text(l.pwSource, style: muted),
          if (issuedText != null) Text(issuedText, style: muted),
          const Divider(height: 24),
        ]);
      },
    );
  }
}

/// 3時間ごとの気温の折れ線。最高点は赤、最低点は青の丸と値
class TempChartPainter extends CustomPainter {
  TempChartPainter({
    required this.temps,
    required this.colW,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    this.fontFamily,
  });

  final List<int?> temps;
  final double colW;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final String? fontFamily;

  static const pad = 20.0;

  /// 縦軸の (下端, 上端)（データの最低・最高。同じなら 1 度の幅を持たせる）
  static (int, int) range(List<int?> temps) {
    final v = temps.whereType<int>().toList();
    if (v.isEmpty) return (0, 1);
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    return (lo, hi == lo ? hi + 1 : hi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (lo, hi) = range(temps);
    final h = size.height - pad * 2;
    double y(int v) => pad + h * (1 - (v - lo) / (hi - lo));
    double x(int i) => colW * i + colW / 2;
    final grid = Paint()..color = gridColor..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, y(hi)), Offset(size.width, y(hi)), grid);
    canvas.drawLine(Offset(0, y(lo)), Offset(size.width, y(lo)), grid);
    // 日付が変わる所の縦線は時刻行の日付表示で足りるので引かない
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    var path = Path();
    var open = false;
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t == null) {
        if (open) canvas.drawPath(path, line);
        path = Path();
        open = false;
        continue;
      }
      final p = Offset(x(i), y(t));
      if (open) {
        path.lineTo(p.dx, p.dy);
      } else {
        path.moveTo(p.dx, p.dy);
        open = true;
      }
    }
    if (open) canvas.drawPath(path, line);
    final dot = Paint()..color = lineColor;
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t != null) canvas.drawCircle(Offset(x(i), y(t)), 2.5, dot);
    }
    void label(int i, int t, Color c, {required bool above}) {
      canvas.drawCircle(Offset(x(i), y(t)), 4.5, Paint()..color = c);
      final tp = TextPainter(
        text: TextSpan(
            text: '$t°',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: c, fontFamily: fontFamily)),
        textDirection: TextDirection.ltr,
      )..layout();
      final dy = above ? y(t) - 7 - tp.height : y(t) + 7;
      tp.paint(canvas, Offset(x(i) - tp.width / 2, dy));
    }

    final iMax = temps.indexWhere((t) => t == hi);
    final iMin = temps.indexWhere((t) => t == lo);
    if (iMax >= 0) label(iMax, hi, _hotColor, above: true);
    if (iMin >= 0 && (iMin != iMax)) label(iMin, lo, _coldColor, above: false);
  }

  @override
  bool shouldRepaint(TempChartPainter old) =>
      !listEquals(old.temps, temps) ||
      old.colW != colW ||
      old.lineColor != lineColor ||
      old.textColor != textColor;
}

/// 折れ線の右端の目盛り（上限・下限）
class TempAxisPainter extends CustomPainter {
  TempAxisPainter({required this.range, required this.textColor, this.fontFamily});
  final (int, int) range;
  final Color textColor;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - TempChartPainter.pad * 2;
    void tp(int v, double y) {
      final p = TextPainter(
        text: TextSpan(
            text: '$v°', style: TextStyle(fontSize: 10, color: textColor, fontFamily: fontFamily)),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, Offset(size.width - p.width, y - p.height / 2));
    }

    tp(range.$2, TempChartPainter.pad);
    tp(range.$1, TempChartPainter.pad + h);
  }

  @override
  bool shouldRepaint(TempAxisPainter old) => old.range != range || old.textColor != textColor;
}
