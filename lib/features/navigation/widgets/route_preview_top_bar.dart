import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_text.dart';
import 'nav_pixel_art.dart';

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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(
          children: [
            if (onBack != null) ...[
              GestureDetector(
                key: const ValueKey('nav_back'),
                onTap: onBack,
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: PixelPalette.paper,
                      border: Border.all(
                        color: const Color(0xFF0D1B2A),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x660D1B2A),
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _PixelBackArrowPainter(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: PixelPalette.paper,
                  border: Border.all(
                    color: const Color(0xFF0D1B2A),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x660D1B2A),
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
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
                        color: const Color(0xFF414844),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        toLabel,
                        style: PixelType.body(
                          context,
                          color: const Color(0xFF0D1B2A),
                        ).copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelBackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0D1B2A);
    final sx = size.width / 24;
    final sy = size.height / 24;
    // Left-pointing arrow centered inside 48x48 box (12dp inset -> 24x24 icon)
    final path = Path()
      ..moveTo(10 * sx, 6 * sy)
      ..lineTo(4 * sx, 12 * sy)
      ..lineTo(10 * sx, 18 * sy)
      ..lineTo(10 * sx, 13.5 * sy)
      ..lineTo(20 * sx, 13.5 * sy)
      ..lineTo(20 * sx, 10.5 * sy)
      ..lineTo(10 * sx, 10.5 * sy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
