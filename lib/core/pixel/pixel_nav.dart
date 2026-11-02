import 'package:flutter/material.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_controls.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

class PixelHotbarItem {
  const PixelHotbarItem({required this.label, this.icon});

  final String label;
  final PixelArt? icon;
}

class PixelHotbar extends StatelessWidget {
  const PixelHotbar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<PixelHotbarItem> items;
  final int index;
  final ValueChanged<int> onTap;

  static const _selectedStyle = PixelBoxStyle(
    fill: PixelPalette.paper,
    highlight: PixelPalette.white,
    shade: PixelPalette.paperDim,
    outline: PixelPalette.white,
    corner: 0,
    shadowPx: 1,
  );

  static const _idleStyle = PixelBoxStyle(
    fill: PixelPalette.slate,
    highlight: PixelPalette.stone,
    shade: PixelPalette.ink,
    outline: PixelPalette.ink,
    corner: 0,
    shadowPx: 0,
  );

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Container(
      color: PixelPalette.ink,
      padding: EdgeInsets.fromLTRB(
        grid.px(2),
        grid.px(2),
        grid.px(2),
        grid.px(2) + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                label: items[i].label,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i != index) pixelTick(context);
                      onTap(i);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: grid.px(1)),
                      child: Transform.translate(
                        offset: Offset(0, i == index ? -grid.unit : 0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: PixelPanel(
                            style: i == index ? _selectedStyle : _idleStyle,
                            sunken: i != index,
                            padding: 1,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (items[i].icon != null) ...[
                                  PixelSprite(items[i].icon!, scale: 3),
                                  SizedBox(height: grid.px(1)),
                                ],
                                Text(
                                  items[i].label.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PixelType.small(
                                    context,
                                    color: i == index
                                        ? PixelPalette.ink
                                        : PixelPalette.paper,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _backIcon = PixelArt('pixelBack', [
  '..0..',
  '.00..',
  '00000',
  '.00..',
  '..0..',
]);

class PixelAppBar extends StatelessWidget {
  const PixelAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Container(
      color: PixelPalette.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            grid.px(2),
            grid.px(2),
            grid.px(2),
            grid.px(2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                if (onBack != null) ...[
                  PixelIconButton(
                    icon: _backIcon,
                    semanticLabel: 'Back',
                    style: PixelBoxStyle.parchment,
                    onPressed: onBack,
                  ),
                  SizedBox(width: grid.px(2)),
                ],
                Expanded(
                  child: ShadowText(
                    title,
                    style: PixelType.title(context, color: PixelPalette.paper),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final action in actions) ...[
                  SizedBox(width: grid.px(1)),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route<T> pixelRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final stepped = (animation.value * 8).ceil() / 8;
            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: stepped < 1
                        ? PixelPalette.ink
                        : PixelPalette.ink.withValues(alpha: 0),
                  ),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: stepped,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
