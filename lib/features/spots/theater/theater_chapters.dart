import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';

enum SpotTheaterChapter {
  overview('overview', 'OVERVIEW'),
  about('about', 'ABOUT'),
  notes('notes', 'NOTES'),
  venue('venue', 'VENUE & MAP'),
  nearby('nearby', 'NEARBY');

  const SpotTheaterChapter(this.id, this.label);
  final String id;
  final String label;

  static List<SpotTheaterChapter> getAvailable({required bool hasAlternatives}) {
    if (hasAlternatives) {
      return SpotTheaterChapter.values;
    }
    return const [
      SpotTheaterChapter.overview,
      SpotTheaterChapter.about,
      SpotTheaterChapter.notes,
      SpotTheaterChapter.venue,
    ];
  }
}

class TheaterChapterBar extends StatelessWidget {
  const TheaterChapterBar({
    super.key,
    required this.currentChapter,
    required this.hasAlternatives,
    required this.readingProgress,
    required this.onSelectChapter,
  });

  final SpotTheaterChapter currentChapter;
  final bool hasAlternatives;
  final double readingProgress;
  final ValueChanged<SpotTheaterChapter> onSelectChapter;

  @override
  Widget build(BuildContext context) {
    final chapters = SpotTheaterChapter.getAvailable(hasAlternatives: hasAlternatives);
    final grid = PixelGrid.of(context);
    final clampedProgress = readingProgress.clamp(0.0, 1.0);

    return Container(
      color: PixelPalette.ink,
      child: Column(
        children: [
          // Segmented row of chapter tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: grid.px(2),
                vertical: grid.px(1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final chapter in chapters) ...[
                    _ChapterTab(
                      chapter: chapter,
                      isActive: chapter == currentChapter,
                      onTap: () => onSelectChapter(chapter),
                    ),
                    if (chapter != chapters.last)
                      SizedBox(width: grid.px(1)),
                  ],
                ],
              ),
            ),
          ),

          // 2-art-px reading progress bar in sun
          SizedBox(
            height: grid.px(1),
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth * clampedProgress;
                return Stack(
                  children: [
                    Container(color: PixelPalette.slate),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: barWidth,
                      child: Container(color: PixelPalette.sun),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTab extends StatelessWidget {
  const _ChapterTab({
    required this.chapter,
    required this.isActive,
    required this.onTap,
  });

  final SpotTheaterChapter chapter;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return Semantics(
      button: true,
      selected: isActive,
      label: chapter.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: PixelPanel(
            style: isActive
                ? PixelBoxStyle.gold.copyWith(corner: 0, shadowPx: 0)
                : PixelBoxStyle.inkDialogue.copyWith(
                    fill: PixelPalette.ink,
                    outline: PixelPalette.slate,
                    corner: 0,
                    shadowPx: 0,
                  ),
            padding: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
              padding: EdgeInsets.symmetric(
                horizontal: grid.px(3),
                vertical: grid.px(1),
              ),
              alignment: Alignment.center,
              child: Text(
                chapter.label,
                style: PixelType.small(
                  context,
                  color: isActive ? PixelPalette.ink : PixelPalette.paper,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
