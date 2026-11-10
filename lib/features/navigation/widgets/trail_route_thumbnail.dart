import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';

/// A small, static drawing of a trail's shape: its stops joined in order.
/// No map tiles. Owner 2026-11-10: "not another map, just the shape and small
/// simple map zoom out like vector".
class TrailRouteThumbnail extends StatelessWidget {
  /// Stop coordinates in visiting order, as (lat, lng).
  final List<(double, double)> points;
  final double height;

  const TrailRouteThumbnail({
    super.key,
    required this.points,
    this.height = 112,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trail route shape, ${points.length} stops',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: TrailShapePainter(points)),
      ),
    );
  }
}

class TrailShapePainter extends CustomPainter {
  final List<(double, double)> points;

  TrailShapePainter(this.points);

  /// Projects (lat, lng) into [size] with equal x/y scale and a margin.
  static List<Offset> project(
    List<(double, double)> points,
    Size size, {
    double margin = 14,
  }) {
    if (points.isEmpty) return const [];
    final midLat =
        points.map((p) => p.$1).reduce((a, b) => a + b) / points.length;
    final k = math.cos(midLat * math.pi / 180);
    final xs = [for (final p in points) p.$2 * k];
    final ys = [for (final p in points) -p.$1];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final w = math.max(size.width - margin * 2, 1.0),
        h = math.max(size.height - margin * 2, 1.0);
    final spanX = maxX - minX, spanY = maxY - minY;
    final scale = math.max(spanX, spanY) == 0
        ? 0.0
        : math.min(
            spanX == 0 ? double.infinity : w / spanX,
            spanY == 0 ? double.infinity : h / spanY,
          );
    final offX = margin + (w - spanX * scale) / 2,
        offY = margin + (h - spanY * scale) / 2;
    return [
      for (var i = 0; i < points.length; i++)
        Offset(offX + (xs[i] - minX) * scale, offY + (ys[i] - minY) * scale),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = PixelPalette.parchment);
    // Faint grid so it reads as a map without being one.
    final grid = Paint()
      ..color = PixelPalette.woodLight.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var x = 16.0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 16.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawRect(
      rect.deflate(1),
      Paint()
        ..color = PixelPalette.woodDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final pts = project(points, size);
    if (pts.length >= 2) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = PixelPalette.wood
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter,
      );
    }
    for (var i = 0; i < pts.length; i++) {
      final first = i == 0, last = i == pts.length - 1 && pts.length > 1;
      final side = last ? 12.0 : (first ? 10.0 : 8.0);
      final fill = first
          ? PixelPalette.blueBright
          : (last ? PixelPalette.red : PixelPalette.woodDeep);
      final r = Rect.fromCenter(center: pts[i], width: side, height: side);
      canvas.drawRect(r, Paint()..color = PixelPalette.cream);
      canvas.drawRect(r.deflate(2), Paint()..color = fill);
    }
  }

  @override
  bool shouldRepaint(TrailShapePainter old) => old.points != points;
}
