import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/jma_flood.dart';
import '../data/situation.dart';
import '../l10n/l10n.dart';
import '../util/jst.dart';
import '../util/prefectures.dart';

/// 地図の上に重ねる「いま起きていること」カード（1.5.0）。
/// 特別警報・危険警報・台風・洪水予報・震度4以上の地震があるときだけ出す。
/// 行をタップすると該当画面へ、×で閉じる（同じ内容のあいだは再表示しない）
class SituationCard extends StatelessWidget {
  const SituationCard({
    super.key,
    required this.situation,
    required this.onClose,
    required this.onOpenWarning,
    required this.onOpenQuake,
    required this.onOpenTyphoon,
    required this.onOpenUnderpass,
    this.collapsed = false,
    this.onToggle,
  });

  final Situation situation;
  final VoidCallback onClose;

  /// 折りたたみ（見出し行だけ表示）。地図を広く使いたいときのため（2026-09-21 要望）
  final bool collapsed;
  final VoidCallback? onToggle;
  final VoidCallback onOpenWarning;
  final VoidCallback onOpenQuake;
  /// 台風行のタップ（TC番号を渡す。地図はその台風だけを表示する）
  final ValueChanged<String> onOpenTyphoon;

  /// 地下道の冠水行のタップ（地図の冠水状況レイヤーを開く）
  final VoidCallback onOpenUnderpass;

  static const _maxRows = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final rows = <_Row>[];
    final s = situation;
    if (s.warnings.special.isNotEmpty) {
      rows.add(_Row(
        icon: Icons.warning,
        color: const Color(0xFF9C27B0),
        text: l10n.situationSpecial(_prefs(l10n, s.warnings.special)),
        onTap: onOpenWarning,
      ));
    }
    if (s.warnings.danger.isNotEmpty) {
      rows.add(_Row(
        icon: Icons.warning_amber,
        color: const Color(0xFFAA00AA),
        text: l10n.situationDanger(_prefs(l10n, s.warnings.danger)),
        onTap: onOpenWarning,
      ));
    }
    for (final t in s.typhoons) {
      final a = t.analysis;
      final intensity = typhoonIntensityOf(l10n, a.intensity);
      final name = intensity.isEmpty
          ? typhoonNameOf(l10n, t)
          : '${typhoonNameOf(l10n, t)}（$intensity）';
      rows.add(_Row(
        icon: Icons.cyclone,
        color: const Color(0xFFD32F2F),
        text: l10n.situationTyphoon(name, a.location.isEmpty ? '-' : a.location),
        onTap: () => onOpenTyphoon(t.id),
      ));
    }
    if (s.floods.isNotEmpty) {
      final f = s.floods.first;
      final kind = floodKindNameOf(l10n, f.level);
      final text = s.floods.length == 1
          ? l10n.situationFlood(f.riverName, kind)
          : '${l10n.situationFlood(f.riverName, kind)} ${l10n.situationMore(s.floods.length - 1)}';
      rows.add(_Row(
        icon: Icons.water,
        color: f.level == FloodLevel.caution ? const Color(0xFFB8A800) : f.level.color,
        text: text,
        onTap: onOpenWarning,
      ));
    }
    for (final src in s.underpass) {
      final alerts = src.alerts;
      if (alerts.isEmpty) continue;
      final worst = alerts.map((p) => p.level).reduce((a, b) => a > b ? a : b);
      final names = alerts.take(3).map((p) => p.name).join('・') +
          (alerts.length > 3 ? ' ${l10n.situationMore(alerts.length - 3)}' : '');
      rows.add(_Row(
        icon: Icons.water_damage,
        color: worst >= 2 ? const Color(0xFFD32F2F) : const Color(0xFFF9A825),
        text: l10n.situationUnderpass(src.operator.isNotEmpty ? src.operator : src.name, names,
            worst >= 2 ? l10n.underpassLevel2 : l10n.underpassLevel1),
        onTap: onOpenUnderpass,
      ));
    }
    if (s.quakes.isNotEmpty) {
      final q = s.quakes.first;
      final j = toJstWallClock(q.at.toUtc());
      final hhmm = '${j.hour.toString().padLeft(2, '0')}:${j.minute.toString().padLeft(2, '0')}';
      final text = s.quakes.length == 1
          ? l10n.situationQuake(intensityLabelOf(l10n, q.maxIntensity), q.place, hhmm)
          : '${l10n.situationQuake(intensityLabelOf(l10n, q.maxIntensity), q.place, hhmm)} ${l10n.situationMore(s.quakes.length - 1)}';
      rows.add(_Row(
        icon: Icons.vibration,
        color: const Color(0xFFE65100),
        text: text,
        onTap: onOpenQuake,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final shown = rows.take(_maxRows).toList();
    final hidden = rows.length - shown.length;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: scheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: onToggle,
                child: Row(children: [
                  Flexible(
                    child: Text(
                        collapsed
                            ? '${l10n.situationTitle} · ${l10n.situationCount(rows.length)}'
                            : l10n.situationTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (onToggle != null)
                    Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 18, color: scheme.onSurfaceVariant),
                ]),
              ),
            ),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ]),
          if (!collapsed)
            for (final r in shown)
              InkWell(
              onTap: r.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(r.icon, size: 16, color: r.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: scheme.onSurface.withValues(alpha: 0.38)),
                ]),
              ),
            ),
          if (!collapsed && hidden > 0)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(l10n.situationMore(hidden),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l10n.situationSource,
                  style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
            ),
        ]),
      ),
    );
  }

  /// 都道府県名を最大3つ、超えた分は「ほかN」
  static String _prefs(AppLocalizations l10n, Set<String> prefs) {
    final codes = prefs.where(prefectureNames.containsKey).toList()..sort();
    final names = codes.take(3).map((c) => prefectureNameOf(l10n, c)).join('・');
    return codes.length > 3 ? '$names ${l10n.situationMore(codes.length - 3)}' : names;
  }
}

class _Row {
  const _Row({required this.icon, required this.color, required this.text, required this.onTap});
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
}

/// カードの行数（[SituationCard] の build() と同じ条件で数える。ボタンの
/// 件数バッジ用に、l10n を使わず数だけ数える）
int situationRowCount(Situation s) {
  var n = 0;
  if (s.warnings.special.isNotEmpty) n++;
  if (s.warnings.danger.isNotEmpty) n++;
  n += s.typhoons.length;
  if (s.floods.isNotEmpty) n++;
  n += s.underpass.where((src) => src.alerts.isNotEmpty).length;
  if (s.quakes.isNotEmpty) n++;
  return n;
}

/// 発生時だけ出す右上の丸い「！」ボタン（design/map_ui/PROPOSAL.md 第5案）。
/// 件数バッジ付き。タップで [SituationOverlay] のカードを開く
class SituationButton extends StatelessWidget {
  const SituationButton({super.key, required this.situation, required this.onTap});

  final Situation situation;
  final VoidCallback onTap;

  /// 最上位段階の色（特別警報 > 危険警報 > その他）
  static Color colorOf(Situation s) {
    if (s.warnings.special.isNotEmpty) return const Color(0xFF9C27B0);
    if (s.warnings.danger.isNotEmpty) return const Color(0xFFAA00AA);
    return const Color(0xFFD32F2F);
  }

  @override
  Widget build(BuildContext context) {
    final count = situationRowCount(situation);
    final color = colorOf(situation);
    return Semantics(
      button: true,
      label: context.l10n.situationButtonLabel(count),
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          key: const Key('situation_button'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(clipBehavior: Clip.none, children: [
              const Center(
                child: Icon(Icons.priority_high, color: Colors.white, size: 26),
              ),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color, width: 1),
                    ),
                    child: Text('$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ボタンとカードの開閉（design 第5案）。展開状態は呼び出し側（map_screen.dart）が
/// `expanded` で渡し、開閉アニメーションとリングの脈動はこのウィジェットが担当する。
/// 開く: 250ms `Cubic(.05,.7,.1,1.0)`（emphasized decelerate相当）、
/// scale 0.6→1.025(80%)→1、opacity 0→1。閉じる: 200ms `Cubic(.3,0,.8,.15)`、
/// scale 1→0.6、opacity 1→0（オーバーシュートなし）。`isNew` が false→true に
/// 変わったときだけ、ボタンの外側に600ms×2回のリング脈動を出す
class SituationOverlay extends StatefulWidget {
  const SituationOverlay({
    super.key,
    required this.situation,
    required this.expanded,
    required this.isNew,
    required this.onOpen,
    required this.onClose,
    required this.onOpenWarning,
    required this.onOpenQuake,
    required this.onOpenTyphoon,
    required this.onOpenUnderpass,
  });

  final Situation situation;
  final bool expanded;

  /// 前回読み込みと signature が変わった直後か（脈動の起動条件）
  final bool isNew;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onOpenWarning;
  final VoidCallback onOpenQuake;
  final ValueChanged<String> onOpenTyphoon;
  final VoidCallback onOpenUnderpass;

  static const _openCurve = Cubic(0.05, 0.7, 0.1, 1.0);
  static const _closeCurve = Cubic(0.3, 0, 0.8, 0.15);

  @override
  State<SituationOverlay> createState() => _SituationOverlayState();
}

class _SituationOverlayState extends State<SituationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    reverseDuration: const Duration(milliseconds: 200),
    value: widget.expanded ? 1 : 0,
  );
  AnimationController? _pulse;

  /// ボタンの周りで常にふくらんでは消える光（2026-09-28 要望「ぼわぼわと
  /// アプローチしたい」）。カードを閉じているあいだだけ回す
  late final AnimationController _aura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);
  // initState では MediaQuery を参照できない（assert になる）ので、
  // 脈動の開始は didChangeDependencies まで持ち越す
  bool _pendingPulse = false;

  @override
  void initState() {
    super.initState();
    _pendingPulse = widget.isNew;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendingPulse) {
      _pendingPulse = false;
      _maybeStartPulse();
    }
    _syncAura();
  }

  void _syncAura() {
    final run = !widget.expanded && !_reduceMotion;
    if (run && !_aura.isAnimating) {
      _aura.repeat();
    } else if (!run && _aura.isAnimating) {
      _aura.stop();
    }
  }

  @override
  void didUpdateWidget(SituationOverlay old) {
    super.didUpdateWidget(old);
    if (widget.expanded != old.expanded) {
      if (_reduceMotion) {
        _controller.value = widget.expanded ? 1 : 0;
      } else if (widget.expanded) {
        _controller.forward(from: 0);
      } else {
        _controller.reverse(from: 1);
      }
    }
    if (widget.isNew && !old.isNew) _maybeStartPulse();
    _syncAura();
  }

  /// リングの脈動を600ms×2回（有限）。無限ループにしない
  void _maybeStartPulse() {
    if (_reduceMotion) return;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulse?.dispose();
    // initState / didUpdateWidget 直後に build() が走るので setState は不要
    // （setState は完了後の後始末だけで使う。build中に呼ぶとエラーになる）
    _pulse = c;
    c.forward().then((_) {
      if (!mounted) return;
      c.forward(from: 0).whenComplete(() {
        if (mounted && _pulse == c) setState(() => _pulse = null);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse?.dispose();
    _aura.dispose();
    super.dispose();
  }

  /// 開く/閉じるで別カーブ（オーバーシュートは開くときだけ）
  double _scaleFor(double t) {
    if (_controller.status == AnimationStatus.reverse) {
      final e = SituationOverlay._closeCurve.transform(t);
      return 0.6 + 0.4 * e;
    }
    final e = SituationOverlay._openCurve.transform(t).clamp(0.0, 1.2);
    if (e <= 0.8) return 0.6 + (1.025 - 0.6) * (e / 0.8);
    return 1.025 + (1.0 - 1.025) * ((e - 0.8) / 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.situation;
    final color = SituationButton.colorOf(s);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topRight,
      children: [
        // ボタンの後ろの光。カードが開くにつれて薄くする
        if (!_reduceMotion)
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_aura, _controller]),
                builder: (context, _) => CustomPaint(
                  size: const Size(48, 48),
                  painter: _AuraPainter(
                    t: _aura.value,
                    color: color,
                    fade: (1 - _controller.value).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),
        if (_pulse != null)
          AnimatedBuilder(
            animation: _pulse!,
            builder: (context, _) {
              final t = _pulse!.value;
              final size = 48 * (1 + 0.55 * t);
              final opacity = (0.65 * (1 - t)).clamp(0.0, 1.0);
              return IgnorePointer(
                child: Opacity(
                  opacity: opacity,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2)),
                    ),
                  ),
                ),
              );
            },
          ),
        // ボタンはカードが開くにつれて消える（カードはボタンの位置から広がる）
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return IgnorePointer(
              ignoring: t > 0.5,
              child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
            );
          },
          child: SituationButton(situation: s, onTap: widget.onOpen),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            if (t == 0) return const SizedBox.shrink();
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                // 起点はボタンの中心（右上から 24px 内側）
                alignment: const Alignment(0.87, -1),
                scale: _scaleFor(t),
                child: child,
              ),
            );
          },
          // カード本体は横幅を明示（Rowの Expanded がある文中省略のため）。
          // design/map_ui/PROPOSAL.md 通り左右12pxの余白を確保する
          child: Padding(
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: math.max(200, MediaQuery.sizeOf(context).width - 24),
              child: SituationCard(
                situation: s,
                onClose: widget.onClose,
                onOpenWarning: widget.onOpenWarning,
                onOpenQuake: widget.onOpenQuake,
                onOpenTyphoon: widget.onOpenTyphoon,
                onOpenUnderpass: widget.onOpenUnderpass,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// 「！」ボタンの周りの光。中心から2つの波が半周期ずらしてふくらみ、
/// 外へ行くほど薄くなって消える。ぼかした円で描くので輪郭は柔らかい。
/// 描画はボタン（48×48）の外へはみ出す
class _AuraPainter extends CustomPainter {
  _AuraPainter({required this.t, required this.color, required this.fade});

  final double t;
  final Color color;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0) return;
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    // 常に灯っている後光（ゆっくり呼吸する）
    final breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
    canvas.drawCircle(
      c,
      base * (1.15 + 0.15 * breath),
      Paint()
        ..color = color.withValues(alpha: (0.35 + 0.25 * breath) * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // 外へふくらんで消える波
    for (final phase in [t, (t + 0.5) % 1.0]) {
      final e = Curves.easeOutCubic.transform(phase);
      final r = base * (1.0 + 1.1 * e);
      final a = 0.7 * (1 - phase) * (1 - phase) * fade;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 10 * e),
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.t != t || old.color != color || old.fade != fade;
}
