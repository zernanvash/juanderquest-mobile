import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../models/spot_model.dart';
import 'collapsible_spot_photo.dart';

class ExploreFeaturedCard extends StatelessWidget {
  const ExploreFeaturedCard({
    super.key,
    required this.spot,
    required this.onTap,
  });

  final SpotModel spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final hasPhoto = spot.imageUrl != null && spot.imageUrl!.trim().isNotEmpty;
    if (!hasPhoto) return const SizedBox.shrink();

    final cardWidth = MediaQuery.sizeOf(context).width;
    final cacheWidth = (cardWidth * MediaQuery.devicePixelRatioOf(context)).round();

    return Semantics(
      button: true,
      label: 'Featured destination: ${spot.name}, in ${spot.municipality}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          pixelTick(context);
          onTap();
        },
        child: PixelPanel(
          style: PixelBoxStyle.darkWood.copyWith(corner: 2, shadowPx: 2),
          padding: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header tag
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: grid.px(1),
                runSpacing: grid.px(1),
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PixelChip(
                      'FEATURED DESTINATION',
                      style: PixelBoxStyle.gold,
                      textColor: PixelPalette.ink,
                    ),
                  ),
                  Text(
                    spot.municipality,
                    style: PixelType.small(context, color: PixelPalette.sunLight),
                  ),
                ],
              ),
              SizedBox(height: grid.px(2)),

              // Sunken photo frame (takes no space when the photo fails)
              CollapsibleSpotPhoto(
                url: spot.imageUrl,
                aspectRatio: 16 / 9,
                gapBelow: grid.px(2),
                cacheWidth: cacheWidth > 0 ? cacheWidth : null,
              ),

              // Name title
              ShadowText(
                spot.name,
                style: PixelType.title(context, color: PixelPalette.paper),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
