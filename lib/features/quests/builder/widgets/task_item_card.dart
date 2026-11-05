import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_input.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../pixel/task_icons.dart';
import '../builder_models.dart';

class TaskItemCard extends StatelessWidget {
  final BuilderTask task;
  final int index;
  final int totalTasks;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<BuilderTask> onChanged;
  final Widget? settingsPanel;
  final GeoFence destinationDefaultFence;
  final String destinationSpotId;

  const TaskItemCard({
    super.key,
    required this.task,
    required this.index,
    required this.totalTasks,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onChanged,
    required this.destinationDefaultFence,
    required this.destinationSpotId,
    this.settingsPanel,
  });

  static const _types = <(String, String)>[
    ('location', 'Location'),
    ('qr', 'QR code'),
    ('photo', 'Photo'),
    ('ar', 'AR finder'),
    ('action', 'In-app action'),
  ];

  void _changeType(String value) {
    TaskVerification newVer;
    switch (value) {
      case 'qr':
        newVer = QrVerification(
          fence: destinationDefaultFence.copyWith(radiusMeters: 80),
          scanMode: 'traveler_scans',
        );
        break;
      case 'photo':
        newVer = const PhotoVerification(
          prompt: 'Take a clear photo of the landmark or site.',
          requireGps: true,
        );
        break;
      case 'ar':
        newVer = ArVerification(
          fence: destinationDefaultFence.copyWith(radiusMeters: 50),
        );
        break;
      case 'action':
        newVer = ActionVerification(
          task: {'kind': 'save_spot', 'spot_id': destinationSpotId},
        );
        break;
      case 'location':
      default:
        newVer = LocationVerification(
          fence: destinationDefaultFence.copyWith(radiusMeters: 100),
        );
        break;
    }
    onChanged(task.copyWith(checkpointType: value, verification: newVer));
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final typeIndex =
        _types.indexWhere((entry) => entry.$1 == task.checkpointType);
    return PixelPanel(
      style: isExpanded
          ? PixelBoxStyle.parchment.copyWith(outline: PixelPalette.green)
          : PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleExpand,
            child: Row(
              children: [
                PixelPanel(
                  style: PixelBoxStyle.slot,
                  padding: 1,
                  child: Text(
                    '${task.stepOrder}',
                    style: PixelType.small(
                      context,
                      color: PixelPalette.slate,
                    ),
                  ),
                ),
                SizedBox(width: grid.px(2)),
                PixelSprite(
                  QuestTaskIcons.forCheckpoint(task.checkpointType),
                  scale: 2,
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title.isEmpty ? 'Untitled task' : task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.body(context)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _types[typeIndex < 0 ? 0 : typeIndex].$2,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index > 0)
                  IconButton(
                    tooltip: 'Move up',
                    onPressed: onMoveUp,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                if (index < totalTasks - 1)
                  IconButton(
                    tooltip: 'Move down',
                    onPressed: onMoveDown,
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                Icon(isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
              ],
            ),
          ),
          if (isExpanded) ...[
            SizedBox(height: grid.px(2)),
            PixelTextField(
              initialValue: task.title,
              label: 'Task title',
              hint: 'e.g. Check in at the park entrance',
              onChanged: (value) => onChanged(task.copyWith(title: value)),
            ),
            SizedBox(height: grid.px(2)),
            PixelTextField(
              initialValue: task.description,
              label: 'Task instructions',
              hint: 'Tell the traveler what to do here.',
              maxLines: 2,
              onChanged: (value) =>
                  onChanged(task.copyWith(description: value)),
            ),
            SizedBox(height: grid.px(3)),
            Text(
              'Verification method',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            KeyedSubtree(
              key: Key('task_type_dropdown_$index'),
              child: Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(2),
                children: [
                  for (var i = 0; i < _types.length; i++)
                    PixelChip(
                      _types[i].$2,
                      key: ValueKey('task_${index}_type_${_types[i].$1}'),
                      style: (typeIndex == i || (typeIndex < 0 && i == 0))
                          ? PixelBoxStyle.gold
                          : PixelBoxStyle.slot.copyWith(
                              outline: PixelPalette.stone,
                            ),
                      textColor: (typeIndex == i || (typeIndex < 0 && i == 0))
                          ? PixelPalette.ink
                          : PixelPalette.slate,
                      onTap: () => _changeType(_types[i].$1),
                    ),
                ],
              ),
            ),
            SizedBox(height: grid.px(2)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Required task',
                    style: PixelType.body(context),
                  ),
                ),
                PixelSwitch(
                  value: task.required,
                  semanticLabel: 'Required task',
                  onChanged: (value) =>
                      onChanged(task.copyWith(required: value)),
                ),
              ],
            ),
            if (settingsPanel != null) ...[
              SizedBox(height: grid.px(2)),
              PixelPanel(
                style: PixelBoxStyle.slot,
                padding: 2,
                child: settingsPanel!,
              ),
            ],
            SizedBox(height: grid.px(2)),
            Align(
              alignment: Alignment.centerRight,
              child: PixelButton(
                key: ValueKey('task_delete_$index'),
                label: 'Delete task',
                variant: PixelButtonVariant.danger,
                onPressed: onDelete,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
