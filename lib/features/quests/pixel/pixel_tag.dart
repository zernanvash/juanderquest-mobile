import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_text.dart';

class PixelTag extends StatelessWidget {
  const PixelTag(
    this.label, {
    super.key,
    this.style = PixelBoxStyle.slot,
    this.textColor = PixelPalette.slate,
    this.maxWidth,
  });

  final String label;
  final PixelBoxStyle style;
  final Color textColor;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: PixelPanel(
        style: style.copyWith(corner: 1, shadowPx: 0),
        padding: 1,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PixelType.small(context, color: textColor),
        ),
      ),
    );
  }
}
