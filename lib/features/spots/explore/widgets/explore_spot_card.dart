import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../models/spot_model.dart';
import '../../theater/theater_backdrop.dart';
import '../explore_art.dart';
import '../recommendation_reason.dart';
import '../spot_filter_state.dart';
import 'collapsible_spot_photo.dart';

class ExploreSpotCard extends StatelessWidget {
  const ExploreSpotCard({
    super.key,
    required this.spot,
    required this.likeCount,
    required this.isLiked,
    required this.isSaved,
    required this.onTapCard,
    required this.onToggleLike,
    this.onDoubleTapLike,
    required this.onToggleSave,
    required this.onPlayQuest,
  });

  final SpotModel spot;
  final int likeCount;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onTapCard;
  final VoidCallback onToggleLike;

  /// Plan 93b WP-13: double-tapping the photo likes the spot.
  final VoidCallback? onDoubleTapLike;
  final VoidCallback onToggleSave;
  final VoidCallback? onPlayQuest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final cardWidth = MediaQuery.sizeOf(context).width;
    final cacheWidth =
        (cardWidth * MediaQuery.devicePixelRatioOf(context)).round();
    final recommendationReason = getTopRecommendationReason(spot);
    final hasQuest = spot.questId != null && spot.questId!.trim().isNotEmpty;

    return Semantics(
      container: true,
      label: 'Destination ${spot.name} in ${spot.municipality}',
      // v0.3 (owner 2026-11-16: "for explore revert the buttons, but remove
      // the outer box"): no card box; a pixel line under each post.
      child: Container(
        padding: EdgeInsets.only(bottom: grid.px(3)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: PixelPalette.woodLight, width: grid.unit),
          ),
        ),
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
                        style: PixelType.small(
                          context,
                          color: PixelPalette.stone,
                        ),
                      ),
                      if (recommendationReason != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: PixelChip(
                            recommendationReason.toUpperCase(),
                            style: _recommendationStyle(recommendationReason),
                            textColor: _recommendationTextColor(
                              recommendationReason,
                            ),
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

            // Photo (takes no space when there is none or it fails)
            TheaterDoubleTapHearts(
              onDoubleTapLike: onDoubleTapLike,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  pixelTick(context);
                  onTapCard();
                },
                // A double-tap handler makes a single tap wait briefly, so the
                // first tap of a double-tap does not open the spot.
                onDoubleTap: onDoubleTapLike == null ? null : () {},
                child: CollapsibleSpotPhoto(
                  url: spot.imageUrl,
                  aspectRatio: 16 / 10,
                  gapBelow: grid.px(2),
                  cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                ),
              ),
            ),

            // Action Row: LIKE (count, pixel heart), SAVE (bookmark), and
            // PLAY QUEST or VIEW SPOT.
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // LIKE Button with Count
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    widthFactor: 1,
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
                    widthFactor: 1,
                    child: PixelIconButton(
                      icon: isSaved
                          ? ExploreArt.bookmarkSaved
                          : ExploreArt.bookmarkUnsaved,
                      semanticLabel:
                          isSaved ? 'Remove bookmark' : 'Save bookmark',
                      // Saved: gold bookmark on wood (gold on gold was invisible).
                      style: isSaved
                          ? PixelBoxStyle.wood
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
                      widthFactor: 1,
                      child: PixelButton(
                        label: 'PLAY QUEST',
                        variant: PixelButtonVariant.primary,
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                        onPressed: onPlayQuest,
                      ),
                    ),
                  ),

                // Plan 93b WP-10: VIEW SPOT stays in the same 48 px row.
                if (!hasQuest)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      widthFactor: 1,
                      child: PixelButton(
                        key: ValueKey('explore_view_spot_${spot.id}'),
                        label: 'VIEW SPOT >',
                        variant: PixelButtonVariant.secondary,
                        onPressed: () {
                          pixelTick(context);
                          onTapCard();
                        },
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

  static PixelBoxStyle _recommendationStyle(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('quest') || lower.contains('saved in your wishlist')) {
      return PixelBoxStyle.gold;
    }
    if (lower.contains('quiet') || lower.startsWith('visited by @')) {
      return PixelBoxStyle.green;
    }
    return PixelBoxStyle.parchment;
  }

  static Color _recommendationTextColor(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('quest') || lower.contains('saved in your wishlist')) {
      return PixelPalette.ink;
    }
    if (lower.contains('quiet') || lower.startsWith('visited by @')) {
      return PixelPalette.white;
    }
    return PixelPalette.greenDeep;
  }
}
