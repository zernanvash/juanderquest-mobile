import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';

/// One line of the tutorial. [target] is the widget to point at (or null).
/// With [choices], the first answer continues and any other skips the rest.
class TutorialStep {
  final String text;
  final GlobalKey? target;
  final List<String> choices;

  const TutorialStep(this.text, {this.target, this.choices = const []});
}

/// Full-screen first-run tutorial (owner 2026-11-04: B's dark spotlight with
/// C's Juan at the bottom left). Tap to finish the line, tap again for the
/// next one. [onDone] runs once, whether finished or skipped.
class PixelTutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onDone;
  final String speaker;

  /// A bar the text box must stay above (the hotbar), so it never covers it.
  final GlobalKey? keepAbove;

  const PixelTutorialOverlay({
    super.key,
    required this.steps,
    required this.onDone,
    this.speaker = 'Juan',
    this.keepAbove,
  });

  @override
  State<PixelTutorialOverlay> createState() => _PixelTutorialOverlayState();
}

class _PixelTutorialOverlayState extends State<PixelTutorialOverlay>
    with SingleTickerProviderStateMixin {
  static const _charInterval = Duration(milliseconds: 35);

  int _step = 0;
  int _chars = 0;
  bool _done = false;
  Timer? _timer;

  /// Drives the blinking cursor and the bouncing arrow.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  TutorialStep get _current => widget.steps[_step];
  bool get _lineDone => _chars >= _current.text.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer == null && !_lineDone) _type();
  }

  void _type() {
    _timer?.cancel();
    _chars = 0;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _chars = _current.text.length;
      return;
    }
    _timer = Timer.periodic(_charInterval, (t) {
      if (!mounted || _lineDone) {
        t.cancel();
        return;
      }
      setState(() => _chars++);
      // A soft "blip" every few letters, like a game text box.
      if (_chars % 3 == 0) HapticFeedback.selectionClick();
    });
  }

  void _tap() {
    if (_done) return;
    if (!_lineDone) {
      _timer?.cancel();
      setState(() => _chars = _current.text.length);
      return;
    }
    // A question waits for a button.
    if (_current.choices.isNotEmpty) return;
    _next();
  }

  void _answer(int index) {
    if (!_lineDone) return;
    if (index == 0) {
      _next();
    } else {
      _finish();
    }
  }

  void _next() {
    if (_step >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _type();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// The target's rectangle in this overlay's coordinates.
  Rect? _targetRect() => _rectOf(_current.target);

  /// [key]'s rectangle in this overlay's coordinates.
  Rect? _rectOf(GlobalKey? key) {
    final target = key?.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (target is! RenderBox || !target.hasSize || me is! RenderBox) {
      return null;
    }
    final topLeft = me.globalToLocal(target.localToGlobal(Offset.zero));
    final r = (topLeft & target.size).intersect(Offset.zero & me.size);
    return r.isEmpty ? null : r;
  }

  String get _visible =>
      _current.text.substring(0, _chars.clamp(0, _current.text.length));

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final target = _targetRect();
    // Transparent Material: the overlay sits above the shell's Scaffold, so
    // without it Flutter draws its yellow "missing text style" underlines.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '${widget.speaker}: ${_current.text}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _ShadePainter(
                      target: target,
                      unit: grid.unit,
                      dim: 0.72,
                    ),
                  ),
                ),
              ),
              ..._arrow(grid, target),
              _box(context, grid, target),
              Positioned(
                top: MediaQuery.paddingOf(context).top + grid.px(3),
                right: grid.px(3),
                child: PixelButton(
                  key: const ValueKey('tutorial-skip'),
                  label: 'Skip',
                  variant: PixelButtonVariant.ghost,
                  onPressed: _finish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The target sits in the lower half (e.g. the hotbar).
  bool _low(Rect? target) =>
      target != null &&
      target.center.dy > MediaQuery.sizeOf(context).height / 2;

  /// A gold arrow bouncing at the spotlight, from the side the box is on.
  List<Widget> _arrow(PixelGrid grid, Rect? target) {
    if (target == null) return const [];
    final low = _low(target);
    return [
      AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final bob = grid.px(3) * _pulse.value;
          final h = grid.px(8);
          return Positioned(
            left: target.center.dx - grid.px(4),
            top: low
                ? target.top - h - grid.px(2) - bob
                : target.bottom + grid.px(2) + bob,
            child: CustomPaint(
              size: Size(grid.px(8), h),
              painter: _ArrowPainter(unit: grid.unit, down: low),
            ),
          );
        },
      ),
    ];
  }

  /// Juan large at the bottom left, a gold name tab over a wood text box.
  /// When the spotlight is low, the box sits just above it.
  Widget _box(BuildContext context, PixelGrid grid, Rect? target) {
    final screenH = MediaQuery.sizeOf(context).height;
    final bar = _rectOf(widget.keepAbove);
    final floor = bar == null
        ? MediaQuery.paddingOf(context).bottom + grid.px(4)
        : screenH - bar.top + grid.px(4);
    final bottom = _low(target)
        ? math.max(floor, screenH - target!.top + grid.px(12))
        : floor;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(grid.px(3), grid.px(30), grid.px(3), 0),
            child: PixelPanel(
              style: PixelBoxStyle.wood,
              padding: 4,
              child: Padding(
                padding: EdgeInsets.only(top: grid.px(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_visible,
                        style: PixelType.body(context,
                            color: PixelPalette.parchment)),
                    SizedBox(height: grid.px(2)),
                    if (_current.choices.isNotEmpty)
                      _buttonChoices(context, grid)
                    else
                      Row(
                        children: [
                          for (var i = 0; i < widget.steps.length; i++)
                            Container(
                              width: grid.px(3),
                              height: grid.px(3),
                              margin: EdgeInsets.only(right: grid.px(2)),
                              color: i == _step
                                  ? PixelPalette.sun
                                  : PixelPalette.woodLight,
                            ),
                          const Spacer(),
                          _moreMark(grid, PixelPalette.parchment),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: grid.px(2),
            top: 0,
            child: const PixelAnimation(DesignerArt.juanIdle, scale: 6),
          ),
          Positioned(
            left: grid.px(40),
            top: grid.px(24),
            child: PixelPanel(
              style: PixelBoxStyle.gold,
              padding: 1,
              child: Text(widget.speaker.toUpperCase(),
                  style: PixelType.small(context, color: PixelPalette.ink)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttonChoices(BuildContext context, PixelGrid grid) {
    if (!_lineDone) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: grid.px(2),
      runSpacing: grid.px(2),
      children: [
        for (var i = 0; i < _current.choices.length; i++)
          PixelButton(
            key: ValueKey('tutorial-choice-$i'),
            label: _current.choices[i],
            variant: i == 0
                ? PixelButtonVariant.primary
                : PixelButtonVariant.secondary,
            onPressed: () => _answer(i),
          ),
      ],
    );
  }

  Widget _moreMark(PixelGrid grid, Color color) => Align(
        alignment: Alignment.centerRight,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Opacity(
            opacity: _lineDone && _pulse.value > 0.3 ? 1 : 0,
            child: CustomPaint(
              size: Size(grid.px(5), grid.px(3)),
              painter: _ArrowPainter(unit: grid.unit, down: true, color: color),
            ),
          ),
        ),
      );
}

/// Dims the screen; marks the target with a frame (and a hole for B).
class _ShadePainter extends CustomPainter {
  final Rect? target;
  final double unit;
  final double dim;

  _ShadePainter({
    required this.target,
    required this.unit,
    required this.dim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final shade = Paint()..color = PixelPalette.ink.withValues(alpha: dim);
    final t = target;
    if (t != null) {
      canvas.drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(screen),
            Path()..addRect(t)),
        shade,
      );
    } else {
      canvas.drawRect(screen, shade);
    }
    if (t != null) {
      canvas.drawRect(
        t,
        Paint()
          ..color = PixelPalette.sun
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 2
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(_ShadePainter old) =>
      old.target != target || old.dim != dim || old.unit != unit;
}

/// A stepped pixel triangle pointing up or down.
class _ArrowPainter extends CustomPainter {
  final double unit;
  final bool down;
  final Color color;

  _ArrowPainter(
      {required this.unit, required this.down, this.color = PixelPalette.sun});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    final cols = (size.width / unit).floor();
    final rows = (size.height / unit).floor();
    for (var r = 0; r < rows; r++) {
      final inset = down ? r : rows - 1 - r;
      final w = cols - inset * 2;
      if (w <= 0) continue;
      canvas.drawRect(
          Rect.fromLTWH(inset * unit, r * unit, w * unit, unit), paint);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.down != down || old.unit != unit || old.color != color;
}

/// The first-run tutorial lines (owner 2026-11-04), shared by every style.
List<TutorialStep> firstRunSteps({
  GlobalKey? hero,
  GlobalKey? nextStop,
  GlobalKey? hotbar,
}) =>
    [
      const TutorialStep(
        "Hey, I'm Juan! First time in Pangasinan?",
        choices: ['Yes, show me', "No, I'll explore"],
      ),
      TutorialStep(
        'This card is your travel log. Visit places and finish quests to level up.',
        target: hero,
      ),
      TutorialStep(
        'Tap here for your next adventure: places near you, the map, or a quest.',
        target: nextStop,
      ),
      TutorialStep(
        'This bar jumps between Home, Explore, the Map, the Shop and your Profile. Have fun!',
        target: hotbar,
      ),
    ];
