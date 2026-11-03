import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';

class TheaterOverviewSection extends StatelessWidget {
  const TheaterOverviewSection({
    super.key,
    required this.spot,
    required this.isAuthor,
    required this.onPlayQuest,
  });

  final SpotModel spot;
  final bool isAuthor;
  final VoidCallback onPlayQuest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final isBusy = spot.crowdStatus == 'estimated_busy' || spot.crowdStatus == 'busy';
    final isQuiet = spot.crowdStatus == 'estimated_quiet' || spot.crowdStatus == 'quiet';

    return TheaterPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter Title
          Text(
            'OVERVIEW',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),

          // Crowd status chip and advisory
          if (isBusy) ...[
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PixelChip(
                'PEAK VISITING HOURS DETECTED',
                style: PixelBoxStyle.red,
                textColor: PixelPalette.white,
              ),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              'This spot may be busy based on recent traveler activity. Consider checking out quieter nearby alternatives below for bonus rewards!',
              style: PixelType.body(context, color: PixelPalette.paperDim),
            ),
            SizedBox(height: grid.px(2)),
          ] else if (isQuiet) ...[
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PixelChip(
                'LOW CROWD PRESSURE',
                style: PixelBoxStyle.green,
                textColor: PixelPalette.white,
              ),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              'Great tranquil time to visit & photograph!',
              style: PixelType.body(context, color: PixelPalette.paperDim),
            ),
            SizedBox(height: grid.px(2)),
          ] else ...[
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PixelChip(
                'MODERATE CROWD',
                style: PixelBoxStyle.stone,
                textColor: PixelPalette.paper,
              ),
            ),
            SizedBox(height: grid.px(2)),
          ],

          // Author / Creator / Source
          if (spot.sourceName.isNotEmpty || isAuthor) ...[
            Wrap(
              spacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (spot.sourceName.isNotEmpty)
                  Text(
                    'SHARED BY ${spot.sourceName.toUpperCase()}',
                    style: PixelType.small(context, color: PixelPalette.mist),
                  ),
                if (isAuthor)
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelChip(
                      'YOU POSTED THIS SPOT',
                      style: PixelBoxStyle.gold,
                      textColor: PixelPalette.ink,
                    ),
                  ),
              ],
            ),
            SizedBox(height: grid.px(2)),
          ],

          // Actions row: ADD PHOTO and CREATE A QUEST HERE
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  label: 'ADD PHOTO',
                  variant: PixelButtonVariant.secondary,
                  expand: true,
                  onPressed: () => context.push('/map/add-spot'),
                ),
              ),
              if (isAuthor) ...[
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: PixelButton(
                    key: const ValueKey('spot_create_quest_btn'),
                    label: 'CREATE A QUEST HERE',
                    variant: PixelButtonVariant.primary,
                    expand: true,
                    onPressed: () => context.push(
                      '/explore/${spot.slug.isNotEmpty ? spot.slug : spot.id}/quests/new',
                      extra: spot,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Quest bounty block when questId != null
          if (spot.questId != null) ...[
            SizedBox(height: grid.px(3)),
            PixelPanel(
              style: PixelBoxStyle.inkDialogue.copyWith(
                fill: PixelPalette.ink,
                outline: PixelPalette.sun,
                corner: 1,
                shadowPx: 0,
              ),
              padding: 2,
              child: Padding(
                padding: EdgeInsets.all(grid.px(2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: PixelChip(
                        'DESTINATION QUEST',
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                      ),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      'CHECK-IN & EARN +250 mJDQ',
                      style: PixelType.body(context, color: PixelPalette.sun),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      'Visit this destination in person to verify your quest and earn available rewards.',
                      style: PixelType.small(context, color: PixelPalette.paperDim),
                    ),
                    SizedBox(height: grid.px(2)),
                    SizedBox(
                      width: double.infinity,
                      child: PixelButton(
                        key: const Key('theater_overview_play_quest_btn'),
                        label: 'PLAY QUEST',
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                        expand: true,
                        onPressed: onPlayQuest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
