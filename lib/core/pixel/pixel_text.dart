import 'package:flutter/widgets.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_grid.dart';

abstract final class PixelType {
  static TextStyle _base(
    BuildContext context,
    int artUnits, {
    Color color = PixelPalette.ink,
    bool bold = false,
    FontFeature? feature,
  }) {
    final grid = PixelGrid.of(context);
    final settings = PixelScope.of(context);
    return TextStyle(
      fontFamily: settings.font,
      fontSize: artUnits * grid.unit * settings.fontScale(),
      height: 1.4,
      color: color,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      letterSpacing: 0,
      fontFeatures: feature == null ? null : [feature],
    );
  }

  static TextStyle display(BuildContext context,
          {Color color = PixelPalette.ink}) =>
      _base(context, 16, color: color, bold: true);

  static TextStyle title(BuildContext context,
          {Color color = PixelPalette.ink}) =>
      _base(context, 12, color: color, bold: true);

  static TextStyle body(BuildContext context,
          {Color color = PixelPalette.ink}) =>
      _base(context, 8, color: color);

  static TextStyle small(BuildContext context,
          {Color color = PixelPalette.ink}) =>
      _base(context, 4, color: color);

  static TextStyle numbers(BuildContext context,
          {Color color = PixelPalette.ink}) =>
      _base(
        context,
        8,
        color: color,
        bold: true,
        feature: const FontFeature.tabularFigures(),
      );
}

class ShadowText extends StatelessWidget {
  const ShadowText(
    this.text, {
    super.key,
    required this.style,
    this.shadow,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final Color? shadow;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style.color ?? PixelPalette.ink;
    final explicit = shadow;
    final automatic = base.computeLuminance() > 0.4 ? PixelPalette.ink : null;
    final color = explicit ?? automatic;
    final resolved = color == null
        ? style
        : style.copyWith(
            shadows: [
              Shadow(
                color: color,
                offset: Offset(
                    PixelGrid.of(context).unit, PixelGrid.of(context).unit),
              ),
            ],
          );
    return Text(
      text,
      style: resolved,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
