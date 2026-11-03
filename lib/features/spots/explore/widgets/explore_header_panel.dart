import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../explore_art.dart';
import '../spot_filter_state.dart';

class ExploreHeaderPanel extends StatelessWidget {
  const ExploreHeaderPanel({
    super.key,
    required this.filterState,
    required this.categories,
    required this.municipalities,
    required this.onToggleCategory,
    required this.onToggleMunicipality,
    required this.onReset,
  });

  final SpotFilterState filterState;
  final List<String> categories;
  final List<String> municipalities;
  final ValueChanged<String> onToggleCategory;
  final ValueChanged<String> onToggleMunicipality;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return PixelPanel(
      style: PixelBoxStyle.parchment.copyWith(corner: 1, shadowPx: 1),
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: grid.px(1),
              vertical: grid.px(1),
            ),
            child: Text(
              'EXPLORE PANGASINAN',
              style: PixelType.title(context, color: PixelPalette.wood),
            ),
          ),
          SizedBox(height: grid.px(1)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "ALL" Reset Chip
                _filterChip(
                  context: context,
                  label: 'ALL',
                  isSelected: filterState.isAllSelected,
                  activeStyle: PixelBoxStyle.green,
                  inactiveStyle: PixelBoxStyle.parchment,
                  activeTextColor: PixelPalette.white,
                  inactiveTextColor: PixelPalette.ink,
                  onTap: onReset,
                ),
                SizedBox(width: grid.px(1)),

                // Up to 5 Category Chips
                for (final cat in categories) ...[
                  _filterChip(
                    context: context,
                    label: categoryLabel(cat).toUpperCase(),
                    isSelected: filterState.selectedCategory == cat,
                    activeStyle: PixelBoxStyle.green,
                    inactiveStyle: PixelBoxStyle.parchment,
                    activeTextColor: PixelPalette.white,
                    inactiveTextColor: PixelPalette.ink,
                    onTap: () => onToggleCategory(cat),
                  ),
                  SizedBox(width: grid.px(1)),
                ],

                // Up to 5 Town Chips (Wood style with pixel pin sprite)
                for (final muni in municipalities) ...[
                  _filterChip(
                    context: context,
                    label: muni.toUpperCase(),
                    icon: ExploreArt.pin,
                    isSelected: filterState.selectedMunicipality == muni,
                    activeStyle: PixelBoxStyle.wood.copyWith(
                      fill: PixelPalette.woodDeep,
                      highlight: PixelPalette.woodMid,
                    ),
                    inactiveStyle: PixelBoxStyle.wood,
                    activeTextColor: PixelPalette.white,
                    inactiveTextColor: PixelPalette.paper,
                    onTap: () => onToggleMunicipality(muni),
                  ),
                  SizedBox(width: grid.px(1)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required PixelBoxStyle activeStyle,
    required PixelBoxStyle inactiveStyle,
    required Color activeTextColor,
    required Color inactiveTextColor,
    required VoidCallback onTap,
    PixelArt? icon,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        child: PixelChip(
          label,
          icon: icon,
          iconScale: 2,
          style: isSelected ? activeStyle : inactiveStyle,
          textColor: isSelected ? activeTextColor : inactiveTextColor,
          onTap: onTap,
        ),
      ),
    );
  }
}
