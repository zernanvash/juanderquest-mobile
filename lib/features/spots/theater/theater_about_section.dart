import 'package:flutter/widgets.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/spot_model.dart';
import 'theater_panel.dart';

class TheaterAboutSection extends StatelessWidget {
  const TheaterAboutSection({
    super.key,
    required this.spot,
  });

  final SpotModel spot;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final descriptionText = spot.description.trim().isNotEmpty
        ? spot.description
        : (spot.municipality.isNotEmpty
            ? 'Explore this destination in ${spot.municipality} and discover what the local community has to offer.'
            : 'Explore this destination and discover what the local community has to offer.');

    return TheaterPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'ABOUT',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),

          // Full Description
          Text(
            descriptionText,
            style: PixelType.body(context, color: PixelPalette.paper).copyWith(
              height: 1.5,
            ),
          ),

          // GOOD FOR Sub-block
          if (spot.goodFor.isNotEmpty) ...[
            SizedBox(height: grid.px(3)),
            Text(
              'GOOD FOR',
              style: PixelType.small(context, color: PixelPalette.mist),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final item in spot.goodFor)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelChip(
                      item.toUpperCase(),
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white,
                    ),
                  ),
              ],
            ),
          ],

          // BEST TIME TO VISIT Sub-block
          if (spot.bestTime.isNotEmpty) ...[
            SizedBox(height: grid.px(3)),
            Text(
              'BEST TIME TO VISIT',
              style: PixelType.small(context, color: PixelPalette.mist),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final item in spot.bestTime)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelChip(
                      item.toUpperCase(),
                      style: PixelBoxStyle.gold,
                      textColor: PixelPalette.ink,
                    ),
                  ),
              ],
            ),
          ],

          // OPERATING HOURS Sub-block
          if (spot.hours.isNotEmpty) ...[
            SizedBox(height: grid.px(3)),
            Text(
              'OPERATING HOURS',
              style: PixelType.small(context, color: PixelPalette.mist),
            ),
            SizedBox(height: grid.px(1)),
            PixelPanel(
              style: PixelBoxStyle.inkDialogue.copyWith(
                fill: PixelPalette.ink,
                outline: PixelPalette.slate,
                corner: 0,
                shadowPx: 0,
              ),
              padding: 1,
              child: Padding(
                padding: EdgeInsets.all(grid.px(2)),
                child: Column(
                  children: [
                    for (final entry in spot.hours.entries) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: PixelType.small(
                              context,
                              color: PixelPalette.sun,
                            ),
                          ),
                          SizedBox(width: grid.px(2)),
                          Flexible(
                            child: Text(
                              entry.value,
                              textAlign: TextAlign.end,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.paper,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (entry.key != spot.hours.keys.last)
                        SizedBox(height: grid.px(1)),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // AMENITIES Sub-block
          if (spot.amenities.isNotEmpty) ...[
            SizedBox(height: grid.px(3)),
            Text(
              'AMENITIES',
              style: PixelType.small(context, color: PixelPalette.mist),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final item in spot.amenities)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelChip(
                      item.toUpperCase(),
                      style: PixelBoxStyle.parchment,
                      textColor: PixelPalette.ink,
                    ),
                  ),
              ],
            ),
          ],

          // Tags Wrap
          if (spot.tags.isNotEmpty) ...[
            SizedBox(height: grid.px(3)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final tag in spot.tags)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelChip(
                      '#${tag.replaceAll('_', ' ').toUpperCase()}',
                      style: PixelBoxStyle.stone.copyWith(
                        fill: PixelPalette.slate,
                        outline: PixelPalette.mist,
                        corner: 1,
                        shadowPx: 0,
                      ),
                      textColor: PixelPalette.paper,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
