import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../widgets/home_adventure_calendar.dart';

/// The Pangasinan Almanac (festival calendar), moved from Home to its own
/// page opened from the main menu (owner 2026-11-16).
class AlmanacScreen extends StatelessWidget {
  const AlmanacScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Scaffold(
      backgroundColor: PixelPalette.paper,
      body: Column(
        children: [
          const PixelAppBar(title: 'Almanac'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                grid.gutter,
                grid.px(3),
                grid.gutter,
                grid.px(8) + MediaQuery.paddingOf(context).bottom,
              ),
              children: const [HomeAdventureCalendar()],
            ),
          ),
        ],
      ),
    );
  }
}
