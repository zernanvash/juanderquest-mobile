import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

/// Colours for [PixelText3D]: face, 1-pixel bevel on top edges, the side
/// (extrusion) and the outline around everything.
@immutable
class PixelText3DColors {
  const PixelText3DColors({
    required this.face,
    required this.bevel,
    required this.side,
    this.outline = PixelPalette.ink,
  });

  final Color face;
  final Color bevel;
  final Color side;
  final Color outline;

  static const gold = PixelText3DColors(
    face: PixelPalette.sun,
    bevel: PixelPalette.sunLight,
    side: PixelPalette.gold,
  );
  static const cream = PixelText3DColors(
    face: PixelPalette.cream,
    bevel: PixelPalette.white,
    side: PixelPalette.woodMid,
  );
  static const green = PixelText3DColors(
    face: PixelPalette.greenMid,
    bevel: PixelPalette.greenLight,
    side: PixelPalette.greenDeep,
  );
  static const red = PixelText3DColors(
    face: PixelPalette.redBright,
    bevel: PixelPalette.redSoft,
    side: PixelPalette.redDeep,
  );
}

/// Plan 101 prototype: bold, beveled, extruded ("2.5D") pixel text. No
/// gradients and no blur: stacked copies of the text, offset by whole art
/// pixels (outline, side, bevel, face).
class PixelText3D extends StatelessWidget {
  const PixelText3D(
    this.text, {
    super.key,
    this.size = 20,
    this.colors = PixelText3DColors.gold,
    this.depth = 2,
    this.pressed = false,
    this.textAlign = TextAlign.center,
  });

  final String text;

  /// Font size in logical pixels before the user's font scale.
  final double size;
  final PixelText3DColors colors;

  /// Extrusion in art pixels.
  final int depth;

  /// Pressed text sinks into its extrusion (for 2.5D buttons).
  final bool pressed;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final u = PixelGrid.of(context).unit;
    final base = PixelType.display(context).copyWith(
      fontSize: size * PixelScope.of(context).fontScale(),
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final d = pressed ? 0 : depth;
    final lift = (depth - d) * u; // pressed: the face moves down

    Widget layer(double dy, TextStyle style) => Transform.translate(
          offset: Offset(0, dy + lift),
          child: Text(text, style: style, textAlign: textAlign, maxLines: 1, softWrap: false),
        );

    final outline = base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * u
        ..strokeJoin = StrokeJoin.miter
        ..isAntiAlias = false
        ..color = colors.outline,
    );

    return Padding(
      // Room for the outline and the extrusion so nothing is clipped.
      padding: EdgeInsets.fromLTRB(u, 2 * u, u, (depth + 1) * u),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sizing child (invisible), so the widget measures like plain text.
          Opacity(opacity: 0, child: Text(text, style: base, textAlign: textAlign, maxLines: 1, softWrap: false)),
          for (var i = d; i >= -1; i--) layer(i * u, outline),
          for (var i = d; i >= 1; i--) layer(i * u, base.copyWith(color: colors.side)),
          layer(-u, base.copyWith(color: colors.bevel)),
          layer(0, base.copyWith(color: colors.face)),
        ],
      ),
    );
  }
}

/// Plan 101 prototype: a box-less 2.5D button. The text is the button; it
/// sinks into its extrusion while pressed.
class PixelText3DButton extends StatefulWidget {
  const PixelText3DButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.iconBox,
    this.size = 16,
    this.colors = PixelText3DColors.gold,
  });

  final String label;
  final VoidCallback? onPressed;
  final PixelArt? icon;

  /// Icon square in logical pixels (default: twice the text size).
  final double? iconBox;
  final double size;
  final PixelText3DColors colors;

  @override
  State<PixelText3DButton> createState() => _PixelText3DButtonState();
}

class _PixelText3DButtonState extends State<PixelText3DButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: enabled
              ? (_) {
                  setState(() => _down = false);
                  widget.onPressed!();
                }
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Transform.translate(
                      offset: Offset(0, _down ? grid.unit : 0),
                      child: PixelIconFit(widget.icon!, box: widget.iconBox ?? widget.size * 2),
                    ),
                  ],
                  // Only the text shrinks to fit; the icon keeps whole pixels.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelText3D(
                      widget.label,
                      size: widget.size,
                      colors: widget.colors,
                      pressed: _down,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plan 101: draws [art] as large as fits in a [box]×[box] square using a
/// whole number of device pixels per art pixel (pixel-perfect, never blurry),
/// centred. Icons of different art sizes end up about the same size.
class PixelIconFit extends StatelessWidget {
  const PixelIconFit(this.art, {super.key, required this.box, this.scale});

  final PixelArt art;
  final double box;

  /// Force one scale for every icon (uniform pixel size) instead of filling.
  final int? scale;

  static final _trimmed = <String, PixelArt>{};

  /// [art] without its transparent margins, so the visible drawing (not the
  /// canvas) decides the size. Cached per sprite.
  static PixelArt trim(PixelArt art) => _trimmed.putIfAbsent(art.name, () {
        var top = art.height, bottom = -1, left = art.width, right = -1;
        for (var y = 0; y < art.height; y++) {
          final row = art.rows[y];
          for (var x = 0; x < row.length; x++) {
            if (row[x] == '.') continue;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
            if (x < left) left = x;
            if (x > right) right = x;
          }
        }
        if (bottom < 0) return art;
        return PixelArt('${art.name}#trim', [
          for (var y = top; y <= bottom; y++) art.rows[y].substring(left, right + 1),
        ]);
      });

  static int fitScale(PixelArt art, double box, double dpr) {
    art = trim(art);
    final longest = art.width > art.height ? art.width : art.height;
    final s = (box * dpr / longest).floor();
    return s < 1 ? 1 : s;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox.square(
      dimension: box,
      child: Center(
        child: PixelSprite(trim(art), scale: scale ?? fitScale(art, box, dpr)),
      ),
    );
  }
}
