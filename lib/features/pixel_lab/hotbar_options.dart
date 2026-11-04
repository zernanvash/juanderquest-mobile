import 'package:flutter/material.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/pixel/placeholder_art.dart';

/// Nav bar looks for the owner to choose from in Pixel lab (2026-11-04:
/// "improve the look of navigation bar so it dont look out of place … give me
/// options"). The chosen one replaces PixelHotbar; the others are removed.
enum HotbarOption {
  /// A: wooden shelf with parchment slots; the active slot is gold and lifted.
  woodShelf,

  /// B: Minecraft hotbar: dark see-through slots, a thick white frame on the
  /// active one, and its name floating above the bar.
  blockHotbar,

  /// C: paper tabs that blend with the page; the active tab is raised with a
  /// gold underline.
  paperTabs,
}

extension HotbarOptionLabel on HotbarOption {
  String get label => switch (this) {
        HotbarOption.woodShelf => 'A · Wood shelf',
        HotbarOption.blockHotbar => 'B · Block hotbar',
        HotbarOption.paperTabs => 'C · Paper tabs',
      };
}

class _Tab {
  final String label;
  final PixelArt icon;
  const _Tab(this.label, this.icon);
}

const _tabs = [
  _Tab('Home', PlaceholderArt.home),
  _Tab('Map', DesignerArt.navExplore),
  _Tab('Quests', DesignerArt.questMarker),
  _Tab('Choice', DesignerArt.juanChoice),
  _Tab('Profile', PlaceholderArt.profile),
];

/// One nav bar in the chosen [option]; tap a slot to select it.
class HotbarPreview extends StatefulWidget {
  final HotbarOption option;

  const HotbarPreview({super.key, required this.option});

  @override
  State<HotbarPreview> createState() => _HotbarPreviewState();
}

class _HotbarPreviewState extends State<HotbarPreview> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return switch (widget.option) {
      HotbarOption.woodShelf => _woodShelf(context, grid),
      HotbarOption.blockHotbar => _blockHotbar(context, grid),
      HotbarOption.paperTabs => _paperTabs(context, grid),
    };
  }

  Widget _slots(PixelGrid grid, Widget Function(int i, bool active) slot) =>
      Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                key: ValueKey('hotbar-option-${widget.option.name}-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(i),
                child: slot(i, i == _index),
              ),
            ),
        ],
      );

  Widget _woodShelf(BuildContext context, PixelGrid grid) {
    return Container(
      color: PixelPalette.woodDeep,
      padding:
          EdgeInsets.fromLTRB(grid.px(2), grid.px(3), grid.px(2), grid.px(3)),
      child: _slots(
        grid,
        (i, active) => Padding(
          padding: EdgeInsets.symmetric(horizontal: grid.px(1)),
          child: Transform.translate(
            offset: Offset(0, active ? -grid.px(2) : 0),
            child: PixelPanel(
              style: active ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
              padding: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelSprite(_tabs[i].icon, scale: 2),
                  Text(
                    _tabs[i].label,
                    maxLines: 1,
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

  Widget _blockHotbar(BuildContext context, PixelGrid grid) {
    final slot = PixelBoxStyle(
      fill: PixelPalette.ink.withValues(alpha: 0.6),
      highlight: PixelPalette.slate,
      shade: PixelPalette.ink,
      outline: PixelPalette.stone,
      corner: 0,
      shadowPx: 0,
      bevel: false,
    );
    final activeSlot = PixelBoxStyle(
      fill: PixelPalette.ink.withValues(alpha: 0.6),
      highlight: PixelPalette.white,
      shade: PixelPalette.white,
      outline: PixelPalette.white,
      corner: 0,
      shadowPx: 0,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The selected item's name floats above the bar, like Minecraft.
        Text(
          _tabs[_index].label,
          style: PixelType.body(context, color: PixelPalette.white).copyWith(
            shadows: const [
              Shadow(color: PixelPalette.ink, offset: Offset(1, 1)),
            ],
          ),
        ),
        SizedBox(height: grid.px(1)),
        Container(
          color: PixelPalette.ink.withValues(alpha: 0.55),
          padding: EdgeInsets.all(grid.px(1)),
          child: _slots(
            grid,
            (i, active) => Padding(
              padding: EdgeInsets.all(grid.px(0.5)),
              child: AspectRatio(
                aspectRatio: 1,
                child: PixelPanel(
                  style: active ? activeSlot : slot,
                  padding: 1,
                  child: Center(child: PixelSprite(_tabs[i].icon, scale: 2)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paperTabs(BuildContext context, PixelGrid grid) {
    return Container(
      decoration: BoxDecoration(
        color: PixelPalette.paper,
        border: Border(
          top: BorderSide(color: PixelPalette.ink, width: grid.px(1)),
        ),
      ),
      padding: EdgeInsets.only(bottom: grid.px(2)),
      child: _slots(
        grid,
        (i, active) => Container(
          padding: EdgeInsets.only(top: grid.px(2)),
          color: active ? PixelPalette.parchment : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelSprite(_tabs[i].icon, scale: 2),
              Text(
                _tabs[i].label,
                maxLines: 1,
                style: PixelType.small(
                  context,
                  color: active ? PixelPalette.ink : PixelPalette.stone,
                ),
              ),
              SizedBox(height: grid.px(1)),
              Container(
                height: grid.px(1.5),
                width: grid.px(14),
                color: active ? PixelPalette.sun : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
