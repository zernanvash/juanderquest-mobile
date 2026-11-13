import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/route_model.dart';
import 'maneuver_arrow_art.dart';
import 'nav_pixel_art.dart';

class AdventureTopBanner extends StatefulWidget {
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

  static int filledSegmentsForDistance(double? meters) {
    if (meters == null || meters >= 400) return 0;
    if (meters <= 0) return 8;
    return ((400 - meters) / 400 * 8).round().clamp(0, 8);
  }

  @override
  State<AdventureTopBanner> createState() => _AdventureTopBannerState();
}

class _AdventureTopBannerState extends State<AdventureTopBanner> {
  Timer? _rerouteTimer;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(AdventureTopBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRerouting != widget.isRerouting) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.isRerouting && !reduce) {
      _rerouteTimer ??= Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (!mounted) return;
        setState(() => _dots = (_dots % 3) + 1);
      });
    } else {
      _rerouteTimer?.cancel();
      _rerouteTimer = null;
    }
  }

  @override
  void dispose() {
    _rerouteTimer?.cancel();
    super.dispose();
  }

  String _formatDistance(double? meters) {
    if (meters == null || meters < 0) return '';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} KM';
    }
    return '${meters.round()} M';
  }

  String _shortThenInstruction(RouteManeuver next) {
    var raw = next.instruction.trim().toUpperCase();
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
    final reduce = MediaQuery.disableAnimationsOf(context);

    final maneuver = widget.currentManeuver;
    final instruction =
        (maneuver?.instruction ?? 'Proceed along route').toUpperCase();
    final arrow = ManeuverArrowArt.fromInstruction(instruction);
    final distanceText = _formatDistance(widget.distanceToManeuverM);
    final isCloseTurn =
        widget.distanceToManeuverM != null && widget.distanceToManeuverM! <= 100;
    final distanceColor = isCloseTurn ? PixelPalette.sun : PixelPalette.cream;
    final nextManeuver = widget.upcomingManeuvers.isNotEmpty
        ? widget.upcomingManeuvers.first
        : null;
    final filledSegments =
        AdventureTopBanner.filledSegmentsForDistance(widget.distanceToManeuverM);
    final rerouteSuffix = reduce ? '…' : '.' * _dots;

    return InkWell(
      key: const ValueKey('nav_adventure_top_banner'),
      onTap: widget.onOpenSteps,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isRerouting ? PixelPalette.wood : PixelPalette.greenDark,
          border: const Border.fromBorderSide(
            BorderSide(color: PixelPalette.ink, width: 2),
          ),
          boxShadow: const [
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
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: grid.px(2),
                vertical: isLandscape ? grid.px(1) : grid.px(2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isRerouting) ...[
                    Text(
                      'RECHARTING PATH$rerouteSuffix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.title(
                        context,
                        color: PixelPalette.sunLight,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: grid.px(1)),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isLandscape ? 40 : 64,
                        height: isLandscape ? 40 : 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2D4A3C),
                          border: Border(
                            top: BorderSide(
                                color: PixelPalette.greenDeep, width: 2),
                            left: BorderSide(
                                color: PixelPalette.greenDeep, width: 2),
                            right: BorderSide(
                                color: PixelPalette.greenMid, width: 2),
                            bottom: BorderSide(
                                color: PixelPalette.greenMid, width: 2),
                          ),
                        ),
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
                                        color: isCloseTurn
                                            ? PixelPalette.sun
                                            : PixelPalette.gold,
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
                                        color: distanceColor,
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
                                        color: PixelPalette.sunLight,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const NavPixelIcon(
                              NavPixelArt.arrowRightSmall,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 8-segment 4dp progress bar along bottom edge
            SizedBox(
              key: const ValueKey('nav_turn_progress'),
              height: 4,
              child: Row(
                children: [
                  for (var i = 0; i < 8; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      child: Container(
                        color: i < filledSegments
                            ? PixelPalette.sun
                            : PixelPalette.greenDeep,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
