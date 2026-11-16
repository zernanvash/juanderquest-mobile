import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_idle.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../quests/models/quest_model.dart';
import '../providers/home_daily_provider.dart';

/// Concept B Band 3: Asymmetric dual bento split — Left emerald Mission box
/// + Right wood Daily Stamp box, plus a 2-pill QOTD / Hidden Gem micro-bar.
///
/// Takes [recommendedQuest] and [recommendedReason] as parameters so 89a stays
/// independent of Plan 88 providers; 89b wires them in.
class HomeDualBentoRow extends StatelessWidget {
  const HomeDualBentoRow({
    super.key,
    this.activeQuest,
    this.recommendedQuest,
    this.recommendedReason,
    this.dailyState,
    this.claimingDaily = false,
    this.onClaimDaily,
    this.onNavigate,
  });

  final QuestModel? activeQuest;
  final QuestModel? recommendedQuest;
  final String? recommendedReason;
  final HomeDailyState? dailyState;
  final bool claimingDaily;
  final VoidCallback? onClaimDaily;
  final ValueChanged<String>? onNavigate;

  static const _greenStyle = PixelBoxStyle(
    fill: PixelPalette.green,
    highlight: PixelPalette.greenMid,
    shade: PixelPalette.greenDeep,
    outline: PixelPalette.ink,
  );

  static const _woodStyle = PixelBoxStyle(
    fill: PixelPalette.wood,
    highlight: PixelPalette.woodMid,
    shade: PixelPalette.woodDeep,
    outline: PixelPalette.ink,
  );

  void _go(BuildContext context, String route) {
    if (onNavigate != null) {
      onNavigate!(route);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Owner 2026-11-16: panels take the full width, stacked.
            final missionBox = _MissionBentoBox(
              key: const ValueKey('home_bento_mission'),
              style: _greenStyle,
              activeQuest: activeQuest,
              recommendedQuest: recommendedQuest,
              recommendedReason: recommendedReason,
              onGo: (route) => _go(context, route),
            );
            final stampBox = _StampBentoBox(
              key: const ValueKey('home_bento_stamp'),
              style: _woodStyle,
              dailyState: dailyState,
              claiming: claimingDaily,
              onClaim: onClaimDaily,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                missionBox,
                SizedBox(height: grid.px(5)),
                stampBox,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MissionBentoBox extends StatelessWidget {
  const _MissionBentoBox({
    super.key,
    required this.style,
    required this.activeQuest,
    required this.recommendedQuest,
    required this.recommendedReason,
    required this.onGo,
  });

  final PixelBoxStyle style;
  final QuestModel? activeQuest;
  final QuestModel? recommendedQuest;
  final String? recommendedReason;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final quest = activeQuest ?? recommendedQuest;
    final isActive = activeQuest != null;
    // The lettered title stays fixed; the changing reason ("0.0 km away",
    // "In your town") is the live value beside it (owner 2026-11-16).
    final badgeText = isActive ? 'ACTIVE QUEST' : 'MISSION';
    final reason = isActive || recommendedReason?.isNotEmpty != true
        ? null
        : recommendedReason;

    return PixelPanel(
      style: style,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelSectionTitle(
                badgeText,
                icon: DesignerArt.questMarker,
                // Idle: the quest marker bobs.
                iconWrap: (icon) => PixelIdleBob(child: icon),
                value: reason,
              ),
              const SizedBox(height: 4),
              if (quest != null) ...[
                Text(
                  quest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.cream)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                if (quest.locationName.isNotEmpty)
                  Text(
                    quest.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context,
                        color: PixelPalette.greenLight),
                  )
                else
                  MjdqAmount(
                    quest.rewardPoints,
                    sign: true,
                    style: PixelType.small(context,
                        color: PixelPalette.greenLight),
                  ),
              ] else ...[
                Text(
                  'Find a destination to start a quest',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.cream),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          PixelButton(
            key: ValueKey(
              isActive
                  ? 'home_mission_continue_button'
                  : (quest != null
                      ? 'home_mission_view_button'
                      : 'home_mission_explore_button'),
            ),
            label: isActive
                ? 'CONTINUE'
                : (quest != null ? 'VIEW QUEST' : 'EXPLORE'),
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () {
              if (quest != null) {
                onGo('/quests/${quest.id}');
              } else {
                onGo('/explore');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StampBentoBox extends StatelessWidget {
  const _StampBentoBox({
    super.key,
    required this.style,
    required this.dailyState,
    required this.claiming,
    required this.onClaim,
  });

  final PixelBoxStyle style;
  final HomeDailyState? dailyState;
  final bool claiming;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final claimedDays = dailyState?.claimedDays ?? 0;
    final streak = dailyState?.streak ?? 0;
    final claimedToday = dailyState?.claimToday ?? false;
    final nominal = dailyState?.nominalStamps ?? 5;

    // Idle states (owner 2026-11-16): unclaimed, the chest wiggles; claimed,
    // a slow gold shimmer crosses the panel.
    return PixelShimmer(
      enabled: claimedToday,
      child: PixelPanel(
        style: style,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelSectionTitle(
                  'STAMP',
                  value: '$claimedDays/7',
                  icon: claimedToday
                      ? DesignerArt.chestOpenAnim.frames.last
                      : DesignerArt.chestOpenAnim.frames.first,
                  iconWrap:
                      claimedToday ? null : (icon) => PixelWiggle(child: icon),
                ),
                const SizedBox(height: 4),
                Text(
                  'Streak: ${streak}d',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.cream)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var d = 1; d <= 7; d++) ...[
                      if (d > 1) const SizedBox(width: 2),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: d <= claimedDays
                                ? PixelPalette.sun
                                : PixelPalette.woodDeep,
                            border:
                                Border.all(color: PixelPalette.ink, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            PixelButton(
              key: const ValueKey('home_daily_claim_button'),
              label: claimedToday ? 'CLAIMED' : 'CLAIM +$nominal',
              variant: claimedToday
                  ? PixelButtonVariant.secondary
                  : PixelButtonVariant.primary,
              expand: true,
              loading: claiming,
              // Owner 2026-11-16: a second try says why nothing happens.
              onPressed: claimedToday
                  ? () => showPixelToast(context,
                      "You already claimed today's stamp. Come back tomorrow!")
                  : onClaim,
            ),
          ],
        ),
      ),
    );
  }
}
