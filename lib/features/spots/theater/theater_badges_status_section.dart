import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../explore/widgets/explore_badges.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';

/// Compact badges + one-line crowd status panel shown right before About.
class TheaterBadgesStatusSection extends StatelessWidget {
  const TheaterBadgesStatusSection({
    super.key,
    required this.spot,
  });

  final SpotModel spot;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final badges = exploreBadgesFor(spot);
    final isBusy =
        spot.crowdStatus == 'estimated_busy' || spot.crowdStatus == 'busy';
    final isQuiet =
        spot.crowdStatus == 'estimated_quiet' || spot.crowdStatus == 'quiet';

    final String chipLabel;
    final PixelBoxStyle chipStyle;
    final Color chipTextColor;
    final String? advisory;

    if (isBusy) {
      chipLabel = 'Peak visiting hours detected';
      chipStyle = PixelBoxStyle.red;
      chipTextColor = PixelPalette.white;
      advisory =
          'This spot may be busy based on recent traveler activity. Consider checking out quieter nearby alternatives below for bonus rewards!';
    } else if (isQuiet) {
      chipLabel = 'Low crowd pressure';
      chipStyle = PixelBoxStyle.green;
      chipTextColor = PixelPalette.white;
      advisory = 'Great tranquil time to visit & photograph!';
    } else {
      chipLabel = 'Moderate crowd';
      chipStyle = PixelBoxStyle.stone;
      chipTextColor = PixelPalette.paper;
      advisory = null;
    }

    return TheaterPanel(
      key: const ValueKey('theater_badges_status_panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badges.isNotEmpty) ...[
            ExploreBadgeRow(badges: badges, spotName: spot.name),
            SizedBox(height: grid.px(2)),
          ],
          Wrap(
            spacing: grid.px(1.5),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PixelChip(
                  chipLabel,
                  style: chipStyle,
                  textColor: chipTextColor,
                ),
              ),
              if (advisory != null)
                Text(
                  advisory,
                  style: PixelType.body(context, color: PixelPalette.paperDim),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
