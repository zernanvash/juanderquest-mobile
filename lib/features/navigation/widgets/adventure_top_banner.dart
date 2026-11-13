import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/route_model.dart';
import 'maneuver_arrow_art.dart';

class AdventureTopBanner extends StatelessWidget {
  final RouteManeuver? currentManeuver;
  final double? distanceToManeuverM;
  final List<RouteManeuver> upcomingManeuvers;
  final bool isRerouting;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const AdventureTopBanner({
    super.key,
    required this.currentManeuver,
    this.distanceToManeuverM,
    this.upcomingManeuvers = const [],
    this.isRerouting = false,
    this.isExpanded = false,
    required this.onToggleExpand,
  });

  String _formatDistance(double? meters) {
    if (meters == null || meters < 0) return '';
    if (meters >= 1000) {
      return 'in ${(meters / 1000).toStringAsFixed(1)} km';
    }
    return 'in ${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final maneuver = currentManeuver;
    final instruction = maneuver?.instruction ?? 'Proceed along route';
    final arrow = ManeuverArrowArt.fromInstruction(instruction);
    final distanceText = _formatDistance(distanceToManeuverM);

    return InkWell(
      key: const ValueKey('nav_banner_expand'),
      onTap: onToggleExpand,
      child: PixelPanel(
        style: PixelBoxStyle.wood,
        padding: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isRerouting) ...[
              const Row(
                children: [
                  PixelChip(
                    'RECHARTING PATH…',
                    style: PixelBoxStyle.gold,
                  ),
                ],
              ),
              SizedBox(height: grid.px(1)),
            ],

            // Main maneuver row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  color: PixelPalette.woodDeep,
                  alignment: Alignment.center,
                  child: PixelSprite(arrow, scale: 3),
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (distanceText.isNotEmpty)
                        Text(
                          distanceText.toUpperCase(),
                          style: PixelType.title(
                            context,
                            color: PixelPalette.gold,
                          ),
                        ),
                      Text(
                        instruction.toUpperCase(),
                        style: PixelType.body(
                          context,
                          color: PixelPalette.paper,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (maneuver?.streetName != null &&
                          maneuver!.streetName!.isNotEmpty)
                        Text(
                          maneuver.streetName!,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.parchment,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                SizedBox(width: grid.px(1)),
                Text(
                  isExpanded ? '▲' : '▼',
                  style: PixelType.small(
                    context,
                    color: PixelPalette.gold,
                  ),
                ),
              ],
            ),

            // Dropdown: next upcoming steps (up to 3)
            if (isExpanded && upcomingManeuvers.isNotEmpty) ...[
              SizedBox(height: grid.px(1)),
              const Divider(color: PixelPalette.woodDeep, height: 1),
              SizedBox(height: grid.px(1)),
              for (var i = 0; i < upcomingManeuvers.length && i < 3; i++) ...[
                Builder(
                  builder: (context) {
                    final up = upcomingManeuvers[i];
                    final upArrow =
                        ManeuverArrowArt.fromInstruction(up.instruction);
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: grid.px(1) / 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: PixelSprite(upArrow, scale: 2),
                          ),
                          SizedBox(width: grid.px(1)),
                          Expanded(
                            child: Text(
                              up.instruction.toUpperCase(),
                              style: PixelType.small(
                                context,
                                color: PixelPalette.parchment,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: grid.px(1)),
                          Text(
                            up.formattedDistance,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.gold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
