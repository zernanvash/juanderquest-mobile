import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_text.dart';
import 'nav_pixel_art.dart';

const _pixelBackIcon = PixelArt('pixelBack', [
  '..0....',
  '.00....',
  '0000000',
  '.00....',
  '..0....',
]);

class RoutePreviewTopBar extends StatelessWidget {
  final String toLabel;
  final VoidCallback? onBack;
  final bool isTrail;

  const RoutePreviewTopBar({
    super.key,
    required this.toLabel,
    this.onBack,
    this.isTrail = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(
          children: [
            if (onBack != null) ...[
              PixelIconButton(
                key: const ValueKey('nav_back'),
                icon: _pixelBackIcon,
                semanticLabel: 'Back',
                style: PixelBoxStyle.parchment,
                iconHeight: 24,
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, maxHeight: 56),
                child: PixelPanel(
                  style: PixelBoxStyle.wood,
                  padding: 2,
                  child: Row(
                    children: [
                      NavPixelIcon(
                        isTrail ? NavPixelArt.flagGold : NavPixelArt.pinRed,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TO',
                        style: PixelType.body(
                          context,
                          color: PixelPalette.parchment,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          toLabel,
                          style: PixelType.body(
                            context,
                            color: PixelPalette.paper,
                          ).copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
