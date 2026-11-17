import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_grid.dart';

/// Disintegrate / materialize transition pattern for UI panels and modals.
enum PixelDisintegrateStyle {
  /// Assembles bottom-up from the nav trigger; dissolves upward like embers.
  upwardEmbers,

  /// Expands radially from the bottom-center nav button and implodes back in.
  centerVortex,

  /// Ordered 4x4 Bayer-dither scanline + edge erosion dissolve.
  edgeErode,
}

/// Mutable pooled particle — mutated in-place inside [PixelParticleSystem] so
/// frame updates perform zero heap allocations.
class PixelParticle {
  bool active = false;
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double ax = 0;
  double ay = 0;
  int sizeArtPx = 2;
  Color color = PixelPalette.sun;
  double life = 0;
  double maxLife = 0.45;

  void spawn({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double ax,
    required double ay,
    required int sizeArtPx,
    required Color color,
    required double maxLife,
  }) {
    active = true;
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.ax = ax;
    this.ay = ay;
    this.sizeArtPx = sizeArtPx;
    this.color = color;
    life = 0;
    this.maxLife = maxLife;
  }
}

/// Pre-allocated, deterministic pixel particle simulation controller.
/// Extends [ChangeNotifier] so [PixelParticleOverlay] repaints without
/// rebuilding surrounding widget trees.
class PixelParticleSystem extends ChangeNotifier {
  PixelParticleSystem({int capacity = 260, int seed = 0x51A7BEEF})
      : _pool = List<PixelParticle>.generate(capacity, (_) => PixelParticle()),
        _seed = seed & 0x7fffffff;

  final List<PixelParticle> _pool;
  int _seed;
  int _cursor = 0;
  int _activeCount = 0;

  static const List<Color> menuModalPalette = <Color>[
    PixelPalette.sun,
    PixelPalette.sunLight,
    PixelPalette.parchment,
    PixelPalette.paper,
    PixelPalette.amber,
    PixelPalette.woodLight,
  ];

  int get capacity => _pool.length;
  int get activeCount => _activeCount;
  bool get isActive => _activeCount > 0;

  /// Direct read-only view for the painter.
  List<PixelParticle> get particles => _pool;

  double _nextDouble() {
    // Numerical Recipes 32-bit LCG: fast, deterministic, zero allocations.
    _seed = (_seed * 1664525 + 1013904223) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  double _range(double min, double max) => min + (max - min) * _nextDouble();

  PixelParticle _alloc() {
    final len = _pool.length;
    for (var i = 0; i < len; i++) {
      final idx = (_cursor + i) % len;
      final candidate = _pool[idx];
      if (!candidate.active) {
        _cursor = (idx + 1) % len;
        return candidate;
      }
    }
    // Pool full: recycle oldest slot cleanly without allocating.
    final recycled = _pool[_cursor];
    _cursor = (_cursor + 1) % len;
    return recycled;
  }

  /// Emits a crisp burst of square pixel sparks around [origin].
  void emitBurst({
    required Offset origin,
    int count = 36,
    List<Color> palette = menuModalPalette,
    double minSpeed = 48,
    double maxSpeed = 190,
    double gravity = 180,
    double upwardBias = -60,
    double minLife = 0.28,
    double maxLife = 0.62,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = _nextDouble() * math.pi * 2;
      final speed = _range(minSpeed, maxSpeed);
      final vx = math.cos(angle) * speed;
      final vy = math.sin(angle) * speed + upwardBias;
      final p = _alloc();
      if (!p.active) _activeCount++;
      p.spawn(
        x: origin.dx + _range(-6, 6),
        y: origin.dy + _range(-4, 4),
        vx: vx,
        vy: vy,
        ax: 0,
        ay: gravity,
        sizeArtPx: (_nextDouble() < 0.25) ? 3 : ((_nextDouble() < 0.6) ? 2 : 1),
        color: palette[(_nextDouble() * palette.length)
            .floor()
            .clamp(0, palette.length - 1)],
        maxLife: _range(minLife, maxLife),
      );
    }
    notifyListeners();
  }

  /// Emits square confetti in a cone around [angle] (radians; -pi/2 is up),
  /// [spread] either side. Used by the party poppers.
  void emitCone({
    required Offset origin,
    required double angle,
    required double spread,
    int count = 40,
    List<Color> palette = menuModalPalette,
    double minSpeed = 200,
    double maxSpeed = 520,
    double gravity = 700,
    double minLife = 0.9,
    double maxLife = 1.6,
  }) {
    for (var i = 0; i < count; i++) {
      final a = angle + _range(-spread, spread);
      final speed = _range(minSpeed, maxSpeed);
      final p = _alloc();
      if (!p.active) _activeCount++;
      p.spawn(
        x: origin.dx,
        y: origin.dy,
        vx: math.cos(a) * speed,
        vy: math.sin(a) * speed,
        ax: 0,
        ay: gravity,
        sizeArtPx: (_nextDouble() < 0.3) ? 3 : 2,
        color: palette[(_nextDouble() * palette.length)
            .floor()
            .clamp(0, palette.length - 1)],
        maxLife: _range(minLife, maxLife),
      );
    }
    notifyListeners();
  }

  /// Emits disintegration / materialization particles along the active dissolve
  /// frontier of [modalRect] relative to the nav button [anchor].
  void emitDisintegrateFrontier({
    required Rect modalRect,
    required Offset anchor,
    required double prevProgress,
    required double progress,
    required bool opening,
    required PixelDisintegrateStyle style,
    List<Color> palette = menuModalPalette,
    int maxPerStep = 28,
  }) {
    if (modalRect.isEmpty) return;
    final tLo = math.min(prevProgress, progress);
    final tHi = math.max(prevProgress, progress);
    if ((tHi - tLo).abs() < 1e-4) return;

    // Normalize frontier band in [0, 1] along height / radius.
    final bandCenter = ((tLo + tHi) * 0.5).clamp(0.0, 1.0);
    var spawned = 0;

    for (var i = 0; i < maxPerStep; i++) {
      double px;
      double py;
      late final double vx;
      late final double vy;
      late final double ax;
      late final double ay;

      switch (style) {
        case PixelDisintegrateStyle.upwardEmbers:
          px = _range(modalRect.left, modalRect.right);
          // Frontier rises from modalRect.bottom -> modalRect.top on open and close.
          final fracFromBottom = bandCenter;
          final spreadY = (modalRect.height * 0.14).clamp(6.0, 26.0);
          py = (modalRect.bottom -
                  fracFromBottom * modalRect.height +
                  _range(-spreadY, spreadY))
              .clamp(modalRect.top, modalRect.bottom);
          if (opening) {
            final toTargetX = (px - anchor.dx) * _range(0.5, 1.4);
            vx = toTargetX * 0.6 + _range(-24, 24);
            vy = -_range(40, 125);
            ax = _range(-20, 20);
            ay = _range(20, 70);
          } else {
            vx = _range(-45, 45);
            vy = -_range(65, 165);
            ax = _range(-30, 30);
            ay = -_range(40, 90);
          }
        case PixelDisintegrateStyle.centerVortex:
          final angle = _range(0, math.pi * 2);
          final radiusScale = bandCenter.clamp(0.05, 1.0);
          final halfW = modalRect.width * 0.5 * radiusScale;
          final halfH = modalRect.height * 0.5 * radiusScale;
          final originCenter = Offset(
              modalRect.center.dx, modalRect.bottom - modalRect.height * 0.35);
          px = (originCenter.dx + math.cos(angle) * halfW)
              .clamp(modalRect.left, modalRect.right);
          py = (originCenter.dy + math.sin(angle) * halfH)
              .clamp(modalRect.top, modalRect.bottom);
          if (opening) {
            vx = math.cos(angle) * _range(35, 110);
            vy = math.sin(angle) * _range(35, 110) - 25;
            ax = 0;
            ay = 45;
          } else {
            vx = (anchor.dx - px) * _range(1.4, 2.6);
            vy = (anchor.dy - py) * _range(1.4, 2.6);
            ax = 0;
            ay = 35;
          }
        case PixelDisintegrateStyle.edgeErode:
          final onHoriz = _nextDouble() < 0.65;
          if (onHoriz) {
            px = _range(modalRect.left, modalRect.right);
            py = (_nextDouble() < 0.5 ? modalRect.top : modalRect.bottom) +
                _range(-6, 6);
          } else {
            px = (_nextDouble() < 0.5 ? modalRect.left : modalRect.right) +
                _range(-6, 6);
            py = _range(modalRect.top, modalRect.bottom);
          }
          // Mix in scanline particles across the dissolving modal face.
          if (_nextDouble() < 0.5) {
            px = _range(modalRect.left, modalRect.right);
            py = modalRect.top +
                modalRect.height * (opening ? (1.0 - bandCenter) : bandCenter);
          }
          vx = _range(-55, 55);
          vy = opening ? -_range(25, 85) : -_range(30, 100);
          ax = 0;
          ay = opening ? 40 : 65;
      }

      final p = _alloc();
      if (!p.active) _activeCount++;
      p.spawn(
        x: px,
        y: py,
        vx: vx,
        vy: vy,
        ax: ax,
        ay: ay,
        sizeArtPx: _nextDouble() < 0.2 ? 3 : (_nextDouble() < 0.65 ? 2 : 1),
        color: palette[(_nextDouble() * palette.length)
            .floor()
            .clamp(0, palette.length - 1)],
        maxLife: _range(0.22, 0.48),
      );
      spawned++;
    }
    if (spawned > 0) notifyListeners();
  }

  /// Advances particle kinematics by [dt] seconds in-place.
  /// Returns `true` if any particle remains alive.
  bool step(double dt) {
    if (_activeCount == 0) return false;
    final clampedDt = dt.clamp(0.0, 0.05);
    var alive = 0;
    for (var i = 0; i < _pool.length; i++) {
      final p = _pool[i];
      if (!p.active) continue;
      p.life += clampedDt;
      if (p.life >= p.maxLife) {
        p.active = false;
        continue;
      }
      p.vx += p.ax * clampedDt;
      p.vy += p.ay * clampedDt;
      p.x += p.vx * clampedDt;
      p.y += p.vy * clampedDt;
      alive++;
    }
    _activeCount = alive;
    notifyListeners();
    return alive > 0;
  }

  void clear() {
    for (var i = 0; i < _pool.length; i++) {
      _pool[i].active = false;
    }
    _activeCount = 0;
    notifyListeners();
  }
}

/// Renders active particles from [system] onto the pixel grid as crisp,
/// art-pixel-snapped squares (no anti-aliased blobs or rounded circles).
class PixelParticleOverlay extends StatelessWidget {
  const PixelParticleOverlay({
    super.key,
    required this.system,
  });

  final PixelParticleSystem system;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PixelParticlePainter(system: system, grid: grid),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PixelParticlePainter extends CustomPainter {
  _PixelParticlePainter({
    required this.system,
    required this.grid,
  }) : super(repaint: system);

  final PixelParticleSystem system;
  final PixelGrid grid;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (!system.isActive) return;
    final pool = system.particles;
    final unit = grid.unit;
    for (var i = 0; i < pool.length; i++) {
      final p = pool[i];
      if (!p.active) continue;
      final remaining = (1.0 - p.life / p.maxLife).clamp(0.0, 1.0);
      // 4-step retro opacity quantization.
      final alpha = remaining > 0.72
          ? 1.0
          : remaining > 0.48
              ? 0.75
              : remaining > 0.24
                  ? 0.5
                  : 0.25;
      final side = p.sizeArtPx * unit;
      final sx = grid.snap(p.x);
      final sy = grid.snap(p.y);
      if (sx + side < 0 ||
          sy + side < 0 ||
          sx > size.width ||
          sy > size.height) {
        continue;
      }
      _paint.color = p.color.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(sx, sy, side, side), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelParticlePainter oldDelegate) =>
      oldDelegate.system != system || oldDelegate.grid.unit != grid.unit;
}

/// Clips [child] on an art-pixel block grid with a 4x4 ordered Bayer-dither
/// disintegrate threshold so any widget (such as the MainMenu modal) can
/// materialize out of or dissolve into pixel blocks.
class PixelDisintegrateMask extends StatelessWidget {
  const PixelDisintegrateMask({
    super.key,
    required this.progress,
    required this.style,
    required this.child,
    this.cellArtPx = 5,
  });

  /// 0.0 = completely disintegrated (hidden), 1.0 = completely assembled.
  final double progress;
  final PixelDisintegrateStyle style;
  final Widget child;
  final int cellArtPx;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.001) return const SizedBox.shrink();
    if (progress >= 0.999) return child;

    final grid = PixelGrid.of(context);
    final cellSize = math.max(4.0, grid.px(cellArtPx));
    return ClipPath(
      clipper: _PixelDisintegrateClipper(
        progress: progress,
        style: style,
        cellSize: cellSize,
      ),
      child: child,
    );
  }
}

class _PixelDisintegrateClipper extends CustomClipper<Path> {
  const _PixelDisintegrateClipper({
    required this.progress,
    required this.style,
    required this.cellSize,
  });

  final double progress;
  final PixelDisintegrateStyle style;
  final double cellSize;

  // Normalized 4x4 Bayer matrix values in [0, 15].
  static const List<int> _bayer4x4 = <int>[
    0,
    8,
    2,
    10,
    12,
    4,
    14,
    6,
    3,
    11,
    1,
    9,
    15,
    7,
    13,
    5,
  ];

  @override
  Path getClip(Size size) {
    final path = Path();
    if (size.isEmpty || progress <= 0.001) return path;
    if (progress >= 0.999) {
      path.addRect(Offset.zero & size);
      return path;
    }

    final cols = math.max(1, (size.width / cellSize).ceil());
    final rows = math.max(1, (size.height / cellSize).ceil());
    final centerCol = (cols - 1) * 0.5;
    final maxDist =
        math.max(1.0, math.sqrt(centerCol * centerCol + rows * rows));

    for (var r = 0; r < rows; r++) {
      final top = r * cellSize;
      final h = math.min(cellSize, size.height - top);
      var runStart = -1;

      for (var c = 0; c <= cols; c++) {
        var visible = false;
        if (c < cols) {
          final bayer = _bayer4x4[(r & 3) * 4 + (c & 3)] / 16.0;
          final double bias;
          switch (style) {
            case PixelDisintegrateStyle.upwardEmbers:
              // Bottom cells (near nav MENU button) assemble first on open.
              final fromBottom = 1.0 - (r / math.max(1, rows - 1));
              bias = fromBottom * 0.62 + bayer * 0.38;
            case PixelDisintegrateStyle.centerVortex:
              // Expands outward from bottom-center nav anchor.
              final dx = c - centerCol;
              final dy = (rows - 1) - r;
              final dist = math.sqrt(dx * dx + dy * dy) / maxDist;
              bias = dist * 0.64 + bayer * 0.36;
            case PixelDisintegrateStyle.edgeErode:
              // Edges dissolve first, core holds longest.
              final nx = (c / math.max(1, cols - 1) - 0.5).abs() * 2.0;
              final ny = (r / math.max(1, rows - 1) - 0.5).abs() * 2.0;
              final edge = math.max(nx, ny);
              bias = edge * 0.45 + bayer * 0.55;
          }
          visible = progress >= bias;
        }

        if (visible && runStart < 0) {
          runStart = c;
        } else if (!visible && runStart >= 0) {
          final left = runStart * cellSize;
          final right = math.min(c * cellSize, size.width);
          path.addRect(Rect.fromLTWH(left, top, right - left, h));
          runStart = -1;
        }
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _PixelDisintegrateClipper oldClipper) =>
      (oldClipper.progress - progress).abs() > 1e-3 ||
      oldClipper.style != style ||
      oldClipper.cellSize != cellSize;
}
