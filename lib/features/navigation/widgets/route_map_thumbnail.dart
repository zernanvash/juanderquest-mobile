import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import 'ph_outline.g.dart';

/// A small map preview: the real route shape drawn over a plain outline of the
/// Philippines (no roads, no labels). Owner 2026-11-13: "the shape of the real
/// route should reflect on preview, with real map (philippines) preview
/// without much details".
class RouteMapThumbnail extends StatelessWidget {
  /// Route as flat lng, lat pairs, in travel order.
  final List<double> route;

  /// Optional stops as flat lng, lat pairs.
  final List<double> stops;
  final Color lineColor;
  final bool border;

  const RouteMapThumbnail({
    super.key,
    required this.route,
    this.stops = const [],
    this.lineColor = PixelPalette.blueBright,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: RouteMapPainter(route, stops, lineColor, border),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class RouteMapPainter extends CustomPainter {
  final List<double> route;
  final List<double> stops;
  final Color lineColor;
  final bool border;

  RouteMapPainter(this.route, this.stops, this.lineColor, this.border);

  /// The lng/lat window to show: the route's box with a margin, never tighter
  /// than [minSpan] degrees so some coastline gives it context.
  static Rect viewport(List<double> route, Size size, {double minSpan = 0.3}) {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i + 1 < route.length; i += 2) {
      minX = math.min(minX, route[i]);
      maxX = math.max(maxX, route[i]);
      minY = math.min(minY, route[i + 1]);
      maxY = math.max(maxY, route[i + 1]);
    }
    if (route.length < 2) return const Rect.fromLTRB(116.5, 4.5, 127, 21.5);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final k = math.cos(cy * math.pi / 180);
    var spanX = math.max((maxX - minX) * 1.5, minSpan);
    var spanY = math.max((maxY - minY) * 1.5, minSpan * k);
    // Match the box's shape (x degrees are shorter than y degrees by k).
    final aspect = size.width / math.max(size.height, 1);
    if (spanX * k / spanY < aspect) {
      spanX = spanY * aspect / k;
    } else {
      spanY = spanX * k / aspect;
    }
    return Rect.fromLTRB(
        cx - spanX / 2, cy - spanY / 2, cx + spanX / 2, cy + spanY / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final v = viewport(route, size);
    Offset p(double lng, double lat) => Offset(
          (lng - v.left) / v.width * size.width,
          (v.bottom - lat) / v.height * size.height,
        );

    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = PixelPalette.blueLight);
    final land = Paint()..color = PixelPalette.cream;
    final coast = Paint()
      ..color = PixelPalette.woodLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.miter;
    for (final ring in kPhilippinesOutline) {
      final path = Path();
      for (var i = 0; i + 1 < ring.length; i += 2) {
        final o = p(ring[i], ring[i + 1]);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, land);
      canvas.drawPath(path, coast);
    }

    if (route.length >= 4) {
      final path = Path();
      for (var i = 0; i + 1 < route.length; i += 2) {
        final o = p(route[i], route[i + 1]);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      final w = (size.shortestSide / 24).clamp(2.0, 6.0);
      Paint line(Color c, double width) => Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.square;
      canvas.drawPath(path, line(PixelPalette.ink, w + 3));
      canvas.drawPath(path, line(lineColor, w));
    }

    void dot(Offset c, double side, Color fill) {
      final r = Rect.fromCenter(center: c, width: side, height: side);
      canvas.drawRect(r.inflate(1.5), Paint()..color = PixelPalette.ink);
      canvas.drawRect(r, Paint()..color = fill);
    }

    final d = (size.shortestSide / 10).clamp(4.0, 12.0);
    for (var i = 0; i + 1 < stops.length; i += 2) {
      dot(p(stops[i], stops[i + 1]), d, PixelPalette.sun);
    }
    if (route.length >= 4) {
      dot(p(route[0], route[1]), d, PixelPalette.blueBright);
      dot(p(route[route.length - 2], route[route.length - 1]), d * 1.2,
          PixelPalette.red);
    }
    canvas.restore();
    if (border) {
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..color = PixelPalette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(RouteMapPainter old) =>
      !identical(old.route, route) ||
      !identical(old.stops, stops) ||
      old.lineColor != lineColor;
}
