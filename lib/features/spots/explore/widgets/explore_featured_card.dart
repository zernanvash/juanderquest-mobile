import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../models/spot_model.dart';

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
          style: PixelBoxStyle.inkDialogue.copyWith(corner: 1, shadowPx: 2),
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
                    spot.municipality.toUpperCase(),
                    style: PixelType.small(context, color: PixelPalette.sunLight),
                  ),
                ],
              ),
              SizedBox(height: grid.px(2)),

              // Sunken photo frame
              PixelPanel(
                style: PixelBoxStyle.slot.copyWith(corner: 0, shadowPx: 0),
                padding: 1,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    spot.imageUrl!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                    errorBuilder: (_, __, ___) => Container(
                      color: PixelPalette.slate,
                      alignment: Alignment.center,
                      child: Text(
                        'PHOTO UNAVAILABLE',
                        style: PixelType.small(context, color: PixelPalette.mist),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: grid.px(2)),

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
