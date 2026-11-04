import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';

/// How the first-run tutorial looks. The owner picks one in the Pixel lab
/// (2026-11-04); the others are removed afterwards.
enum TutorialStyle {
  /// A: black text box at the bottom, "* " lines, heart cursor for choices.
  undertale,

  /// B: dark screen with a spotlight, Juan beside a speech bubble, an arrow
  /// bouncing at the target.
  guide,

  /// C: Juan large at the bottom left, a name tab over the text box.
  novel,
}

extension TutorialStyleLabel on TutorialStyle {
  String get label => switch (this) {
        TutorialStyle.undertale => 'A · Story box',
        TutorialStyle.guide => 'B · Guide spotlight',
        TutorialStyle.novel => 'C · Visual novel',
      };
}

/// One line of the tutorial. [target] is the widget to point at (or null).
/// With [choices], the first answer continues and any other skips the rest.
class TutorialStep {
  final String text;
  final GlobalKey? target;
  final List<String> choices;

  const TutorialStep(this.text, {this.target, this.choices = const []});
}

/// Full-screen first-run tutorial. Tap to finish the line, tap again for the
/// next one. [onDone] runs once, whether finished or skipped.
class PixelTutorialOverlay extends StatefulWidget {
  final TutorialStyle style;
  final List<TutorialStep> steps;
  final VoidCallback onDone;
  final String speaker;

  const PixelTutorialOverlay({
    super.key,
    required this.style,
    required this.steps,
    required this.onDone,
    this.speaker = 'Juan',
  });

  @override
  State<PixelTutorialOverlay> createState() => _PixelTutorialOverlayState();
}

class _PixelTutorialOverlayState extends State<PixelTutorialOverlay>
    with SingleTickerProviderStateMixin {
  static const _charInterval = Duration(milliseconds: 35);

  int _step = 0;
  int _chars = 0;
  int _choice = 0;
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
    if (_current.choices.isNotEmpty) {
      _answer(_choice);
      return;
    }
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
    setState(() {
      _step++;
      _choice = 0;
    });
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
  Rect? _targetRect() {
    final key = _current.target;
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
    return Semantics(
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
                    dim: switch (widget.style) {
                      TutorialStyle.guide => 0.72,
                      TutorialStyle.undertale => 0.45,
                      TutorialStyle.novel => 0.35,
                    },
                    cutout: widget.style == TutorialStyle.guide,
                    outline: widget.style == TutorialStyle.undertale
                        ? PixelPalette.white
                        : PixelPalette.sun,
                    blink: widget.style == TutorialStyle.undertale
                        ? _pulse.value > 0.5
                        : true,
                  ),
                ),
              ),
            ),
            ...switch (widget.style) {
              TutorialStyle.undertale => _undertale(context, grid),
              TutorialStyle.guide => _guide(context, grid, target),
              TutorialStyle.novel => _novel(context, grid),
            },
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
    );
  }

  /// A: Undertale-like box. White frame on black, "* " text, heart cursor.
  List<Widget> _undertale(BuildContext context, PixelGrid grid) {
    const box = PixelBoxStyle(
      fill: PixelPalette.ink,
      highlight: PixelPalette.ink,
      shade: PixelPalette.ink,
      outline: PixelPalette.white,
      corner: 0,
      shadowPx: 0,
      bevel: false,
    );
    return [
      Positioned(
        left: grid.px(3),
        right: grid.px(3),
        bottom: MediaQuery.paddingOf(context).bottom + grid.px(6),
        child: PixelPanel(
          style: box,
          padding: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PixelAnimation(DesignerArt.juanIdle, scale: 3),
              SizedBox(width: grid.px(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('* $_visible',
                        style:
                            PixelType.body(context, color: PixelPalette.white)),
                    if (_lineDone && _current.choices.isNotEmpty) ...[
                      SizedBox(height: grid.px(3)),
                      for (var i = 0; i < _current.choices.length; i++)
                        _heartChoice(context, grid, i),
                    ] else
                      _moreMark(grid, PixelPalette.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _heartChoice(BuildContext context, PixelGrid grid, int i) {
    final selected = _choice == i;
    return GestureDetector(
      key: ValueKey('tutorial-choice-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) {
          _answer(i);
        } else {
          HapticFeedback.selectionClick();
          setState(() => _choice = i);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Row(
          children: [
            SizedBox(
              width: grid.px(10),
              child: selected
                  ? const PixelSprite(DesignerArt.heartLiked, scale: 1)
                  : null,
            ),
            Expanded(
              child: Text(
                _current.choices[i].toUpperCase(),
                style: PixelType.body(context,
                    color: selected ? PixelPalette.sun : PixelPalette.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// B: speech bubble with Juan beside it; an arrow bounces at the target.
  List<Widget> _guide(BuildContext context, PixelGrid grid, Rect? target) {
    final size = MediaQuery.sizeOf(context);
    final targetLow = target != null && target.center.dy > size.height / 2;
    final bubble = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const PixelAnimation(DesignerArt.juanIdle, scale: 4),
        SizedBox(width: grid.px(1)),
        Expanded(
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.speaker.toUpperCase(),
                    style: PixelType.small(context, color: PixelPalette.gold)),
                SizedBox(height: grid.px(1)),
                Text(_visible, style: PixelType.body(context)),
                SizedBox(height: grid.px(2)),
                _buttonChoices(context, grid),
              ],
            ),
          ),
        ),
      ],
    );
    return [
      if (target != null)
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final bob = grid.px(3) * _pulse.value;
            final arrowH = grid.px(8);
            return Positioned(
              left: target.center.dx - grid.px(4),
              top: targetLow
                  ? target.top - arrowH - grid.px(2) - bob
                  : target.bottom + grid.px(2) + bob,
              child: CustomPaint(
                size: Size(grid.px(8), arrowH),
                painter: _ArrowPainter(unit: grid.unit, down: targetLow),
              ),
            );
          },
        ),
      Positioned(
        left: grid.px(3),
        right: grid.px(3),
        top: targetLow ? MediaQuery.paddingOf(context).top + grid.px(16) : null,
        bottom: targetLow
            ? null
            : MediaQuery.paddingOf(context).bottom + grid.px(6),
        child: bubble,
      ),
    ];
  }

  /// C: Juan large at the left, a gold name tab over a wood text box.
  List<Widget> _novel(BuildContext context, PixelGrid grid) {
    return [
      Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.paddingOf(context).bottom + grid.px(4),
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
      ),
    ];
  }

  Widget _buttonChoices(BuildContext context, PixelGrid grid) {
    if (!_lineDone) return const SizedBox.shrink();
    if (_current.choices.isEmpty) {
      return Align(
        alignment: Alignment.centerRight,
        child: PixelButton(
          key: const ValueKey('tutorial-next'),
          label: _step >= widget.steps.length - 1 ? 'Got it' : 'Next >',
          onPressed: _next,
        ),
      );
    }
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
  final bool cutout;
  final Color outline;
  final bool blink;

  _ShadePainter({
    required this.target,
    required this.unit,
    required this.dim,
    required this.cutout,
    required this.outline,
    required this.blink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final shade = Paint()..color = PixelPalette.ink.withValues(alpha: dim);
    final t = target;
    if (t != null && cutout) {
      canvas.drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(screen),
            Path()..addRect(t)),
        shade,
      );
    } else {
      canvas.drawRect(screen, shade);
    }
    if (t != null && blink) {
      canvas.drawRect(
        t,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 2
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(_ShadePainter old) =>
      old.target != target ||
      old.blink != blink ||
      old.dim != dim ||
      old.unit != unit;
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
