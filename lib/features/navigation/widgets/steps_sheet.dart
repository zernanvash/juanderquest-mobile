import 'package:flutter/material.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/route_model.dart';

class StepsSheet extends StatelessWidget {
  final List<RouteManeuver> maneuvers;
  final int? activeStepIndex;
  final ValueChanged<int>? onStepSelected;

  const StepsSheet({
    super.key,
    required this.maneuvers,
    this.activeStepIndex,
    this.onStepSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RouteManeuver> maneuvers,
    int? activeStepIndex,
    ValueChanged<int>? onStepSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StepsSheet(
        maneuvers: maneuvers,
        activeStepIndex: activeStepIndex,
        onStepSelected: onStepSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: PixelPalette.paper,
        border: Border(
          top: BorderSide(color: PixelPalette.woodDeep, width: 3),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(grid.px(3), grid.px(2), grid.px(3), grid.px(1)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TURN GUIDANCE (${maneuvers.length} STEPS)',
                    style: PixelType.title(context, color: PixelPalette.woodDeep),
                  ),
                  PixelButton(
                    key: const ValueKey('steps_sheet_close'),
                    label: 'X',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: PixelPalette.woodLight, height: 1),

            if (maneuvers.isEmpty)
              Padding(
                padding: EdgeInsets.all(grid.px(4)),
                child: Text(
                  'No maneuver guidance available for this route.',
                  style: PixelType.body(context, color: PixelPalette.woodMid),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(grid.px(2)),
                  itemCount: maneuvers.length,
                  separatorBuilder: (_, __) => SizedBox(height: grid.px(1)),
                  itemBuilder: (context, index) {
                    final m = maneuvers[index];
                    final isActive = activeStepIndex == index;

                    return InkWell(
                      onTap: () {
                        onStepSelected?.call(index);
                        Navigator.of(context).pop();
                      },
                      child: PixelPanel(
                        style: isActive ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PixelChip(
                              '${index + 1}',
                              style: isActive ? PixelBoxStyle.wood : PixelBoxStyle.parchment,
                            ),
                            SizedBox(width: grid.px(2)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.instruction.toUpperCase(),
                                    style: PixelType.body(
                                      context,
                                      color: isActive ? PixelPalette.woodDeep : PixelPalette.ink,
                                    ),
                                  ),
                                  if (m.streetName != null && m.streetName!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      m.streetName!,
                                      style: PixelType.small(
                                        context,
                                        color: isActive ? PixelPalette.woodDeep : PixelPalette.woodMid,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: grid.px(1)),
                            Text(
                              m.formattedDistance,
                              style: PixelType.small(
                                context,
                                color: isActive ? PixelPalette.woodDeep : PixelPalette.woodMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
