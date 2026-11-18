import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_grid.dart';
import 'pixel_surface.dart';
import 'pixel_text.dart';

/// Colours for [PixelText3D]: face, 1-pixel bevel on top edges, the side
/// (extrusion) and the outline around everything.
@immutable
class PixelText3DColors {
  const PixelText3DColors({
    required this.face,
    required this.bevel,
    required this.side,
    required this.band,
    this.outline = PixelPalette.ink,
  });

  /// Lower band of the banded look: one step darker than [face], softer
  /// than [side].
  final Color band;
  final Color face;
  final Color bevel;
  final Color side;
  final Color outline;

  static const gold = PixelText3DColors(
    face: PixelPalette.sun,
    band: PixelPalette.flame,
    bevel: PixelPalette.sunLight,
    side: PixelPalette.gold,
  );
  static const cream = PixelText3DColors(
    face: PixelPalette.cream,
    band: PixelPalette.sunLight,
    bevel: PixelPalette.white,
    side: PixelPalette.woodMid,
  );
  // Owner 2026-11-17: the bottom band was too dark; the whole ramp moved
  // one step lighter.
  static const green = PixelText3DColors(
    face: PixelPalette.greenSoft,
    band: PixelPalette.greenMid,
    bevel: PixelPalette.greenLight,
    side: PixelPalette.greenDeep,
  );
  static const red = PixelText3DColors(
    face: PixelPalette.redBright,
    band: PixelPalette.red,
    bevel: PixelPalette.redSoft,
    side: PixelPalette.redDeep,
  );
}

/// Plan 101 title/button looks (owner 2026-11-16: "more variation ... 2d bold
/// text with outline"). Our own takes on common pixel-game lettering; drawn
/// with our OFL fonts, never copied glyphs.
enum PixelTextLook {
  /// Stepped extrusion with a 1-pixel bevel on top (the first prototype).
  extruded,

  /// Flat 2D bold text with a dark outline.
  flat,

  /// Face in three hard colour bands (light, mid, dark) with an outline and
  /// a one-step drop below.
  banded,

  /// Thick outline and a hard diagonal shadow, two colour bands.
  chunky,

  /// No outline: bold face over a hard drop shadow.
  shadow,
}

/// Plan 101 prototype: bold pixel text for titles and buttons in one of the
/// [PixelTextLook]s. No blur and no smooth gradients: stacked copies of the
/// text offset by whole art pixels, and hard colour bands.
class PixelText3D extends StatelessWidget {
  const PixelText3D(
    this.text, {
    super.key,
    this.size = 20,
    this.colors = PixelText3DColors.gold,
    this.depth = 2,
    this.pressed = false,
    this.textAlign = TextAlign.center,
    this.look = PixelTextLook.banded,
    this.font = PixelText3D.defaultFont,
  });

  /// Owner 2026-11-16: "menu C, banded, pressstart2p for buttons and headers".
  static const defaultFont = 'PressStart2P';

  final String text;

  /// Font size in logical pixels before the user's font scale.
  final double size;
  final PixelText3DColors colors;

  /// Extrusion / shadow in art pixels.
  final int depth;

  /// Pressed text sinks into its extrusion (for 2.5D buttons).
  final bool pressed;
  final TextAlign textAlign;
  final PixelTextLook look;

  /// Font family (one of `PixelFonts.families`); null = the user's font.
  final String? font;

  @override
  Widget build(BuildContext context) {
    // Lettering is always capitals (lower-case pixel lettering reads badly).
    final text = this.text.toUpperCase();
    final u = PixelGrid.of(context).unit;
    // v0.3.1 dark mode (Pixel Lab 0.3): gold lettering turns cream on the
    // dark-brown page.
    final colors = identical(this.colors, PixelText3DColors.gold) &&
            PixelSurface.isDark(context) &&
            PixelSurface.darkMode(context)
        ? PixelText3DColors.cream
        : this.colors;
    var base = PixelType.display(context).copyWith(
      fontSize: size * PixelType.headerScale,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    if (font != null) base = base.copyWith(fontFamily: font);
    // Outlined looks need space between letters so outlines don't merge.
    // PressStart2P already has wide gaps; keep them tight (owner
    // 2026-11-17).
    final spacing = switch (look) {
      PixelTextLook.chunky => 1 * u,
      _ => 0.0,
    };
    base = base.copyWith(letterSpacing: spacing);
    final d = pressed ? 0 : depth;
    final lift = (depth - d) * u; // pressed: the face moves down

    // Drawing layers are RichText so only the one sizing Text below is "the
    // text" (screen readers and finders see the label once).
    final scaler = MediaQuery.textScalerOf(context);
    Widget text_(TextStyle style) => RichText(
          text: TextSpan(text: text, style: style),
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
          textScaler: scaler,
        );
    Widget at(double dx, double dy, Widget child) =>
        Transform.translate(offset: Offset(dx, dy + lift), child: child);
    TextStyle stroke(double w) => base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..strokeJoin = StrokeJoin.miter
            ..isAntiAlias = false
            ..color = colors.outline,
        );
    // Hard colour bands, top to bottom: the same text clipped to slices of
    // its height (clipping is cheap; no offscreen layer per label).
    Widget bands(List<Color> cs) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < cs.length; i++)
              ClipRect(
                clipper: _BandClip(i / cs.length, (i + 1) / cs.length),
                child: text_(base.copyWith(color: cs[i])),
              ),
          ],
        );

    final layers = switch (look) {
      PixelTextLook.extruded => [
          for (var i = d; i >= -1; i--) at(0, i * u, text_(stroke(2 * u))),
          for (var i = d; i >= 1; i--)
            at(0, i * u, text_(base.copyWith(color: colors.side))),
          at(0, -u, text_(base.copyWith(color: colors.bevel))),
          at(0, 0, text_(base.copyWith(color: colors.face))),
        ],
      PixelTextLook.flat => [
          at(0, 0, text_(stroke(2 * u))),
          at(0, 0, text_(base.copyWith(color: colors.face))),
        ],
      PixelTextLook.banded => [
          for (var i = d; i >= 0; i--) at(0, i * u, text_(stroke(2 * u))),
          for (var i = d; i >= 1; i--)
            at(0, i * u, text_(base.copyWith(color: colors.outline))),
          at(0, 0, bands([colors.bevel, colors.face, colors.band])),
        ],
      PixelTextLook.chunky => [
          for (var i = d; i >= 1; i--) at(i * u, i * u, text_(stroke(3 * u))),
          at(0, 0, text_(stroke(3 * u))),
          at(0, 0, bands([colors.face, colors.band])),
        ],
      PixelTextLook.shadow => [
          for (var i = d; i >= 1; i--)
            at(i * u, i * u, text_(base.copyWith(color: colors.outline))),
          at(0, 0, text_(base.copyWith(color: colors.face))),
        ],
    };

    final pad = look == PixelTextLook.chunky ? 2 * u : u;
    return Padding(
      // Room for the outline and the extrusion so nothing is clipped.
      padding: EdgeInsets.fromLTRB(
          pad,
          2 * u,
          pad + (look == PixelTextLook.chunky ? depth * u : 0),
          (depth + 2) * u),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sizing child (invisible), so the widget measures like plain text.
          Text(
            text,
            style: base.copyWith(color: PixelPalette.ink.withValues(alpha: 0)),
            textAlign: textAlign,
            maxLines: 1,
            softWrap: false,
          ),
          // Drawing copies are decoration; the sizing text above is read once.
          ...[for (final l in layers) ExcludeSemantics(child: l)],
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
    this.look = PixelTextLook.banded,
    this.font = PixelText3D.defaultFont,
  });

  final PixelTextLook look;
  final String? font;
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
                      child: PixelIconFit(widget.icon!,
                          box: widget.iconBox ?? widget.size * 2),
                    ),
                  ],
                  // Only the text shrinks to fit; the icon keeps whole pixels.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelText3D(
                      widget.label,
                      size: widget.size,
                      colors: widget.colors,
                      look: widget.look,
                      font: widget.font,
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
          for (var y = top; y <= bottom; y++)
            art.rows[y].substring(left, right + 1),
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

/// Clips to a horizontal slice [from]..[to] of the child's height (wide
/// enough sideways for italics and outlines).
class _BandClip extends CustomClipper<Rect> {
  const _BandClip(this.from, this.to);

  final double from;
  final double to;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        -size.width,
        from > 0 ? size.height * from : -size.height,
        size.width * 2,
        to < 1 ? size.height * to : size.height * 2,
      );

  @override
  bool shouldReclip(_BandClip old) => old.from != from || old.to != to;
}

/// v0.3 section title (owner 2026-11-16: "titles like 'Today's Mission'
/// should have the new text style, then remove the yellow background"): an
/// optional whole-pixel icon and banded lettering, no box behind it. Long
/// titles shrink to fit one line.
///
/// A live [value] (owner: "dynamic variables like the 4/7 should be
/// separated ... so the user can differentiate it from static texts") is
/// drawn as plain bold text in [valueColor] after the title, and pops each
/// time it changes.
class PixelSectionTitle extends StatelessWidget {
  const PixelSectionTitle(
    this.text, {
    super.key,
    this.icon,
    this.iconWrap,
    this.value,
    this.valueColor = PixelPalette.cream,
    this.colors = PixelText3DColors.gold,
    this.size = 12,
  });

  final String text;
  final PixelArt? icon;

  /// Wraps the icon, e.g. in an idle loop (`PixelWiggle`, `PixelTilt`).
  final Widget Function(Widget icon)? iconWrap;
  final String? value;
  final Color valueColor;
  final PixelText3DColors colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          iconWrap == null
              ? PixelIconFit(icon!, box: size + 8)
              : iconWrap!(PixelIconFit(icon!, box: size + 8)),
          SizedBox(width: grid.px(1)),
        ],
        Flexible(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PixelText3D(text,
                  size: size,
                  depth: 1,
                  colors: colors,
                  textAlign: TextAlign.left),
            ),
          ),
        ),
        if (value != null) ...[
          SizedBox(width: grid.px(2)),
          // Long values ("Today's mission") shrink rather than overflow.
          // Right end of the row; the title keeps at least 3/5 of it.
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: PixelValuePop(value!, color: valueColor),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A live number or count: plain bold text that pops (stepped, whole-pixel
/// feel) whenever [value] changes. Respects reduced motion.
class PixelValuePop extends StatelessWidget {
  const PixelValuePop(this.value, {super.key, this.color = PixelPalette.ink});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final text = Text(
      value,
      maxLines: 1,
      style: PixelType.title(context, color: color)
          .copyWith(fontWeight: FontWeight.w700),
    );
    if (still) return text;
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 1.35, end: 1),
      duration: const Duration(milliseconds: 320),
      builder: (context, t, child) => Transform.scale(
        // Four steps, not a smooth zoom.
        scale: (t * 8).round() / 8,
        child: child,
      ),
      child: text,
    );
  }
}
