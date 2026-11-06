import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_text.dart';

class DisplayName extends StatelessWidget {
  const DisplayName({
    super.key,
    required this.name,
    this.title,
    this.color,
    this.style,
  });

  final String name;
  final String? title;
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(
            name,
            style: (style ?? PixelType.title(context))
                .copyWith(color: color ?? style?.color),
          ),
          if (title != null && title!.isNotEmpty)
            PixelPanel(
              style: PixelBoxStyle.gold,
              padding: 1,
              child: Text(
                title!,
                style: PixelType.small(
                  context,
                  color: PixelPalette.woodDeep,
                ),
              ),
            ),
        ],
      );
}
