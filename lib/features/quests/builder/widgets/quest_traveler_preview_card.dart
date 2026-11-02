import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../pixel/task_icons.dart';
import '../builder_models.dart';

class QuestTravelerPreviewCard extends StatelessWidget {
  final QuestBuilderState state;
  final String locationName;

  const QuestTravelerPreviewCard({
    super.key,
    required this.state,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              Text(
                'Traveler view preview',
                style: PixelType.small(
                  context,
                  color: PixelPalette.greenBright,
                ),
              ),
              PixelChip(
                '+${state.rewardPoints} mJDQ',
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            state.title.isEmpty ? 'Untitled quest' : state.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            locationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            state.description.isEmpty
                ? 'No description provided yet.'
                : state.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelChip(
                '${state.tasks.length} tasks',
                style: PixelBoxStyle.slot,
                textColor: PixelPalette.slate,
              ),
              PixelChip(
                state.stepOrderMode == 'sequential' ? 'In order' : 'Any order',
                style: PixelBoxStyle.slot,
                textColor: PixelPalette.slate,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          if (state.tasks.isEmpty)
            Text(
              'No tasks added yet.',
              style: PixelType.small(context, color: PixelPalette.stone),
            )
          else
            for (final task in state.tasks)
              Padding(
                padding: EdgeInsets.only(bottom: grid.px(1)),
                child: Row(
                  children: [
                    Text(
                      '${task.stepOrder}',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                    PixelSprite(
                      QuestTaskIcons.forCheckpoint(task.checkpointType),
                      scale: 2,
                    ),
                    SizedBox(width: grid.px(1)),
                    Expanded(
                      child: Text(
                        task.title.isEmpty
                            ? 'Task ${task.stepOrder}'
                            : task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.small(context),
                      ),
                    ),
                    if (task.required)
                      Text(
                        '*',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.red,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
