import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../utils/spot_posting.dart';
import 'studio_icons.dart';
import 'studio_text.dart';

/// Two-column grid of square category tiles. The selected tile is gold; no
/// colour emoji is ever rendered.
class StudioCategoryGrid extends StatelessWidget {
  const StudioCategoryGrid({
    super.key,
    required this.selectedCategory,
    required this.picked,
    required this.onSelected,
  });

  final String selectedCategory;
  final bool picked;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = grid.px(1);
        final tile = ((constraints.maxWidth - gap) / 2)
            .floorToDouble()
            .clamp(1.0, 400.0);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final category in spotPostingCategories)
              SizedBox(
                width: tile,
                child: _CategoryTile(
                  id: category['id'] as String,
                  label: studioPlainLabel(category['label'] as String),
                  selected: picked && selectedCategory == category['id'],
                  onTap: () => onSelected(category['id'] as String),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final icon = StudioIcons.forCategory(id);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final longest = icon.width > icon.height ? icon.width : icon.height;
    final scale = (22 * dpr / longest).floor().clamp(1, 8).toInt();
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('studio_category_$id'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: PixelPanel(
            style: selected ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
            padding: 2,
            // Compact (phone check 2026-11-05: square tiles were a third of
            // the screen tall); grows only when the text is large.
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: grid.px(28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Same on-screen size for every icon, whole device pixels per
                  // art pixel (no stretching).
                  PixelSprite(icon, scale: scale),
                  SizedBox(height: grid.px(1)),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: PixelType.small(context, color: PixelPalette.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
