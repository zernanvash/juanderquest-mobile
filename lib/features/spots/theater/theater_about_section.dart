import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/pixel_text_3d.dart';
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
          const PixelSectionTitle(
            'ABOUT',
            colors: PixelText3DColors.cream,
          ),
          SizedBox(height: grid.px(2)),

          // Full Description
          PixelText.rich(
            descriptionText,
            style: PixelType.body(context, color: PixelPalette.paper).copyWith(
              height: 1.4,
            ),
          ),

          // Plan 118: "Posted by @handle" author line (hidden when author is null).
          if (spot.author != null) ...[
            SizedBox(height: grid.px(2.5)),
            _SpotAuthorRow(author: spot.author!),
          ],

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
                      item,
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
                      item,
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
            // Plan 101: plain rows inside the section panel.
            Padding(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final entry in spot.hours.entries) ...[
                    PixelStatRow(
                      entry.key,
                      entry.value,
                      labelColor: PixelPalette.sun,
                      valueColor: PixelPalette.paper,
                      style: PixelType.small(context),
                    ),
                    if (entry.key != spot.hours.keys.last)
                      SizedBox(height: grid.px(1)),
                  ],
                ],
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
                      item.replaceAll('_', ' '),
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
                      '#${tag.replaceAll('_', ' ')}',
                      style: PixelBoxStyle.stone.copyWith(
                        fill: PixelPalette.slate,
                        outline: PixelPalette.mist,
                        corner: 2,
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

class _SpotAuthorRow extends StatelessWidget {
  const _SpotAuthorRow({required this.author});

  final SpotAuthor author;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final handleClean =
        (author.handle ?? '').trim().replaceFirst(RegExp(r'^@+'), '');
    final target = handleClean.isNotEmpty ? handleClean : author.id;
    final initial = author.displayName.trim().isNotEmpty
        ? author.displayName.trim().substring(0, 1).toUpperCase()
        : 'T';

    return InkWell(
      key: const Key('spot_author_line'),
      onTap: () {
        if (target.isEmpty) return;
        try {
          context.push('/profile/${Uri.encodeComponent(target)}');
        } catch (_) {}
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(0.5)),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: PixelPalette.parchment,
                border: Border.all(color: PixelPalette.ink, width: 2),
              ),
              alignment: Alignment.center,
              child: author.avatarUrl.trim().isNotEmpty
                  ? Image.network(
                      SpotModel.resolveImageUrl(author.avatarUrl),
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        initial,
                        style: PixelType.small(context, color: PixelPalette.ink)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    )
                  : Text(
                      initial,
                      style: PixelType.small(context, color: PixelPalette.ink)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
            SizedBox(width: grid.px(1.5)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      context,
                      en: 'Posted by ${author.formattedHandle}',
                      tl: 'Ni-post ni ${author.formattedHandle}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.sun)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (author.displayName.trim().isNotEmpty &&
                      author.displayName.trim() != author.formattedHandle)
                    Text(
                      author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          PixelType.small(context, color: PixelPalette.paperDim),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
