import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../quests/widgets/sponsorship_conditions_widgets.dart';
import '../explore/spot_filter_state.dart';
import '../models/spot_model.dart';
import 'theater_still_photo.dart';

/// Strips a leading `PHOTO:` (any case) from a spot credit name.
String spotCreditName(String sourceName) {
  final trimmed = sourceName.trim();
  final match = RegExp(
    r'^photo\s*:\s*',
    caseSensitive: false,
  ).firstMatch(trimmed);
  return match == null ? trimmed : trimmed.substring(match.end).trim();
}

/// Same label as the Explore filter chips, so a spot reads the same everywhere.
String spotCategoryLabel(String? category) => categoryLabel(category);

class TheaterFirstViewport extends StatelessWidget {
  const TheaterFirstViewport({
    super.key,
    required this.spot,
    required this.scrollOffset,
    required this.onDirections,
    required this.onPlayQuest,
    this.onAddPhoto,
    this.onOpenSponsoredQuest,
    this.hasQuests = false,
    this.hasPhoto = true,
  });

  final SpotModel spot;
  final double scrollOffset;
  final VoidCallback onDirections;
  final VoidCallback onPlayQuest;
  final VoidCallback? onAddPhoto;
  final ValueChanged<String>? onOpenSponsoredQuest;
  final bool hasQuests;

  /// Plan 98 Option A: with no working photo there is nothing to look at, so
  /// the header shrinks to the badge and the title and Overview shows sooner.
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (!hasPhoto) {
      final grid = PixelGrid.of(context);
      return Padding(
        key: const Key('theater_first_viewport_compact'),
        // Clears the sticky top bar.
        padding: EdgeInsets.fromLTRB(
          grid.px(3),
          mediaQuery.padding.top + 88,
          grid.px(3),
          grid.px(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: SpotNoPhotoPlaceholder()),
            SizedBox(height: grid.px(4)),
            _HeroTitleBlock(
              spot: spot,
              scrollOffset: scrollOffset,
              onDirections: onDirections,
              onPlayQuest: onPlayQuest,
              onAddPhoto: onAddPhoto,
              onOpenSponsoredQuest: onOpenSponsoredQuest,
              hasQuests: hasQuests,
              // Owner 2026-11-20: no photo → ADD PHOTO right away, no scroll hint.
              hasCover: false,
            ),
          ],
        ),
      );
    }
    final viewportHeight = mediaQuery.size.height;
    final grid = PixelGrid.of(context);
    // On landscape or extreme font scaling, ensure enough height for hero block
    final effectiveHeight = viewportHeight < 520.0 ? 520.0 : viewportHeight;

    return SizedBox(
      height: effectiveHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // Scrims live in the stationary TheaterBackdropLayers (no edge
          // shows when the page is pulled past its top).

          // Plan 93b WP-11: Back, gallery, like, save, share and report live
          // in the sticky top bar on SpotDetailScreen.

          // Pinned Bottom Hero Title Block
          Positioned(
            bottom: grid.px(3),
            left: grid.px(3),
            right: grid.px(3),
            child: _HeroTitleBlock(
              spot: spot,
              scrollOffset: scrollOffset,
              onDirections: onDirections,
              onPlayQuest: onPlayQuest,
              onAddPhoto: onAddPhoto,
              onOpenSponsoredQuest: onOpenSponsoredQuest,
              hasQuests: hasQuests,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTitleBlock extends StatelessWidget {
  const _HeroTitleBlock({
    required this.spot,
    required this.scrollOffset,
    required this.onDirections,
    required this.onPlayQuest,
    this.onAddPhoto,
    this.onOpenSponsoredQuest,
    this.hasQuests = false,
    this.hasCover = true,
  });

  final SpotModel spot;
  final double scrollOffset;
  final VoidCallback onDirections;
  final VoidCallback onPlayQuest;
  final VoidCallback? onAddPhoto;
  final ValueChanged<String>? onOpenSponsoredQuest;
  final bool hasQuests;

  /// A cover photo fills the first screen: the secondary actions wait for a scroll and the
  /// SCROLL hint shows. Without one, the actions show at once and there is no hint.
  final bool hasCover;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final categoryText = spotCategoryLabel(spot.category);
    final townText =
        spot.municipality.isNotEmpty ? spot.municipality : 'Pangasinan';
    final sourceName = spotCreditName(spot.sourceName);

    final trustChip = spot.isTest
        ? const PixelChip(
            'Test spot',
            style: PixelBoxStyle.red,
            textColor: PixelPalette.white,
          )
        : spot.trustLevel == 'lgu_verified'
            ? const PixelChip(
                'LGU verified',
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
              )
            : PixelChip(
                sourceName.isNotEmpty ? sourceName : 'Community spot',
                style: PixelBoxStyle.stone,
                textColor: PixelPalette.paper,
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trust status chip
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: trustChip,
        ),
        SizedBox(height: grid.px(2)),

        // Spot Name (title 24, wraps)
        Text(
          spot.name,
          style: PixelType.title(
            context,
            color: PixelPalette.white,
          ).copyWith(fontSize: 24, height: 1.2),
        ),
        SizedBox(height: grid.px(1)),

        // Town · Category caption
        Text(
          '$townText · $categoryText',
          style: PixelType.small(context, color: PixelPalette.mist),
        ),

        if (spot.sponsors.isNotEmpty) ...[
          SizedBox(height: grid.px(1)),
          SponsoredByLine(
            key: const Key('spot_sponsored_by'),
            names: [for (final s in spot.sponsors) s.name],
            logoUrl: spot.sponsors
                .map((s) => s.logo?.trim() ?? '')
                .firstWhere((l) => l.isNotEmpty, orElse: () => ''),
            textColor: PixelPalette.sunLight,
            onTap: () {
              final questId = spot.sponsors.first.questId;
              if (questId.isEmpty) return;
              if (onOpenSponsoredQuest != null) {
                onOpenSponsoredQuest!(questId);
              } else {
                GoRouter.maybeOf(context)
                    ?.push('/quests/${Uri.encodeComponent(questId)}');
              }
            },
          ),
        ],

        // 1-line teaser (first sentence)
        if (spot.teaser.isNotEmpty) ...[
          SizedBox(height: grid.px(1)),
          Text(
            spot.teaser,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.body(context, color: PixelPalette.paperDim),
          ),
        ],

        SizedBox(height: grid.px(3)),

        // Action buttons row (GET DIRECTIONS)
        Row(
          children: [
            Expanded(
              child: PixelButton(
                key: const Key('theater_directions_btn'),
                label: 'GET DIRECTIONS',
                variant: PixelButtonVariant.primary,
                expand: true,
                onPressed: onDirections,
              ),
            ),
          ],
        ),

        // Scrolled-only secondary actions: ADD PHOTO + PLAY QUEST
        if ((scrollOffset > 0 || !hasCover) &&
            (onAddPhoto != null || hasQuests)) ...[
          SizedBox(height: grid.px(1.5)),
          Row(
            children: [
              if (onAddPhoto != null)
                Expanded(
                  child: PixelButton(
                    key: const ValueKey('spot_add_photo'),
                    label: 'ADD PHOTO',
                    variant: PixelButtonVariant.secondary,
                    expand: true,
                    onPressed: onAddPhoto,
                  ),
                ),
              if (onAddPhoto != null && hasQuests) SizedBox(width: grid.px(2)),
              if (hasQuests)
                Expanded(
                  child: PixelButton(
                    key: const ValueKey('spot_play_quest_btn'),
                    label: 'PLAY QUEST',
                    variant: PixelButtonVariant.primary,
                    expand: true,
                    onPressed: onPlayQuest,
                  ),
                ),
            ],
          ),
        ],

        // Stepped SCROLL ▼ hint (bobs 2 art px at 4 fps)
        if (hasCover && scrollOffset < 10) ...[
          SizedBox(height: grid.px(2)),
          Center(
            child: _SteppedScrollHint(
              disabled: MediaQuery.of(context).disableAnimations,
            ),
          ),
        ],
      ],
    );
  }
}

class _SteppedScrollHint extends StatefulWidget {
  const _SteppedScrollHint({required this.disabled});

  final bool disabled;

  @override
  State<_SteppedScrollHint> createState() => _SteppedScrollHintState();
}

class _SteppedScrollHintState extends State<_SteppedScrollHint> {
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.disabled) {
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) {
          setState(() => _step = (_step + 1) % 2);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final offsetY = (widget.disabled || _step == 0) ? 0.0 : grid.px(2);

    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Text(
        'SCROLL ▼',
        style: PixelType.small(context, color: PixelPalette.mist),
      ),
    );
  }
}
