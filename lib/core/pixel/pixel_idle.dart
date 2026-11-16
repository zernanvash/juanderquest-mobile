import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_grid.dart';
import 'pixel_rpg.dart';

/// Idle loops for Home panels (owner 2026-11-16): small, stepped, whole-pixel
/// motion (no smooth tweening). Each loop is a list of steps played on a
/// timer, then an optional pause. They stop under Settings -> Reduce motion,
/// and stay still in widget tests (an endless timer would never let
/// `pumpAndSettle` finish) unless [PixelLoop.debugRunInTests] is set.
class PixelLoop extends StatefulWidget {
  const PixelLoop({
    super.key,
    required this.steps,
    required this.builder,
    this.stepMs = 160,
    this.pauseMs = 0,
    this.enabled = true,
    this.child,
  });

  /// Number of steps in one loop.
  final int steps;

  /// Draws step `i` (0 = rest pose).
  final Widget Function(BuildContext context, int step, Widget? child) builder;
  final int stepMs;

  /// Rest time (step 0) after each loop.
  final int pauseMs;
  final bool enabled;
  final Widget? child;

  @visibleForTesting
  static bool debugRunInTests = false;

  static final bool _inTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<PixelLoop> createState() => _PixelLoopState();
}

class _PixelLoopState extends State<PixelLoop> {
  Timer? _timer;
  int _step = 0;
  int _restLeft = 0;

  bool _shouldRun(BuildContext context) =>
      widget.enabled &&
      pixelMotion(context) &&
      (!PixelLoop._inTest || PixelLoop.debugRunInTests);

  void _sync(bool run) {
    if (run && _timer == null) {
      _timer = Timer.periodic(Duration(milliseconds: widget.stepMs), (_) {
        if (!mounted) return;
        setState(() {
          if (_restLeft > 0) {
            _restLeft -= widget.stepMs;
            return;
          }
          _step = (_step + 1) % widget.steps;
          if (_step == 0) _restLeft = widget.pauseMs;
        });
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
    _sync(_shouldRun(context));
  }

  @override
  void didUpdateWidget(PixelLoop old) {
    super.didUpdateWidget(old);
    if (old.stepMs != widget.stepMs) {
      _timer?.cancel();
      _timer = null;
    }
    _sync(_shouldRun(context));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _step, widget.child);
}

/// Shakes left-right a few art px, then rests (the unclaimed stamp chest).
class PixelWiggle extends StatelessWidget {
  const PixelWiggle({
    super.key,
    required this.child,
    this.enabled = true,
    this.restMs = 2600,
  });

  final Widget child;
  final bool enabled;
  final int restMs;

  static const _dx = [0, -1, 1, -1, 1, 0];

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelLoop(
      steps: _dx.length,
      stepMs: 90,
      pauseMs: restMs,
      enabled: enabled,
      child: child,
      builder: (context, step, child) => Transform.translate(
        offset: Offset(_dx[step] * grid.unit, 0),
        child: child,
      ),
    );
  }
}

/// Tilts side to side in steps (the QOTD "?").
class PixelTilt extends StatelessWidget {
  const PixelTilt({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  static const _angles = [0.0, -0.18, 0.0, 0.18];

  @override
  Widget build(BuildContext context) {
    return PixelLoop(
      steps: _angles.length,
      stepMs: 300,
      enabled: enabled,
      child: child,
      builder: (context, step, child) =>
          Transform.rotate(angle: _angles[step], child: child),
    );
  }
}

/// Grows a step and back (the map pin, the next task's reward).
class PixelPulse extends StatelessWidget {
  const PixelPulse({
    super.key,
    required this.child,
    this.enabled = true,
    this.restMs = 900,
  });

  final Widget child;
  final bool enabled;
  final int restMs;

  static const _scale = [1.0, 1.12, 1.24, 1.12];

  @override
  Widget build(BuildContext context) {
    return PixelLoop(
      steps: _scale.length,
      stepMs: 120,
      pauseMs: restMs,
      enabled: enabled,
      child: child,
      builder: (context, step, child) =>
          Transform.scale(scale: _scale[step], child: child),
    );
  }
}

/// A pale band that sweeps across its child in whole-pixel steps, then rests
/// (claimed stamp, all daily tasks done).
class PixelShimmer extends StatelessWidget {
  const PixelShimmer({
    super.key,
    required this.child,
    this.enabled = true,
    this.color = PixelPalette.sunLight,
    this.restMs = 2200,
  });

  final Widget child;
  final bool enabled;
  final Color color;
  final int restMs;

  static const _steps = 12;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelLoop(
      steps: _steps,
      stepMs: 70,
      pauseMs: restMs,
      enabled: enabled,
      child: child,
      builder: (context, step, child) => Stack(
        children: [
          child!,
          if (step > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final band = grid.px(6);
                      final x = grid
                          .snap((box.maxWidth + band) * step / _steps - band);
                      return Stack(
                        children: [
                          Positioned(
                            left: x,
                            top: 0,
                            bottom: 0,
                            width: band,
                            child: ColoredBox(
                              color: color.withValues(alpha: 0.22),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
