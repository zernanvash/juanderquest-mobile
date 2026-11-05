import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../../juanchoice/models/juanchoice_models.dart';
import '../../models/spot_model.dart';
import '../../../juanchoice/utils/juanchoice_dates.dart';

class ExploreJuanChoiceCard extends StatelessWidget {
  const ExploreJuanChoiceCard({
    super.key,
    required this.spotlight,
    required this.winnerSpots,
    required this.onTapWinner,
    required this.onSeeResults,
  });

  final ChoiceSpotlight spotlight;
  final List<SpotModel> winnerSpots;
  final ValueChanged<SpotModel> onTapWinner;
  final VoidCallback onSeeResults;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return Semantics(
      label: 'JuanChoice community spotlight: ${spotlight.theme}',
      child: PixelPanel(
        style: PixelBoxStyle.gold.copyWith(
          fill: PixelPalette.paper,
          highlight: PixelPalette.sun,
          shade: PixelPalette.goldDeep,
          outline: PixelPalette.goldDeep,
          corner: 1,
          shadowPx: 2,
        ),
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Badge
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: PixelChip(
                    'JUANCHOICE SPOTLIGHT',
                    style: PixelBoxStyle.gold,
                    textColor: PixelPalette.ink,
                  ),
                ),
                Text(
                  'Community-selected',
                  style: PixelType.small(context, color: PixelPalette.goldDeep),
                ),
              ],
            ),
            SizedBox(height: grid.px(2)),

            // Theme
            ShadowText(
              spotlight.theme,
              style: PixelType.title(context, color: PixelPalette.wood),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: grid.px(1)),

            Text(
              'Promotional community spotlight chosen by verified traveler ballots.',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),

            // Winners list
            if (winnerSpots.isNotEmpty) ...[
              Wrap(
                spacing: grid.px(1),
                runSpacing: grid.px(1),
                children: [
                  for (final winner in winnerSpots)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        child: PixelButton(
                          label: '${winner.name.toUpperCase()} · ${winner.municipality.toUpperCase()}',
                          variant: PixelButtonVariant.secondary,
                          style: PixelBoxStyle.parchment.copyWith(
                            outline: PixelPalette.goldDeep,
                          ),
                          textColor: PixelPalette.greenDeep,
                          onPressed: () => onTapWinner(winner),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: grid.px(2)),
            ],

            // Footer
            // Date and link on separate lines so they never run together.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spotlight until ${choiceDate(spotlight.expiresAt, withYear: false)}',
                  key: const ValueKey('explore_choice_until'),
                  style: PixelType.small(context, color: PixelPalette.stone),
                ),
                Semantics(
                  button: true,
                  label: 'See final results',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      pixelTick(context);
                      onSeeResults();
                    },
                    child: Padding(
                      padding: EdgeInsets.all(grid.px(1)),
                      child: Text(
                        'SEE FINAL RESULTS ›',
                        style: PixelType.small(context, color: PixelPalette.green),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
