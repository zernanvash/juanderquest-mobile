import 'package:flutter/material.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../navigation/widgets/route_map_thumbnail.dart';
import '../models/vlog_manifest.dart';

/// 2.5D Pixel HUD lower-third plate rendered live in the viewfinder, in the
/// instant preview player, and rasterized to PNG for native Media3 export.
class PixelVlogLowerThird extends StatelessWidget {
  final VlogFrameStyle frameStyle;
  final String badgeText;
  final String title;
  final String subtitle;

  const PixelVlogLowerThird({
    super.key,
    required this.frameStyle,
    required this.badgeText,
    required this.title,
    required this.subtitle,
  });

  ({
    Color bg,
    Color border,
    Color badgeBg,
    Color badgeFg,
    Color titleFg,
    Color subFg,
  }) _palette() {
    return switch (frameStyle) {
      VlogFrameStyle.defaultFrame => (
          bg: PixelPalette.paper.withValues(alpha: 0.94),
          border: PixelPalette.ink,
          badgeBg: PixelPalette.sun,
          badgeFg: PixelPalette.ink,
          titleFg: PixelPalette.ink,
          subFg: PixelPalette.slate,
        ),
      VlogFrameStyle.bamboo => (
          bg: PixelPalette.greenDeep.withValues(alpha: 0.94),
          border: PixelPalette.greenLight,
          badgeBg: PixelPalette.greenLight,
          badgeFg: PixelPalette.greenDeep,
          titleFg: PixelPalette.paper,
          subFg: PixelPalette.greenLight,
        ),
      VlogFrameStyle.hiyasGold => (
          bg: PixelPalette.woodDeep.withValues(alpha: 0.95),
          border: PixelPalette.sun,
          badgeBg: PixelPalette.sun,
          badgeFg: PixelPalette.ink,
          titleFg: PixelPalette.cream,
          subFg: PixelPalette.sunLight,
        ),
      VlogFrameStyle.woodSign => (
          bg: PixelPalette.wood.withValues(alpha: 0.95),
          border: PixelPalette.woodLight,
          badgeBg: PixelPalette.parchment,
          badgeFg: PixelPalette.woodDeep,
          titleFg: PixelPalette.paper,
          subFg: PixelPalette.cream,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _palette();
    Widget buildPlate() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: c.bg,
            border: Border.all(color: c.border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: PixelPalette.ink,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 76),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.badgeBg,
                      border: Border.all(color: PixelPalette.ink, width: 2),
                    ),
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      style: PixelType.small(context, color: c.badgeFg)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.body(context, color: c.titleFg)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(context, color: c.subFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
        if (w < 220) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: SizedBox(width: 240, child: buildPlate()),
          );
        }
        return buildPlate();
      },
    );
  }
}

/// 1.5-second Pixel Stop Card inserted whenever a traveler checked into a stop
/// without recording a video clip, keeping the full 1..N trail story intact.
class SkippedStopCard extends StatelessWidget {
  final int stopPosition;
  final int totalStops;
  final String spotName;
  final String municipality;
  final VlogFrameStyle frameStyle;
  final List<double> routeCoords;
  final List<double> stopCoords;

  const SkippedStopCard({
    super.key,
    required this.stopPosition,
    required this.totalStops,
    required this.spotName,
    required this.municipality,
    this.frameStyle = VlogFrameStyle.defaultFrame,
    this.routeCoords = const [],
    this.stopCoords = const [],
  });

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Container(
      color: PixelPalette.woodNight,
      padding: EdgeInsets.all(grid.px(3)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelPanel(
            style: frameStyle == VlogFrameStyle.hiyasGold
                ? PixelBoxStyle.gold
                : PixelBoxStyle.wood,
            padding: 1,
            child: Text(
              'CHECKED IN · STOP $stopPosition OF $totalStops',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(
                context,
                color: frameStyle == VlogFrameStyle.hiyasGold
                    ? PixelPalette.ink
                    : PixelPalette.cream,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: grid.px(2)),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: PixelPalette.parchment,
                border: Border.fromBorderSide(
                  BorderSide(color: PixelPalette.ink, width: 2),
                ),
              ),
              child: routeCoords.length >= 4
                  ? RouteMapThumbnail(
                      route: routeCoords,
                      stops: stopCoords,
                      border: false,
                    )
                  : Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PixelSprite(DesignerArt.badgeVerified,
                                scale: 3),
                            SizedBox(height: grid.px(1)),
                            Text(
                              'STOP $stopPosition',
                              style: PixelType.title(
                                context,
                                color: PixelPalette.woodDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(height: grid.px(2)),
          PixelVlogLowerThird(
            frameStyle: frameStyle,
            badgeText: '$stopPosition/$totalStops',
            title: spotName,
            subtitle: municipality.isEmpty ? 'Pangasinan' : municipality,
          ),
        ],
      ),
    );
  }
}

/// 2.0-second Outro Passport Stamp Card appended to every Trail Vlog.
class OutroStampCard extends StatelessWidget {
  final String trailTitle;
  final int totalStops;
  final double totalKm;
  final int rewardPoints;
  final VlogFrameStyle frameStyle;

  const OutroStampCard({
    super.key,
    required this.trailTitle,
    required this.totalStops,
    required this.totalKm,
    this.rewardPoints = 0,
    this.frameStyle = VlogFrameStyle.defaultFrame,
  });

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Container(
      color: PixelPalette.woodDeep,
      padding: EdgeInsets.all(grid.px(3)),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 260,
            child: PixelPanel(
              style: PixelBoxStyle.parchment,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PixelSprite(DesignerArt.juanIdle.frames.first, scale: 2),
                  SizedBox(height: grid.px(1)),
                  Text(
                    'TRAIL COMPLETE!',
                    textAlign: TextAlign.center,
                    style:
                        PixelType.title(context, color: PixelPalette.greenDeep),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trailTitle.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.body(context, color: PixelPalette.ink)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalStops STOPS · ${totalKm.toStringAsFixed(1)} KM',
                    textAlign: TextAlign.center,
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                  if (rewardPoints > 0) ...[
                    SizedBox(height: grid.px(1)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PixelPalette.sun,
                        border: Border.all(color: PixelPalette.ink, width: 2),
                      ),
                      child: Text(
                        '+$rewardPoints PTS',
                        style: PixelType.small(context, color: PixelPalette.ink)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  SizedBox(height: grid.px(2)),
                  Text(
                    'JUANDERQUEST.APP',
                    style:
                        PixelType.small(context, color: PixelPalette.woodMid),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
