import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/spot_model.dart';
import 'theater_gallery_dialog.dart';
import 'theater_panel.dart';

class TheaterFirstViewport extends StatelessWidget {
  const TheaterFirstViewport({
    super.key,
    required this.spot,
    required this.isSaved,
    required this.scrollOffset,
    required this.onToggleSave,
    required this.onShare,
    required this.onDirections,
    required this.onPlayQuest,
  });

  final SpotModel spot;
  final bool isSaved;
  final double scrollOffset;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;
  final VoidCallback onDirections;
  final VoidCallback onPlayQuest;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewportHeight = mediaQuery.size.height;
    final grid = PixelGrid.of(context);
    // On landscape or extreme font scaling, ensure enough height for hero block
    final effectiveHeight = viewportHeight < 520.0 ? 520.0 : viewportHeight;

    return SizedBox(
      height: effectiveHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // Top scrim
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TheaterTopScrim(height: 140),
          ),

          // Bottom scrim
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: TheaterBottomScrim(height: effectiveHeight * 0.65),
          ),

          // Top Controls (Back, Gallery, Credit, Save, Share)
          Positioned(
            top: mediaQuery.padding.top + grid.px(1),
            left: grid.px(2),
            right: grid.px(2),
            child: _TopControls(
              spot: spot,
              isSaved: isSaved,
              onToggleSave: onToggleSave,
              onShare: onShare,
            ),
          ),

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
            ),
          ),
        ],
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.spot,
    required this.isSaved,
    required this.onToggleSave,
    required this.onShare,
  });

  final SpotModel spot;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final photoCount = spot.media.length;

    return Row(
      children: [
        // Back button
        Semantics(
          button: true,
          label: 'Back',
          child: InkWell(
            key: const Key('theater_back_btn'),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              alignment: Alignment.center,
              child: PixelPanel(
                style: PixelBoxStyle.inkDialogue.copyWith(
                  fill: PixelPalette.ink,
                  outline: PixelPalette.paper,
                  corner: 0,
                  shadowPx: 0,
                ),
                padding: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: grid.px(2),
                    vertical: grid.px(1),
                  ),
                  child: Text(
                    '◀',
                    style: PixelType.small(context, color: PixelPalette.paper),
                  ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(width: grid.px(1)),

        // Gallery button
        if (photoCount > 0)
          Semantics(
            button: true,
            label: 'Open photo gallery',
            child: InkWell(
              key: const Key('theater_gallery_btn'),
              onTap: () => TheaterGalleryDialog.show(context, media: spot.media),
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, maxWidth: 96, minHeight: 48),
                alignment: Alignment.center,
                child: PixelPanel(
                  style: PixelBoxStyle.inkDialogue.copyWith(
                    fill: PixelPalette.slate,
                    outline: PixelPalette.paper,
                    corner: 0,
                    shadowPx: 0,
                  ),
                  padding: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: grid.px(2),
                      vertical: grid.px(1),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$photoCount PHOTOS',
                        style: PixelType.small(context, color: PixelPalette.paper),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Photo source credit chip
        if (spot.sourceName.isNotEmpty) ...[
          SizedBox(width: grid.px(1)),
          Expanded(
            child: GestureDetector(
              onTap: spot.sourceUrl != null && spot.sourceUrl!.isNotEmpty
                  ? () => launchUrlString(spot.sourceUrl!)
                  : null,
              child: PixelPanel(
                style: PixelBoxStyle.inkDialogue.copyWith(
                  fill: PixelPalette.ink,
                  outline: PixelPalette.slate,
                  corner: 0,
                  shadowPx: 0,
                ),
                padding: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: grid.px(2),
                    vertical: grid.px(1),
                  ),
                  child: Text(
                    spot.sourceName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.mist),
                  ),
                ),
              ),
            ),
          ),
        ] else
          const Spacer(),

        // Save heart button
        Semantics(
          button: true,
          label: isSaved ? 'Remove from saved spots' : 'Save spot',
          child: InkWell(
            key: const Key('theater_save_btn'),
            onTap: onToggleSave,
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              alignment: Alignment.center,
              child: PixelPanel(
                style: isSaved
                    ? PixelBoxStyle.red.copyWith(corner: 0, shadowPx: 0)
                    : PixelBoxStyle.inkDialogue.copyWith(
                        fill: PixelPalette.ink,
                        outline: PixelPalette.paper,
                        corner: 0,
                        shadowPx: 0,
                      ),
                padding: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: grid.px(2),
                    vertical: grid.px(1),
                  ),
                  child: Text(
                    isSaved ? '♥' : '♡',
                    style: PixelType.small(
                      context,
                      color: isSaved ? PixelPalette.white : PixelPalette.paper,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(width: grid.px(1)),

        // Share button
        Semantics(
          button: true,
          label: 'Share spot link',
          child: InkWell(
            key: const Key('theater_share_btn'),
            onTap: onShare,
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              alignment: Alignment.center,
              child: PixelPanel(
                style: PixelBoxStyle.inkDialogue.copyWith(
                  fill: PixelPalette.ink,
                  outline: PixelPalette.paper,
                  corner: 0,
                  shadowPx: 0,
                ),
                padding: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: grid.px(2),
                    vertical: grid.px(1),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Share',
                      style: PixelType.small(context, color: PixelPalette.paper),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroTitleBlock extends StatelessWidget {
  const _HeroTitleBlock({
    required this.spot,
    required this.scrollOffset,
    required this.onDirections,
    required this.onPlayQuest,
  });

  final SpotModel spot;
  final double scrollOffset;
  final VoidCallback onDirections;
  final VoidCallback onPlayQuest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final categoryText = spot.category.replaceAll('_', ' ');
    final townText = spot.municipality.isNotEmpty
        ? spot.municipality
        : 'Pangasinan';

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
                spot.sourceName.isNotEmpty
                    ? spot.sourceName
                    : 'Community spot',
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
          style: PixelType.title(context, color: PixelPalette.white).copyWith(
            fontSize: 24,
            height: 1.2,
          ),
        ),
        SizedBox(height: grid.px(1)),

        // Town · Category caption
        Text(
          '$townText · $categoryText',
          style: PixelType.small(context, color: PixelPalette.mist),
        ),

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

        // Action buttons row (GET DIRECTIONS, PLAY QUEST)
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
            if (spot.questId != null) ...[
              SizedBox(width: grid.px(2)),
              Expanded(
                child: PixelButton(
                  key: const Key('theater_play_quest_btn'),
                  label: 'PLAY QUEST',
                  style: PixelBoxStyle.gold,
                  textColor: PixelPalette.ink,
                  expand: true,
                  onPressed: onPlayQuest,
                ),
              ),
            ],
          ],
        ),

        // Stepped SCROLL ▼ hint (bobs 2 art px at 4 fps)
        if (scrollOffset < 10) ...[
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
