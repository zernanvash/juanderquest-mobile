import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';

class PixelDashedButton extends StatelessWidget {
  const PixelDashedButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final unit = PixelGrid.of(context).unit;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: CustomPaint(
              painter: _DashedWoodPainter(unit: unit),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: unit * 3,
                  vertical: unit * 2,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: PixelType.small(
                      context,
                      color: PixelPalette.paper,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedWoodPainter extends CustomPainter {
  const _DashedWoodPainter({required this.unit});

  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..isAntiAlias = false
      ..color = PixelPalette.wood;
    canvas.drawRect(Offset.zero & size, fill);

    final dashPaint = Paint()
      ..isAntiAlias = false
      ..color = PixelPalette.sun;
    final thickness = unit;
    const dashUnits = 2;
    const gapUnits = 1;
    final dash = unit * dashUnits;
    final gap = unit * gapUnits;

    for (var x = unit; x < size.width - unit; x += dash + gap) {
      final width =
          (x + dash > size.width - unit) ? size.width - unit - x : dash;
      if (width <= 0) break;
      canvas.drawRect(Rect.fromLTWH(x, 0, width, thickness), dashPaint);
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - thickness, width, thickness),
        dashPaint,
      );
    }
    for (var y = unit; y < size.height - unit; y += dash + gap) {
      final height =
          (y + dash > size.height - unit) ? size.height - unit - y : dash;
      if (height <= 0) break;
      canvas.drawRect(Rect.fromLTWH(0, y, thickness, height), dashPaint);
      canvas.drawRect(
        Rect.fromLTWH(size.width - thickness, y, thickness, height),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedWoodPainter oldDelegate) =>
      oldDelegate.unit != unit;
}
