import 'package:flutter/material.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_controls.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

class PixelHotbarItem {
  const PixelHotbarItem({
    required this.label,
    this.icon,
    this.pressedIcon,
    this.badge,
  });

  final String label;
  final PixelArt? icon;
  final PixelArt? pressedIcon;
  final String? badge;
}

class PixelHotbar extends StatefulWidget {
  const PixelHotbar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<PixelHotbarItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<PixelHotbar> createState() => _PixelHotbarState();
}

class _PixelHotbarState extends State<PixelHotbar> {
  int? _pressed;

  static const _selectedStyle = PixelBoxStyle(
    fill: PixelPalette.mist,
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
          for (var i = 0; i < widget.items.length; i++)
            Expanded(child: _slot(context, grid, i)),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, PixelGrid grid, int i) {
    final item = widget.items[i];
    final selected = i == widget.index;
    final pressed = _pressed == i;
    final icon =
        pressed && item.pressedIcon != null ? item.pressedIcon! : item.icon;
    final numeric = item.badge == null ? null : int.tryParse(item.badge!);
    final badgeText = numeric != null && numeric > 9 ? '9+' : item.badge;
    final badgeSemantics = item.badge == null
        ? ''
        : item.badge == '!'
            ? 'new'
            : numeric != null
                ? '$numeric new'
                : item.badge!;
    final semanticsLabel =
        item.badge == null ? item.label : '${item.label}, $badgeSemantics';
    final iconScale = icon == null
        ? 1
        : (32 * MediaQuery.devicePixelRatioOf(context) / icon.height)
            .round()
            .clamp(1, 16)
            .toInt();
    final offset =
        selected ? -grid.unit : (pressed ? grid.unit : 0.0);
    return Semantics(
      selected: selected,
      button: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = i),
          onTapCancel: () => setState(() => _pressed = null),
          onTapUp: (_) {
            setState(() => _pressed = null);
            if (!selected) pixelTick(context);
            widget.onTap(i);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: grid.px(1)),
            child: Transform.translate(
              offset: Offset(0, offset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: PixelPanel(
                  style: selected ? _selectedStyle : _idleStyle,
                  sunken: !selected,
                  pressed: pressed,
                  padding: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null)
                        SizedBox(
                          height: 28,
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                PixelSprite(icon, scale: iconScale),
                                if (badgeText != null)
                                  Positioned(
                                    top: -2,
                                    right: -6,
                                    child: _Badge(
                                      text: badgeText,
                                      alert: item.badge != '!',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (icon != null) SizedBox(height: grid.px(1)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          item.label.toUpperCase(),
                          maxLines: 1,
                          softWrap: false,
                          style: PixelType.small(
                            context,
                            color: selected
                                ? PixelPalette.ink
                                : PixelPalette.paper,
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
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.alert});

  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: (alert ? PixelBoxStyle.red : PixelBoxStyle.gold)
          .copyWith(corner: 1, shadowPx: 0),
      padding: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: grid.px(1)),
        child: Text(
          text,
          style: PixelType.small(
            context,
            color: alert ? PixelPalette.white : PixelPalette.ink,
          ),
        ),
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
                    iconHeight: 24,
                    onPressed: onBack,
                  ),
                  SizedBox(width: grid.px(2)),
                ],
                Expanded(
                  child: ShadowText(
                    title,
                    style: PixelType.title(context, color: PixelPalette.paper),
                    maxLines: 2,
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
