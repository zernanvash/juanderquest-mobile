import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';

class TheaterNearbySection extends StatelessWidget {
  const TheaterNearbySection({
    super.key,
    required this.alternatives,
    required this.isLoading,
  });

  final List<SpotModel> alternatives;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return TheaterPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'NEARBY HIDDEN GEMS',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Discover quieter alternatives and local favorites.',
            style: PixelType.body(context, color: PixelPalette.mist),
          ),
          SizedBox(height: grid.px(2)),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: PixelPalette.sun),
              ),
            )
          else if (alternatives.isEmpty)
            Text(
              'No other alternatives found in immediate vicinity.',
              style: PixelType.small(context, color: PixelPalette.stone),
            )
          else
            Column(
              children: [
                for (final alt in alternatives) ...[
                  _AlternativeRow(alt: alt),
                  if (alt != alternatives.last)
                    SizedBox(height: grid.px(2)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.alt});

  final SpotModel alt;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final hasPhoto = alt.imageUrl != null && alt.imageUrl!.isNotEmpty;
    final isQuiet = alt.crowdStatus == 'estimated_quiet' || alt.crowdStatus == 'quiet';

    return Semantics(
      button: true,
      label: 'View alternative destination: ${alt.name}',
      child: InkWell(
        onTap: () => context.push('/explore/${alt.slug}', extra: alt),
        child: PixelPanel(
          style: PixelBoxStyle.inkDialogue.copyWith(
            fill: PixelPalette.ink,
            outline: PixelPalette.slate,
            corner: 0,
            shadowPx: 0,
          ),
          padding: 1,
          child: Padding(
            padding: EdgeInsets.all(grid.px(2)),
            child: Row(
              children: [
                // Sunken thumbnail slot
                SizedBox(
                  width: 64,
                  height: 64,
                  child: PixelPanel(
                    style: PixelBoxStyle.slot.copyWith(
                      fill: PixelPalette.ink,
                      outline: PixelPalette.stone,
                      corner: 0,
                      shadowPx: 0,
                    ),
                    padding: 0,
                    child: hasPhoto
                        ? Image.network(
                            alt.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const DitherBackground(
                              top: PixelPalette.greenDeep,
                              bottom: PixelPalette.ink,
                            ),
                          )
                        : const DitherBackground(
                            top: PixelPalette.greenDeep,
                            bottom: PixelPalette.ink,
                          ),
                  ),
                ),

                SizedBox(width: grid.px(2)),

                // Info: Name, Town, Chip, Distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alt.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.small(context, color: PixelPalette.paper),
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        alt.municipality.isNotEmpty
                            ? alt.municipality.toUpperCase()
                            : 'PANGASINAN',
                        style: PixelType.small(context, color: PixelPalette.mist),
                      ),
                      SizedBox(height: grid.px(1)),
                      Row(
                        children: [
                          if (isQuiet)
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: PixelChip(
                                'QUIET',
                                style: PixelBoxStyle.green,
                                textColor: PixelPalette.white,
                              ),
                            )
                          else
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: PixelChip(
                                alt.category.replaceAll('_', ' ').toUpperCase(),
                                style: PixelBoxStyle.stone.copyWith(
                                  fill: PixelPalette.slate,
                                  outline: PixelPalette.mist,
                                  corner: 1,
                                  shadowPx: 0,
                                ),
                                textColor: PixelPalette.paper,
                              ),
                            ),
                          const Spacer(),
                          if (alt.distanceKm != null)
                            Text(
                              '${alt.distanceKm!.toStringAsFixed(0)} KM',
                              style: PixelType.small(
                                context,
                                color: PixelPalette.sun,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
