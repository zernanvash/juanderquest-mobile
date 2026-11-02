import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_grid.dart';

class PixelBoxStyle {
  const PixelBoxStyle({
    required this.fill,
    required this.highlight,
    required this.shade,
    this.outline = PixelPalette.ink,
    this.shadow = PixelPalette.ink,
    this.corner = 2,
    this.shadowPx = 1,
    this.bevel = true,
  });

  final Color fill;
  final Color highlight;
  final Color shade;
  final Color outline;
  final Color? shadow;
  final int corner;
  final int shadowPx;
  final bool bevel;

  PixelBoxStyle copyWith({
    Color? fill,
    Color? highlight,
    Color? shade,
    Color? outline,
    Color? shadow,
    int? corner,
    int? shadowPx,
    bool? bevel,
  }) =>
      PixelBoxStyle(
        fill: fill ?? this.fill,
        highlight: highlight ?? this.highlight,
        shade: shade ?? this.shade,
        outline: outline ?? this.outline,
        shadow: shadow ?? this.shadow,
        corner: corner ?? this.corner,
        shadowPx: shadowPx ?? this.shadowPx,
        bevel: bevel ?? this.bevel,
      );

  static const parchment = PixelBoxStyle(
    fill: PixelPalette.parchment,
    highlight: PixelPalette.white,
    shade: PixelPalette.paperDim,
  );

  static const wood = PixelBoxStyle(
    fill: PixelPalette.wood,
    highlight: PixelPalette.woodMid,
    shade: PixelPalette.woodDeep,
  );

  static const green = PixelBoxStyle(
    fill: PixelPalette.green,
    highlight: PixelPalette.greenMid,
    shade: PixelPalette.greenDark,
  );

  static const gold = PixelBoxStyle(
    fill: PixelPalette.sun,
    highlight: PixelPalette.sunLight,
    shade: PixelPalette.amber,
  );

  static const red = PixelBoxStyle(
    fill: PixelPalette.red,
    highlight: PixelPalette.redBright,
    shade: PixelPalette.redDeep,
  );

  static const stone = PixelBoxStyle(
    fill: PixelPalette.stone,
    highlight: PixelPalette.mist,
    shade: PixelPalette.slate,
  );

  static const inkDialogue = PixelBoxStyle(
    fill: PixelPalette.ink,
    highlight: PixelPalette.ink,
    shade: PixelPalette.ink,
    outline: PixelPalette.paper,
    corner: 0,
    shadowPx: 0,
    bevel: false,
  );

  static const slot = PixelBoxStyle(
    fill: PixelPalette.paperDim,
    highlight: PixelPalette.white,
    shade: PixelPalette.mist,
    corner: 1,
    shadowPx: 0,
  );
}

List<Rect> steppedRects(int x, int y, int w, int h, int steps) {
  if (w <= 0 || h <= 0) return const [];
  final limit = (w < h ? w : h) ~/ 2;
  final s = steps.clamp(0, limit);
  if (s == 0) {
    return [
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
    ];
  }
  final out = <Rect>[];
  for (var i = 0; i < s; i++) {
    final inset = s - i;
    out.add(Rect.fromLTWH(
      (x + inset).toDouble(),
      (y + i).toDouble(),
      (w - 2 * inset).toDouble(),
      1,
    ));
    out.add(Rect.fromLTWH(
      (x + inset).toDouble(),
      (y + h - 1 - i).toDouble(),
      (w - 2 * inset).toDouble(),
      1,
    ));
  }
  out.add(Rect.fromLTWH(
    x.toDouble(),
    (y + s).toDouble(),
    w.toDouble(),
    (h - 2 * s).toDouble(),
  ));
  return out;
}

class PixelBoxPainter extends CustomPainter {
  PixelBoxPainter({
    required this.style,
    required this.grid,
    this.pressed = false,
    this.sunken = false,
  });

  final PixelBoxStyle style;
  final PixelGrid grid;
  final bool pressed;
  final bool sunken;

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final sh = style.shadowPx;
    final cols = (size.width / u).floor() - sh;
    final rows = (size.height / u).floor() - sh;
    if (cols < 3 || rows < 3) return;
    final paint = Paint()..isAntiAlias = false;
    final corner = style.corner;

    void fill(int x, int y, int w, int h, int steps, Color color) {
      paint.color = color;
      for (final r in steppedRects(x, y, w, h, steps)) {
        canvas.drawRect(
          Rect.fromLTRB(
            grid.snap(r.left * u),
            grid.snap(r.top * u),
            grid.snap(r.right * u),
            grid.snap(r.bottom * u),
          ),
          paint,
        );
      }
    }

    final o = pressed ? sh : 0;
    if (!pressed && sh > 0 && style.shadow != null) {
      fill(sh, sh, cols, rows, corner, style.shadow!.withValues(alpha: 0.45));
    }
    fill(o, o, cols, rows, corner, style.outline);

    final inverted = pressed || sunken;
    final hi = inverted ? style.shade : style.highlight;
    final lo = inverted ? style.highlight : style.shade;
    final innerCorner = corner > 0 ? corner - 1 : 0;
    if (style.bevel) {
      fill(o + 1, o + 1, cols - 2, rows - 2, innerCorner, lo);
      fill(o + 1, o + 1, cols - 3, rows - 3, innerCorner, hi);
      fill(
        o + 2,
        o + 2,
        cols - 4,
        rows - 4,
        innerCorner > 0 ? innerCorner - 1 : 0,
        style.fill,
      );
    } else {
      fill(o + 1, o + 1, cols - 2, rows - 2, innerCorner, style.fill);
    }
  }

  @override
  bool shouldRepaint(PixelBoxPainter old) =>
      old.style != style ||
      old.grid.unit != grid.unit ||
      old.pressed != pressed ||
      old.sunken != sunken;
}

class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.style = PixelBoxStyle.parchment,
    this.padding = 3,
    this.pressed = false,
    this.sunken = false,
  });

  final Widget child;
  final PixelBoxStyle style;
  final int padding;
  final bool pressed;
  final bool sunken;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final frame = 1 + (style.bevel ? 1 : 0) + padding;
    final sh = style.shadowPx;
    final shift = pressed ? sh : 0;
    return PixelSnap(
      child: CustomPaint(
        painter: PixelBoxPainter(
          style: style,
          grid: grid,
          pressed: pressed,
          sunken: sunken,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            grid.px(frame + shift),
            grid.px(frame + shift),
            grid.px(frame + sh - shift),
            grid.px(frame + sh - shift),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PixelSnap extends SingleChildRenderObjectWidget {
  const PixelSnap({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPixelSnap(MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPixelSnap).dpr =
        MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderPixelSnap extends RenderProxyBox {
  _RenderPixelSnap(this._dpr);

  double _dpr;

  set dpr(double value) {
    if (value == _dpr) return;
    _dpr = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final snapped = Offset(
      (offset.dx * _dpr).roundToDouble() / _dpr,
      (offset.dy * _dpr).roundToDouble() / _dpr,
    );
    super.paint(context, snapped);
  }
}
