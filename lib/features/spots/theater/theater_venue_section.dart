import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/widgets/base_tile_layer.dart';
import '../../map/pixel/map_marker_art.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';

class TheaterVenueSection extends StatelessWidget {
  const TheaterVenueSection({
    super.key,
    required this.spot,
    required this.onDirections,
  });

  final SpotModel spot;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final hasCoords = spot.gpsLat != 0 || spot.gpsLng != 0;
    final spotCoord = LatLng(spot.gpsLat, spot.gpsLng);

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

          // Non-interactive pixel-framed FlutterMap preview
          if (hasCoords)
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
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: spotCoord,
                          initialZoom: 16.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          buildBaseTileLayer(),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: spotCoord,
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: PixelPalette.red,
                                    border: Border.fromBorderSide(
                                      BorderSide(
                                        color: PixelPalette.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const PixelSprite(
                                    MapMarkerArt.spotPin,
                                    scale: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                  onPressed: onDirections,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
