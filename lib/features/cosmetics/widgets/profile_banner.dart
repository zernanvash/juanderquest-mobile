import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../procedural/procedural_banner_painter.dart';

class ProfileBanner extends StatefulWidget {
  const ProfileBanner({
    super.key,
    required this.asset,
    this.seed,
    this.animate = false,
    this.height = 112,
    this.child,
  });

  final Map<String, dynamic>? asset;
  final int? seed;
  final bool animate;
  final double height;
  final Widget? child;

  @override
  State<ProfileBanner> createState() => _ProfileBannerState();
}

class _ProfileBannerState extends State<ProfileBanner>
    with TickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier(6);
  Ticker? _ticker;
  int _lastFrameMicros = 0;
  bool _reduceMotion = false;
  ProceduralBannerPainter? _painter;

  bool get _isProcedural => widget.asset?['style'] == 'procedural';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    _reduceMotion = reduce;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ProfileBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        !identical(oldWidget.asset, widget.asset) ||
        oldWidget.animate != widget.animate) {
      _painter?.disposeCache();
      _painter = null;
      _time.value = 6;
      _lastFrameMicros = 0;
      _syncTicker();
    }
  }

  void _syncTicker() {
    final shouldAnimate = widget.animate &&
        !_reduceMotion &&
        _isProcedural &&
        widget.seed != null;
    if (shouldAnimate) {
      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isActive) _ticker!.start();
    } else {
      _ticker?.stop();
      _time.value = 6;
    }
  }

  void _onTick(Duration elapsed) {
    final micros = elapsed.inMicroseconds;
    if (micros - _lastFrameMicros < 33333) return;
    _lastFrameMicros = micros;
    _time.value = 6 + micros / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    _painter?.disposeCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final colors = ((asset?['colors'] as List?) ?? const ['#3f6653', '#95d5b2'])
        .map((e) => _color(e.toString()))
        .toList();
    final angle = ((asset?['angle'] as num?) ?? 135).toDouble();
    final gradient = LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(angle * 3.14159 / 180),
    );
    final procedural = _isProcedural && widget.seed != null;
    if (procedural && _painter == null) {
      _painter = ProceduralBannerPainter(
        asset: asset!,
        seed: widget.seed!,
        time: _time,
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (procedural)
              CustomPaint(painter: _painter)
            else
              CustomPaint(
                painter:
                    _PatternPainter((asset?['pattern'] ?? 'none').toString()),
              ),
            if (widget.child != null) ...[
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                        stops: [0.40, 1],
                      ),
                    ),
                  ),
                ),
              ),
              widget.child!,
            ],
          ],
        ),
      ),
    );
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
    final paint = Paint()
      ..color = Colors.white.withOpacity(.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (pattern == 'sun') {
      canvas.drawCircle(Offset(size.width * .82, size.height * .25), 18, paint);
      canvas.drawCircle(Offset(size.width * .82, size.height * .25), 27, paint);
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
        canvas.drawPath(path, paint);
      }
    } else if (pattern == 'bamboo') {
      for (var x = size.width * .7; x < size.width; x += 18) {
        canvas.drawLine(Offset(x, 0), Offset(x - 30, size.height), paint);
      }
    } else if (pattern == 'capiz') {
      for (var x = size.width * .7; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, size.height * .35), 5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.pattern != pattern;
}
