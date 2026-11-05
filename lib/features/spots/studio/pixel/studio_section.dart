import 'package:flutter/material.dart';

import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';

/// A numbered pixel panel in the Spot Discovery Studio flow.
class StudioSection extends StatelessWidget {
  const StudioSection({
    super.key,
    required this.title,
    required this.child,
    this.step,
    this.trailing,
  });

  final int? step;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step != null) ...[
                PixelChip('$step', style: PixelBoxStyle.gold),
                SizedBox(width: grid.px(1)),
              ],
              Expanded(
                child: Text(
                  title,
                  style: PixelType.body(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: grid.px(1)),
                Flexible(child: trailing!),
              ],
            ],
          ),
          SizedBox(height: grid.px(2)),
          child,
        ],
      ),
    );
  }
}
