import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';

class AdventureArriveOverlay extends StatelessWidget {
  final TrailStop? checkedInStop;
  final TrailStop? nextStop;
  final int totalStops;
  final bool isTrailCompleted;
  final String? trailTitle;
  final int? trailRewardPoints;
  final bool hasArrivedDirect;
  final String destinationName;
  final VoidCallback onContinueCheckIn;
  final VoidCallback onDone;

  const AdventureArriveOverlay({
    super.key,
    this.checkedInStop,
    this.nextStop,
    this.totalStops = 0,
    this.isTrailCompleted = false,
    this.trailTitle,
    this.trailRewardPoints,
    this.hasArrivedDirect = false,
    required this.destinationName,
    required this.onContinueCheckIn,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final showCheckIn = checkedInStop != null && !isTrailCompleted;
    final showTrailDone = isTrailCompleted;
    final showDirectDone = !showTrailDone && hasArrivedDirect;

    if (!showCheckIn && !showTrailDone && !showDirectDone) {
      return const SizedBox.shrink();
    }

    final grid = PixelGrid.of(context);
    final media = MediaQuery.of(context);

    return ColoredBox(
      color: PixelPalette.ink.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 360,
                maxHeight: media.size.height * 0.8,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: PixelPalette.paper,
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
                padding: EdgeInsets.all(grid.px(3)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (showCheckIn) ...[
                              const PixelChip(
                                'CHECKED IN!',
                                style: PixelBoxStyle.gold,
                              ),
                              SizedBox(height: grid.px(2)),
                              Text(
                                'STOP ${checkedInStop!.position} OF $totalStops',
                                style: PixelType.small(
                                  context,
                                  color: PixelPalette.slate,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                checkedInStop!.name.toUpperCase(),
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.ink,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (nextStop != null) ...[
                                SizedBox(height: grid.px(2)),
                                PixelPanel(
                                  style: PixelBoxStyle.parchment,
                                  padding: 1,
                                  child: Text(
                                    'NEXT: ${nextStop!.name.toUpperCase()}',
                                    style: PixelType.small(
                                      context,
                                      color: PixelPalette.woodDeep,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ] else if (showTrailDone) ...[
                              const PixelChip(
                                'TRAIL COMPLETE!',
                                style: PixelBoxStyle.gold,
                              ),
                              SizedBox(height: grid.px(2)),
                              if (trailTitle != null && trailTitle!.isNotEmpty)
                                Text(
                                  trailTitle!.toUpperCase(),
                                  style: PixelType.title(
                                    context,
                                    color: PixelPalette.ink,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (trailRewardPoints != null &&
                                  trailRewardPoints! > 0) ...[
                                SizedBox(height: grid.px(2)),
                                PixelChip(
                                  '+$trailRewardPoints PTS',
                                  style: PixelBoxStyle.gold,
                                ),
                              ],
                            ] else ...[
                              const PixelChip(
                                "YOU'VE ARRIVED",
                                style: PixelBoxStyle.gold,
                              ),
                              SizedBox(height: grid.px(2)),
                              Text(
                                destinationName.toUpperCase(),
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.ink,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: grid.px(2)),
                    SizedBox(
                      height: 48,
                      child: PixelButton(
                        key: ValueKey(
                          showCheckIn
                              ? 'nav_checkin_continue'
                              : 'nav_arrive_done',
                        ),
                        label: showCheckIn ? 'CONTINUE' : 'DONE',
                        variant: PixelButtonVariant.primary,
                        onPressed: showCheckIn ? onContinueCheckIn : onDone,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
