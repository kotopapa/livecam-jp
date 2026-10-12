import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/tide_level.dart';
import '../data/wave_forecast.dart';
import '../l10n/l10n.dart';
import '../models/camera.dart';

typedef WaveForecastLoader = Future<WaveForecast?> Function(Camera camera);

typedef TideLoader = Future<TideInfo?> Function(Camera camera);

Future<WaveForecast?> _defaultLoader(Camera camera) => WaveForecasts.fetch(camera);
Future<TideInfo?> _defaultTideLoader(Camera camera) => TideLevels.fetch(camera);

/// 海岸・港湾カメラ詳細の波の予報（気象庁の府県予報の一次細分区域単位）と、
/// 最寄り（30 km 以内）の潮位観測点の潮位。どちらか一方でもあれば出し、
/// 両方無い・取得に失敗したときは何も出さない（区切り線も出さない）
class WaveForecastCard extends StatefulWidget {
  const WaveForecastCard(
      {super.key,
      required this.camera,
      this.loader = _defaultLoader,
      this.tideLoader = _defaultTideLoader,
      this.resumeTick});

  final Camera camera;

  /// バックグラウンドからの復帰の合図。進んだら控えを捨てて取り直す
  final ValueListenable<int>? resumeTick;
  final WaveForecastLoader loader;
  final TideLoader tideLoader;

  @override
  State<WaveForecastCard> createState() => _WaveForecastCardState();
}

class _WaveForecastCardState extends State<WaveForecastCard> {
  late Future<(WaveForecast?, TideInfo?)> _future;

  Future<(WaveForecast?, TideInfo?)> _load() async {
    final r = await Future.wait<Object?>([
      widget.loader(widget.camera).catchError((_) => null),
      widget.tideLoader(widget.camera).catchError((_) => null),
    ]);
    return (r[0] as WaveForecast?, r[1] as TideInfo?);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.resumeTick?.addListener(_onResume);
  }

  @override
  void didUpdateWidget(WaveForecastCard old) {
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
    WaveForecasts.invalidate();
    TideLevels.invalidate();
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _height(AppLocalizations l10n, WaveHeight h) =>
      h.under ? l10n.waveUnder(_num(h.meters)) : l10n.waveMeters(_num(h.meters));

  /// 高さの並び＋接続語＋うねり
  static String seqText(AppLocalizations l10n, WaveSeq seq) {
    var text = _height(l10n, seq.heights.first);
    for (var i = 1; i < seq.heights.length; i++) {
      final next = _height(l10n, seq.heights[i]);
      text = switch (seq.connectors[i - 1]) {
        WaveConnector.then => l10n.waveThen(text, next),
        WaveConnector.sometimes => l10n.waveSometimes(text, next),
        WaveConnector.temporarily => l10n.waveTemporarily(text, next),
      };
    }
    return seq.swell ? l10n.waveSwell(text) : text;
  }

  /// 1日分の表示文。解析できなければ原文（日本語以外は「（日本語）」付き）
  static String dayText(AppLocalizations l10n, WaveDay day) {
    final p = day.parsed;
    if (p == null) return l10n.waveRaw(day.raw.replaceAll('　', ' ').trim());
    var text = seqText(l10n, p.main);
    final ex = p.exception;
    if (ex != null) {
      text = '$text\n${l10n.waveException(ex.place, seqText(l10n, ex.seq))}';
    }
    return text;
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _extremes(AppLocalizations l10n, List<TideExtreme> l) =>
      l.map((e) => l10n.tideItem(_hm(e.time), e.cm.toString())).join('・');

  Widget _waves(AppLocalizations l10n, WaveForecast f) {
    String label(int off) => switch (off) {
          0 => l10n.waveDayToday,
          1 => l10n.waveDayTomorrow,
          _ => l10n.waveDayAfter,
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final d in f.days)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 72,
              child: Text(label(d.dayOffset),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(dayText(l10n, d), style: const TextStyle(fontSize: 14))),
          ]),
        ),
    ]);
  }

  Widget _tide(AppLocalizations l10n, TideInfo t, TextStyle muted, {required bool gap}) {
    final highs = t.highs, lows = t.lows;
    const body = TextStyle(fontSize: 14);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (gap) const SizedBox(height: 10),
      Text(l10n.tideStation(t.stationName, t.distanceKm.toString()),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
        Text(l10n.tideNow(t.cm.toString(), _hm(t.at)),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (t.trend != null)
          Text(t.trend == TideTrend.rising ? l10n.tideRising : l10n.tideFalling, style: body),
      ]),
      if (highs.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(l10n.tideHighToday(_extremes(l10n, highs)), style: body),
      ],
      if (lows.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(l10n.tideLowToday(_extremes(l10n, lows)), style: body),
      ],
      const SizedBox(height: 4),
      Text(l10n.tideDatum, style: muted),
      if (t.extremes.isNotEmpty) Text(l10n.tideAstroNote, style: muted),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return FutureBuilder<(WaveForecast?, TideInfo?)>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        final f = data?.$1;
        final tide = data?.$2;
        final hasWave = f != null && f.days.isNotEmpty;
        if (snap.connectionState != ConnectionState.done || (!hasWave && tide == null)) {
          return const SizedBox.shrink();
        }
        final area = hasWave
            ? (Localizations.localeOf(context).languageCode == 'en' && f.enName.isNotEmpty
                ? f.enName
                : f.name)
            : '';
        final title = hasWave && tide != null
            ? l10n.waveTideTitle(area)
            : hasWave
                ? l10n.waveTitle(area)
                : l10n.tideTitle;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.waves, size: 20, color: Color(0xFF1E6FD9)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          if (hasWave) _waves(l10n, f),
          if (tide != null) _tide(l10n, tide, muted, gap: hasWave),
          const SizedBox(height: 4),
          if (hasWave) Text(l10n.waveNote, style: muted),
          if (tide != null) Text(l10n.tideDerived, style: muted),
          const SizedBox(height: 4),
          if (hasWave) Text(l10n.waveSource, style: muted),
          if (tide != null) Text(l10n.tideSource, style: muted),
          const Divider(height: 24),
        ]);
      },
    );
  }
}
