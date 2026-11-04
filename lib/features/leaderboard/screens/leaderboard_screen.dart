import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _activeTab = 0; // 0 = Sprint, 1 = All-Time

  final List<Map<String, dynamic>> _sprintScouts = const [
    {'rank': 1, 'name': 'Zernan Vash', 'points': 4850, 'quests': 18, 'tier': 'Master Scout', 'avatar': 'Z'},
    {'rank': 2, 'name': 'Ana Victoria', 'points': 4200, 'quests': 15, 'tier': 'Pioneer Scout', 'avatar': 'A'},
    {'rank': 3, 'name': 'Clarissa Angel', 'points': 3900, 'quests': 14, 'tier': 'Pioneer Scout', 'avatar': 'C'},
    {'rank': 4, 'name': 'Carl Jacob', 'points': 3450, 'quests': 12, 'tier': 'Trailblazer', 'avatar': 'C'},
    {'rank': 5, 'name': 'Alyana S.', 'points': 3100, 'quests': 11, 'tier': 'Trailblazer', 'avatar': 'A'},
    {'rank': 6, 'name': 'Sample Explorer', 'points': 1250, 'quests': 4, 'tier': 'Pathfinder', 'avatar': 'S'},
    {'rank': 7, 'name': 'Maria Santos', 'points': 980, 'quests': 3, 'tier': 'Pathfinder', 'avatar': 'M'},
  ];

  final List<Map<String, dynamic>> _allTimeScouts = const [
    {'rank': 1, 'name': 'Zernan Vash', 'points': 28500, 'quests': 84, 'tier': 'Grand Legend', 'avatar': 'Z'},
    {'rank': 2, 'name': 'Ana Victoria', 'points': 24200, 'quests': 72, 'tier': 'Grand Legend', 'avatar': 'A'},
    {'rank': 3, 'name': 'Clarissa Angel', 'points': 21900, 'quests': 65, 'tier': 'Master Scout', 'avatar': 'C'},
    {'rank': 4, 'name': 'Carl Jacob', 'points': 19450, 'quests': 58, 'tier': 'Master Scout', 'avatar': 'C'},
    {'rank': 5, 'name': 'Alyana S.', 'points': 17100, 'quests': 51, 'tier': 'Pioneer Scout', 'avatar': 'A'},
    {'rank': 14, 'name': 'Sample Explorer', 'points': 5250, 'quests': 16, 'tier': 'Trailblazer', 'avatar': 'S'},
  ];

  final List<Map<String, dynamic>> _municipalActivity = const [
    {'name': 'Alaminos City (Hundred Islands)', 'completions': 1420, 'badge': 'Top Eco Spot'},
    {'name': 'Bolinao (Cape & Falls)', 'completions': 1180, 'badge': 'Sunset Trail'},
    {'name': 'Dagupan City (Culinary Hub)', 'completions': 980, 'badge': 'Bangus Capital'},
    {'name': 'Manaoag (Minor Basilica)', 'completions': 890, 'badge': 'Heritage Trail'},
    {'name': 'Lingayen (Capitol & Gulf)', 'completions': 740, 'badge': 'Provincial Seat'},
  ];

  @override
  Widget build(BuildContext context) {
    final scouts = _activeTab == 0 ? _sprintScouts : _allTimeScouts;
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
                    title: 'Leaderboard',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _hero(context, grid),
                        SizedBox(height: grid.px(3)),
                        PixelSegmented(
                          items: const ['30-Day Sprint', 'All-Time'],
                          selectedIndex: _activeTab,
                          onChanged: (index) =>
                              setState(() => _activeTab = index),
                        ),
                        SizedBox(height: grid.px(3)),
                        if (scouts.length >= 3) _podium(context, grid, scouts),
                        SizedBox(height: grid.px(3)),
                        Text('Scout rankings', style: PixelType.title(context)),
                        SizedBox(height: grid.px(2)),
                        for (final scout in scouts) ...[
                          _scoutRow(context, grid, scout),
                          SizedBox(height: grid.px(1)),
                        ],
                        SizedBox(height: grid.px(3)),
                        Text('Top municipalities by check-in volume',
                            style: PixelType.title(context)),
                        SizedBox(height: grid.px(2)),
                        for (final muni in _municipalActivity) ...[
                          _municipalCard(context, grid, muni),
                          SizedBox(height: grid.px(1)),
                        ],
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

  Widget _hero(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorer Leaderboard',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Illustrative preview using pilot places. Scores are not live.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
        ],
      ),
    );
  }

  Widget _podium(
      BuildContext context, PixelGrid grid, List<Map<String, dynamic>> scouts) {
    Widget item(int index, String label, PixelBoxStyle style, int height) {
      final scout = scouts[index];
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelPanel(
              style: PixelBoxStyle.slot,
              padding: 1,
              child: Text(
                scout['avatar'].toString(),
                style: PixelType.title(context),
              ),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              scout['name'].toString().split(' ')[0],
              maxLines: 2,
              textAlign: TextAlign.center,
              style: PixelType.body(context),
            ),
            Text(
              '${scout['points']} pts',
              style: PixelType.small(context, color: PixelPalette.greenDark),
            ),
            SizedBox(height: grid.px(1)),
            SizedBox(
              height: grid.px(height.toDouble()),
              child: PixelPanel(
                style: style,
                child: Center(
                  child: Text(label, style: PixelType.title(context)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          item(1, '#2', PixelBoxStyle.stone, 30),
          SizedBox(width: grid.px(1)),
          item(0, '#1', PixelBoxStyle.gold, 38),
          SizedBox(width: grid.px(1)),
          item(2, '#3', PixelBoxStyle.wood, 25),
        ],
      ),
    );
  }

  Widget _scoutRow(
      BuildContext context, PixelGrid grid, Map<String, dynamic> scout) {
    final isUser = scout['isUser'] == true;
    return PixelPanel(
      style: isUser ? PixelBoxStyle.green : PixelBoxStyle.parchment,
      child: Row(
        children: [
          PixelChip('#${scout['rank']}',
              style: scout['rank'] <= 3
                  ? PixelBoxStyle.gold
                  : PixelBoxStyle.slot),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scout['name'].toString(),
                  maxLines: 2,
                  style: PixelType.title(
                    context,
                    color: isUser ? PixelPalette.white : PixelPalette.ink,
                  ),
                ),
                Text(
                  '${scout['tier']} · ${scout['quests']} quests completed',
                  style: PixelType.body(
                    context,
                    color: isUser ? PixelPalette.cream : PixelPalette.slate,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: grid.px(2)),
          Text(
            '${scout['points']} mJDQ',
            style: PixelType.numbers(
              context,
              color: isUser ? PixelPalette.white : PixelPalette.greenDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _municipalCard(
      BuildContext context, PixelGrid grid, Map<String, dynamic> muni) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(muni['name'].toString(), style: PixelType.title(context)),
                Text(
                  muni['badge'].toString(),
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
              ],
            ),
          ),
          SizedBox(width: grid.px(2)),
          PixelChip('${muni['completions']} visits'),
        ],
      ),
    );
  }
}
