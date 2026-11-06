import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_art.dart';
import 'pixel_box.dart';
import 'pixel_controls.dart';
import 'pixel_grid.dart';
import 'pixel_rpg.dart';
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

  /// Owner 2026-11-04 picked "A · Wood shelf": dark wood bar, square
  /// parchment slots, the active slot gold and lifted. Slots are square and
  /// sized in whole art pixels; icons draw at a whole-number device scale.
  static const _selectedStyle = PixelBoxStyle(
    fill: PixelPalette.sun,
    highlight: PixelPalette.sunLight,
    shade: PixelPalette.amber,
    corner: 1,
    shadowPx: 1,
  );

  static const _idleStyle = PixelBoxStyle(
    fill: PixelPalette.parchment,
    highlight: PixelPalette.white,
    shade: PixelPalette.paperDim,
    corner: 1,
    shadowPx: 1,
  );

  /// Largest slot side, in logical px.
  static const _maxSide = 72.0;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Container(
      decoration: BoxDecoration(
        color: PixelPalette.woodDeep,
        border: Border(
          top: BorderSide(color: PixelPalette.wood, width: grid.px(1)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        grid.px(2),
        grid.px(4),
        grid.px(2),
        grid.px(3) + MediaQuery.paddingOf(context).bottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final n = widget.items.length;
          final gap = grid.px(2);
          // Square side: an equal share of the width, capped, rounded down to
          // whole art pixels so every slot is exactly the same size.
          final share = (constraints.maxWidth - gap * (n - 1)) / n;
          final side = (share.clamp(0, _maxSide) / grid.unit).floorToDouble() *
              grid.unit;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < n; i++)
                SizedBox.square(
                  dimension: side,
                  child: _slot(context, grid, i, side),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _slot(BuildContext context, PixelGrid grid, int i, double side) {
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Whole device pixels per art pixel, so the icon fits about half the slot
    // without stretching.
    final iconScale = icon == null
        ? 1
        : (side * 0.5 * dpr / math.max(icon.width, icon.height))
            .floor()
            .clamp(1, 16)
            .toInt();
    final lift = selected ? -grid.px(2) : (pressed ? grid.unit : 0.0);
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
          child: Transform.translate(
            offset: Offset(0, lift),
            child: PixelPanel(
              style: selected ? _selectedStyle : _idleStyle,
              pressed: pressed,
              padding: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null)
                    Expanded(
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Plan 75k: the active tab's icon breathes.
                            PixelIdleBob(
                              enabled: selected,
                              child: PixelSprite(icon, scale: iconScale),
                            ),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      style: PixelType.small(
                        context,
                        color: selected ? PixelPalette.ink : PixelPalette.wood,
                      ),
                    ),
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
  '..0....',
  '.00....',
  '0000000',
  '.00....',
  '..0....',
]);

class PixelAppBar extends StatelessWidget {
  const PixelAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
    this.isTab = false,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool isTab;

  static const _tabPaths = {
    '/',
    '/dashboard',
    '/explore',
    '/map',
    '/shop',
    '/profile',
  };

  bool _isMainTab(BuildContext context) {
    if (isTab) return true;
    try {
      final route = GoRouterState.of(context);
      final path = route.uri.path;
      final normalized = path.length > 1 && path.endsWith('/')
          ? path.substring(0, path.length - 1)
          : path;
      if (_tabPaths.contains(normalized)) {
        if (normalized == '/profile' &&
            route.pathParameters['username'] != null) {
          return false;
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final canPop = Navigator.of(context).canPop();
    final isMain = _isMainTab(context);

    final VoidCallback? effectiveBack = isMain
        ? null
        : (canPop
            ? (onBack ?? () => Navigator.of(context).maybePop())
            : () {
                try {
                  context.go('/dashboard');
                } catch (_) {
                  (onBack ?? () => Navigator.of(context).maybePop())();
                }
              });

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
                if (effectiveBack != null) ...[
                  PixelIconButton(
                    key: const ValueKey('pixel_app_bar_back'),
                    icon: _backIcon,
                    semanticLabel: 'Back',
                    style: PixelBoxStyle.parchment,
                    iconHeight: 24,
                    onPressed: effectiveBack,
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
