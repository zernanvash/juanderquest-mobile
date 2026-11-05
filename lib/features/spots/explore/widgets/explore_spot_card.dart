import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../models/spot_model.dart';
import '../explore_art.dart';
import '../recommendation_reason.dart';
import '../spot_filter_state.dart';

class ExploreSpotCard extends StatelessWidget {
  const ExploreSpotCard({
    super.key,
    required this.spot,
    required this.likeCount,
    required this.isLiked,
    required this.isSaved,
    required this.onTapCard,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onPlayQuest,
  });

  final SpotModel spot;
  final int likeCount;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onTapCard;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback? onPlayQuest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final hasPhoto = spot.imageUrl != null && spot.imageUrl!.trim().isNotEmpty;
    final cardWidth = MediaQuery.sizeOf(context).width;
    final cacheWidth =
        (cardWidth * MediaQuery.devicePixelRatioOf(context)).round();
    final recommendationReason = getTopRecommendationReason(spot);
    final hasQuest = spot.questId != null && spot.questId!.trim().isNotEmpty;

    return Semantics(
      container: true,
      label: 'Destination ${spot.name} in ${spot.municipality}',
      child: PixelPanel(
        style: PixelBoxStyle.parchment.copyWith(
          fill: PixelPalette.paper,
          outline: PixelPalette.ink,
          corner: 1,
          shadowPx: 1,
        ),
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Plan 75m: credit and "Report a problem" live on the spot page;
            // the card goes straight to the place.
            // Name (Tap opens theater)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                pixelTick(context);
                onTapCard();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShadowText(
                    spot.name,
                    style: PixelType.title(context, color: PixelPalette.wood),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: grid.px(1)),

                  // Town · Category caption + Optional Truthful Recommendation Chip
                  Wrap(
                    spacing: grid.px(1),
                    runSpacing: grid.px(1),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${spot.municipality.toUpperCase()} · ${categoryLabel(spot.category).toUpperCase()}',
                        style:
                            PixelType.small(context, color: PixelPalette.stone),
                      ),
                      if (recommendationReason != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: PixelChip(
                            recommendationReason.toUpperCase(),
                            style: _recommendationStyle(recommendationReason),
                            textColor:
                                _recommendationTextColor(recommendationReason),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: grid.px(1)),

                  // 2-line Description
                  PixelText.rich(
                    spot.description,
                    style: PixelType.body(context, color: PixelPalette.slate),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(height: grid.px(2)),

            // Photo or 64px placeholder strip
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                pixelTick(context);
                onTapCard();
              },
              child: hasPhoto
                  ? PixelPanel(
                      style:
                          PixelBoxStyle.slot.copyWith(corner: 0, shadowPx: 0),
                      padding: 1,
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.network(
                          spot.imageUrl!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                          errorBuilder: (_, __, ___) =>
                              _errorPhotoFallback(context),
                        ),
                      ),
                    )
                  : _categoryStripPlaceholder(context),
            ),
            SizedBox(height: grid.px(2)),

            // Action Row: LIKE (count, pixel heart), SAVE (bookmark), PLAY QUEST (if available)
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // LIKE Button with Count
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: PixelButton(
                      label: '$likeCount',
                      icon: isLiked
                          ? DesignerArt.heartLiked
                          : DesignerArt.heartUnliked,
                      iconScale: 2,
                      variant: isLiked
                          ? PixelButtonVariant.danger
                          : PixelButtonVariant.secondary,
                      style:
                          isLiked ? PixelBoxStyle.red : PixelBoxStyle.parchment,
                      textColor:
                          isLiked ? PixelPalette.white : PixelPalette.ink,
                      onPressed: onToggleLike,
                    ),
                  ),
                ),

                // SAVE Bookmark Button
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: PixelIconButton(
                      icon: isSaved
                          ? ExploreArt.bookmarkSaved
                          : ExploreArt.bookmarkUnsaved,
                      semanticLabel:
                          isSaved ? 'Remove bookmark' : 'Save bookmark',
                      style: isSaved
                          ? PixelBoxStyle.gold
                          : PixelBoxStyle.parchment,
                      iconHeight: 20,
                      onPressed: onToggleSave,
                    ),
                  ),
                ),

                // PLAY QUEST Button (when questId exists)
                if (hasQuest && onPlayQuest != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: PixelButton(
                        label: 'PLAY QUEST',
                        variant: PixelButtonVariant.primary,
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                        onPressed: onPlayQuest,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPhotoFallback(BuildContext context) {
    return Container(
      color: PixelPalette.slate,
      alignment: Alignment.center,
      child: Text(
        'Photo unavailable',
        style: PixelType.small(context, color: PixelPalette.mist),
      ),
    );
  }

  Widget _categoryStripPlaceholder(BuildContext context) {
    final grid = PixelGrid.of(context);
    final strip = ExploreArt.categoryStrip(spot.category);

    return PixelPanel(
      style: PixelBoxStyle.slot.copyWith(corner: 0, shadowPx: 0),
      padding: 1,
      child: Container(
        height: 64,
        color: PixelPalette.slate,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.6,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: PixelSprite(strip, scale: 4),
                  ),
                ),
              ),
              Positioned(
                right: grid.px(2),
                bottom: grid.px(2),
                child: PixelPanel(
                  style: PixelBoxStyle.inkDialogue
                      .copyWith(corner: 0, shadowPx: 0),
                  padding: 1,
                  child: Text(
                    '${categoryLabel(spot.category).toUpperCase()} · EXPLORE ›',
                    style: PixelType.small(context, color: PixelPalette.paper),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static PixelBoxStyle _recommendationStyle(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('quest')) {
      return PixelBoxStyle.gold;
    }
    if (lower.contains('quiet')) {
      return PixelBoxStyle.green;
    }
    return PixelBoxStyle.parchment;
  }

  static Color _recommendationTextColor(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('quest')) {
      return PixelPalette.ink;
    }
    if (lower.contains('quiet')) {
      return PixelPalette.white;
    }
    return PixelPalette.greenDeep;
  }
}
