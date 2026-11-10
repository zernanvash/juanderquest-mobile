import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import '../models/route_model.dart';

class AdventureBottomBar extends StatelessWidget {
  final RouteSummary summary;
  final TrailDetail? selectedTrail;
  final TrailStop? nextStop;
  final int totalStops;
  final int currentStopNumber;
  final bool isWithinCheckinRadius;
  final double currentSpeedMs;
  final bool isCheckingIn;
  final bool hasArrivedDirect;
  final bool isTrailCompleted;
  final int trailRewardPoints;
  final VoidCallback onCheckIn;
  final VoidCallback onOpenSteps;
  final VoidCallback onEnd;

  const AdventureBottomBar({
    super.key,
    required this.summary,
    this.selectedTrail,
    this.nextStop,
    this.totalStops = 0,
    this.currentStopNumber = 1,
    this.isWithinCheckinRadius = false,
    this.currentSpeedMs = 0.0,
    this.isCheckingIn = false,
    this.hasArrivedDirect = false,
    this.isTrailCompleted = false,
    this.trailRewardPoints = 0,
    required this.onCheckIn,
    required this.onOpenSteps,
    required this.onEnd,
  });

  bool get isMovingTooFast => currentSpeedMs > 3.0;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final isTrail = selectedTrail != null;

    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arrival / Completion Banner
          if (hasArrivedDirect) ...[
            PixelPanel(
              style: PixelBoxStyle.gold,
              padding: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "YOU'VE ARRIVED!",
                    style: PixelType.title(
                      context,
                      color: PixelPalette.woodDeep,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: grid.px(1)),
          ] else if (isTrail && isTrailCompleted) ...[
            PixelPanel(
              style: PixelBoxStyle.gold,
              padding: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'TRAIL COMPLETED! +$trailRewardPoints PTS',
                    style: PixelType.title(
                      context,
                      color: PixelPalette.woodDeep,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: grid.px(1)),
          ] else if (isTrail && nextStop != null) ...[
            // STOP K OF N
            Row(
              children: [
                PixelChip(
                  'STOP $currentStopNumber OF $totalStops',
                  style: PixelBoxStyle.wood,
                ),
                SizedBox(width: grid.px(1)),
                Expanded(
                  child: Text(
                    nextStop!.name.toUpperCase(),
                    style: PixelType.body(
                      context,
                      color: PixelPalette.woodDeep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
          ],

          // Check-in CTA button (when near stop on a trail)
          if (isTrail &&
              !isTrailCompleted &&
              isWithinCheckinRadius &&
              nextStop != null) ...[
            PixelButton(
              key: const ValueKey('nav_check_in_button'),
              label: isMovingTooFast
                  ? 'Park first to check in'
                  : "YOU'RE HERE! CHECK IN",
              variant: isMovingTooFast
                  ? PixelButtonVariant.secondary
                  : PixelButtonVariant.primary,
              onPressed: (isMovingTooFast || isCheckingIn) ? null : onCheckIn,
            ),
            SizedBox(height: grid.px(1)),
          ],

          // Telemetry and Action Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.durationFormatted.toUpperCase()} · ${summary.distanceKm.toStringAsFixed(1)} KM',
                      style: PixelType.title(
                        context,
                        color: PixelPalette.woodDeep,
                      ),
                    ),
                    Text(
                      'ACTIVE ADVENTURE',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.woodMid,
                      ),
                    ),
                  ],
                ),
              ),
              PixelButton(
                key: const ValueKey('nav_adventure_steps'),
                label: 'STEPS',
                variant: PixelButtonVariant.secondary,
                onPressed: onOpenSteps,
              ),
              SizedBox(width: grid.px(1)),
              PixelButton(
                key: const ValueKey('nav_end_adventure'),
                label: 'END',
                variant: PixelButtonVariant.secondary,
                onPressed: onEnd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
