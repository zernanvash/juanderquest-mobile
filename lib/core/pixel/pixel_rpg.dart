import 'dart:async';

import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_controls.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

// Plan 75k (owner 2026-11-05, from argon's audit): the RPG feel.
// Hypixel-style lore panels, Terraria-style pressable slots, and small stepped
// animations. Everything moves in whole art pixels at a few frames per second,
// stops when the phone asks for reduced motion, and allocates nothing in paint.

/// True when animations should run: the widget allows it and the phone does
/// not ask for reduced motion (tests set disableAnimations, so pumpAndSettle
/// never waits on these).
bool pixelMotion(BuildContext context, {bool animate = true}) =>
    animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// A dark "item lore" box like Hypixel SkyBlock's tooltips: near-black fill,
/// a 1 art px accent frame with notched corners, and an optional title with a
/// rule under it. Coloured text (PixelText.rich tokens) pops on it.
class PixelLorePanel extends StatelessWidget {
  const PixelLorePanel({
    super.key,
    required this.child,
    this.title,
    this.accent = PixelPalette.sun,
    this.padding = 4,
  });

  final Widget child;
  final String? title;
  final Color accent;

  /// Inner padding in art pixels (inside the frame).
  final int padding;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelSnap(
      child: CustomPaint(
        painter: _LorePainter(unit: grid.unit, accent: accent),
        child: Padding(
          padding: EdgeInsets.all(grid.px(3 + padding)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: PixelType.body(context, color: accent)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: grid.px(1)),
                Container(height: grid.px(1), color: accent),
                SizedBox(height: grid.px(2)),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LorePainter extends CustomPainter {
  _LorePainter({required this.unit, required this.accent})
      : _accent = Paint()
          ..color = accent
          ..isAntiAlias = false;

  final double unit;
  final Color accent;
  final Paint _accent;

  static final _fill = Paint()
    ..color = PixelPalette.ink.withValues(alpha: 0.94)
    ..isAntiAlias = false;
  static final _edge = Paint()
    ..color = PixelPalette.blueDeep
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final u = unit;
    final w = (size.width / u).floor();
    final h = (size.height / u).floor();
    if (w < 8 || h < 8) return;
    Rect r(int x, int y, int rw, int rh) =>
        Rect.fromLTWH(x * u, y * u, rw * u, rh * u);
    // Outer edge (square, 1 px) and fill.
    canvas.drawRect(r(0, 0, w, h), _edge);
    canvas.drawRect(r(1, 1, w - 2, h - 2), _fill);
    // Accent frame 1 px inside, with the corners notched out.
    canvas.drawRect(r(3, 1 + 1, w - 6, 1), _accent); // top
    canvas.drawRect(r(3, h - 3, w - 6, 1), _accent); // bottom
    canvas.drawRect(r(2, 3, 1, h - 6), _accent); // left
    canvas.drawRect(r(w - 3, 3, 1, h - 6), _accent); // right
    // A pin in each notch.
    canvas.drawRect(r(3, 3, 1, 1), _accent);
    canvas.drawRect(r(w - 4, 3, 1, 1), _accent);
    canvas.drawRect(r(3, h - 4, 1, 1), _accent);
    canvas.drawRect(r(w - 4, h - 4, 1, 1), _accent);
  }

  @override
  bool shouldRepaint(_LorePainter old) =>
      old.unit != unit || old.accent != accent;
}

/// Any tappable slot that physically presses like an inventory button: on
/// touch the bevel inverts and the content sinks 1 art px; release ticks.
class PixelTappableSlot extends StatefulWidget {
  const PixelTappableSlot({
    super.key,
    required this.child,
    required this.onTap,
    this.style = PixelBoxStyle.parchment,
    this.padding = 2,
    this.sunken = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final PixelBoxStyle style;
  final int padding;
  final bool sunken;
  final String? semanticLabel;

  @override
  State<PixelTappableSlot> createState() => _PixelTappableSlotState();
}

class _PixelTappableSlotState extends State<PixelTappableSlot> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final panel = PixelPanel(
      style: widget.style,
      padding: widget.padding,
      sunken: widget.sunken,
      pressed: _down,
      child: widget.child,
    );
    if (!enabled) return panel;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) {
          _set(false);
          pixelTick(context);
          widget.onTap!();
        },
        child: panel,
      ),
    );
  }
}

/// Steps its child up 1 art px and back at 2 fps, like an equipped item
/// breathing in an RPG hotbar.
class PixelIdleBob extends StatefulWidget {
  const PixelIdleBob({
    super.key,
    required this.child,
    this.enabled = true,
    this.fps = 2,
  });

  final Widget child;
  final bool enabled;
  final int fps;

  @override
  State<PixelIdleBob> createState() => _PixelIdleBobState();
}

class _PixelIdleBobState extends State<PixelIdleBob> {
  Timer? _timer;
  bool _up = false;

  void _sync(bool run) {
    if (run && _timer == null) {
      _timer = Timer.periodic(
        Duration(milliseconds: 1000 ~/ widget.fps),
        (_) {
          if (mounted) setState(() => _up = !_up);
        },
      );
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _up = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(widget.enabled && pixelMotion(context));
  }

  @override
  void didUpdateWidget(PixelIdleBob old) {
    super.didUpdateWidget(old);
    _sync(widget.enabled && pixelMotion(context));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Transform.translate(
      offset: Offset(0, _up ? -grid.unit : 0),
      child: widget.child,
    );
  }
}

/// Rocks its child 1 art px left and right at 6 fps while [active] (the
/// notification bell when there is something unread); still otherwise.
class PixelRing extends StatefulWidget {
  const PixelRing({super.key, required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  State<PixelRing> createState() => _PixelRingState();
}

class _PixelRingState extends State<PixelRing> {
  Timer? _timer;
  int _step = 0;

  /// Ring pattern in art px: a short wobble, then a pause.
  static const _pattern = [0, -1, 0, 1, 0, -1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0];

  void _sync(bool run) {
    if (run && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 166), (_) {
        if (mounted) setState(() => _step = (_step + 1) % _pattern.length);
      });
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _step = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(widget.active && pixelMotion(context));
  }

  @override
  void didUpdateWidget(PixelRing old) {
    super.didUpdateWidget(old);
    _sync(widget.active && pixelMotion(context));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: Offset(_pattern[_step] * PixelGrid.of(context).unit, 0),
        child: widget.child,
      );
}

/// Stepped micro sprites (palette keys: h sun, i sun light, 6 white,
/// e gold, f amber, d gold deep, 0 ink).
abstract final class PixelMicroArt {
  /// A 4-point RPG glint: dot, plus, star, plus. 7×7, 4 fps.
  static const sparkle = PixelFrames('rpgSparkle', fps: 4, frames: [
    PixelArt('rpgSparkle0', [
      '.......',
      '.......',
      '.......',
      '...i...',
      '.......',
      '.......',
      '.......',
    ]),
    PixelArt('rpgSparkle1', [
      '.......',
      '.......',
      '...i...',
      '..i6i..',
      '...i...',
      '.......',
      '.......',
    ]),
    PixelArt('rpgSparkle2', [
      '...h...',
      '...i...',
      '..hih..',
      'hii6iih',
      '..hih..',
      '...i...',
      '...h...',
    ]),
    PixelArt('rpgSparkle3', [
      '.......',
      '.......',
      '...i...',
      '..i6i..',
      '...i...',
      '.......',
      '.......',
    ]),
  ]);

  /// A turning mJDQ coin: front, three-quarter, edge, three-quarter. 8×8, 6 fps.
  static const coin = PixelFrames('rpgCoin', fps: 6, frames: [
    PixelArt('rpgCoin0', [
      '..dddd..',
      '.dhhhhd.',
      'dhi66hfd',
      'dhihhhfd',
      'dhihhhfd',
      'dhhhhffd',
      '.dfffff.',
      '..dddd..',
    ]),
    PixelArt('rpgCoin1', [
      '...ddd..',
      '..dhhhd.',
      '..di6hfd',
      '..dihhfd',
      '..dihhfd',
      '..dhhffd',
      '..dfffd.',
      '...ddd..',
    ]),
    PixelArt('rpgCoin2', [
      '....dd..',
      '....dd..',
      '....id..',
      '....hd..',
      '....hd..',
      '....fd..',
      '....dd..',
      '....dd..',
    ]),
    PixelArt('rpgCoin3', [
      '..ddd...',
      '.dhhhd..',
      'dhi6hd..',
      'dhihhd..',
      'dhihhd..',
      'dhhffd..',
      '.dfffd..',
      '..ddd...',
    ]),
  ]);
}

/// A looping micro sprite. It steps with a timer at the sprite's fps and
/// repaints only when the frame changes (no per-frame ticker, so it costs
/// almost nothing and never keeps a test's pumpAndSettle waiting). It sits
/// on its first frame when motion is off (reduced motion).
class PixelMicro extends StatefulWidget {
  const PixelMicro(this.frames,
      {super.key, this.scale = 2, this.animate = true});

  final PixelFrames frames;
  final int scale;
  final bool animate;

  @override
  State<PixelMicro> createState() => _PixelMicroState();
}

class _PixelMicroState extends State<PixelMicro> {
  Timer? _timer;
  int _frame = 0;

  void _sync() {
    final run = pixelMotion(context, animate: widget.animate) &&
        widget.frames.frames.length > 1;
    if (run && _timer == null) {
      _timer = Timer.periodic(
        Duration(milliseconds: 1000 ~/ widget.frames.fps),
        (_) {
          if (mounted) {
            setState(() => _frame = (_frame + 1) % widget.frames.frames.length);
          }
        },
      );
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _frame = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PixelMicro old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PixelSprite(widget.frames.frames[_frame], scale: widget.scale);
}

/// A number that rolls to its new value in steps (16 fps over 350 ms) and
/// flashes sun-gold while it rolls, like an arcade score.
class PixelRollingNumber extends StatefulWidget {
  const PixelRollingNumber({
    super.key,
    required this.value,
    required this.style,
    this.format,
    this.animate = true,
  });

  final int value;
  final TextStyle style;
  final String Function(int value)? format;
  final bool animate;

  @override
  State<PixelRollingNumber> createState() => _PixelRollingNumberState();
}

class _PixelRollingNumberState extends State<PixelRollingNumber> {
  late int _shown = widget.value;
  Timer? _timer;
  bool _rolling = false;

  static const _steps = 6; // ≈ 350 ms at 16 fps

  @override
  void didUpdateWidget(PixelRollingNumber old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    _timer?.cancel();
    if (!pixelMotion(context, animate: widget.animate)) {
      _shown = widget.value;
      _rolling = false;
      return;
    }
    final from = _shown;
    final to = widget.value;
    var step = 0;
    _rolling = true;
    _timer = Timer.periodic(const Duration(milliseconds: 62), (t) {
      step++;
      if (!mounted) return t.cancel();
      setState(() {
        if (step >= _steps) {
          _shown = to;
          _rolling = false;
          t.cancel();
        } else {
          _shown = from + ((to - from) * step / _steps).round();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        widget.format?.call(_shown) ?? '$_shown',
        style: _rolling
            ? widget.style.copyWith(color: PixelPalette.sun)
            : widget.style,
      );
}
