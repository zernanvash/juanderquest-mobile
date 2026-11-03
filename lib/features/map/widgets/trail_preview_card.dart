import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../pixel/pixel_scope_fallback.dart';

const List<String> _trailPreferences = [
  'Scenic route',
  'Local food stops',
  'Quieter alternatives',
];

class TrailPreviewCard extends StatefulWidget {
  const TrailPreviewCard({super.key});

  @override
  State<TrailPreviewCard> createState() => _TrailPreviewCardState();
}

class _TrailPreviewCardState extends State<TrailPreviewCard> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return PixelScopeFallback(
      child: Builder(
        builder: (ctx) {
          final grid = PixelGrid.of(ctx);

          return PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.explore_rounded,
                            size: 14, color: PixelPalette.green),
                        SizedBox(width: grid.px(1)),
                        Text(
                          'THE TRAIL',
                          style: PixelType.small(ctx,
                                  color: PixelPalette.greenDeep)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    PixelPanel(
                      style: PixelBoxStyle.gold,
                      padding: 1,
                      child: Text(
                        'IN DEVELOPMENT',
                        style: PixelType.small(ctx, color: PixelPalette.ink)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  'A personalized multi-stop Trail to this destination is not available yet. '
                  'Tell us what you would prefer — nothing is routed or promised today.',
                  style: PixelType.small(ctx, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(1.5)),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _trailPreferences.map((preference) {
                    final selected = _selected.contains(preference);
                    return GestureDetector(
                      onTap: () {
                        pixelTick(ctx);
                        setState(() {
                          if (selected) {
                            _selected.remove(preference);
                          } else {
                            _selected.add(preference);
                          }
                        });
                      },
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: preference,
                        child: PixelPanel(
                          style: selected
                              ? PixelBoxStyle.gold
                              : PixelBoxStyle.slot,
                          padding: 1,
                          child: Text(
                            preference,
                            style: PixelType.small(
                              ctx,
                              color: selected
                                  ? PixelPalette.ink
                                  : PixelPalette.slate,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  'Preferences stay on this screen only; they are not sent anywhere yet.',
                  style: PixelType.small(ctx, color: PixelPalette.stone),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
