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

/// 天気の種別（タイルの色とマークの対応）
enum WxKind { sun, cloud, rain, snow, sleet, thunder }

/// 天気マーク（Meteocons、Bas Milius、MIT。同梱 PNG）。
///
/// 組み合わせの表し方はウェザーニュースの天気マークに倣う（2026-11-03 ユーザー要望）:
/// - 「のち」は 1 枚の正方形タイルを斜めに 2 分割し、左上に前半・右下に後半の色とマークを置く
/// - 「時々・一時」は主の天気の色とマークに、右下の小さな三角で副の天気の色とマークを添える
/// - 雪は必ず雪だるま。雨は 10mm/3h 以上で雨粒の多いマーク。下地の濃さは雨・雪の階級で変える
/// 無いコードは Material Icons の雲で代える
class WeatherIcon extends StatelessWidget {
  const WeatherIcon(this.code, {super.key, this.width = 36, this.rain = 0, this.snow = 0});
  final String? code;
  final double width;

  /// 3時間降水量の階級（0=1mm未満 … 5=20mm以上）。10mm/3h 以上（3〜）は雨粒の多いマーク、
  /// 下地も濃くする。週間など階級が無いときは 0
  final int rain;

  /// 3時間降雪量の階級（0=1cm未満 … 3=6cm以上）。下地の濃さだけ変える（マークは雪だるまのまま）
  final int snow;

  /// マーク名 → (主の天気, 副の天気)。composite 名（overcast-rain = くもり時々雨 など）は
  /// 2 つに分けて、主のマーク＋右下の三角に副のマークで表す
  static (WxKind, WxKind?) kindsOf(String name) => switch (name) {
        'clear-day' => (WxKind.sun, null),
        'partly-cloudy-day' => (WxKind.sun, WxKind.cloud),
        'partly-cloudy-day-rain' => (WxKind.sun, WxKind.rain),
        'partly-cloudy-day-snow' => (WxKind.sun, WxKind.snow),
        'partly-cloudy-day-sleet' => (WxKind.sun, WxKind.sleet),
        'overcast' => (WxKind.cloud, null),
        'overcast-day' => (WxKind.cloud, WxKind.sun),
        'overcast-rain' => (WxKind.cloud, WxKind.rain),
        'overcast-snow' => (WxKind.cloud, WxKind.snow),
        'rain' || 'extreme-rain' => (WxKind.rain, null),
        'snow' || 'snowman' => (WxKind.snow, null),
        'sleet' => (WxKind.sleet, null),
        'thunderstorms-rain' => (WxKind.thunder, null),
        _ => (WxKind.cloud, null),
      };

  /// 種別ごとの 1 枚マーク。雨は 10mm/3h 以上で雨粒の多い extreme-rain。
  /// 雪は雪だるま（Tabler Icons の形を白塗りにして目とボタンを抜いた snowman-white。
  /// Meteocons の雪だるまは白一色にすると形だけになり判別できなかった）、
  /// 雷雨は雲と雨粒だけ白にして稲妻の黄色を残した thunderstorms-rain-white（元 SVG から生成）。
  /// この 2 つは画像の時点で白いので実行時に塗らない（[isPrecolored]）
  static String assetOf(WxKind k, {int rain = 0}) => switch (k) {
        WxKind.sun => 'clear-day',
        WxKind.cloud => 'overcast',
        WxKind.rain => rain >= 3 ? 'extreme-rain' : 'rain',
        WxKind.snow => 'snowman-white',
        WxKind.sleet => 'sleet',
        WxKind.thunder => 'thunderstorms-rain-white',
      };

  /// 画像の時点で白く仕上げてあり、実行時の白塗り（srcIn）をしない種別
  static bool isPrecolored(WxKind k) => k == WxKind.snow || k == WxKind.thunder;

  /// 下地の色（不透明。晴れ＝橙、くもり＝灰、雨＝青、雪＝水色、みぞれ＝青灰、雷雨＝濃い青）。
  /// マークは白一色なので、下地は半透明にせずはっきりした色で塗る。雨・雪は階級が上がるほど濃く
  static Color tileColor(WxKind k, {int rain = 0, int snow = 0}) => switch (k) {
        WxKind.sun => const Color(0xFFF7A738),
        WxKind.cloud => const Color(0xFF9DA7B0),
        WxKind.rain => const [
            Color(0xFF3D93E8), Color(0xFF3D93E8), Color(0xFF2F80D6),
            Color(0xFF256EC2), Color(0xFF1C5DAD), Color(0xFF154C94),
          ][rain.clamp(0, 5)],
        WxKind.snow => const [
            Color(0xFF6FC3EE), Color(0xFF6FC3EE), Color(0xFF52B2E6), Color(0xFF3AA0DB),
          ][snow.clamp(0, 3)],
        WxKind.sleet => const Color(0xFF6E92B8),
        WxKind.thunder => const Color(0xFF5B62C4),
      };

  @override
  Widget build(BuildContext context) {
    final c = code;
    final box = width + 6;
    if (c == null) return SizedBox(width: box, height: box);
    final spec = weatherIconSpec(c);
    final scheme = Theme.of(context).colorScheme;
    // マークは白一色のシルエット（Meteocons の塗り版をそのまま使うと雲の階調や雪だるまの
    // 描き込みが小さい表示でつぶれ、種類ごとに重さがばらつく。2026-11-03 ウェザーニュース比較）
    Widget img(WxKind k, double w) {
      final white = !isPrecolored(k);
      return Image.asset('assets/weather/${assetOf(k, rain: rain)}.png',
        width: w,
        height: w,
        color: white ? Colors.white : null,
        colorBlendMode: white ? BlendMode.srcIn : null,
        errorBuilder: (_, _, _) => SizedBox(
            width: w, height: w, child: Icon(Icons.cloud, size: w * 0.8, color: Colors.grey)));
    }
    if (spec == null) {
      return Container(
        width: box,
        height: box,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.cloud, size: width * 0.8, color: Colors.grey),
      );
    }
    final radius = BorderRadius.circular(8);
    if (spec.then != null) {
      // 「のち」: 斜線（上 60% → 下 40%）で左右に 2 分割。前半は左、後半は右に、
      // どちらも縦はほぼ中央（斜線の空きに合わせて前半を少し上、後半を少し下）に置く
      final a = kindsOf(spec.main).$1, b = kindsOf(spec.then!).$1;
      final w = width * 0.56;
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: box,
          height: box,
          child: Stack(children: [
            CustomPaint(
                size: Size(box, box),
                painter: _SplitTilePainter(
                    tileColor(a, rain: rain, snow: snow), tileColor(b, rain: rain, snow: snow))),
            Positioned(left: box * 0.27 - w / 2, top: box * 0.42 - w / 2, child: img(a, w)),
            Positioned(left: box * 0.73 - w / 2, top: box * 0.58 - w / 2, child: img(b, w)),
          ]),
        ),
      );
    }
    final (main, sub) = kindsOf(spec.main);
    if (sub == null) {
      return Container(
        width: box,
        height: box,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tileColor(main, rain: rain, snow: snow), borderRadius: radius),
        child: img(main, width),
      );
    }
    // 「時々・一時」: 主のマークをほぼ中央（少し左上）に大きく、右下の三角に副の天気を小さく
    final wm = width * 0.78, ws = width * 0.44;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(children: [
          CustomPaint(
              size: Size(box, box),
              painter: _CornerPainter(
                  tileColor(main, rain: rain, snow: snow), tileColor(sub, rain: rain, snow: snow))),
          Positioned(left: box * 0.42 - wm / 2, top: box * 0.42 - wm / 2, child: img(main, wm)),
          // 副のマークは三角の中だけに描く（雪だるまの頭が斜線を越えないように）
          ClipPath(
            clipper: _CornerClipper(),
            child: SizedBox(
              width: box,
              height: box,
              child: Stack(children: [
                Positioned(left: box * 0.79 - ws / 2, top: box * 0.79 - ws / 2, child: img(sub, ws)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 「のち」の下地。斜線（右上寄りから左下寄りへ）で 2 分割。半透明の色なので重ねずに
/// 左右の多角形を別々に塗る（重ねると混ざって別の色になる）
class _SplitTilePainter extends CustomPainter {
  const _SplitTilePainter(this.left, this.right);
  final Color left;
  final Color right;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final l = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.60, 0)
      ..lineTo(w * 0.40, h)
      ..lineTo(0, h)
      ..close();
    final r = Path()
      ..moveTo(w * 0.60, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(w * 0.40, h)
      ..close();
    canvas.drawPath(l, Paint()..color = left);
    canvas.drawPath(r, Paint()..color = right);
    canvas.drawLine(Offset(w * 0.60, 0), Offset(w * 0.40, h),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_SplitTilePainter old) => old.left != left || old.right != right;
}

/// 「時々・一時」の右下の三角（斜線の内側）
class _CornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w, h * 0.38)
      ..lineTo(w, h)
      ..lineTo(w * 0.38, h)
      ..close();
  }

  @override
  bool shouldReclip(_CornerClipper old) => false;
}

/// 「時々・一時」の下地。主の色の面と、右下の三角（副の色）を重ねずに塗る
class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.main, this.corner);
  final Color main;
  final Color corner;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final m = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.38)
      ..lineTo(w * 0.38, h)
      ..lineTo(0, h)
      ..close();
    final c = Path()
      ..moveTo(w, h * 0.38)
      ..lineTo(w, h)
      ..lineTo(w * 0.38, h)
      ..close();
    canvas.drawPath(m, Paint()..color = main);
    canvas.drawPath(c, Paint()..color = corner);
    canvas.drawLine(Offset(w, h * 0.38), Offset(w * 0.38, h),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.main != main || old.corner != corner;
}

/// 各列に代表する数字 1 つ（3時間降水量）。天気分布予報は階級（1-5 / 5-10 / 10-15 /
/// 15-20 / 20以上 mm）なので、階級の中央値を代表値にする（上限の無い階級はしきい値）。
/// 0 も「0mm」と出す（2026-11-02 ユーザー決定: レンジや「〜」「-」は出さない）。
/// 降雪量（cm）は一般の天気予報と同じく時間別には出さない（雪は天気マークと下地の濃さで表す。同日決定）
/// 天気が雨・雪・みぞれ・雷雨なのに階級が 0（1mm 未満）の列は「1mm」と出す
/// （雪マークで 0mm は矛盾して見える。2026-11-02 ユーザー決定）
String rainText(int r, {String? weatherCode}) => switch (r) {
      0 when weatherCode != null && (weatherCode.startsWith('3') || weatherCode.startsWith('4')) => '1mm',
      1 => '3mm',
      2 => '8mm',
      3 => '13mm',
      4 => '18mm',
      5 => '20mm',
      _ => '0mm',
    };

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
  static const _axisW = 48.0; // 左の固定列（気温の目盛りと行の見出し）

  static String dirName(AppLocalizations l, int d) => switch (d) {
        1 => l.pwDir1, 2 => l.pwDir2, 3 => l.pwDir3, 4 => l.pwDir4,
        5 => l.pwDir5, 6 => l.pwDir6, 7 => l.pwDir7, 8 => l.pwDir8,
        9 => l.pwDir9, 10 => l.pwDir10, 11 => l.pwDir11, 12 => l.pwDir12,
        13 => l.pwDir13, 14 => l.pwDir14, 15 => l.pwDir15, 16 => l.pwDir16,
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
                  child: Text(warningNameOf(l, c) ?? advisoryNameOf(l, c) ?? c,
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
      rowOf(44, (c, _) => Center(child: WeatherIcon(c.weatherCode, rain: c.rain ?? 0, snow: c.snow ?? 0))),
      rowOf(15, (c, _) => Center(
            child: Text(rainText(c.rain ?? 0, weatherCode: c.weatherCode),
                style: const TextStyle(fontSize: 11, color: _coldColor), maxLines: 1, overflow: TextOverflow.clip))),
      if (hasPop)
        rowOf(14, (c, _) => Center(
            child: Text(c.pop == null ? '' : '${c.pop}%',
                style: small.copyWith(color: scheme.onSurfaceVariant)))),
    ]);
    // 左の固定列: 気温の上限・下限、各行の見出し（降水量・降雪量・降水確率）。
    // 数字が何かを左で示す（2026-11-02 利用者要望）
    final labelStyle = small.copyWith(color: scheme.onSurfaceVariant);
    Widget label(double h, String text) => SizedBox(
        height: h,
        child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text, style: labelStyle, maxLines: 1))));
    final left = SizedBox(
      width: _axisW,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: _timeH),
        if (hasTemp)
          SizedBox(
            height: _chartH,
            child: CustomPaint(
                size: const Size(_axisW, _chartH),
                painter: TempAxisPainter(
                    range: range, textColor: scheme.onSurfaceVariant, fontFamily: font)),
          ),
        const SizedBox(height: 44),
        label(15, l.pwRowRain),
        if (hasPop) label(14, l.pwRowPop),
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        left,
        Expanded(
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: scroll),
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
    // 今日＋週間7日で最大8列。8列のときはマークを少し小さく
    final days = w.days.take(8).toList();
    final iconW = days.length > 7 ? 36.0 : 40.0;
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
              WeatherIcon(d.code, width: iconW),
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
              : w.nearStationName == null
                  ? l.pwWeekNote(w.areaName, w.stationName!)
                  : l.pwWeekNoteNear(w.areaName, w.nearStationName!, w.stationName!),
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
    // 全部の点に値を出す（右端の点にも数字が付くように。2026-11-02 利用者要望）。
    // 最高は赤で上側、最低は青で下側、ほかは本文色で、線が上向きなら下側・下向きなら上側に置く
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t == null) continue;
      if (i == iMax) {
        label(i, t, _hotColor, above: true);
      } else if (i == iMin) {
        label(i, t, _coldColor, above: false);
      } else {
        final prev = i > 0 ? temps[i - 1] : null;
        final next = i + 1 < temps.length ? temps[i + 1] : null;
        final rising = (next ?? t) >= t && (prev ?? t) <= t;
        final tp = TextPainter(
          text: TextSpan(
              text: '$t°', style: TextStyle(fontSize: 10, color: textColor, fontFamily: fontFamily)),
          textDirection: TextDirection.ltr,
        )..layout();
        final dy = rising ? y(t) + 6 : y(t) - 6 - tp.height;
        tp.paint(canvas, Offset(x(i) - tp.width / 2, dy));
      }
    }
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
      p.paint(canvas, Offset(size.width - p.width - 6, y - p.height / 2)); // 左列なので折れ線側に寄せる
    }

    tp(range.$2, TempChartPainter.pad);
    tp(range.$1, TempChartPainter.pad + h);
  }

  @override
  bool shouldRepaint(TempAxisPainter old) => old.range != range || old.textColor != textColor;
}
