import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text_3d.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../models/spot_model.dart';
import '../../theater/theater_backdrop.dart';
import '../../widgets/spot_like_heart.dart';
import '../explore_art.dart';
import '../recommendation_reason.dart';
import '../spot_filter_state.dart';
import 'explore_badges.dart';
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
    this.badges = const [],
  });

  /// Colour badges at the top right (owner 2026-11-16).
  final List<ExploreBadge> badges;

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
    final isHiddenGem = badges.any((b) => b.id == 'gem') ||
        spot.reasons.any((r) => r.toLowerCase().contains('hidden gem'));
    final townLabel =
        spot.municipality.isNotEmpty ? spot.municipality : 'Pangasinan';
    final questSummaryLine = isHiddenGem
        ? 'Quest · Hidden gem in $townLabel'
        : 'Quest in $townLabel';

    return Semantics(
      container: true,
      label: 'Destination ${spot.name} in ${spot.municipality}',
      // Owner 2026-11-17: each place sits in its own box (was a line under
      // each post).
      // The whole post opens the place (no VIEW SPOT button).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          pixelTick(context);
          onTapCard();
        },
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ShadowText(
                            spot.name,
                            style: PixelType.title(context,
                                color: PixelPalette.ink),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badges.isNotEmpty) ...[
                          SizedBox(width: grid.px(2)),
                          ExploreBadgeRow(badges: badges, spotName: spot.name),
                        ],
                      ],
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
                    if (hasQuest) ...[
                      SizedBox(height: grid.px(1)),
                      Row(
                        key: ValueKey('explore_quest_row_${spot.id}'),
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const PixelIconFit(
                            DesignerArt.plazaTrophy,
                            box: 16,
                          ),
                          SizedBox(width: grid.px(1)),
                          Expanded(
                            child: Text(
                              questSummaryLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Owner 2026-11-17: no caption/traveler note on the card;
                    // the place page shows it.
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

              // Action Row: LIKE (count, pixel heart) on the left, SAVE (bookmark)
              // on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Like: heart + count, no box (owner 2026-11-16).
                  Semantics(
                    button: true,
                    label: isLiked
                        ? 'Unlike, $likeCount likes'
                        : 'Like, $likeCount likes',
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        key: ValueKey('explore_like_${spot.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          pixelTick(context);
                          onToggleLike();
                        },
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(minHeight: 48, minWidth: 48),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SpotLikeHeartIcon(
                                liked: isLiked,
                                box: 24,
                              ),
                              SizedBox(width: grid.px(1)),
                              Text(
                                '$likeCount',
                                style: PixelType.numbers(
                                  context,
                                  color: isLiked
                                      ? PixelPalette.red
                                      : PixelPalette.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Save: bookmark, no box.
                  PixelIconButton(
                    key: ValueKey('explore_save_${spot.id}'),
                    icon: isSaved
                        ? ExploreArt.bookmarkSaved
                        : ExploreArt.bookmarkUnsaved,
                    semanticLabel:
                        isSaved ? 'Remove bookmark' : 'Save bookmark',
                    iconHeight: 24,
                    boxed: false,
                    onPressed: onToggleSave,
                  ),
                ],
              ),
            ],
          ),
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
