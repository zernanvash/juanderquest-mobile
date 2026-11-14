import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../map/pixel/map_marker_art.dart';
import '../../navigation/widgets/nav_pixel_art.dart';
import '../../spots/explore/explore_art.dart';
import '../../vote/pixel/wave3_art.dart';

enum CommandTileCategory { all, play, town, logs }

class _CommandTileSpec {
  const _CommandTileSpec({
    required this.key,
    required this.label,
    required this.icon,
    required this.badge,
    required this.category,
    this.badgeLive = false,
    this.subtitle,
    this.route,
    this.onTap,
  });

  final Key key;
  final String label;
  final PixelArt icon;
  final String badge;
  final bool badgeLive;
  final CommandTileCategory category;
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
  CommandTileCategory _category = CommandTileCategory.all;

  static const _creamPanel = PixelBoxStyle(
    fill: PixelPalette.cream,
    highlight: PixelPalette.white,
    shade: PixelPalette.woodLight,
    outline: PixelPalette.woodDeep,
  );

  void _openRoute(BuildContext context, String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      context.push(route);
    }
  }

  List<_CommandTileSpec> _tiles(BuildContext context) {
    final all = <_CommandTileSpec>[
      _CommandTileSpec(
        key: const ValueKey('home_menu_quests'),
        label: 'QUESTS',
        subtitle:
            '${widget.activeQuestsCount} active · ${widget.savedCount} saved',
        icon: DesignerArt.questMarker,
        badge: '${widget.activeQuestsCount}',
        category: CommandTileCategory.play,
        route: '/quests',
      ),
      _CommandTileSpec(
        key: const ValueKey('home_tile_route'),
        label: 'ROUTE',
        icon: NavPixelArt.modeCar,
        badge: 'GO',
        badgeLive: true,
        category: CommandTileCategory.play,
        route: '/navigate',
      ),
      _CommandTileSpec(
        key: const ValueKey('home_tile_vote'),
        label: 'VOTE',
        icon: DesignerArt.juanChoice,
        badge: widget.voteLive ? 'LIVE' : 'SOON',
        badgeLive: widget.voteLive,
        category: CommandTileCategory.town,
        route: '/choice',
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_plaza'),
        label: 'PLAZA',
        icon: DesignerArt.plazaTrophy,
        badge: 'RANKS',
        category: CommandTileCategory.town,
        route: '/plaza',
      ),
      _CommandTileSpec(
        key: const ValueKey('home_tile_quizzes'),
        label: 'QUIZZES',
        icon: NavPixelArt.questionTile,
        badge: '${widget.nearbyQuizCount}',
        category: CommandTileCategory.play,
        onTap: widget.onOpenQuizzes,
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_add_spot'),
        label: '+ SPOT',
        icon: MapMarkerArt.iconAddPin,
        badge: '+XP',
        category: CommandTileCategory.play,
        route: '/map/add-spot',
      ),
      _CommandTileSpec(
        key: const ValueKey('home_tile_saved'),
        label: 'SAVED',
        icon: ExploreArt.bookmarkSaved,
        badge: '${widget.savedCount}',
        category: CommandTileCategory.logs,
        route: '/saved',
      ),
      const _CommandTileSpec(
        key: ValueKey('home_tile_history'),
        label: 'HISTORY',
        icon: Wave3Art.list,
        badge: 'LOG',
        category: CommandTileCategory.logs,
        route: '/history',
      ),
    ];

    if (_category == CommandTileCategory.all) return all;
    return all.where((t) => t.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final tiles = _tiles(context);

    return PixelPanel(
      key: const ValueKey('home_command_grid'),
      style: _creamPanel,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              Text(
                'MAIN MENU',
                style: PixelType.small(context, color: PixelPalette.woodDeep)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _CatChip(
                    label: 'ALL',
                    active: _category == CommandTileCategory.all,
                    onTap: () =>
                        setState(() => _category = CommandTileCategory.all),
                  ),
                  _CatChip(
                    label: 'PLAY',
                    active: _category == CommandTileCategory.play,
                    onTap: () =>
                        setState(() => _category = CommandTileCategory.play),
                  ),
                  _CatChip(
                    label: 'TOWN',
                    active: _category == CommandTileCategory.town,
                    onTap: () =>
                        setState(() => _category = CommandTileCategory.town),
                  ),
                  _CatChip(
                    label: 'LOGS',
                    active: _category == CommandTileCategory.logs,
                    onTap: () =>
                        setState(() => _category = CommandTileCategory.logs),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
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

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? PixelPalette.sun : PixelPalette.wood,
          border: Border.all(color: PixelPalette.ink, width: 1),
        ),
        child: Text(
          label,
          style: PixelType.small(
            context,
            color: active ? PixelPalette.ink : PixelPalette.cream,
          ).copyWith(fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MenuIconTile extends StatelessWidget {
  const _MenuIconTile({
    required this.spec,
    required this.onPressed,
  });

  final _CommandTileSpec spec;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: spec.key,
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
        decoration: BoxDecoration(
          color: PixelPalette.white,
          border: Border.all(color: PixelPalette.woodDeep, width: 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: PixelSprite(
                        spec.icon,
                        scale: spec.icon.width <= 16 ? 2 : 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: PixelType.small(context, color: PixelPalette.ink)
                        .copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  if (spec.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      spec.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: PixelType.small(context, color: PixelPalette.slate)
                          .copyWith(fontSize: 8),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: -3,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: spec.badgeLive
                      ? PixelPalette.greenBright
                      : PixelPalette.sun,
                  border: Border.all(color: PixelPalette.ink, width: 1),
                ),
                child: Text(
                  spec.badge,
                  style: PixelType.small(
                    context,
                    color: spec.badgeLive
                        ? PixelPalette.white
                        : PixelPalette.ink,
                  ).copyWith(fontSize: 8, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
