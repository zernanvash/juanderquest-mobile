import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/pixel/generated/designer_art.g.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text_3d.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../models/spot_model.dart';
import '../../providers/hidden_gem_provider.dart';

/// Owner 2026-11-16: the hidden gem and the featured destination share one
/// row, two columns, at the top of Explore. Each tile opens its place; a
/// tile alone takes the full width.
class ExploreSpotlightRow extends ConsumerWidget {
  const ExploreSpotlightRow({super.key, this.featured});

  final SpotModel? featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final gem = ref.watch(hiddenGemProvider).valueOrNull?.firstOrNull;
    final f = featured;

    final tiles = <Widget>[
      if (gem != null)
        _SpotlightTile(
          key: const ValueKey('explore_spotlight_gem'),
          tag: 'HIDDEN GEM',
          name: gem.name,
          town: gem.municipality,
          imageUrl: gem.imageUrl,
          semantics:
              'Hidden gem, not sponsored: ${gem.name}, ${gem.municipality}',
          onTap: () => context.push('/explore/${Uri.encodeComponent(gem.id)}'),
        ),
      if (f != null)
        _SpotlightTile(
          key: const ValueKey('explore_spotlight_featured'),
          tag: 'FEATURED',
          name: f.name,
          town: f.municipality,
          imageUrl: f.imageUrl,
          semantics: 'Featured destination: ${f.name}, in ${f.municipality}',
          onTap: () => context.push('/explore/${f.slug}', extra: f),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: grid.px(4)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) SizedBox(width: grid.px(3)),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpotlightTile extends StatelessWidget {
  const _SpotlightTile({
    super.key,
    required this.tag,
    required this.name,
    required this.town,
    required this.imageUrl,
    required this.semantics,
    required this.onTap,
  });

  final String tag;
  final String name;
  final String town;
  final String? imageUrl;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final url = imageUrl;
    final hasImage = url != null && url.trim().isNotEmpty;
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            pixelTick(context);
            onTap();
          },
          child: PixelPanel(
            style: PixelBoxStyle.darkWood.copyWith(shadowPx: 2),
            padding: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: PixelChip(
                    tag,
                    style: PixelBoxStyle.gold,
                    textColor: PixelPalette.ink,
                  ),
                ),
                SizedBox(height: grid.px(2)),
                // Owner 2026-11-17: no photo, no placeholder box; the name
                // gets the room and is set larger instead.
                if (hasImage) ...[
                  // Photo frame: square corners (photos are never stepped).
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: PixelPalette.parchment,
                        width: grid.unit,
                      ),
                    ),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const _NoPhoto(),
                      ),
                    ),
                  ),
                  SizedBox(height: grid.px(2)),
                ],
                Text(
                  name,
                  maxLines: hasImage ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: hasImage
                      ? PixelType.body(context, color: PixelPalette.paper)
                          .copyWith(fontWeight: FontWeight.w700)
                      : PixelType.title(context, color: PixelPalette.paper),
                ),
                Text(
                  town,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.sunLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    // A photo that fails to load: a plain panel, no gradient.
    return const ColoredBox(
      color: PixelPalette.woodMid,
      child: Center(child: PixelIconFit(DesignerArt.gem, box: 36)),
    );
  }
}
