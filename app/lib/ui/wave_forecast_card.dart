import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/wave_forecast.dart';
import '../l10n/l10n.dart';
import '../models/camera.dart';

typedef WaveForecastLoader = Future<WaveForecast?> Function(Camera camera);

Future<WaveForecast?> _defaultLoader(Camera camera) => WaveForecasts.fetch(camera);

/// 海岸・港湾カメラ詳細の波の予報（気象庁の府県予報の一次細分区域単位）。
/// 予報が無い・取得に失敗したときは何も出さない（区切り線も出さない）
class WaveForecastCard extends StatefulWidget {
  const WaveForecastCard(
      {super.key, required this.camera, this.loader = _defaultLoader, this.resumeTick});

  final Camera camera;

  /// バックグラウンドからの復帰の合図。進んだら控えを捨てて取り直す
  final ValueListenable<int>? resumeTick;
  final WaveForecastLoader loader;

  @override
  State<WaveForecastCard> createState() => _WaveForecastCardState();
}

class _WaveForecastCardState extends State<WaveForecastCard> {
  late Future<WaveForecast?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(widget.camera);
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
    final next = widget.loader(widget.camera);
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return FutureBuilder<WaveForecast?>(
      future: _future,
      builder: (context, snap) {
        final f = snap.data;
        if (snap.connectionState != ConnectionState.done || f == null || f.days.isEmpty) {
          return const SizedBox.shrink();
        }
        final area = Localizations.localeOf(context).languageCode == 'en' && f.enName.isNotEmpty
            ? f.enName
            : f.name;
        String label(int off) => switch (off) {
              0 => l10n.waveDayToday,
              1 => l10n.waveDayTomorrow,
              _ => l10n.waveDayAfter,
            };
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.waves, size: 20, color: Color(0xFF1E6FD9)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l10n.waveTitle(area),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
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
          const SizedBox(height: 4),
          Text(l10n.waveNote, style: muted),
          const SizedBox(height: 4),
          Text(l10n.waveSource, style: muted),
          const Divider(height: 24),
        ]);
      },
    );
  }
}
