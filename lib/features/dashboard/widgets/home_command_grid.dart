import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../spots/explore/explore_art.dart';
import '../../vote/pixel/wave3_art.dart';

class _CommandTileSpec {
  const _CommandTileSpec({
    required this.key,
    required this.label,
    required this.icon,
    this.badge,
    this.badgeLive = false,
    this.subtitle,
    this.route,
    this.onTap,
  });

  final Key key;
  final String label;
  final PixelArt icon;
  final String? badge;
  final bool badgeLive;
  final String? subtitle;
  final String? route;
  final VoidCallback? onTap;
}

/// Concept B Band 2: Top 4x2 Super-App Icon Matrix (switches to 2x4 when
/// text scale >= 1.4 or available width < 280 dp).
class HomeCommandGrid extends StatefulWidget {
  const HomeCommandGrid({
    super.key,
    this.activeQuestsCount = 0,
    this.savedCount = 0,
    this.nearbyQuizCount = 0,
    this.voteLive = false,
    this.onOpenQuizzes,
    this.onNavigate,
  });

  final int activeQuestsCount;
  final int savedCount;
  final int nearbyQuizCount;
  final bool voteLive;
  final VoidCallback? onOpenQuizzes;
  final ValueChanged<String>? onNavigate;

  @override
  State<HomeCommandGrid> createState() => _HomeCommandGridState();
}

class _HomeCommandGridState extends State<HomeCommandGrid> {
  void _openRoute(BuildContext context, String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      context.push(route);
    }
  }

  List<_CommandTileSpec> _tiles(BuildContext context) {
    return <_CommandTileSpec>[
      _CommandTileSpec(
        key: const ValueKey('home_menu_quests'),
        label: 'QUESTS',
        subtitle:
            '${widget.activeQuestsCount} active · ${widget.savedCount} saved',
        icon: DesignerArt.questMarker,
        route: '/quests',
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_merchants'),
        label: 'MERCHANTS',
        icon: DesignerArt.salakot,
        route: '/affiliate',
      ),
      _CommandTileSpec(
        key: const ValueKey('home_tile_vote'),
        label: 'VOTE',
        icon: DesignerArt.juanChoice,
        badge: widget.voteLive ? 'LIVE' : 'SOON',
        badgeLive: widget.voteLive,
        route: '/choice',
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_plaza'),
        label: 'PLAZA',
        icon: DesignerArt.plazaTrophy,
        route: '/plaza',
      ),
      _CommandTileSpec(
        key: const ValueKey('home_tile_quizzes'),
        label: 'QUIZZES',
        icon: DesignerArt.questionMark,
        onTap: widget.onOpenQuizzes,
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_add_spot'),
        label: '+ SPOT',
        icon: DesignerArt.spotMarker,
        badge: '+XP',
        route: '/map/add-spot',
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_saved'),
        label: 'SAVED',
        icon: ExploreArt.bookmarkSaved,
        route: '/saved',
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_history'),
        label: 'HISTORY',
        icon: Wave3Art.list,
        route: '/history',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final tiles = _tiles(context);

    return KeyedSubtree(
      key: const ValueKey('home_command_grid'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cols =
                  (constraints.maxWidth < 280 || textScale >= 1.4) ? 2 : 4;
              final rows = <Widget>[];
              for (var i = 0; i < tiles.length; i += cols) {
                final slice = tiles.sublist(
                  i,
                  (i + cols > tiles.length) ? tiles.length : i + cols,
                );
                rows.add(
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i + cols < tiles.length ? 6 : 0,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < cols; c++) ...[
                            if (c > 0) const SizedBox(width: 5),
                            Expanded(
                              child: c < slice.length
                                  ? _MenuIconTile(
                                      spec: slice[c],
                                      onPressed: () {
                                        final item = slice[c];
                                        if (item.onTap != null) {
                                          item.onTap!();
                                        } else if (item.route != null) {
                                          _openRoute(context, item.route!);
                                        }
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuIconTile extends StatefulWidget {
  const _MenuIconTile({
    required this.spec,
    required this.onPressed,
  });

  final _CommandTileSpec spec;
  final VoidCallback onPressed;

  @override
  State<_MenuIconTile> createState() => _MenuIconTileState();
}

class _MenuIconTileState extends State<_MenuIconTile> {
  bool _down = false;

  static const _tileStyle = PixelBoxStyle(
    fill: PixelPalette.cream,
    highlight: PixelPalette.white,
    shade: PixelPalette.woodLight,
    outline: PixelPalette.ink,
    corner: 2,
    shadowPx: 0,
  );

  static const _tilePressedStyle = PixelBoxStyle(
    fill: PixelPalette.cream,
    highlight: PixelPalette.woodLight,
    shade: PixelPalette.white,
    outline: PixelPalette.ink,
    corner: 2,
    shadowPx: 0,
  );

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return GestureDetector(
      key: spec.key,
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: Transform.translate(
        offset: Offset(0, _down ? 1 : 0),
        child: PixelPanel(
          style: _down ? _tilePressedStyle : _tileStyle,
          padding: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 45),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Owner 2026-11-16 picked "menu A": icons fill the
                        // box at a whole-pixel scale (sharp, same size).
                        PixelIconFit(spec.icon, box: 36),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            spec.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: PixelType.small(context,
                                    color: PixelPalette.ink)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (spec.subtitle != null) ...[
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              spec.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (spec.badge != null)
                    Positioned(
                      top: -3,
                      right: -1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: spec.badgeLive
                              ? PixelPalette.red
                              : PixelPalette.sun,
                          border: Border.all(color: PixelPalette.ink, width: 1),
                        ),
                        child: Text(
                          spec.badge!,
                          style: PixelType.small(
                            context,
                            color: spec.badgeLive
                                ? PixelPalette.white
                                : PixelPalette.ink,
                          ).copyWith(fontWeight: FontWeight.w700),
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
