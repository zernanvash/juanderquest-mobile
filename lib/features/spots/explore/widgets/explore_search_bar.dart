import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../../../core/pixel/pixel_text_3d.dart';

/// Owner 2026-11-16: an open text box under Explore's top bar. It is not a
/// real field: a tap sinks it one art pixel, then opens Search.
class ExploreSearchBar extends StatefulWidget {
  const ExploreSearchBar({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends State<ExploreSearchBar> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      button: true,
      label: 'Search & Filters',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('explore_search_bar'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) {
            setState(() => _down = false);
            pixelTick(context);
            widget.onOpen();
          },
          child: Transform.translate(
            offset: Offset(0, _down ? grid.unit : 0),
            child: PixelPanel(
              style: PixelBoxStyle.slot.copyWith(
                fill: PixelPalette.white,
                bevel: false,
                shadowPx: _down ? 0 : 1,
              ),
              padding: 3,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(
                  children: [
                    const PixelIconFit(DesignerArt.search, box: 20),
                    SizedBox(width: grid.px(3)),
                    Expanded(
                      child: Text(
                        'SEARCH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.label(
                          context,
                          color: PixelPalette.stone,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
