import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProfileBanner extends StatelessWidget {
  const ProfileBanner(
      {super.key, required this.asset, this.height = 112, this.child});
  final Map<String, dynamic>? asset;
  final double height;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final colors = ((asset?['colors'] as List?) ?? ['#3f6653', '#95d5b2'])
        .map((e) => _color(e.toString()))
        .toList();
    final angle = ((asset?['angle'] as num?) ?? 135).toDouble();
    return SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    transform: GradientRotation(angle * 3.14159 / 180))),
            child: CustomPaint(
                painter:
                    _PatternPainter((asset?['pattern'] ?? 'none').toString()),
                child: child)));
  }

  static Color _color(String value) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xff')));
    } catch (_) {
      return Colors.green;
    }
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.pattern);
  final String pattern;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (pattern == 'sun') {
      canvas.drawCircle(Offset(size.width * .82, size.height * .25), 18, p);
      canvas.drawCircle(Offset(size.width * .82, size.height * .25), 27, p);
    } else if (pattern == 'waves' || pattern == 'islands') {
      for (var row = 0; row < 3; row++) {
        final path = Path();
        for (double x = 0; x <= size.width; x += 8) {
          final y = size.height * (.48 + row * .18) + 6 * math.sin(x / 24);
          if (x == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, p);
      }
    } else if (pattern == 'bamboo') {
      for (var x = size.width * .7; x < size.width; x += 18) {
        canvas.drawLine(Offset(x, 0), Offset(x - 30, size.height), p);
      }
    } else if (pattern == 'capiz') {
      for (var x = size.width * .7; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, size.height * .35), 5, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.pattern != pattern;
}
