import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_particles.dart';
import 'pixel_rpg.dart';

/// How big the moment is.
enum PixelPopperSize {
  /// One task done: a short pop from each corner.
  small,

  /// Stamp claimed, all tasks done, quest complete, spot posted.
  big,
}

/// Pixel party poppers (owner 2026-11-16: the pixel version of the old
/// confetti): two cones of square confetti shoot up from the bottom corners,
/// arc and fall. Drawn on the pixel grid by [PixelParticleSystem]; nothing is
/// tweened or rounded.
///
/// Does nothing under Settings -> Reduce motion, and in widget tests unless
/// [debugRunInTests] is set (a ticker would keep `pumpAndSettle` busy).
abstract final class PixelPoppers {
  @visibleForTesting
  static bool debugRunInTests = false;

  /// Counts calls that passed the motion check (tests read it).
  @visibleForTesting
  static int debugFired = 0;

  static final bool _inTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static const confetti = <Color>[
    PixelPalette.sun,
    PixelPalette.red,
    PixelPalette.greenBright,
    PixelPalette.blueBright,
    PixelPalette.flame,
    PixelPalette.white,
    PixelPalette.greenLight,
  ];

  static void fire(
    BuildContext context, {
    PixelPopperSize size = PixelPopperSize.big,
  }) {
    if (!pixelMotion(context)) return;
    debugFired++;
    if (_inTest && !debugRunInTests) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PopperLayer(size: size, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _PopperLayer extends StatefulWidget {
  const _PopperLayer({required this.size, required this.onDone});

  final PixelPopperSize size;
  final VoidCallback onDone;

  @override
  State<_PopperLayer> createState() => _PopperLayerState();
}

class _PopperLayerState extends State<_PopperLayer>
    with SingleTickerProviderStateMixin {
  final _system = PixelParticleSystem(capacity: 220, seed: 0x0C0FE771);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _fired = false;
  bool _secondDone = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _burst(Size screen, {required bool second}) {
    final big = widget.size == PixelPopperSize.big;
    final count = big ? (second ? 34 : 56) : 22;
    final speed = screen.height * (big ? 1.05 : 0.7);
    final y = screen.height - 8;
    // Up and inward from each bottom corner.
    _system.emitCone(
      origin: Offset(8, y),
      angle: -math.pi * 0.36,
      spread: math.pi * 0.20,
      count: count,
      palette: PixelPoppers.confetti,
      minSpeed: speed * 0.55,
      maxSpeed: speed,
      gravity: screen.height * 1.15,
      minLife: big ? 1.1 : 0.8,
      maxLife: big ? 1.9 : 1.2,
    );
    _system.emitCone(
      origin: Offset(screen.width - 8, y),
      angle: -math.pi * 0.64,
      spread: math.pi * 0.20,
      count: count,
      palette: PixelPoppers.confetti,
      minSpeed: speed * 0.55,
      maxSpeed: speed,
      gravity: screen.height * 1.15,
      minLife: big ? 1.1 : 0.8,
      maxLife: big ? 1.9 : 1.2,
    );
  }

  void _tick(Duration elapsed) {
    final screen = MediaQuery.sizeOf(context);
    if (!_fired) {
      _fired = true;
      _last = elapsed;
      _burst(screen, second: false);
      return;
    }
    // A second, smaller pop makes the big one read as a celebration.
    if (!_secondDone &&
        widget.size == PixelPopperSize.big &&
        elapsed.inMilliseconds > 260) {
      _secondDone = true;
      _burst(screen, second: true);
    }
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final alive = _system.step(dt);
    if (!alive && (_secondDone || widget.size == PixelPopperSize.small)) {
      _ticker.stop();
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _system.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: PixelParticleOverlay(system: _system));
  }
}
