import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../procedural/procedural_banner_painter.dart';

class ProfileBanner extends StatefulWidget {
  const ProfileBanner({
    super.key,
    required this.asset,
    this.seed,
    this.animate = false,
    this.forceMotion = false,
    this.height = 112,
    this.child,
  });

  final Map<String, dynamic>? asset;
  final int? seed;
  final bool animate;

  /// Plan 69: motion the traveler asked for (a preview, or "Live animations" on) plays even
  /// when the system asks to remove animations. Everything else follows the system setting.
  final bool forceMotion;
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
        oldWidget.animate != widget.animate ||
        oldWidget.forceMotion != widget.forceMotion) {
      _painter?.disposeCache();
      _painter = null;
      _time.value = 6;
      _lastFrameMicros = 0;
      _syncTicker();
    }
  }

  void _syncTicker() {
    // Procedural banners redraw from the clock; gradient banners drift slowly with it.
    final shouldAnimate = widget.animate &&
        (widget.forceMotion || !_reduceMotion) &&
        (!_isProcedural || widget.seed != null);
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
    final procedural = _isProcedural && widget.seed != null;
    LinearGradient gradientAt(double t) {
      // 8 s drift loop; still frames (t = 6) keep the original diagonal.
      final shift = procedural || t == 6
          ? 0.0
          : .45 * math.sin((t - 6) * 2 * math.pi / 8);
      return LinearGradient(
        colors: colors,
        begin: Alignment(-1 + shift, -1),
        end: Alignment(1 + shift, 1),
        transform: GradientRotation(angle * math.pi / 180),
      );
    }

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
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (asset == null)
            const DitherBackground(
              top: PixelPalette.greenMid,
              bottom: PixelPalette.greenDeep,
            )
          else
            ValueListenableBuilder<double>(
              valueListenable: _time,
              builder: (context, t, child) => DecoratedBox(
                decoration: BoxDecoration(gradient: gradientAt(t)),
                child: child,
              ),
              child: procedural
                  ? CustomPaint(painter: _painter)
                  : CustomPaint(
                      painter: _PatternPainter(
                        (asset['pattern'] ?? 'none').toString(),
                        PixelGrid.of(context).unit,
                      ),
                    ),
            ),
          if (widget.child != null) ...[
            widget.child!,
          ],
        ],
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
  _PatternPainter(this.pattern, this.unit);
  final String pattern;

  /// One art pixel in logical px (whole device pixels), for pixel patterns.
  final double unit;

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
      _CapizWindow.paint(canvas, size, unit);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) =>
      old.pattern != pattern || old.unit != unit;
}

/// Capiz Heritage (owner 2026-11-05: "draw a proper capiz-shell pattern"):
/// a Philippine capiz window: square pearly shell panes in a dark wooden
/// lattice. Everything sits on whole art pixels; palette colours only.
abstract final class _CapizWindow {
  /// Pane interior, lattice bar and outer frame, in art pixels.
  static const _pane = 10;
  static const _bar = 1;
  static const _frame = 2;

  /// Pearly tints; each pane picks one from its position (no randomness, so
  /// the banner is the same everywhere and paints identically every frame).
  static const _tints = [
    PixelPalette.cream,
    PixelPalette.sunLight,
    PixelPalette.paperDim,
    PixelPalette.parchment,
    PixelPalette.mist,
  ];

  static final _wood = Paint()..color = PixelPalette.woodDeep;
  static final _woodLight = Paint()..color = PixelPalette.wood;
  static final _white = Paint()..color = PixelPalette.white;
  static final _sheen = Paint()
    ..color = PixelPalette.white.withValues(alpha: 0.55);
  static final _shade = Paint()
    ..color = PixelPalette.woodLight.withValues(alpha: 0.45);
  static final _fill = Paint();

  static void paint(Canvas canvas, Size size, double u) {
    if (u <= 0) return;
    final cols = (size.width / u).ceil();
    final rows = (size.height / u).ceil();
    Rect px(int x, int y, int w, int h) =>
        Rect.fromLTWH(x * u, y * u, w * u, h * u);

    // Lattice: the whole banner is wood; panes are cut out of it.
    canvas.drawRect(Offset.zero & size, _wood);
    // Top highlight of the outer frame.
    canvas.drawRect(px(0, 0, cols, 1), _woodLight);

    const step = _pane + _bar;
    for (var py = _frame, row = 0; py < rows - _frame; py += step, row++) {
      for (var pxl = _frame, col = 0; pxl < cols - _frame; pxl += step, col++) {
        final w = math.min(_pane, cols - _frame - pxl);
        final h = math.min(_pane, rows - _frame - py);
        if (w < 3 || h < 3) continue;
        _fill.color =
            _tints[(row * 3 + col * 2 + (row * col) % 3) % _tints.length];
        canvas.drawRect(px(pxl, py, w, h), _fill);
        // Shell sheen: a soft diagonal of light across the pane.
        for (var i = 1; i < math.min(w, h) - 2; i += 2) {
          canvas.drawRect(px(pxl + i, py + h - 2 - i, 1, 1), _sheen);
        }
        // Light from the top-left, shadow on the bottom-right inner edges.
        canvas.drawRect(px(pxl, py, w, 1), _white);
        canvas.drawRect(px(pxl, py, 1, h), _white);
        canvas.drawRect(px(pxl, py + h - 1, w, 1), _shade);
        canvas.drawRect(px(pxl + w - 1, py, 1, h), _shade);
      }
    }
  }
}
