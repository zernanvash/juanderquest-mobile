import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../pixel/map_marker_art.dart';
import '../pixel/pixel_scope_fallback.dart';

class MapClusterListItem {
  const MapClusterListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class MapClusterListSheet extends StatelessWidget {
  const MapClusterListSheet({
    required this.items,
    required this.onSelect,
    super.key,
  });

  final List<MapClusterListItem> items;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return PixelScopeFallback(
      child: Builder(
        builder: (ctx) {
          final grid = PixelGrid.of(ctx);

          return SafeArea(
            child: SizedBox(
              height: maxHeight,
              child: PixelPanel(
                style: PixelBoxStyle.parchment,
                padding: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Destinations at this location',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.body(ctx, color: PixelPalette.ink)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        PixelIconButton(
                          icon: MapMarkerArt.iconClose,
                          semanticLabel: 'Close destination list',
                          style: PixelBoxStyle.parchment,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: grid.px(0.5)),
                    Text(
                      '${items.length} DESTINATIONS',
                      style: PixelType.small(ctx, color: PixelPalette.slate),
                    ),
                    SizedBox(height: grid.px(2)),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => SizedBox(height: grid.px(1)),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return GestureDetector(
                            onTap: () {
                              pixelTick(ctx);
                              onSelect(item.id);
                            },
                            child: PixelPanel(
                              style: PixelBoxStyle.slot,
                              padding: 2,
                              child: Row(
                                children: [
                                  Icon(item.icon, color: PixelPalette.green, size: 20),
                                  SizedBox(width: grid.px(2)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: PixelType.body(ctx, color: PixelPalette.ink)
                                              .copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          item.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: PixelType.small(ctx, color: PixelPalette.slate),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
