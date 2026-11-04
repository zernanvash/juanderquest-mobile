import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/theme/app_theme.dart';

class TrailComingSoonScreen extends StatelessWidget {
  const TrailComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'The Trail',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        PixelPanel(
                          style: PixelBoxStyle.wood,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PixelChip(
                                'COMING SOON',
                                style: PixelBoxStyle.gold,
                              ),
                              SizedBox(height: grid.px(2)),
                              Text(
                                'A better way to explore along your route',
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.paper,
                                ),
                              ),
                              SizedBox(height: grid.px(1)),
                              Text(
                                'The Trail is being designed to suggest worthwhile stops between your starting point and destination, shaped by your interests and community feedback.',
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.cream,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
                        _idea(
                          context,
                          grid,
                          'Plan a route',
                          'Choose where your trip begins and ends.',
                        ),
                        SizedBox(height: grid.px(2)),
                        _idea(
                          context,
                          grid,
                          'Find stops along the way',
                          'Discover destinations and local experiences near your route.',
                        ),
                        SizedBox(height: grid.px(2)),
                        _idea(
                          context,
                          grid,
                          'Make it yours',
                          'Future suggestions can reflect your interests and travel history.',
                        ),
                        SizedBox(height: grid.px(3)),
                        PixelButton(
                          key: const ValueKey('trail_back_explore'),
                          label: 'Back to Explore',
                          expand: true,
                          onPressed: () => context.go('/explore'),
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
    );
  }

  Widget _idea(
      BuildContext context, PixelGrid grid, String title, String body) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(body, style: PixelType.body(context, color: PixelPalette.slate)),
        ],
      ),
    );
  }
}
