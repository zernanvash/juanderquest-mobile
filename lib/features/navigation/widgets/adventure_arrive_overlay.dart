import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import 'trail_tracker_bar.dart';

class AdventureArriveOverlay extends StatefulWidget {
  final TrailStop? checkedInStop;
  final TrailStop? nextStop;
  final List<TrailStop> stops;
  final int totalStops;
  final bool isTrailCompleted;
  final String? trailTitle;
  final int? trailRewardPoints;
  final bool hasArrivedDirect;
  final String destinationName;
  final int? tripMinutes;
  final double? tripKm;
  final VoidCallback onContinueCheckIn;
  final VoidCallback onDone;

  const AdventureArriveOverlay({
    super.key,
    this.checkedInStop,
    this.nextStop,
    this.stops = const [],
    this.totalStops = 0,
    this.isTrailCompleted = false,
    this.trailTitle,
    this.trailRewardPoints,
    this.hasArrivedDirect = false,
    required this.destinationName,
    this.tripMinutes,
    this.tripKm,
    required this.onContinueCheckIn,
    required this.onDone,
  });

  @override
  State<AdventureArriveOverlay> createState() => _AdventureArriveOverlayState();
}

class _AdventureArriveOverlayState extends State<AdventureArriveOverlay> {
  Timer? _countTimer;
  int _step = 8;
  int _lastTargetReward = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCountUp();
  }

  @override
  void didUpdateWidget(AdventureArriveOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTrailCompleted != widget.isTrailCompleted ||
        oldWidget.trailRewardPoints != widget.trailRewardPoints) {
      _syncCountUp();
    }
  }

  void _syncCountUp() {
    final target =
        widget.isTrailCompleted ? (widget.trailRewardPoints ?? 0) : 0;
    if (target <= 0) {
      _countTimer?.cancel();
      _countTimer = null;
      _step = 8;
      _lastTargetReward = 0;
      return;
    }

    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _countTimer?.cancel();
      _countTimer = null;
      _step = 8;
      _lastTargetReward = target;
      return;
    }

    if (target != _lastTargetReward) {
      _lastTargetReward = target;
      _countTimer?.cancel();
      _step = 0;
      _countTimer = Timer.periodic(const Duration(milliseconds: 60), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_step >= 8) {
          t.cancel();
          _countTimer = null;
          return;
        }
        setState(() => _step++);
      });
    }
  }

  @override
  void dispose() {
    _countTimer?.cancel();
    super.dispose();
  }

  Widget _buildJuan(bool reduce) {
    return SizedBox(
      width: 36,
      height: 52,
      child: FittedBox(
        fit: BoxFit.contain,
        child: reduce
            ? PixelSprite(DesignerArt.juanIdle.frames.first, scale: 2)
            : const PixelAnimation(DesignerArt.juanIdle, scale: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCheckIn =
        widget.checkedInStop != null && !widget.isTrailCompleted;
    final showTrailDone = widget.isTrailCompleted;
    final showDirectDone = !showTrailDone && widget.hasArrivedDirect;

    if (!showCheckIn && !showTrailDone && !showDirectDone) {
      return const SizedBox.shrink();
    }

    final grid = PixelGrid.of(context);
    final media = MediaQuery.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final String headerTitle;
    if (showCheckIn) {
      headerTitle = 'CHECKED IN!';
    } else if (showTrailDone) {
      headerTitle = 'TRAIL COMPLETE!';
    } else {
      headerTitle = "YOU'VE ARRIVED";
    }

    final targetReward = widget.trailRewardPoints ?? 0;
    final displayReward = _step >= 8
        ? targetReward
        : ((targetReward * _step) / 8).round();

    return ColoredBox(
      color: PixelPalette.ink.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 360,
                maxHeight: media.size.height * 0.85,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Wood title strip with paper text + Juan top-left
                    Container(
                      color: PixelPalette.wood,
                      padding: EdgeInsets.symmetric(
                        horizontal: grid.px(2),
                        vertical: grid.px(1.5),
                      ),
                      child: Row(
                        children: [
                          _buildJuan(reduce),
                          SizedBox(width: grid.px(1.5)),
                          Expanded(
                            child: Text(
                              headerTitle,
                              style: PixelType.title(
                                context,
                                color: PixelPalette.paper,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(grid.px(3)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (showCheckIn) ...[
                              if (widget.stops.isNotEmpty) ...[
                                TrailTrackerBar(
                                  key: const ValueKey(
                                      'nav_arrive_trail_tracker'),
                                  stops: widget.stops,
                                  nextStopPosition: widget.nextStop?.position,
                                ),
                                SizedBox(height: grid.px(1.5)),
                              ],
                              Text(
                                'STOP ${widget.checkedInStop!.position} OF ${widget.totalStops}',
                                style: PixelType.small(
                                  context,
                                  color: PixelPalette.slate,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.checkedInStop!.name.toUpperCase(),
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.ink,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.nextStop != null) ...[
                                SizedBox(height: grid.px(2)),
                                PixelPanel(
                                  style: PixelBoxStyle.parchment,
                                  padding: 1,
                                  child: Text(
                                    'NEXT: ${widget.nextStop!.name.toUpperCase()}',
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
                              if (widget.trailTitle != null &&
                                  widget.trailTitle!.isNotEmpty)
                                Text(
                                  widget.trailTitle!.toUpperCase(),
                                  style: PixelType.title(
                                    context,
                                    color: PixelPalette.ink,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (targetReward > 0) ...[
                                SizedBox(height: grid.px(2)),
                                PixelChip(
                                  '+$displayReward PTS',
                                  key: const ValueKey('nav_arrive_reward_chip'),
                                  style: PixelBoxStyle.gold,
                                ),
                              ],
                            ] else ...[
                              Text(
                                widget.destinationName.toUpperCase(),
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.ink,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.tripMinutes != null ||
                                  widget.tripKm != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${widget.tripMinutes ?? 0} MIN · ${(widget.tripKm ?? 0).toStringAsFixed(1)} KM',
                                  key: const ValueKey('nav_arrive_trip_stats'),
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.slate,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(3),
                        0,
                        grid.px(3),
                        grid.px(3),
                      ),
                      child: SizedBox(
                        height: 48,
                        child: PixelButton(
                          key: ValueKey(
                            showCheckIn
                                ? 'nav_checkin_continue'
                                : 'nav_arrive_done',
                          ),
                          label: showCheckIn ? 'CONTINUE' : 'DONE',
                          variant: PixelButtonVariant.primary,
                          onPressed: showCheckIn
                              ? widget.onContinueCheckIn
                              : widget.onDone,
                        ),
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
