import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_art.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../submissions/models/submission_model.dart';
import '../../submissions/providers/submission_provider.dart';
import '../../vote/models/governance_proposal_model.dart';
import '../providers/home_daily_provider.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/home_qotd_provider.dart';
import 'home_juanchoice_card.dart';
import 'home_widgets.dart';

class HomeProgressTab extends StatelessWidget {
  const HomeProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _QotdSection(),
        SizedBox(height: grid.px(2)),
        const _DailyStampsSection(),
        SizedBox(height: grid.px(2)),
        const _WalletSection(),
        SizedBox(height: grid.px(2)),
        const _TravelStatsSection(),
        SizedBox(height: grid.px(2)),
        const _NearbySection(),
        SizedBox(height: grid.px(2)),
        const _ProofActivitySection(),
        SizedBox(height: grid.px(2)),
        const HomeJuanChoiceCard(),
        SizedBox(height: grid.px(2)),
        const _CommunityVotingSection(),
        SizedBox(height: grid.px(2)),
        const _AffiliateInvite(),
      ],
    );
  }
}

// ------------------------------------------------------------------- QOTD

class _QotdSection extends ConsumerWidget {
  const _QotdSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final qotd = ref.watch(homeQotdProvider);
    return HomePanel(
      key: const ValueKey('home_qotd_panel'),
      title: 'Question of the Day',
      subtitle: 'Answer once today to earn +5 stamps.',
      child: qotd.when(
        loading: () => const HomeInlineLoading(label: 'Loading question'),
        error: (_, __) => HomeErrorPanel(
          message: 'Question of the Day is unavailable.',
          retryKey: const ValueKey('home_qotd_retry'),
          onRetry: () => ref.read(homeQotdProvider.notifier).load(),
        ),
        data: (state) {
          if (!state.hasQuestion) {
            return const HomeEmptyText('No question today.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Plan 75k: the question as an RPG encounter box.
              PixelLorePanel(
                key: const ValueKey('home_qotd_prompt'),
                padding: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.quizTitle.isNotEmpty) ...[
                      Text(
                        '* ${state.quizTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            PixelType.small(context, color: PixelPalette.sun),
                      ),
                      SizedBox(height: grid.px(1)),
                    ],
                    Text(
                      state.questionText,
                      style: PixelType.body(context, color: PixelPalette.paper),
                    ),
                  ],
                ),
              ),
              SizedBox(height: grid.px(2)),
              for (var i = 0; i < state.options.length; i++) ...[
                if (i > 0) SizedBox(height: grid.px(1)),
                _QotdOptionRow(
                  option: state.options[i],
                  state: state,
                  onTap: state.answered || state.submitting
                      ? null
                      : () => ref
                          .read(homeQotdProvider.notifier)
                          .answer(state.options[i].id),
                ),
              ],
              if (state.submitting) ...[
                SizedBox(height: grid.px(2)),
                const HomeInlineLoading(label: 'Checking your answer'),
              ],
              if (state.answerError != null) ...[
                SizedBox(height: grid.px(2)),
                Text(
                  state.answerError!,
                  style: PixelType.small(context, color: PixelPalette.redDeep),
                ),
              ],
              if (state.answered) ...[
                SizedBox(height: grid.px(2)),
                PixelPanel(
                  style:
                      state.correct ? PixelBoxStyle.green : PixelBoxStyle.gold,
                  padding: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.correct ? 'Correct!' : 'Not quite.',
                        style: PixelType.body(
                          context,
                          color: state.correct
                              ? PixelPalette.white
                              : PixelPalette.ink,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (state.explanation != null &&
                          state.explanation!.isNotEmpty) ...[
                        SizedBox(height: grid.px(1)),
                        Text(
                          state.explanation!,
                          style: PixelType.small(
                            context,
                            color: state.correct
                                ? PixelPalette.cream
                                : PixelPalette.goldDeep,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QotdOptionRow extends StatelessWidget {
  const _QotdOptionRow({
    required this.option,
    required this.state,
    required this.onTap,
  });

  final HomeQotdOption option;
  final HomeQotdState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final selected = state.selectedOptionId == option.id;
    final correct = state.answered &&
        (state.correctOptionId == option.id || (state.correct && selected));
    final wrong = state.answered && selected && !state.correct;
    final style = correct
        ? PixelBoxStyle.green
        : wrong
            ? PixelBoxStyle.red
            : selected
                ? PixelBoxStyle.gold
                : PixelBoxStyle.parchment;
    final textColor = correct || wrong ? PixelPalette.white : PixelPalette.ink;
    final letter = String.fromCharCode(64 + option.ordinal);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: Row(
        children: [
          // Keycap letter: stone, gold once chosen.
          PixelPanel(
            style:
                selected || correct ? PixelBoxStyle.gold : PixelBoxStyle.stone,
            padding: 1,
            child: SizedBox(
              width: grid.px(8),
              child: Center(
                child: Text(
                  letter,
                  style: PixelType.small(
                    context,
                    color: selected || correct
                        ? PixelPalette.ink
                        : PixelPalette.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Text(
              option.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(context, color: textColor),
            ),
          ),
        ],
      ),
    );
    // Plan 75k: answers press like inventory slots.
    return PixelTappableSlot(
      key: ValueKey('home_qotd_option_${option.id}'),
      style: style,
      padding: 1,
      semanticLabel: 'Option $letter: ${option.text}',
      onTap: onTap,
      child: ExcludeSemantics(child: row),
    );
  }
}

// ------------------------------------------------------------ daily stamps

class _DailyStampsSection extends ConsumerWidget {
  const _DailyStampsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final daily = ref.watch(homeDailyProvider);
    final claim = ref.watch(homeDailyClaimProvider);
    return HomePanel(
      key: const ValueKey('home_daily_panel'),
      title: 'Daily passport stamps',
      subtitle: 'Claim once a day and keep the streak alive.',
      child: daily.when(
        loading: () => const HomeInlineLoading(label: 'Loading daily stamps'),
        error: (_, __) => HomeErrorPanel(
          message: 'Daily stamps are unavailable.',
          retryKey: const ValueKey('home_daily_retry'),
          onRetry: () => ref.invalidate(homeDailyProvider),
        ),
        data: (data) {
          final latest = claim.latest;
          final state =
              latest != null && latest.date == data.date ? latest : data;
          final claimed = state.claimToday;
          final claimedDay = state.claimDay;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: grid.px(1),
                runSpacing: grid.px(1),
                children: [
                  PixelChip(
                    '${homeNumber(state.stamps)} stamps',
                    style: PixelBoxStyle.gold,
                  ),
                  PixelChip(
                    '${state.streak}-day streak',
                    style: PixelBoxStyle.slot,
                    textColor: PixelPalette.greenDark,
                  ),
                  if (state.bestStreak > 0)
                    PixelChip(
                      'Best ${state.bestStreak}',
                      style: PixelBoxStyle.slot,
                      textColor: PixelPalette.slate,
                    ),
                ],
              ),
              if (state.calendar.isNotEmpty) ...[
                SizedBox(height: grid.px(2)),
                Row(
                  children: [
                    for (var i = 0; i < state.calendar.length; i++) ...[
                      if (i > 0) SizedBox(width: grid.px(1)),
                      Expanded(
                        child: _StampDaySlot(
                          day: state.calendar[i],
                          today:
                              !claimed && state.calendar[i].day == claimedDay,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: const ValueKey('home_daily_claim'),
                label: claimed
                    ? 'Claimed today · Day $claimedDay'
                    : 'Claim +${state.nominalStamps} stamps',
                iconScale: 2,
                expand: true,
                loading: claim.claiming,
                onPressed: claimed || claim.claiming
                    ? null
                    : () =>
                        ref.read(homeDailyClaimProvider.notifier).claim(state),
              ),
              if (state.capped) ...[
                SizedBox(height: grid.px(1)),
                Text(
                  'Weekly cap reached. Today\'s claim was recorded without stamps.',
                  style: PixelType.small(context, color: PixelPalette.goldDeep),
                ),
              ],
              if (claim.error != null) ...[
                SizedBox(height: grid.px(1)),
                Text(
                  claim.error!,
                  style: PixelType.small(context, color: PixelPalette.redDeep),
                ),
              ],
              if (state.weekCap > 0) ...[
                SizedBox(height: grid.px(2)),
                PixelProgressBar(
                  value: state.weekCap == 0
                      ? 0
                      : (state.weekUsed / state.weekCap).clamp(0, 1),
                  segments: 10,
                  color: PixelPalette.sun,
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  'Weekly cap ${state.weekUsed} / ${state.weekCap}',
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
              ],
              SizedBox(height: grid.px(2)),
              Text(
                'Today\'s missions',
                style: PixelType.body(
                  context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: grid.px(1)),
              if (state.missions.isEmpty)
                const HomeEmptyText('No daily missions today.')
              else
                for (var i = 0; i < state.missions.length; i++) ...[
                  if (i > 0) SizedBox(height: grid.px(1)),
                  _DailyMissionRow(mission: state.missions[i]),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Plan 75k: the 7-day strip as RPG inventory slots. Unclaimed days are
/// recessed slots; a claimed day carries a green stamp seal; today's claimable
/// day pulses gold (2 fps, stepped); D7 is a rare gold slot with a sparkle.
class _StampDaySlot extends StatefulWidget {
  const _StampDaySlot({required this.day, required this.today});

  final HomeStampDay day;

  /// Today's day, still unclaimed.
  final bool today;

  @override
  State<_StampDaySlot> createState() => _StampDaySlotState();
}

class _StampDaySlotState extends State<_StampDaySlot> {
  Timer? _pulse;
  bool _bright = false;

  static const _seal = PixelArt('homeStampSeal', [
    '..999..',
    '.9aaa9.',
    '9aaa6a9',
    '9a6a6a9',
    '9aa6aa9',
    '.9aaa9.',
    '..999..',
  ]);

  static const _rare = PixelBoxStyle(
    fill: PixelPalette.goldDeep,
    highlight: PixelPalette.sun,
    shade: PixelPalette.woodDeep,
    outline: PixelPalette.sun,
    corner: 1,
    shadowPx: 0,
  );

  void _sync() {
    final run = widget.today && pixelMotion(context);
    if (run && _pulse == null) {
      _pulse = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() => _bright = !_bright);
      });
    } else if (!run && _pulse != null) {
      _pulse!.cancel();
      _pulse = null;
      _bright = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StampDaySlot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _pulse?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final day = widget.day;
    final rare = day.day == 7;
    final style = widget.today
        ? PixelBoxStyle.gold.copyWith(
            outline: _bright ? PixelPalette.white : PixelPalette.ink,
            corner: 1,
            shadowPx: 0,
          )
        : rare
            ? _rare
            : PixelBoxStyle.slot;
    final labelColor = widget.today
        ? PixelPalette.ink
        : rare
            ? PixelPalette.sunLight
            : PixelPalette.slate;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PixelPanel(
          style: style,
          padding: 1,
          sunken: !widget.today && !rare,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  'D${day.day}',
                  style: PixelType.small(context, color: labelColor),
                ),
                SizedBox(height: grid.px(1)),
                if (day.claimed)
                  const PixelSprite(_seal, scale: 3, semanticLabel: 'Claimed')
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '+${day.stamps}',
                      style: PixelType.small(
                        context,
                        color: widget.today || rare
                            ? labelColor
                            : PixelPalette.greenDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (rare && !day.claimed)
          Positioned(
            top: -grid.px(2),
            right: -grid.px(1),
            child: const PixelMicro(PixelMicroArt.sparkle, scale: 2),
          ),
      ],
    );
  }
}

class _DailyMissionRow extends StatelessWidget {
  const _DailyMissionRow({required this.mission});

  final HomeDailyMission mission;

  String? get _route => switch (mission.kind) {
        'cheer_post' => '/plaza',
        'read_story' => '/explore',
        'check_in' || 'quest_step' => '/quests',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final progress =
        mission.target <= 0 ? '' : '${mission.progress}/${mission.target}';
    final row = PixelPanel(
      style: mission.completed ? PixelBoxStyle.green : PixelBoxStyle.parchment,
      padding: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(
                      context,
                      color: mission.completed
                          ? PixelPalette.white
                          : PixelPalette.ink,
                    ),
                  ),
                  if (progress.isNotEmpty)
                    Text(
                      mission.completed ? 'Done · $progress' : progress,
                      style: PixelType.small(
                        context,
                        color: mission.completed
                            ? PixelPalette.cream
                            : PixelPalette.slate,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: grid.px(1)),
            PixelChip(
              '+${mission.stamps}',
              style:
                  mission.completed ? PixelBoxStyle.gold : PixelBoxStyle.slot,
              textColor:
                  mission.completed ? PixelPalette.ink : PixelPalette.greenDark,
            ),
          ],
        ),
      ),
    );
    final route = _route;
    if (route == null) return row;
    return Semantics(
      button: true,
      label: 'Daily mission: ${mission.title}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_daily_mission_${mission.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(route),
          child: row,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ wallet

class _WalletSection extends ConsumerWidget {
  const _WalletSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final user = ref.watch(authProvider).user;
    return HomePanel(
      key: const ValueKey('home_wallet_panel'),
      title: 'Wallet',
      child: Column(
        children: [
          HomeStatSlot(
            key: const ValueKey('home_wallet_mjdq'),
            label: 'mJDQ balance',
            // Same number as Profile and Shop (owner 2026-11-05: "150 is right");
            // mjdqBalance is a different, larger field.
            value: homeNumber(user?.points ?? 0),
            onTap: () => context.go('/profile'),
          ),
          SizedBox(height: grid.px(1)),
          HomeStatSlot(
            key: const ValueKey('home_wallet_jdq'),
            label: 'JDQ governance',
            value: homeNumber(user?.jdqGovernanceBalance ?? 0),
            onTap: () => context.go('/profile'),
          ),
          SizedBox(height: grid.px(1)),
          HomeStatSlot(
            key: const ValueKey('home_wallet_rep'),
            label: 'Scout reputation',
            value: homeNumber(user?.scoutReputation ?? 0),
            onTap: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ travel stats

class _TravelStatsSection extends ConsumerWidget {
  const _TravelStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final engagement = ref.watch(choiceEngagementProvider);
    return HomePanel(
      key: const ValueKey('home_travel_panel'),
      title: 'Travel stats',
      child: engagement.when(
        loading: () => const HomeInlineLoading(label: 'Loading travel stats'),
        error: (_, __) => HomeErrorPanel(
          message: 'Travel stats are unavailable.',
          retryKey: const ValueKey('home_progress_stats_retry'),
          onRetry: () => ref.invalidate(choiceEngagementProvider),
        ),
        data: (summary) => Column(
          children: [
            HomeStatSlot(
              key: const ValueKey('home_stat_streak'),
              label: 'Visit streak',
              value:
                  '${summary.currentStreak} ${summary.currentStreak == 1 ? 'day' : 'days'}',
              onTap: () => context.go('/profile'),
            ),
            SizedBox(height: grid.px(1)),
            HomeStatSlot(
              key: const ValueKey('home_stat_visits'),
              label: 'Verified visits',
              value: '${summary.verifiedVisits}',
              onTap: () => context.go('/profile'),
            ),
            SizedBox(height: grid.px(1)),
            HomeStatSlot(
              key: const ValueKey('home_stat_destinations'),
              label: 'Destinations',
              value: '${summary.uniqueDestinations}',
              onTap: () => context.go('/profile'),
            ),
            SizedBox(height: grid.px(1)),
            HomeStatSlot(
              key: const ValueKey('home_stat_municipalities'),
              label: 'Municipalities',
              value: '${summary.municipalities}',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ nearby

class _NearbySection extends ConsumerWidget {
  const _NearbySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final spots = ref.watch(spotDiscoveryProvider);
    final sorted = [...spots.spots]..sort((a, b) {
        final da = a.distanceKm ?? double.infinity;
        final db = b.distanceKm ?? double.infinity;
        return da.compareTo(db);
      });
    final shown = sorted.take(3).toList();
    return HomePanel(
      key: const ValueKey('home_radar_panel'),
      title: 'Nearby',
      subtitle: 'Destinations around you',
      actionLabel: 'Map',
      onAction: () => context.push('/map'),
      child: spots.isInitialLoading && spots.spots.isEmpty
          ? const HomeInlineLoading(label: 'Loading nearby places')
          : spots.failure != null && spots.spots.isEmpty
              ? HomeErrorPanel(
                  message: 'Nearby destinations are unavailable.',
                  retryKey: const ValueKey('home_radar_retry'),
                  onRetry: () => ref
                      .read(spotDiscoveryProvider.notifier)
                      .load(refresh: true),
                )
              : shown.isEmpty
                  ? const HomeEmptyText('No destinations nearby yet.')
                  : Column(
                      // Every card full width (a short name made one narrower).
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) SizedBox(height: grid.px(1)),
                          _NearbySpotRow(spot: shown[i]),
                        ],
                      ],
                    ),
    );
  }
}

class _NearbySpotRow extends StatelessWidget {
  const _NearbySpotRow({required this.spot});

  final SpotModel spot;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final distance = spot.distanceKm == null
        ? spot.municipality
        : '${spot.municipality} · ${spot.distanceKm!.toStringAsFixed(1)} km';
    return Semantics(
      button: true,
      label: 'Open ${spot.name}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_nearby_${spot.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/explore/${Uri.encodeComponent(spot.id)}'),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: grid.px(0.5)),
                  Text(
                    distance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------- proof & activity

class _ProofActivitySection extends ConsumerWidget {
  const _ProofActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final submissions = ref.watch(submissionProvider);
    int count(String status) => submissions.submissions
        .where((item) => item.status.toLowerCase() == status)
        .length;
    final recent = submissions.submissions.take(3).toList();
    return HomePanel(
      key: const ValueKey('home_proof_panel'),
      title: 'Proof & activity',
      subtitle: 'Your verified proofs and trails',
      actionLabel: 'History',
      onAction: () => context.push('/history'),
      child: submissions.isLoading && submissions.submissions.isEmpty
          ? const HomeInlineLoading(label: 'Loading submissions')
          : submissions.error != null && submissions.submissions.isEmpty
              ? HomeErrorPanel(
                  message: 'Proof submissions are unavailable.',
                  retryKey: const ValueKey('home_progress_proof_retry'),
                  onRetry: () => ref
                      .read(submissionProvider.notifier)
                      .fetchSubmissions(force: true),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeStatSlot(
                      key: const ValueKey('home_proof_pending'),
                      label: 'Pending proofs',
                      value: '${count('pending')}',
                      onTap: () => context.push('/history'),
                    ),
                    SizedBox(height: grid.px(1)),
                    HomeStatSlot(
                      key: const ValueKey('home_proof_approved'),
                      label: 'Approved proofs',
                      value: '${count('approved')}',
                      onTap: () => context.push('/history'),
                    ),
                    SizedBox(height: grid.px(1)),
                    HomeStatSlot(
                      key: const ValueKey('home_proof_rejected'),
                      label: 'Rejected proofs',
                      value: '${count('rejected')}',
                      onTap: () => context.push('/history'),
                    ),
                    SizedBox(height: grid.px(2)),
                    Text(
                      'Recent activity',
                      style: PixelType.body(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: grid.px(1)),
                    if (recent.isEmpty)
                      const HomeEmptyText('No recent submissions yet.')
                    else
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0) SizedBox(height: grid.px(1)),
                        _RecentSubmissionRow(submission: recent[i]),
                      ],
                  ],
                ),
    );
  }
}

class _RecentSubmissionRow extends StatelessWidget {
  const _RecentSubmissionRow({required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final status = submission.status.isEmpty
        ? 'Pending'
        : '${submission.status[0].toUpperCase()}${submission.status.substring(1)}';
    final style = switch (submission.status) {
      'approved' => PixelBoxStyle.green,
      'rejected' => PixelBoxStyle.red,
      _ => PixelBoxStyle.gold,
    };
    final textColor = switch (submission.status) {
      'approved' || 'rejected' => PixelPalette.white,
      _ => PixelPalette.ink,
    };
    return Semantics(
      button: true,
      label: '${submission.questTitle}, $status',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_recent_${submission.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/history'),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelChip(status, style: style, textColor: textColor),
                SizedBox(width: grid.px(1)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.questTitle,
                        style: PixelType.small(context),
                      ),
                      Text(
                        submission.createdAt.split('T').first,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------- community voting

class _CommunityVotingSection extends ConsumerWidget {
  const _CommunityVotingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final proposals = ref.watch(homeProposalsProvider);
    return HomePanel(
      key: const ValueKey('home_proposals_panel'),
      title: 'Community voting',
      subtitle: 'JuanChoice & municipal proposals',
      actionLabel: 'Open',
      onAction: () => context.push('/vote'),
      child: proposals.when(
        loading: () => const HomeInlineLoading(label: 'Loading proposals'),
        error: (_, __) => HomeErrorPanel(
          message: 'Community voting is unavailable.',
          retryKey: const ValueKey('home_proposals_retry'),
          onRetry: () => ref.invalidate(homeProposalsProvider),
        ),
        data: (items) {
          final active = items
              .where(
                (proposal) =>
                    proposal.status == 'voting' || proposal.status == 'active',
              )
              .toList();
          if (active.isEmpty) {
            return const HomeEmptyText('No open proposals right now.');
          }
          return Column(
            children: [
              for (var i = 0; i < active.take(2).length; i++) ...[
                if (i > 0) SizedBox(height: grid.px(1)),
                _ProposalRow(proposal: active[i]),
              ],
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: const ValueKey('home_vote_open'),
                label: 'Open community voting',
                expand: true,
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/vote'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({required this.proposal});

  final GovernanceProposalModel proposal;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      button: true,
      label: 'Open proposal ${proposal.title}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_proposal_${proposal.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/vote'),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: grid.px(0.5)),
                PixelText.rich(
                  '{green:Yes ${proposal.yesVotes}} · {red:No ${proposal.noVotes}} · {grey:${proposal.locationName}}',
                  maxLines: 2,
                  style: PixelType.small(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- affiliate

class _AffiliateInvite extends StatelessWidget {
  const _AffiliateInvite();

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const ValueKey('home_affiliate_panel'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Run a Pangasinan tourism establishment?',
            style: PixelType.body(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Get discovered by travelers along scenic coastal trails. Zero listing fees.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('home_affiliate'),
            label: 'Partner hub',
            expand: true,
            variant: PixelButtonVariant.secondary,
            onPressed: () => context.push('/affiliate'),
          ),
        ],
      ),
    );
  }
}
