import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Noisy pixel gradients (owner 2026-11-17): a gentle four-tone ramp from
/// the top colour to the bottom colour; neighbouring tones mix as scattered
/// pixel cells, so the fade is smooth but still pixel-textured. Chosen in Pixel Lab → Gradient
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
  // Owner 2026-11-17: "lets do scatter but more subtle".
  static final style =
      ValueNotifier<PixelTextureStyle>(PixelTextureStyle.scatter);

  /// How far down the ramp the noisy styles get at the very bottom (owner:
  /// the green was too dark at the bottom, keep it gentle).
  static const reach = 0.8;

  /// Scatter is chunkier, so it stops earlier to stay subtle.
  static const scatterReach = 0.5;

  /// How far down the four-tone ramp a textured panel gets at its bottom
  /// (white panels ramp toward gray, coloured ones toward their shade).
  static const panelReach = 0.85;
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

  static double hash(int x, int y, int seed) => _hash(x, y, seed);

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

  /// Number of tones in the ramp: [top], two shades mixed between, and
  /// [bottom]. Noise only blends neighbouring tones, so steps are gentle.
  static const tones = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cell = unit * (style == PixelTextureStyle.scatter ? 2 : 1);
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    canvas.drawRect(Offset.zero & size, Paint()..color = top);
    final buckets = List.generate(tones, (_) => <double>[]);
    for (var r = 0; r < rows; r++) {
      final t = rows <= 1 ? 1.0 : r / (rows - 1);
      // Where this row sits on the ramp, 0 (top) .. tones-1 (bottom).
      final r0 = style == PixelTextureStyle.scatter
          ? PixelTexture.scatterReach
          : reach;
      final base = t * r0 * (tones - 1);
      for (var c = 0; c < cols; c++) {
        var v = base;
        if (style == PixelTextureStyle.clouds) {
          v += (_value(c / 9, r / 7, seed + 1) - 0.5) * 0.9;
        }
        v = v.clamp(0.0, tones - 1.0);
        final lo = v.floor();
        final tone = _hash(c, r, seed) < v - lo ? lo + 1 : lo;
        if (tone == 0) continue;
        buckets[math.min(tone, tones - 1)]
          ..add((c + 0.5) * cell)
          ..add((r + 0.5) * cell);
      }
    }
    for (var k = 1; k < tones; k++) {
      if (buckets[k].isEmpty) continue;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(buckets[k]),
        Paint()
          ..color = Color.lerp(top, bottom, k / (tones - 1))!
          ..strokeWidth = cell
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = false,
      );
    }
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
