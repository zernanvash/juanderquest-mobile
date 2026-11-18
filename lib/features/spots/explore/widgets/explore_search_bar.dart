import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../../../core/pixel/pixel_text_3d.dart';

/// Owner 2026-11-16: an open text box under Explore's top bar.
/// Owner 2026-11-18 (v0.3.3): search lives inside Explore ("i dont like that
/// search feels like other page"): the box is a real field; Explore shows
/// recent searches and live matches under it.
class ExploreSearchBar extends StatelessWidget {
  const ExploreSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// True while searching (focused or has text): shows CLOSE.
  final bool active;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const ValueKey('explore_search_bar'),
      style: PixelBoxStyle.slot.copyWith(
        fill: PixelPalette.white,
        bevel: false,
        shadowPx: active ? 0 : 1,
      ),
      padding: 3,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            const PixelIconFit(DesignerArt.search, box: 20),
            SizedBox(width: grid.px(3)),
            Expanded(
              child: TextField(
                key: const ValueKey('explore_search_field'),
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                maxLines: 1,
                cursorColor: PixelPalette.ink,
                style: PixelType.body(context, color: PixelPalette.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'SEARCH',
                  hintStyle:
                      PixelType.label(context, color: PixelPalette.stone),
                ),
              ),
            ),
            if (active)
              Semantics(
                button: true,
                label: 'Close search',
                child: GestureDetector(
                  key: const ValueKey('explore_search_close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: Padding(
                    padding: EdgeInsets.only(left: grid.px(2)),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 32),
                      child: Center(
                        child: Text(
                          'CLOSE',
                          style: PixelType.labelSmall(context,
                              color: PixelPalette.slate),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
