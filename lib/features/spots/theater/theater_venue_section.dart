import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../map/engine/jdq_map.dart';
import '../../map/engine/jdq_map_canvas.dart';
import '../../map/engine/maplibre_jdq_map.dart';
import '../../map/pixel/map_marker_art.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';

class TheaterVenueSection extends ConsumerStatefulWidget {
  const TheaterVenueSection({
    super.key,
    required this.spot,
    required this.onDirections,
  });

  final SpotModel spot;
  final VoidCallback onDirections;

  @override
  ConsumerState<TheaterVenueSection> createState() =>
      _TheaterVenueSectionState();
}

class _TheaterVenueSectionState extends ConsumerState<TheaterVenueSection> {
  late final JdqMap _map;
  late final Future<String> _style;

  bool get _hasCoords => widget.spot.gpsLat != 0 || widget.spot.gpsLng != 0;

  @override
  void initState() {
    super.initState();
    _map = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);
    _syncCameraAndPin();
  }

  @override
  void didUpdateWidget(covariant TheaterVenueSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spot.id != widget.spot.id ||
        oldWidget.spot.gpsLat != widget.spot.gpsLat ||
        oldWidget.spot.gpsLng != widget.spot.gpsLng) {
      _syncCameraAndPin();
    }
  }

  void _syncCameraAndPin() {
    if (!_hasCoords) return;
    final spotCoord = LatLng(widget.spot.gpsLat, widget.spot.gpsLng);
    unawaited(_map.easeTo(spotCoord, 16.0, reducedMotion: true));
    unawaited(_map.setPins([
      JdqPin('spot:${widget.spot.id}', spotCoord, widget.spot.name),
    ]));
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final spot = widget.spot;

    return TheaterPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'VENUE & MAP',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),

          // Address
          Text(
            spot.address.isNotEmpty
                ? spot.address
                : (spot.municipality.isNotEmpty
                    ? spot.municipality
                    : 'Location in Pangasinan'),
            style: PixelType.body(context, color: PixelPalette.paper),
          ),
          if (spot.distanceKm != null) ...[
            SizedBox(height: grid.px(1)),
            Text(
              '${spot.distanceKm!.toStringAsFixed(1)} km away',
              style: PixelType.small(context, color: PixelPalette.sun),
            ),
          ],
          SizedBox(height: grid.px(2)),

          // Non-interactive pixel-framed JdqMapCanvas preview
          if (_hasCoords)
            PixelPanel(
              style: PixelBoxStyle.inkDialogue.copyWith(
                fill: PixelPalette.ink,
                outline: PixelPalette.paper,
                corner: 0,
                shadowPx: 0,
              ),
              padding: 0,
              child: SizedBox(
                height: 160,
                width: double.infinity,
                // Plan 75m: story panels scrolling past must not repaint the
                // map tiles.
                child: RepaintBoundary(
                  child: ClipRect(
                    child: IgnorePointer(
                      child: JdqMapCanvas(
                        map: _map,
                        style: _style,
                        fallback: const ColoredBox(
                          color: PixelPalette.ink,
                          child: Center(
                            child: PixelSprite(
                              MapMarkerArt.spotPin,
                              scale: 2,
                            ),
                          ),
                        ),
                        onFallback: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),

          SizedBox(height: grid.px(2)),

          // Actions: FULL MAP › and GET DIRECTIONS
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  key: const Key('theater_full_map_btn'),
                  label: 'FULL MAP ›',
                  variant: PixelButtonVariant.secondary,
                  expand: true,
                  onPressed: () => context.go('/map?spot=${spot.id}'),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: PixelButton(
                  key: const Key('theater_venue_directions_btn'),
                  label: 'GET DIRECTIONS',
                  variant: PixelButtonVariant.primary,
                  expand: true,
                  onPressed: widget.onDirections,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
