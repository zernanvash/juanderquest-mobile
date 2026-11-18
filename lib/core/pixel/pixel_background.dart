import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_box.dart';
import 'pixel_grid.dart';
import 'pixel_surface.dart';
import 'pixel_texture.dart';

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
    this.style,
  });

  final Color top;
  final Color bottom;
  final int bands;
  final Widget? child;

  /// Fixed texture (Pixel Lab swatches); null follows [PixelTexture.style].
  final PixelTextureStyle? style;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    // v0.3.1 dark mode: a light page becomes plain dark brown.
    if (PixelSurface.darkMode(context) &&
        (top.computeLuminance() + bottom.computeLuminance()) / 2 > 0.5) {
      return ColoredBox(
        key: const ValueKey('pixel_dark_page'),
        color: PixelSurface.darkPage,
        child: PixelSurface(
          dark: true,
          child: child ?? const SizedBox.expand(),
        ),
      );
    }
    // Owner 2026-11-17: Pixel Lab can swap the bands for a noisy texture.
    return ValueListenableBuilder<PixelTextureStyle>(
      valueListenable: PixelTexture.style,
      builder: (context, picked, _) {
        final style = this.style ?? picked;
        return PixelSnap(
          child: CustomPaint(
            isComplex: true,
            painter: style == PixelTextureStyle.classic
                ? _DitherPainter(grid.unit * 2, top, bottom, bands)
                : PixelNoisePainter(
                    unit: grid.unit,
                    top: top,
                    bottom: bottom,
                    style: style,
                  ),
            child: child ?? const SizedBox.expand(),
          ),
        );
      },
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
