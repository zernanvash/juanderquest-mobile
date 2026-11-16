import 'package:flutter/widgets.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import 'theater_panel.dart';

/// Plan 101 (owner): a "coming soon" section for what the destination page
/// will show later: places to stay, crowd forecast, destination data.
class TheaterComingSoonSection extends StatelessWidget {
  const TheaterComingSoonSection({super.key});

  static const _rows = [
    ('Places to stay', 'Inns, homestays and resorts near this destination.'),
    ('Crowd forecast', 'How busy it gets by hour and day, before you go.'),
    ('Destination data', 'Visitor counts, ratings and seasons over time.'),
  ];

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return TheaterPanel(
      key: const ValueKey('spot_coming_soon'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PixelSectionTitle(
            'COMING SOON',
            colors: PixelText3DColors.cream,
          ),
          for (final (i, (title, body)) in _rows.indexed) ...[
            if (i > 0)
              Container(
                height: grid.unit,
                color: PixelPalette.paper.withValues(alpha: 0.18),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: grid.px(2)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: PixelType.body(context,
                              color: PixelPalette.paper),
                        ),
                        SizedBox(height: grid.px(0.5)),
                        Text(
                          body,
                          style: PixelType.small(context,
                              color: PixelPalette.mist),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: grid.px(2)),
                  const PixelChip(
                    'SOON',
                    style: PixelBoxStyle.gold,
                    textColor: PixelPalette.ink,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
