import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';

/// Plan 95: catalog list icon (3 square bullets + 3 bars), from the
/// approved prototype `implementation_plans/assets/95-merchant-affiliate-prototype.html`.
const merchantCatalogList = PixelArt('merchantCatalogList', [
  '.................................',
  '.................................',
  '.................................',
  '..kkkkkk...kkkkkkkkkkkkkkkkkkkk..',
  '.k66hhhek.k66666666666666666663k.',
  '.k6hhhhek.k64444444444444444443k.',
  '.khhhhhek.k64444444444444444443k.',
  '.kheeeeek.k44444444444444444433k.',
  '..kkkkkk...kkkkkkkkkkkkkkkkkkkk..',
  '.................................',
  '.................................',
  '.................................',
  '.................................',
  '..kkkkkk...kkkkkkkkkkkkkkkkkkkk..',
  '.k66hhhek.k66666666666666666663k.',
  '.k6hhhhek.k64444444444444444443k.',
  '.khhhhhek.k64444444444444444443k.',
  '.kheeeeek.k44444444444444444433k.',
  '..kkkkkk...kkkkkkkkkkkkkkkkkkkk..',
  '.................................',
  '.................................',
  '.................................',
  '.................................',
  '..kkkkkk...kkkkkkkkkkkkkkkkkkkk..',
  '.k66hhhek.k66666666666666666663k.',
  '.k6hhhhek.k64444444444444444443k.',
  '.khhhhhek.k64444444444444444443k.',
  '.kheeeeek.k44444444444444444433k.',
  '..kkkkkk...kkkkkkkkkkkkkkkkkkkk..',
  '.................................',
  '.................................',
  '.................................',
  '.................................',
]);

class MerchantTab {
  const MerchantTab({
    required this.key,
    required this.icon,
    required this.label,
    this.badge,
  });

  final Key key;
  final PixelArt icon;
  final String label;
  final String? badge;
}

/// Four icon tabs joined to the panel below like browser tabs: the selected
/// tab shares the panel fill and covers the panel's top border.
class MerchantTabbedPanel extends StatelessWidget {
  const MerchantTabbedPanel({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  final List<MerchantTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final border = grid.px(1);
    final tall = grid.px(20);
    final short = grid.px(17);
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: tall - border),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PixelPalette.parchment,
              border: Border.all(color: PixelPalette.woodDeep, width: border),
            ),
            child: Padding(padding: EdgeInsets.all(grid.px(3)), child: child),
          ),
        ),
        Positioned(
          top: 0,
          left: grid.px(2),
          right: grid.px(2),
          height: tall,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) SizedBox(width: grid.px(1)),
                Expanded(
                  child: _tab(
                    context,
                    grid,
                    tabs[i],
                    i == selected,
                    i == selected ? tall : short,
                    border,
                    i,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tab(
    BuildContext context,
    PixelGrid grid,
    MerchantTab tab,
    bool active,
    double height,
    double border,
    int index,
  ) {
    final side = BorderSide(color: PixelPalette.woodDeep, width: border);
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      child: Tooltip(
        message: tab.label,
        child: GestureDetector(
          key: tab.key,
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(index),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: active ? PixelPalette.parchment : PixelPalette.woodLight,
              border: Border(
                top: side,
                left: side,
                right: side,
                bottom: active ? BorderSide.none : side,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: grid.px(12),
                    child: FittedBox(child: PixelSprite(tab.icon, scale: 1)),
                  ),
                ),
                if (tab.badge != null)
                  Positioned(
                    top: grid.px(1),
                    right: grid.px(1),
                    child: ExcludeSemantics(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: grid.px(1)),
                        color: PixelPalette.red,
                        child: Text(
                          tab.badge!,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
