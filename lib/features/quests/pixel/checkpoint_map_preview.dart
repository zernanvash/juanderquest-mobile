import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/widgets/base_tile_layer.dart';
import '../models/quest_model.dart';

class CheckpointMapPreview extends StatelessWidget {
  const CheckpointMapPreview({
    super.key,
    required this.quest,
    required this.onTap,
  });

  final QuestModel quest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.slot,
      sunken: true,
      padding: 1,
      child: ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 160,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(quest.gpsLat, quest.gpsLng),
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
                backgroundColor: PixelPalette.paperDim,
              ),
              children: [
                buildBaseTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(quest.gpsLat, quest.gpsLng),
                      width: grid.px(24),
                      height: grid.px(24),
                      child: const PixelSprite(
                        DesignerArt.questMarker,
                        scale: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
