import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/providers/home_daily_provider.dart';
import '../providers/profile_stats_provider.dart';
import '../showcase.dart';

const _medalEarned = PixelArt('medalEarned', [
  '....yy....yy....',
  '....yyy..yyy....',
  '.....yy..yy.....',
  '.....yyyyyy.....',
  '......yyyy......',
  '....ssssssss....',
  '...ssuussuuss...',
  '..ssuuuuuuuuss..',
  '..ssuuuuuuuuss..',
  '..ssuu6666uuss..',
  '..ssuu6666uuss..',
  '..ssuuuuuuuuss..',
  '...ssuussuuss...',
  '....ssssssss....',
  '.....ssssss.....',
  '................',
]);

const _medalLocked = PixelArt('medalLocked', [
  '....mm....mm....',
  '....mmm..mmm....',
  '.....mm..mm.....',
  '.....mmmmmm.....',
  '......mmmm......',
  '....kkkkkkkk....',
  '...kkppkkppkk...',
  '..kkppppppppkk..',
  '..kkppppppppkk..',
  '..kkppkkkkppkk..',
  '..kkppkkkkppkk..',
  '..kkppppppppkk..',
  '...kkppkkppkk...',
  '....kkkkkkkk....',
  '.....kkkkkk.....',
  '................',
]);

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(homeDailyProvider);
    // Owner 2026-11-08: the real server badges (the same ones you can equip on
    // your profile), not a list worked out on the phone.
    final achievements = ref.watch(achievementsProvider).valueOrNull ?? const AchievementsData();

    final badges = [
      for (final b in achievements.catalog)
        (
          title: b.title,
          desc: b.description,
          state: achievements.has(b.id) ? BadgeState.earned : BadgeState.locked,
        ),
    ];
    final earnedCount = badges.where((b) => b.state == BadgeState.earned).length;

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
                    title: 'Traveler Badges',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : () => context.go('/profile'),
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
                        dailyAsync.when(
                          data: (daily) => _stampsSummaryCard(context, grid, daily, earnedCount, badges.length),
                          loading: () => const Center(child: PixelLoader(label: 'Loading stamps')),
                          error: (_, __) => _stampsSummaryCard(
                            context,
                            grid,
                            null,
                            earnedCount,
                            badges.length,
                          ),
                        ),
                        SizedBox(height: grid.px(4)),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: grid.px(2),
                          runSpacing: grid.px(1),
                          children: [
                            Text(
                              'Pangasinan Badge Case',
                              style: PixelType.title(context),
                            ),
                            PixelChip(
                              '$earnedCount / ${badges.length} Unlocked',
                              style: PixelBoxStyle.gold,
                              textColor: PixelPalette.ink,
                            ),
                          ],
                        ),
                        SizedBox(height: grid.px(2)),
                        for (final b in badges) ...[
                          _badgeCard(context, grid, b),
                          SizedBox(height: grid.px(2)),
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

  Widget _stampsSummaryCard(
    BuildContext context,
    PixelGrid grid,
    HomeDailyState? daily,
    int earnedBadges,
    int totalBadges,
  ) {
    final stamps = daily?.stamps ?? 0;
    final streak = daily?.streak ?? 0;

    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PixelMicro(PixelMicroArt.sparkle, scale: 3),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: Text(
                  'Passport & Medals',
                  style: PixelType.title(context, color: PixelPalette.paper),
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Row(
            children: [
              Expanded(
                child: PixelPanel(
                  style: PixelBoxStyle.gold,
                  padding: 1,
                  child: Column(
                    children: [
                      Text(
                        '$stamps',
                        style: PixelType.numbers(context, color: PixelPalette.ink),
                      ),
                      Text(
                        stamps == 1 ? 'Stamp' : 'Stamps',
                        style: PixelType.small(context, color: PixelPalette.woodNight),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: PixelPanel(
                  style: PixelBoxStyle.parchment,
                  padding: 1,
                  child: Column(
                    children: [
                      Text(
                        '$streak ${streak == 1 ? 'Day' : 'Days'}',
                        style: PixelType.numbers(context, color: PixelPalette.greenDark),
                      ),
                      Text(
                        'Streak',
                        style: PixelType.small(context, color: PixelPalette.slate),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: PixelPanel(
                  style: PixelBoxStyle.parchment,
                  padding: 1,
                  child: Column(
                    children: [
                      Text(
                        '$earnedBadges / $totalBadges',
                        style: PixelType.numbers(context, color: PixelPalette.ink),
                      ),
                      Text(
                        totalBadges == 1 ? 'Badge' : 'Badges',
                        style: PixelType.small(context, color: PixelPalette.slate),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(
    BuildContext context,
    PixelGrid grid,
    ({String title, String desc, BadgeState state}) badge,
  ) {
    final isEarned = badge.state == BadgeState.earned;
    final isInProgress = badge.state == BadgeState.inProgress;

    final statusLabel = isEarned
        ? 'EARNED'
        : isInProgress
            ? 'IN PROGRESS'
            : 'LOCKED';

    final statusStyle = isEarned
        ? PixelBoxStyle.green
        : isInProgress
            ? PixelBoxStyle.gold
            : PixelBoxStyle.slot;

    final statusTextColor = isEarned
        ? PixelPalette.white
        : isInProgress
            ? PixelPalette.ink
            : PixelPalette.slate;

    return PixelPanel(
      style: isEarned ? PixelBoxStyle.parchment : PixelBoxStyle.slot,
      padding: 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelPanel(
            style: isEarned ? PixelBoxStyle.gold : PixelBoxStyle.stone,
            padding: 1,
            child: SizedBox(
              width: grid.px(12),
              height: grid.px(12),
              child: Center(
                child: PixelSprite(
                  isEarned ? _medalEarned : _medalLocked,
                  scale: 2,
                ),
              ),
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        badge.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.title(context),
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                    PixelChip(
                      statusLabel,
                      style: statusStyle,
                      textColor: statusTextColor,
                    ),
                  ],
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  badge.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
                if (!isEarned) ...[
                  SizedBox(height: grid.px(2)),
                  PixelButton(
                    label: 'Find Quests ›',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => context.push('/quests'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
