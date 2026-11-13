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
  final VoidCallback? onOpenSteps;

  const AdventureTopBanner({
    super.key,
    required this.currentManeuver,
    this.distanceToManeuverM,
    this.upcomingManeuvers = const [],
    this.isRerouting = false,
    this.onOpenSteps,
  });

  String _formatDistance(double? meters) {
    if (meters == null || meters < 0) return '';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} KM';
    }
    return '${meters.round()} M';
  }

  String _shortThenInstruction(RouteManeuver next) {
    var raw = next.instruction.trim().toUpperCase();
    // Keep concise up to first comma/onto/period or ~24 chars
    final ontoIdx = raw.indexOf(' ONTO ');
    if (ontoIdx > 0) {
      raw = raw.substring(0, ontoIdx);
    }
    final periodIdx = raw.indexOf('.');
    if (periodIdx > 0) {
      raw = raw.substring(0, periodIdx);
    }
    if (raw.length > 26) {
      raw = '${raw.substring(0, 25)}…';
    }
    return 'THEN $raw';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final media = MediaQuery.of(context);
    final isLandscape =
        media.orientation == Orientation.landscape || media.size.height < 450;

    final maneuver = currentManeuver;
    final instruction =
        (maneuver?.instruction ?? 'Proceed along route').toUpperCase();
    final arrow = ManeuverArrowArt.fromInstruction(instruction);
    final distanceText = _formatDistance(distanceToManeuverM);
    final nextManeuver =
        upcomingManeuvers.isNotEmpty ? upcomingManeuvers.first : null;

    return InkWell(
      key: const ValueKey('nav_adventure_top_banner'),
      onTap: onOpenSteps,
      child: Container(
        decoration: const BoxDecoration(
          color: PixelPalette.greenDark,
          border: Border.fromBorderSide(
            BorderSide(color: PixelPalette.ink, width: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: PixelPalette.ink,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: grid.px(2),
          vertical: isLandscape ? grid.px(1) : grid.px(2),
        ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isLandscape ? 40 : 64,
                  height: isLandscape ? 40 : 64,
                  color: const Color(0xFF2D4A3C),
                  alignment: Alignment.center,
                  child: PixelSprite(
                    arrow,
                    scale: isLandscape ? 2 : 4,
                  ),
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: isLandscape
                      ? Row(
                          children: [
                            if (distanceText.isNotEmpty) ...[
                              Text(
                                distanceText,
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.gold,
                                ),
                              ),
                              SizedBox(width: grid.px(2)),
                            ],
                            Expanded(
                              child: Text(
                                instruction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.cream,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (distanceText.isNotEmpty)
                              Text(
                                distanceText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.cream,
                                ),
                              ),
                            Text(
                              instruction,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.cream,
                              ).copyWith(fontWeight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (maneuver?.streetName != null &&
                                maneuver!.streetName!.isNotEmpty)
                              Text(
                                maneuver.streetName!,
                                style: PixelType.small(
                                  context,
                                  color: const Color(0xFFFFDEA9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                ),
              ],
            ),
            if (!isLandscape && nextManeuver != null) ...[
              SizedBox(height: grid.px(1)),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  color: PixelPalette.ink,
                  child: Text(
                    _shortThenInstruction(nextManeuver),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(
                      context,
                      color: PixelPalette.cream,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
