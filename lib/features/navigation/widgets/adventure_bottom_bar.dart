import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import '../models/route_model.dart';
import 'trail_tracker_bar.dart';

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
  final double? remainingDistanceMeters;
  final int? remainingDurationSeconds;
  final double? distanceToStopMeters;
  final bool isDegraded;
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
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.distanceToStopMeters,
    this.isDegraded = false,
    required this.onCheckIn,
    required this.onOpenSteps,
    required this.onEnd,
  });

  bool get isMovingTooFast => currentSpeedMs > 3.0;

  String _formatArriveTime(int secondsFromNow) {
    final eta = DateTime.now().add(Duration(seconds: secondsFromNow));
    final hour24 = eta.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final min = eta.minute.toString().padLeft(2, '0');
    final amPm = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:$min $amPm';
  }

  String _formatMeters(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} KM';
    }
    return '${meters.round()} M';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final isTrail = selectedTrail != null;

    final remMeters = remainingDistanceMeters ?? (summary.distanceKm * 1000.0);
    final remKm = remMeters / 1000.0;
    final remSec = remainingDurationSeconds ?? summary.durationSeconds;
    final remMins = (remSec / 60).ceil().clamp(0, 9999);
    final arriveText = 'ARRIVE ${_formatArriveTime(remSec)}';
    final subLine = isDegraded
        ? 'ESTIMATE · ${remKm.toStringAsFixed(0)} KM'
        : '$remMins MIN · ${remKm.toStringAsFixed(1)} KM';

    return Container(
      decoration: const BoxDecoration(
        color: PixelPalette.paper,
        border: Border(
          top: BorderSide(color: PixelPalette.ink, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: grid.px(2),
            vertical: grid.px(2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trail stop strip with TrailTrackerBar (when on a trail)
              if (isTrail && !isTrailCompleted && nextStop != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TrailTrackerBar(
                      key: const ValueKey('nav_trail_tracker'),
                      stops: selectedTrail!.stops,
                      nextStopPosition: nextStop!.position,
                    ),
                    SizedBox(width: grid.px(1)),
                    Text(
                      'STOP $currentStopNumber OF $totalStops',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.woodDeep,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: grid.px(1)),
                    Expanded(
                      child: Text(
                        nextStop!.name.toUpperCase(),
                        style: PixelType.body(
                          context,
                          color: PixelPalette.ink,
                        ).copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (distanceToStopMeters != null) ...[
                      SizedBox(width: grid.px(1)),
                      Text(
                        _formatMeters(distanceToStopMeters!),
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: grid.px(1)),
              ],

              // Check-in CTA button (64dp gold when near stop on a trail)
              if (isTrail &&
                  !isTrailCompleted &&
                  isWithinCheckinRadius &&
                  nextStop != null) ...[
                InkWell(
                  key: const ValueKey('nav_check_in_button'),
                  onTap:
                      (isMovingTooFast || isCheckingIn) ? null : onCheckIn,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMovingTooFast
                          ? PixelPalette.parchment
                          : PixelPalette.gold,
                      border: const Border.fromBorderSide(
                        BorderSide(color: PixelPalette.ink, width: 2),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: PixelPalette.ink,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isMovingTooFast
                              ? 'PARK FIRST TO CHECK IN'
                              : "YOU'RE HERE! CHECK IN",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: PixelType.title(
                            context,
                            color: PixelPalette.ink,
                          ),
                        ),
                        if (!isMovingTooFast)
                          Text(
                            isCheckingIn
                                ? 'CHECKING IN…'
                                : 'CHECK IN TO CONTINUE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.woodDeep,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: grid.px(1)),
              ],

              // Telemetry and END button Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          arriveText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PixelType.title(
                            context,
                            color: PixelPalette.ink,
                          ),
                        ),
                        Text(
                          subLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PixelType.body(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: grid.px(2)),
                  InkWell(
                    key: const ValueKey('nav_end_adventure'),
                    onTap: onEnd,
                    child: Container(
                      width: 88,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: PixelPalette.red,
                        border: Border.fromBorderSide(
                          BorderSide(color: PixelPalette.ink, width: 2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PixelPalette.ink,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'END',
                        style: PixelType.body(
                          context,
                          color: PixelPalette.cream,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
