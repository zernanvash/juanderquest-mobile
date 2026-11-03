import 'package:flutter/widgets.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';

class TheaterPanel extends StatelessWidget {
  const TheaterPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.cornerSteps = 2,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final int cornerSteps;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final pad = padding ?? EdgeInsets.all(grid.px(3));

    final panel = CustomPaint(
      painter: _TheaterPanelPainter(
        unit: grid.unit,
        cornerSteps: cornerSteps,
      ),
      child: Padding(
        padding: pad,
        child: child,
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: panel);
    }
    return panel;
  }
}

class _TheaterPanelPainter extends CustomPainter {
  _TheaterPanelPainter({
    required this.unit,
    required this.cornerSteps,
  });

  final double unit;
  final int cornerSteps;

  static final Paint _outlinePaint = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.fill
    ..color = PixelPalette.paper.withValues(alpha: 0.12);

  static final Paint _fillPaint = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.fill
    ..color = PixelPalette.ink.withValues(alpha: 0.82);

  @override
  void paint(Canvas canvas, Size size) {
    final w = (size.width / unit).floor();
    final h = (size.height / unit).floor();
    if (w <= 0 || h <= 0) return;

    final outline = steppedRects(0, 0, w, h, cornerSteps);
    for (final r in outline) {
      canvas.drawRect(
        Rect.fromLTWH(
          r.left * unit,
          r.top * unit,
          r.width * unit,
          r.height * unit,
        ),
        _outlinePaint,
      );
    }

    if (w > 2 && h > 2) {
      final innerSteps = (cornerSteps - 1).clamp(0, cornerSteps);
      final fill = steppedRects(1, 1, w - 2, h - 2, innerSteps);
      for (final r in fill) {
        canvas.drawRect(
          Rect.fromLTWH(
            r.left * unit,
            r.top * unit,
            r.width * unit,
            r.height * unit,
          ),
          _fillPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TheaterPanelPainter oldDelegate) =>
      oldDelegate.unit != unit || oldDelegate.cornerSteps != cornerSteps;
}

class TheaterTopScrim extends StatelessWidget {
  const TheaterTopScrim({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PixelPalette.ink.withValues(alpha: 0.75),
              PixelPalette.ink.withValues(alpha: 0.40),
              PixelPalette.ink.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
      ),
    );
  }
}

class TheaterBottomScrim extends StatelessWidget {
  const TheaterBottomScrim({super.key, this.height = 240});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PixelPalette.ink.withValues(alpha: 0.0),
              PixelPalette.ink.withValues(alpha: 0.50),
              PixelPalette.ink.withValues(alpha: 0.88),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}
