import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_grid.dart';
import 'pixel_surface.dart';
import 'pixel_texture.dart';

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

  /// Behind coin amounts (owner 2026-11-17: not yellow, the coin is yellow).
  static const coin = PixelBoxStyle(
    fill: PixelPalette.blueDeep,
    highlight: PixelPalette.blue,
    shade: PixelPalette.ink,
  );

  /// The earlier, darker brown for spotlight cards (owner 2026-11-17: the
  /// lighter logo brown looked off on them).
  static const darkWood = PixelBoxStyle(
    fill: PixelPalette.woodDark,
    highlight: PixelPalette.woodMid,
    shade: PixelPalette.woodDeep,
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

  static final tooltip = PixelBoxStyle(
    fill: PixelPalette.ink.withValues(alpha: 0.92),
    highlight: PixelPalette.ink.withValues(alpha: 0.92),
    shade: PixelPalette.ink.withValues(alpha: 0.92),
    outline: PixelPalette.mist,
    corner: 0,
    shadowPx: 0,
    bevel: false,
  );

  static const slot = PixelBoxStyle(
    fill: PixelPalette.paperDim,
    highlight: PixelPalette.white,
    shade: PixelPalette.mist,
    corner: 2,
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
    this.textured = false,
    this.textureStrength = 1,
  });

  final PixelBoxStyle style;
  final PixelGrid grid;
  final bool pressed;
  final bool sunken;

  /// Faint scatter speckles on the fill (see [PixelPanelTexture]).
  final bool textured;

  /// How far the ramp's bottom colour is from the fill, 0..1.
  final double textureStrength;

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
    if (textured) _speckle(canvas, o, cols, rows, innerCorner);
  }

  // Owner 2026-11-17: panel fills are a visible four-tone ramp, top to
  // bottom: white panels fade toward gray, coloured panels toward their own
  // shade. Neighbouring tones mix as 2-unit scatter cells (no bands).
  void _speckle(Canvas canvas, int o, int cols, int rows, int corner) {
    final b = style.bevel ? 2 : 1;
    final x0 = o + b, y0 = o + b;
    final w = cols - 2 * b, h = rows - 2 * b;
    if (w < 4 || h < 4) return;
    final u = grid.unit;
    final steps = style.bevel && corner > 0 ? corner - 1 : corner;
    final clip = Path();
    for (final r in steppedRects(x0, y0, w, h, steps)) {
      clip.addRect(Rect.fromLTRB(grid.snap(r.left * u), grid.snap(r.top * u),
          grid.snap(r.right * u), grid.snap(r.bottom * u)));
    }
    final light = style.fill.computeLuminance() > 0.6;
    // Owner 2026-11-17: white panels fade to a dirty cream, not gray.
    final target = light
        ? Color.lerp(
            style.fill, PixelPalette.woodLight, PixelTexture.panelCreamTone)!
        : style.shade;
    final bottom = Color.lerp(style.fill, target, textureStrength)!;
    const tones = PixelNoisePainter.tones;
    const reach = PixelTexture.panelReach;
    final buckets = List.generate(tones, (_) => <double>[]);
    final cellsX = (w + 1) ~/ 2, cellsY = (h + 1) ~/ 2;
    for (var r = 0; r < cellsY; r++) {
      final t = cellsY <= 1 ? 1.0 : r / (cellsY - 1);
      final v = t * reach * (tones - 1);
      final lo = v.floor();
      for (var c = 0; c < cellsX; c++) {
        final tone = math.min(
            PixelNoisePainter.hash(c, r, w * 31 + h) < v - lo ? lo + 1 : lo,
            tones - 1);
        if (tone == 0) continue;
        buckets[tone]
          ..add((x0 + c * 2 + 1) * u)
          ..add((y0 + r * 2 + 1) * u);
      }
    }
    canvas.save();
    canvas.clipPath(clip, doAntiAlias: false);
    for (var k = 1; k < tones; k++) {
      if (buckets[k].isEmpty) continue;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(buckets[k]),
        Paint()
          ..isAntiAlias = false
          ..strokeWidth = 2 * u
          ..strokeCap = StrokeCap.square
          ..color = Color.lerp(style.fill, bottom, k / (tones - 1))!,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PixelBoxPainter old) =>
      old.style != style ||
      old.grid.unit != grid.unit ||
      old.pressed != pressed ||
      old.sunken != sunken ||
      old.textured != textured ||
      old.textureStrength != textureStrength;
}

/// Turns on the subtle scatter texture for every [PixelPanel] below it big
/// enough to carry it (owner 2026-11-17: tried on Home first).
class PixelPanelTexture extends InheritedWidget {
  const PixelPanelTexture({super.key, required super.child, this.strength = 1});

  /// How strong the fade is under this scope, 0..1 (Explore uses a faint
  /// one; owner 2026-11-17: "too distracting").
  final double strength;

  /// The nearest scope's strength, or 0 when there is none.
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PixelPanelTexture>()
          ?.strength ??
      0;

  @override
  bool updateShouldNotify(PixelPanelTexture oldWidget) =>
      oldWidget.strength != strength;
}

class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.style = PixelBoxStyle.parchment,
    this.padding = sectionPadding,
    this.pressed = false,
    this.sunken = false,
  });

  /// Inside padding (art px) of a section panel, the default (owner
  /// 2026-11-17: wide panels, roomy inside).
  static const sectionPadding = 6;

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
    final texture = PixelPanelTexture.of(context);
    return PixelSnap(
      child: CustomPaint(
        painter: PixelBoxPainter(
          style: style,
          grid: grid,
          pressed: pressed,
          sunken: sunken,
          // Only section panels; buttons, chips and small boxes stay plain.
          textured: padding >= sectionPadding && texture > 0,
          textureStrength: texture,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            grid.px(frame + shift),
            grid.px(frame + shift),
            grid.px(frame + sh - shift),
            grid.px(frame + sh - shift),
          ),
          // A panel is its own surface: dark-mode page colours stop here.
          child: PixelSurface(
            dark: style.fill.computeLuminance() < 0.2,
            child: child,
          ),
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
