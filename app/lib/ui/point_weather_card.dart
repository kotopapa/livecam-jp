import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/muni_warnings.dart';
import '../data/point_weather.dart';
import '../data/warning_levels.dart';
import '../l10n/l10n.dart';
import '../models/camera.dart';
import '../util/jst.dart';
import 'bosai_screen.dart' show jmaCityName;

typedef PointWeatherLoader = Future<PointWeather?> Function(Camera camera);

typedef MuniWarningLoader = Future<MuniWarnings?> Function(Camera camera);

Future<PointWeather?> _defaultLoader(Camera camera) => PointWeathers.fetch(camera);
Future<MuniWarnings?> _defaultWarningLoader(Camera camera) => MuniWarnings.fetch(camera);

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
      {super.key,
      required this.camera,
      this.loader = _defaultLoader,
      this.warningLoader = _defaultWarningLoader,
      this.onOpenWarningTab,
      this.resumeTick,
      this.now});

  /// 市区町村に発表中の警報・注意報（取れなくても他の部分は出す）
  final MuniWarningLoader warningLoader;

  /// 警報シートの「防災タブで見る」。null ならボタンを出さない
  final VoidCallback? onOpenWarningTab;

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
  late Future<MuniWarnings?> _wfuture;

  Future<PointWeather?> _load() =>
      widget.loader(widget.camera).then<PointWeather?>((v) => v, onError: (_) => null);

  Future<MuniWarnings?> _loadWarnings() =>
      widget.warningLoader(widget.camera).then<MuniWarnings?>((v) => v, onError: (_) => null);

  @override
  void initState() {
    super.initState();
    _future = _load();
    _wfuture = _loadWarnings();
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
    MuniWarnings.invalidate();
    final next = _load();
    final nextW = _loadWarnings();
    setState(() {
      _future = next;
      _wfuture = nextW;
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

  /// 各列に代表する数字 1 つ（3時間あたり。青=降水量、紫=降雪量）。
  /// 天気分布予報は階級（1-5 / 5-10 / 10-15 / 15-20 / 20以上 mm、1-3 / 3-6 / 6以上 cm）
  /// なので、気象庁の凡例のしきい値（階級の下限）を代表値にする（2026-11-02 ユーザー決定:
  /// レンジや「〜」「-」は出さない）
  static String rainText(int r) => switch (r) {
        1 => '1mm',
        2 => '5mm',
        3 => '10mm',
        4 => '15mm',
        5 => '20mm',
        _ => '',
      };

  static String snowText(int s) => switch (s) {
        1 => '1cm',
        2 => '3cm',
        3 => '6cm',
        _ => '',
      };

  static String weekday(AppLocalizations l, int w) => switch (w) {
        1 => l.pwWeekday1, 2 => l.pwWeekday2, 3 => l.pwWeekday3, 4 => l.pwWeekday4,
        5 => l.pwWeekday5, 6 => l.pwWeekday6, _ => l.pwWeekday7,
      };

  static String _two(int v) => v.toString().padLeft(2, '0');

  Widget _current(AppLocalizations l, AmedasNow a, TextStyle muted, Widget badge) {
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
          badge,
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

  /// 発表中の最上位の段階を1つのバッジで（無ければ何も出さない）。タップで一覧シート
  Widget _warningBadge({bool pad = false}) => FutureBuilder<MuniWarnings?>(
        future: _wfuture,
        builder: (context, snap) {
          final w = snap.data;
          if (w == null || w.codes.isEmpty) return const SizedBox.shrink();
          final l = context.l10n;
          final level = w.topLevel;
          final badge = Padding(
            padding: EdgeInsets.only(bottom: pad ? 8 : 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                key: const Key('point_weather_warning_badge'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showWarningSheet(context, w),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: warningBadgeColor(level),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(l.pwWarnBadge(levelName(l, level), '$level'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: warningBadgeTextColor(level))),
                ),
              ),
            ),
          );
          return badge;
        },
      );

  static String levelName(AppLocalizations l, int level) => switch (level) {
        5 => l.pwLevel5,
        4 => l.pwLevel4,
        3 => l.pwLevel3,
        _ => l.pwLevel2,
      };

  void _showWarningSheet(BuildContext context, MuniWarnings w) {
    final l = context.l10n;
    final issued = w.issuedAt == null ? null : toJstWallClock(w.issuedAt!);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.pwWarnSheetTitle(jmaCityName(w.cityName)),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in w.codes)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: warningBadgeColor(warningLevelOf(c)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(warningNameOf(l, c) ?? c,
                      style: TextStyle(
                          fontSize: 13,
                          color: warningBadgeTextColor(warningLevelOf(c)))),
                ),
            ]),
            if (issued != null) ...[
              const SizedBox(height: 8),
              Text(l.pwIssued('${issued.month}/${issued.day} ${_two(issued.hour)}:${_two(issued.minute)}'),
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(sheet).colorScheme.onSurfaceVariant)),
            ],
            if (widget.onOpenWarningTab != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    widget.onOpenWarningTab!();
                  },
                  child: Text(l.pwWarnOpenTab),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
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
      if (pw.tempIsRepresentative && pw.wind != null)
        Text(
            l.pwRepTemp(Localizations.localeOf(context).languageCode == 'en' &&
                    (pw.wind!.repEnName ?? '').isNotEmpty
                ? pw.wind!.repEnName!
                : (pw.wind!.repName ?? pw.wind!.areaName)),
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
            _current(l, pw.amedas!, muted, _warningBadge()),
            const SizedBox(height: 12),
          ] else
            _warningBadge(pad: true),
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
