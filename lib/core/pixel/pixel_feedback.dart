import 'dart:async';

import 'package:flutter/material.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_controls.dart';
import 'pixel_grid.dart';
import 'pixel_idle.dart';
import 'pixel_text.dart';

/// Dark-to-light fill variation options for [PixelProgressBar].
enum PixelProgressRamp {
  emerald(
    label: 'EMERALD',
    startColor: PixelPalette.greenDeep,
    endColor: PixelPalette.greenLight,
  ),
  bamboo(
    label: 'BAMBOO',
    startColor: PixelPalette.greenDark,
    endColor: PixelPalette.sunLight,
  ),
  gold(
    label: 'GOLD SUN',
    startColor: PixelPalette.goldDeep,
    endColor: PixelPalette.sunLight,
  ),
  ember(
    label: 'EMBER',
    startColor: PixelPalette.redDeep,
    endColor: PixelPalette.orangeLight,
  ),
  sky(
    label: 'SKY',
    startColor: PixelPalette.blueDeep,
    endColor: PixelPalette.sky,
  ),
  flat(
    label: 'FLAT',
    startColor: PixelPalette.greenBright,
    endColor: PixelPalette.greenBright,
  );

  const PixelProgressRamp({
    required this.label,
    required this.startColor,
    required this.endColor,
  });

  final String label;
  final Color startColor;
  final Color endColor;
}

/// Active color variation chosen in Pixel Lab (defaults to dark-to-light emerald).
final ValueNotifier<PixelProgressRamp> pixelProgressRampNotifier =
    ValueNotifier<PixelProgressRamp>(PixelProgressRamp.emerald);

class PixelProgressBar extends StatelessWidget {
  const PixelProgressBar({
    super.key,
    required this.value,
    this.segments = 10,
    this.color = PixelPalette.greenBright,
    this.height = 5,
    this.showTipGlint = false,
    this.idle = true,
    this.ramp,
  });

  final double value;
  final int segments;
  final Color color;
  final int height;
  final PixelProgressRamp? ramp;

  /// Owner 2026-11-17: an idle animation inside the bar.
  /// - When `< 100%` (`0 < value < 1.0`), stepped particles emit from the end of the filled bar.
  /// - When `100%` (`value >= 1.0`), an alive multi-band scanning sweep travels across the bar.
  /// Stepped and whole-pixel; off under Reduce motion (see [PixelLoop]).
  final bool idle;

  static const _idleSteps = 28;

  /// Plan 75k: a 1 art px sun-light cap on the leading filled segment, so XP
  /// bars read like glowing RPG gauges.
  final bool showTipGlint;

  Color _segmentColor(int index, PixelProgressRamp activeRamp) {
    if (activeRamp == PixelProgressRamp.flat) return color;
    final t = segments <= 1 ? 1.0 : index / (segments - 1);
    if (color != PixelPalette.greenBright && ramp == null) {
      final dark = Color.lerp(color, PixelPalette.ink, 0.35)!;
      final light = Color.lerp(color, PixelPalette.white, 0.45)!;
      return Color.lerp(dark, light, t)!;
    }
    return Color.lerp(activeRamp.startColor, activeRamp.endColor, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final v = value.clamp(0.0, 1.0);

    Widget buildWithRamp(PixelProgressRamp activeRamp) {
      Widget bar(int step) => SizedBox(
            height: grid.px(height + 2),
            child: PixelSnap(
              child: CustomPaint(
                painter: _BarPainter(
                  grid,
                  v,
                  segments,
                  color,
                  activeRamp,
                  _segmentColor,
                  height,
                  showTipGlint,
                  step,
                ),
                size: Size.infinite,
              ),
            ),
          );
      if (!idle || v <= 0) return bar(0);
      return PixelLoop(
        steps: _idleSteps,
        stepMs: 85,
        pauseMs: v >= 1.0 ? 900 : 1100,
        builder: (context, step, _) => bar(step),
      );
    }

    if (ramp != null) return buildWithRamp(ramp!);
    return ValueListenableBuilder<PixelProgressRamp>(
      valueListenable: pixelProgressRampNotifier,
      builder: (context, selectedRamp, _) => buildWithRamp(selectedRamp),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(
    this.grid,
    this.value,
    this.segments,
    this.color,
    this.ramp,
    this.segmentColorAt,
    this.h,
    this.glint,
    this.step,
  );

  final PixelGrid grid;
  final double value;
  final int segments;
  final Color color;
  final PixelProgressRamp ramp;
  final Color Function(int index, PixelProgressRamp ramp) segmentColorAt;
  final int h;
  final bool glint;

  /// Idle step; 0 is the rest pose (nothing extra drawn).
  final int step;

  Rect _r(num x, num y, num w, num hh) => Rect.fromLTRB(
        grid.snap(x * grid.unit),
        grid.snap(y * grid.unit),
        grid.snap((x + w) * grid.unit),
        grid.snap((y + hh) * grid.unit),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / grid.unit).floor();
    if (cols < 4) return;
    final paint = Paint()..isAntiAlias = false;
    paint.color = PixelPalette.ink;
    for (final r in steppedRects(0, 0, cols, h + 2, 1)) {
      canvas.drawRect(_r(r.left, r.top, r.width, r.height), paint);
    }
    paint.color = PixelPalette.slate;
    canvas.drawRect(_r(1, 1, cols - 2, h), paint);
    final inner = cols - 2;
    final segW = ((inner - (segments - 1)) / segments).floor();
    final filled = (value * segments).round();
    final isFull = value >= 1.0 || filled >= segments;
    if (segW < 1) {
      final w = (inner * value).round();
      if (w > 0) {
        paint.color =
            ramp == PixelProgressRamp.flat ? color : segmentColorAt(0, ramp);
        canvas.drawRect(_r(1, 1, w, h), paint);
        if (step > 0) {
          if (isFull) {
            _fullScan(canvas, paint, 1, w, (_) => true);
          } else {
            _tipParticles(canvas, paint, 1 + w, inner);
          }
        }
      }
      return;
    }
    for (var i = 0; i < segments; i++) {
      final x = 1 + i * (segW + 1);
      final on = i < filled;
      final segColor = on ? segmentColorAt(i, ramp) : PixelPalette.stone;
      paint.color = segColor;
      canvas.drawRect(_r(x, 1, segW, h), paint);
      if (on) {
        paint.color = Color.lerp(segColor, PixelPalette.white, 0.55)!;
        canvas.drawRect(_r(x, 1, segW, 1), paint);
        paint.color = PixelPalette.ink;
        canvas.drawRect(_r(x, h, segW, 1), paint);
      }
    }
    if (glint && filled > 0 && filled <= segments) {
      final x = 1 + (filled - 1) * (segW + 1);
      paint.color = PixelPalette.sunLight;
      canvas.drawRect(_r(x + segW - 1, 1, 1, h - 1), paint);
    }
    if (step > 0 && filled > 0) {
      bool lit(int x) => (x - 1) % (segW + 1) < segW;
      final filledW = filled * (segW + 1) - 1;
      if (isFull) {
        _fullScan(canvas, paint, 1, filledW, lit);
      } else {
        _tipParticles(canvas, paint, 1 + filledW, inner);
      }
    }
  }

  /// Stepped particles emitting from the leading filled tip when `< 100%`.
  void _tipParticles(Canvas canvas, Paint paint, int tipX, int inner) {
    if (h < 2) return;
    final tipLight = ramp == PixelProgressRamp.flat
        ? Color.lerp(color, PixelPalette.white, 0.65)!
        : Color.lerp(ramp.endColor, PixelPalette.white, 0.45)!;

    // Subtle breathing pulse right on the tip column.
    if (step % 4 < 2 && tipX - 1 >= 1) {
      paint.color = PixelPalette.white;
      canvas.drawRect(_r(tipX - 1, 2, 1, h - 2), paint);
    }

    // 5 staggered whole-pixel sparks drifting forward & upward from the end.
    const life = 9;
    for (var k = 0; k < 5; k++) {
      final age = (step - 1 - k * 5);
      if (age < 0 || age >= life) continue;
      final progress = age ~/ 2; // stepped integer travel
      final dx = (k.isEven ? 1 : 0) + progress;
      final dy = -((age + k) ~/ 3);
      final px = tipX + dx - 1;
      final py = (1 + ((k * 2 + 1) % (h - 1))) + dy;
      if (px < 1 || px >= 1 + inner) continue;
      paint.color = age < 3
          ? PixelPalette.white
          : age < 6
              ? PixelPalette.sunLight
              : tipLight;
      canvas.drawRect(_r(px, py, 1, 1), paint);
    }
  }

  /// Alive multi-band scanning sweep across a full (`100%`) bar.
  void _fullScan(
      Canvas canvas, Paint paint, int x0, int w, bool Function(int x) lit) {
    if (w < 3 || h < 3) return;
    const steps = PixelProgressBar._idleSteps;
    const headColor = PixelPalette.white;
    final trailColor = ramp == PixelProgressRamp.flat
        ? Color.lerp(color, PixelPalette.white, 0.55)!
        : Color.lerp(ramp.endColor, PixelPalette.white, 0.55)!;
    const echoColor = PixelPalette.sunLight;

    // Primary 5 px stepped scanner with bright leading core and fading trail.
    final sweep = x0 + ((step - 1) * (w + 6) / (steps - 2)).floor() - 5;
    for (var dx = 0; dx < 5; dx++) {
      final x = sweep + dx;
      if (x < x0 || x >= x0 + w || !lit(x)) continue;
      paint.color = dx >= 3
          ? headColor
          : dx >= 1
              ? trailColor
              : echoColor;
      final topY = dx == 4 ? 1 : 2;
      final spanH = dx == 4 ? h - 1 : h - 2;
      canvas.drawRect(_r(x, topY, 1, spanH), paint);
    }

    // Secondary shimmer glints dancing along upper edges so 100% feels alive.
    paint.color = PixelPalette.white;
    for (var k = 0; k < 4; k++) {
      final offset = (step * 2 + k * (w ~/ 4)) % w;
      final sx = x0 + offset;
      if (!lit(sx)) continue;
      final sy = 2 + ((step + k) % (h - 2).clamp(1, h));
      canvas.drawRect(_r(sx, sy, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.grid.unit != grid.unit ||
      old.color != color ||
      old.ramp != ramp ||
      old.segments != segments ||
      old.glint != glint ||
      old.step != step;
}

class PixelDialogue extends StatefulWidget {
  const PixelDialogue({
    super.key,
    required this.speaker,
    required this.lines,
    this.portrait,
    this.interval = const Duration(milliseconds: 30),
    this.animate = true,
  });

  final String speaker;
  final List<String> lines;
  final PixelArt? portrait;
  final Duration interval;
  final bool animate;

  @override
  State<PixelDialogue> createState() => _PixelDialogueState();
}

class _PixelDialogueState extends State<PixelDialogue> {
  int _line = 0;
  int _chars = 0;
  Timer? _timer;

  String get _current => widget.lines.isEmpty
      ? ''
      : widget.lines[_line.clamp(0, widget.lines.length - 1).toInt()];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _chars = 0;
    if (!widget.animate) {
      _chars = _current.length;
      return;
    }
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_chars >= _current.length) {
        timer.cancel();
        return;
      }
      setState(() => _chars++);
    });
  }

  void _advance() {
    if (widget.lines.isEmpty) return;
    if (_chars < _current.length) {
      _timer?.cancel();
      setState(() => _chars = _current.length);
      return;
    }
    setState(() => _line = (_line + 1) % widget.lines.length);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final done = _chars >= _current.length;
    final visible =
        _current.substring(0, _chars.clamp(0, _current.length).toInt());
    return Semantics(
      button: true,
      label: '${widget.speaker}: $_current',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: PixelPanel(
            style: PixelBoxStyle.inkDialogue,
            padding: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.portrait != null) ...[
                  PixelPanel(
                    style: PixelBoxStyle.inkDialogue,
                    padding: 1,
                    child: PixelSprite(widget.portrait!, scale: 3),
                  ),
                  SizedBox(width: grid.px(3)),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '* ${widget.speaker}',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.sun,
                        ),
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        visible,
                        style:
                            PixelType.body(context, color: PixelPalette.paper),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Opacity(
                          opacity: done ? 1 : 0,
                          child: SizedBox(
                            width: grid.px(5),
                            height: grid.px(3),
                            child: CustomPaint(painter: _ArrowPainter(grid)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.grid);

  final PixelGrid grid;

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final paint = Paint()
      ..color = PixelPalette.paper
      ..isAntiAlias = false;
    for (var row = 0; row < 3; row++) {
      final width = 5 - row * 2;
      canvas.drawRect(
        Rect.fromLTWH(
          grid.snap(row * u),
          grid.snap(row * u),
          grid.snap(width * u),
          grid.snap(u),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.grid.unit != grid.unit;
}

Future<T?> showPixelDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Close',
    barrierColor: PixelPalette.ink.withValues(alpha: 0.7),
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final grid = PixelGrid.of(dialogContext);
      final buttons = actions ??
          [
            PixelButton(
              label: 'OK',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ];
      return Center(
        child: Padding(
          padding: EdgeInsets.all(grid.px(4)),
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: grid.px(150)),
              child: SingleChildScrollView(
                child: PixelPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShadowText(
                        title,
                        style: PixelType.title(dialogContext),
                      ),
                      if (message != null) ...[
                        SizedBox(height: grid.px(2)),
                        Text(
                          message,
                          style: PixelType.body(
                            dialogContext,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                      if (content != null) ...[
                        SizedBox(height: grid.px(2)),
                        content,
                      ],
                      SizedBox(height: grid.px(3)),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: grid.px(2),
                        runSpacing: grid.px(2),
                        children: buttons,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void showPixelToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: PixelPalette.ink.withValues(alpha: 0),
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
      content: PixelPanel(
        style: PixelBoxStyle.inkDialogue,
        padding: 2,
        child: Text(
          message,
          style: PixelType.body(context, color: PixelPalette.paper),
        ),
      ),
    ),
  );
}

class PixelLoader extends StatefulWidget {
  const PixelLoader({
    super.key,
    this.label = 'Loading',
    this.artPx = 8,
    this.color = PixelPalette.sun,
  });

  final String label;
  final int artPx;
  final Color color;

  @override
  State<PixelLoader> createState() => _PixelLoaderState();
}

class _PixelLoaderState extends State<PixelLoader> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 160), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      label: widget.label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: grid.px(widget.artPx),
          height: grid.px(widget.artPx),
          child: CustomPaint(
            painter: _LoaderPainter(
              grid: grid,
              step: _step,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({required this.grid, required this.step, required this.color});

  final PixelGrid grid;
  final int step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final paint = Paint()..isAntiAlias = false;
    const points = <(int, int)>[(1, 1), (5, 1), (5, 5), (1, 5)];
    for (var i = 0; i < points.length; i++) {
      paint.color = i == step ? color : PixelPalette.slate;
      canvas.drawRect(
        Rect.fromLTWH(
          grid.snap(points[i].$1 * u),
          grid.snap(points[i].$2 * u),
          grid.snap(2 * u),
          grid.snap(2 * u),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LoaderPainter old) =>
      old.step != step || old.color != color || old.grid.unit != grid.unit;
}

class PixelEmptyState extends StatelessWidget {
  const PixelEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final PixelArt? icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(grid.px(3)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              PixelSprite(icon!, scale: 4),
              SizedBox(height: grid.px(3)),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: PixelType.title(context),
            ),
            if (message != null) ...[
              SizedBox(height: grid.px(2)),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: grid.px(3)),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
