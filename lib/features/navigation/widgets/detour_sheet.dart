import 'package:flutter/material.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';

class DetourSheet extends StatelessWidget {
  final List<DetourArea> availableDetours;
  final List<DetourArea> selectedDetours;
  final ValueChanged<DetourArea> onToggleDetour;
  final VoidCallback onClear;

  const DetourSheet({
    super.key,
    required this.availableDetours,
    required this.selectedDetours,
    required this.onToggleDetour,
    required this.onClear,
  });

  static Future<void> show(
    BuildContext context, {
    required List<DetourArea> availableDetours,
    required List<DetourArea> selectedDetours,
    required ValueChanged<DetourArea> onToggleDetour,
    required VoidCallback onClear,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DetourSheet(
        availableDetours: availableDetours,
        selectedDetours: selectedDetours,
        onToggleDetour: onToggleDetour,
        onClear: onClear,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCENIC DETOURS',
                          style: PixelType.title(context, color: PixelPalette.woodDeep),
                        ),
                        Text(
                          'Add up to 3 towns along your route',
                          style: PixelType.small(context, color: PixelPalette.woodMid),
                        ),
                      ],
                    ),
                  ),
                  PixelButton(
                    key: const ValueKey('detour_sheet_close'),
                    label: 'X',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: PixelPalette.woodLight, height: 1),

            if (availableDetours.isEmpty)
              Padding(
                padding: EdgeInsets.all(grid.px(4)),
                child: Text(
                  'No scenic detours found along this direct path.',
                  style: PixelType.body(context, color: PixelPalette.woodMid),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(grid.px(2)),
                  itemCount: availableDetours.length,
                  separatorBuilder: (_, __) => SizedBox(height: grid.px(1)),
                  itemBuilder: (context, index) {
                    final area = availableDetours[index];
                    final isAdded = selectedDetours.any(
                      (d) => d.municipality == area.municipality,
                    );

                    final extraInfo = area.detourKm < 2
                        ? 'On the way · +${formatMinutes(area.extraMinutes)}'
                        : '+${area.detourKm.toStringAsFixed(1)} km · +${formatMinutes(area.extraMinutes)}';

                    final highlightNames =
                        area.highlights.map((h) => h.name).join(' · ');

                    return InkWell(
                      onTap: () => onToggleDetour(area),
                      child: PixelPanel(
                        style: isAdded ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    area.municipality.toUpperCase(),
                                    style: PixelType.body(context, color: PixelPalette.woodDeep),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    extraInfo,
                                    style: PixelType.small(context, color: PixelPalette.woodMid),
                                  ),
                                  if (highlightNames.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      highlightNames,
                                      style: PixelType.small(context, color: PixelPalette.slate),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: grid.px(1)),
                            PixelChip(
                              isAdded ? 'ADDED' : '+ ADD',
                              style: isAdded ? PixelBoxStyle.wood : PixelBoxStyle.parchment,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (selectedDetours.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(grid.px(2)),
                child: PixelButton(
                  key: const ValueKey('detour_clear_button'),
                  label: 'Clear All Detours',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () {
                    onClear();
                    Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
