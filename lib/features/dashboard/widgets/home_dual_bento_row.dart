import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
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
    this.qotdDone = false,
    this.onTapQotd,
    this.gemName,
    this.gemSlug,
    this.onTapGem,
    this.onNavigate,
  });

  final QuestModel? activeQuest;
  final QuestModel? recommendedQuest;
  final String? recommendedReason;
  final HomeDailyState? dailyState;
  final bool claimingDaily;
  final VoidCallback? onClaimDaily;
  final bool qotdDone;
  final VoidCallback? onTapQotd;
  final String? gemName;
  final String? gemSlug;
  final VoidCallback? onTapGem;
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
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

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
                SizedBox(height: grid.px(2)),
                stampBox,
              ],
            );
          },
        ),
        SizedBox(height: grid.px(2)),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 260 || textScale >= 1.6;
            final qotdChip = _MicroPillButton(
              key: const ValueKey('home_qotd_pill'),
              icon: DesignerArt.questionMark,
              label: qotdDone ? 'QOTD DONE' : 'QOTD +5 mJDQ',
              labelWidget: qotdDone
                  ? null
                  : MjdqAmount(
                      5,
                      sign: true,
                      prefix: 'QOTD ',
                      style:
                          PixelType.small(context, color: PixelPalette.woodDeep)
                              .copyWith(fontWeight: FontWeight.w700),
                    ),
              onTap: onTapQotd,
            );
            final gemChip = _MicroPillButton(
              key: const ValueKey('home_gem_pill'),
              icon: DesignerArt.gem,
              label: gemName != null && gemName!.isNotEmpty
                  ? 'GEM: $gemName'
                  : 'HIDDEN GEM',
              onTap: onTapGem ??
                  (gemSlug != null && gemSlug!.isNotEmpty
                      ? () => _go(context, '/explore/$gemSlug')
                      : () => _go(context, '/explore')),
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  qotdChip,
                  const SizedBox(height: 6),
                  gemChip,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: qotdChip),
                const SizedBox(width: 6),
                Expanded(child: gemChip),
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
                'STAMP',
                value: '$claimedDays/7',
                icon: claimedToday
                    ? DesignerArt.chestOpenAnim.frames.last
                    : DesignerArt.chestOpenAnim.frames.first,
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
                          border: Border.all(color: PixelPalette.ink, width: 1),
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
            variant: PixelButtonVariant.primary,
            expand: true,
            loading: claiming,
            onPressed: claimedToday ? null : onClaim,
          ),
        ],
      ),
    );
  }
}

class _MicroPillButton extends StatelessWidget {
  const _MicroPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelWidget,
  });

  final PixelArt icon;
  final String label;
  final Widget? labelWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: PixelPalette.parchment,
          border: Border.all(color: PixelPalette.woodDeep, width: 2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: FittedBox(
                fit: BoxFit.contain,
                child: PixelSprite(icon, scale: 1),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: labelWidget ??
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        PixelType.small(context, color: PixelPalette.woodDeep)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
