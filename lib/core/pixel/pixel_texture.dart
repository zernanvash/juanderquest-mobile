import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Noisy pixel gradients (owner 2026-11-17): instead of straight bands, the
/// two colours mix as scattered pixel cells, thin at the top and thicker
/// toward the bottom, like a dissolve. Chosen in Pixel Lab → Gradient
/// textures; [DitherBackground] follows the pick.
enum PixelTextureStyle {
  /// The original ordered dither in bands.
  classic('Classic bands', 'Even steps, the look until now.'),

  /// White-noise dissolve in 2-unit cells (the owner's reference).
  scatter('Scatter', 'Random pixel cells, chunky.'),

  /// The same dissolve in 1-unit cells, gentler.
  grain('Fine grain', 'Smaller cells, quieter.'),

  /// The dissolve pushed around by soft blobs, so it is not a straight line.
  clouds('Clouds', 'Patches of colour drift across.');

  const PixelTextureStyle(this.label, this.hint);
  final String label;
  final String hint;
}

abstract final class PixelTexture {
  /// The texture every [DitherBackground] uses. Not saved yet; Pixel Lab
  /// sets it while the owner picks.
  static final style =
      ValueNotifier<PixelTextureStyle>(PixelTextureStyle.classic);

  /// How much of the bottom colour the noisy styles reach at the very
  /// bottom (owner: the green was too dark at the bottom).
  static const reach = 0.72;
}

/// Paints a noisy two-colour gradient from [top] to [bottom] in pixel cells.
class PixelNoisePainter extends CustomPainter {
  PixelNoisePainter({
    required this.unit,
    required this.top,
    required this.bottom,
    required this.style,
    this.reach = PixelTexture.reach,
    this.seed = 7,
  });

  final double unit;
  final Color top;
  final Color bottom;
  final PixelTextureStyle style;
  final double reach;
  final int seed;

  static double _hash(int x, int y, int seed) {
    var h = x * 374761393 + y * 668265263 + seed * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0xffffff) / 0x1000000;
  }

  // Smooth value noise for [PixelTextureStyle.clouds].
  static double _value(double x, double y, int seed) {
    final xi = x.floor(), yi = y.floor();
    final fx = x - xi, fy = y - yi;
    double s(double t) => t * t * (3 - 2 * t);
    final a = _hash(xi, yi, seed), b = _hash(xi + 1, yi, seed);
    final c = _hash(xi, yi + 1, seed), d = _hash(xi + 1, yi + 1, seed);
    final top = a + (b - a) * s(fx);
    final bot = c + (d - c) * s(fx);
    return top + (bot - top) * s(fy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cell = unit * (style == PixelTextureStyle.scatter ? 2 : 1);
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    canvas.drawRect(Offset.zero & size, Paint()..color = top);
    final pts = <double>[];
    for (var r = 0; r < rows; r++) {
      final t = rows <= 1 ? 1.0 : r / (rows - 1);
      // Ease in: the top stays clean longer, the mix builds near the bottom.
      final base = math.pow(t, 1.35) * reach;
      for (var c = 0; c < cols; c++) {
        var p = base;
        if (style == PixelTextureStyle.clouds) {
          p += (_value(c / 9, r / 7, seed + 1) - 0.5) * 0.45;
        }
        if (_hash(c, r, seed) < p) {
          pts
            ..add((c + 0.5) * cell)
            ..add((r + 0.5) * cell);
        }
      }
    }
    if (pts.isEmpty) return;
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(pts),
      Paint()
        ..color = bottom
        ..strokeWidth = cell
        ..strokeCap = StrokeCap.square
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(PixelNoisePainter old) =>
      old.unit != unit ||
      old.top != top ||
      old.bottom != bottom ||
      old.style != style ||
      old.reach != reach ||
      old.seed != seed;
}
