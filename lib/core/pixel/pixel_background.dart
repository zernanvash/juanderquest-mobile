import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_box.dart';
import 'pixel_grid.dart';

abstract final class PixelShaders {
  static ui.FragmentProgram? _ditherBg;

  static bool get isReady => _ditherBg != null;

  static Future<void> load() async {
    try {
      _ditherBg = await ui.FragmentProgram.fromAsset('shaders/dither_bg.frag');
    } catch (error) {
      _ditherBg = null;
      debugPrint('[PixelShaders] dither background unavailable: $error');
    }
  }

  static ui.FragmentShader? ditherShader() => _ditherBg?.fragmentShader();
}

class DitherBackground extends StatelessWidget {
  const DitherBackground({
    super.key,
    required this.top,
    required this.bottom,
    this.bands = 6,
    this.child,
  });

  final Color top;
  final Color bottom;
  final int bands;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelSnap(
      child: CustomPaint(
        painter: _DitherPainter(grid.unit * 2, top, bottom, bands),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _DitherPainter extends CustomPainter {
  _DitherPainter(this.cell, this.top, this.bottom, this.bands);

  final double cell;
  final Color top;
  final Color bottom;
  final int bands;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = PixelShaders.ditherShader();
    if (shader != null) {
      var i = 0;
      void f(double value) => shader.setFloat(i++, value);
      f(size.width);
      f(size.height);
      f(cell);
      for (final color in [top, bottom]) {
        f(color.r);
        f(color.g);
        f(color.b);
        f(color.a);
      }
      f(bands.toDouble());
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      return;
    }
    _paintBands(canvas, size);
  }

  void _paintBands(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final rows = math.max((size.height / cell).floor(), 1);
    final count = math.max(bands, 1);
    var previousStep = -1;
    var previousY = 0.0;
    for (var row = 0; row <= rows; row++) {
      final t = rows <= 1 ? 0.0 : row / rows;
      final step = (t * count).round().clamp(0, count);
      final y = math.min(row * cell, size.height);
      if (step == previousStep && row != rows) continue;
      if (previousStep >= 0) {
        paint.color =
            Color.lerp(top, bottom, previousStep / count) ?? PixelPalette.paper;
        canvas.drawRect(
          Rect.fromLTRB(0, previousY, size.width, y),
          paint,
        );
      }
      previousStep = step;
      previousY = y;
    }
  }

  @override
  bool shouldRepaint(_DitherPainter old) =>
      old.cell != cell ||
      old.top != top ||
      old.bottom != bottom ||
      old.bands != bands;
}
