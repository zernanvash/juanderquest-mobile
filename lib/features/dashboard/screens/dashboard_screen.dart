import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/campaign_provider.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/providers/hidden_gem_provider.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/screens/interests_screen.dart';
import '../../submissions/providers/submission_provider.dart';
import '../data/home_events.dart';
import '../home_tips.dart';
import '../providers/home_daily_provider.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/home_qotd_provider.dart';
import '../widgets/home_hero.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _tipsRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(choiceEngagementProvider.future);
      ref.read(choiceOverviewProvider.future);
      ref.read(homeDailyProvider.future);
      ref.read(homeQotdProvider);
      ref.read(submissionProvider.notifier).fetchSubmissions();
      ref.read(spotDiscoveryProvider.notifier).load();
      ref.read(questProvider.notifier).fetchQuests();
      ref.read(campaignProvider.notifier).fetchCampaigns();
      InterestsPrompt.maybeShow(context, ref);
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(choiceEngagementProvider.future),
      ref.refresh(choiceOverviewProvider.future),
      ref.refresh(homeDailyProvider.future),
      ref.read(submissionProvider.notifier).fetchSubmissions(force: true),
      ref.read(spotDiscoveryProvider.notifier).load(refresh: true),
      ref.read(questProvider.notifier).fetchQuests(),
      ref.read(campaignProvider.notifier).fetchCampaigns(forceRefresh: true),
    ]);
    ref.invalidate(homeQotdProvider);
    ref.invalidate(homeNearbyQuizProvider);
    ref.invalidate(hiddenGemProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final tipsKeys = ref.watch(homeTipsKeysProvider);

    if (!_tipsRequested && user != null) {
      _tipsRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(homeTipsControllerProvider.notifier).maybeStart();
      });
    }

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Your journey',
                    isTab: true,
                    actions: [
                      Tooltip(
                        message: 'Notifications',
                        child: PixelIconButton(
                          icon: DesignerArt.notifBell,
                          semanticLabel: 'Notifications',
                          iconHeight: 36,
                          onPressed: () => context.go('/notifications'),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: _refresh,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          grid.px(4),
                          grid.px(3),
                          grid.px(4),
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          // SECTION 1: TOP HERO, PURSE & NUMBERS
                          KeyedSubtree(
                            key: tipsKeys.hero,
                            child: UiSpecContainer(
                              spec: const UiSpec(
                                title: 'Traveler dashboard',
                                figmaLayer: 'Mobile / Dashboard / Home',
                                dimensions:
                                    'Responsive, single-page RPG status menu and command center',
                                dataBinding:
                                    'Authenticated profile, daily passport check-in, QOTD, active quest, and explorer launcher menu',
                                stateNotes:
                                    'Real-time stats from backend; zero synthetic rankings or unverified counts',
                                uxNotes:
                                    '1-screen RPG Menu Page: compact hero with 3-slot purse and numbers strip, Today\'s Pulse live preview, and 2×3 launcher grid',
                              ),
                              child: HomeHero(user: user),
                            ),
                          ),
                          SizedBox(height: grid.px(3)),

                          // SECTION 2: TODAY'S PULSE (LIVE PREVIEW)
                          const _TodaysPulsePanel(),
                          SizedBox(height: grid.px(3)),

                          // SECTION 3: EXPLORER MENU (2×3 LAUNCHER GRID)
                          _ExplorerMenuGrid(nextStopKey: tipsKeys.nextStop),

                          // SECTION 4: LIVE CAMPAIGNS (EVENTS ROW)
                          const _HomeEventsRow(),
                        ],
                      ),
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
}

// ============================================================================
// SECTION 2: TODAY'S PULSE (LIVE PREVIEW)
// ============================================================================

class _TodaysPulsePanel extends ConsumerWidget {
  const _TodaysPulsePanel();

  static List<QuestModel> _inProgressQuests(
    List<QuestModel> quests,
    SubmissionState submissions,
  ) {
    final completedTitles = submissions.submissions
        .where((item) => item.status == 'approved')
        .map((item) => item.questTitle)
        .toSet();
    return quests.where((quest) {
      if (completedTitles.contains(quest.title)) return false;
      if (quest.steps.isEmpty) return false;
      final anyVerified = quest.steps.any((step) => step.isVerified);
      final allVerified = quest.steps.every((step) => step.isVerified);
      return anyVerified && !allVerified;
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final dailyAsync = ref.watch(homeDailyProvider);
    final claimState = ref.watch(homeDailyClaimProvider);
    final qotdAsync = ref.watch(homeQotdProvider);
    final questsState = ref.watch(questProvider);
    final submissionsState = ref.watch(submissionProvider);

    final quests = withoutTestContent(
      questsState.quests,
      (quest) => quest.isTest,
      showTest: ref.watch(showTestContentProvider),
    );
    final inProgress = _inProgressQuests(quests, submissionsState);
    final activeQuest = inProgress.isNotEmpty ? inProgress.first : null;

    final daily = claimState.latest ?? dailyAsync.valueOrNull;
    final isClaimed = daily?.claimToday == true;
    final nominalStamps =
        daily != null && daily.nominalStamps > 0 ? daily.nominalStamps : 5;
    final streak = daily?.streak ?? 0;
    final dayNumber = daily?.claimDay ?? 1;
    final dailyHasError = dailyAsync.hasError && claimState.latest == null;
    final dailyIsEmpty = daily != null && daily.stamps == 0 && daily.missions.isEmpty;

    final String dailyTitle;
    final String dailySubtitle;
    final String dailyActionLabel;
    final Key dailyActionKey;
    final bool dailyIsPrimary;
    final VoidCallback dailyOnAction;

    if (dailyHasError) {
      dailyTitle = 'DAILY STAMP';
      dailySubtitle = 'Daily missions unavailable.';
      dailyActionLabel = 'RETRY';
      dailyActionKey = const ValueKey('home_daily_retry');
      dailyIsPrimary = false;
      dailyOnAction = () => ref.refresh(homeDailyProvider);
    } else if (dailyIsEmpty) {
      dailyTitle = 'DAILY STAMP';
      dailySubtitle = 'No daily missions today.';
      dailyActionLabel = 'DETAILS ›';
      dailyActionKey = const ValueKey('home_daily_details');
      dailyIsPrimary = false;
      dailyOnAction = () => _showStampCalendarSheet(context, daily);
    } else if (isClaimed) {
      dailyTitle = 'STAMP CLAIMED · DAY $dayNumber';
      dailySubtitle = '$streak-day streak alive · Great job!';
      dailyActionLabel = 'CALENDAR ›';
      dailyActionKey = const ValueKey('home_daily_details');
      dailyIsPrimary = false;
      dailyOnAction = () => _showStampCalendarSheet(context, daily!);
    } else {
      dailyTitle = 'DAILY STAMP: +$nominalStamps READY';
      dailySubtitle = 'Keep your $streak-day streak active today';
      dailyActionLabel = 'CLAIM TODAY ›';
      dailyActionKey = const ValueKey('home_daily_claim');
      dailyIsPrimary = true;
      dailyOnAction = () {
        if (daily != null) {
          ref.read(homeDailyClaimProvider.notifier).claim(daily);
        }
      };
    }

    final qotd = qotdAsync.asData?.value;
    final qotdAnswered = qotd?.answered == true;
    final qotdCorrect = qotd?.correct == true;
    final qotdHasError = qotdAsync.hasError;
    final qotdIsEmpty = qotd != null && (qotd.questionText.isEmpty || qotd.options.isEmpty);

    final String qotdTitle;
    final String qotdSubtitle;
    final String qotdActionLabel;
    final Key qotdActionKey;
    final bool qotdIsPrimary;
    final VoidCallback qotdOnAction;

    if (qotdHasError) {
      qotdTitle = 'QUESTION OF THE DAY';
      qotdSubtitle = 'Question of the Day is unavailable.';
      qotdActionLabel = 'RETRY';
      qotdActionKey = const ValueKey('home_qotd_retry');
      qotdIsPrimary = false;
      qotdOnAction = () => ref.invalidate(homeQotdProvider);
    } else if (qotdIsEmpty) {
      qotdTitle = 'QUESTION OF THE DAY';
      qotdSubtitle = 'No question today.';
      qotdActionLabel = 'WAIT';
      qotdActionKey = const ValueKey('home_qotd_wait');
      qotdIsPrimary = false;
      qotdOnAction = () {};
    } else if (qotdAnswered) {
      qotdTitle = 'QOTD ANSWERED (+5 STAMPS)';
      qotdSubtitle = qotdCorrect
          ? '✓ Correct answer recorded'
          : 'Answer recorded';
      qotdActionLabel = 'REVIEW ›';
      qotdActionKey = const ValueKey('home_qotd_review');
      qotdIsPrimary = false;
      qotdOnAction = () => _showQotdSheet(context, ref, qotd);
    } else {
      qotdTitle = 'QUESTION OF THE DAY';
      qotdSubtitle = 'Unanswered · Earn +5 passport stamps';
      qotdActionLabel = 'ANSWER ›';
      qotdActionKey = const ValueKey('home_qotd_answer');
      qotdIsPrimary = true;
      qotdOnAction = () => _showQotdSheet(context, ref, qotd);
    }

    return PixelPanel(
      key: const ValueKey('home_todays_pulse'),
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TODAY\'S PULSE',
                  style: PixelType.title(context, color: PixelPalette.paper),
                ),
              ),
              SizedBox(width: grid.px(1)),
              const PixelMicro(PixelMicroArt.sparkle, scale: 2),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Daily stamp, questions and active missions',
            style: PixelType.small(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),

          // 1. Daily Stamp Row
          _pulseCard(
            context,
            grid,
            key: const ValueKey('pulse_row_daily_stamp'),
            iconWidget: isClaimed
                ? const PixelMicro(PixelMicroArt.sparkle, scale: 2)
                : const PixelMicro(PixelMicroArt.coin, scale: 2),
            title: dailyTitle,
            subtitle: dailySubtitle,
            actionLabel: dailyActionLabel,
            actionKey: dailyActionKey,
            isPrimary: dailyIsPrimary,
            loading: claimState.claiming,
            onAction: dailyOnAction,
          ),
          SizedBox(height: grid.px(1)),

          // 2. Question of the Day Row
          _pulseCard(
            context,
            grid,
            key: const ValueKey('pulse_row_qotd'),
            iconWidget: const PixelMicro(PixelMicroArt.sparkle, scale: 2),
            title: qotdTitle,
            subtitle: qotdSubtitle,
            actionLabel: qotdActionLabel,
            actionKey: qotdActionKey,
            isPrimary: qotdIsPrimary,
            onAction: qotdOnAction,
          ),
          SizedBox(height: grid.px(1)),

          // 3. Active Quest Row
          _pulseCard(
            context,
            grid,
            key: const ValueKey('pulse_row_active_quest'),
            iconWidget: const PixelSprite(DesignerArt.questMarker, scale: 2),
            title: activeQuest != null
                ? 'ACTIVE: ${activeQuest.title}'
                : 'NEXT MISSION: ${daily?.nextMission?.title ?? 'Explore Pangasinan'}',
            subtitle: activeQuest != null
                ? 'Step ${activeQuest.steps.where((s) => s.isVerified).length} of ${activeQuest.steps.length} verified'
                : 'Pick a quest to start earning XP & rewards',
            actionLabel: activeQuest != null ? 'CONTINUE ›' : 'QUEST LOG ›',
            actionKey: activeQuest != null
                ? const ValueKey('home_active_quest_continue')
                : const ValueKey('home_active_quest_explore'),
            isPrimary: false,
            onAction: () {
              if (activeQuest != null) {
                context.push('/quests/${activeQuest.id}');
              } else {
                context.push('/quests');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _pulseCard(
    BuildContext context,
    PixelGrid grid, {
    required Key key,
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required String actionLabel,
    required Key actionKey,
    required bool isPrimary,
    required VoidCallback onAction,
    bool loading = false,
  }) {
    return PixelPanel(
      key: key,
      style: PixelBoxStyle.parchment,
      padding: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: grid.px(1)),
              child: iconWidget,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(
                      context,
                      color: PixelPalette.ink,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(
                      context,
                      color: PixelPalette.slate,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: grid.px(1)),
            Flexible(
              child: PixelButton(
                key: actionKey,
                label: actionLabel,
                variant: isPrimary
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                loading: loading,
                onPressed: onAction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStampCalendarSheet(BuildContext context, HomeDailyState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final grid = PixelGrid.of(ctx);
        return SafeArea(
          child: Container(
            margin: EdgeInsets.all(grid.px(2)),
            child: PixelPanel(
              style: PixelBoxStyle.wood,
              padding: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '7-DAY PASSPORT STAMPS',
                        style: PixelType.title(ctx, color: PixelPalette.paper),
                      ),
                      const Spacer(),
                      PixelIconButton(
                        icon: DesignerArt.heartUnliked,
                        semanticLabel: 'Close',
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: grid.px(2)),
                  Text(
                    'Claim every day to build your streak and earn rewards.',
                    style: PixelType.small(ctx, color: PixelPalette.cream),
                  ),
                  SizedBox(height: grid.px(2)),
                  Row(
                    children: [
                      for (var i = 0; i < state.calendar.length; i++) ...[
                        if (i > 0) SizedBox(width: grid.px(1)),
                        Expanded(
                          child: PixelPanel(
                            style: state.calendar[i].claimed
                                ? PixelBoxStyle.green
                                : state.calendar[i].day == state.claimDay
                                    ? PixelBoxStyle.gold
                                    : PixelBoxStyle.slot,
                            padding: 1,
                            child: Column(
                              children: [
                                Text(
                                  'D${state.calendar[i].day}',
                                  style: PixelType.small(
                                    ctx,
                                    color: state.calendar[i].claimed
                                        ? PixelPalette.white
                                        : PixelPalette.ink,
                                  ),
                                ),
                                SizedBox(height: grid.px(1)),
                                Text(
                                  '+${state.calendar[i].stamps}',
                                  style: PixelType.small(
                                    ctx,
                                    color: state.calendar[i].claimed
                                        ? PixelPalette.cream
                                        : PixelPalette.greenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: grid.px(3)),
                  PixelButton(
                    label: 'DONE',
                    expand: true,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQotdSheet(
    BuildContext context,
    WidgetRef ref,
    HomeQotdState? initialQotd,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final liveQotd =
                ref.watch(homeQotdProvider).asData?.value ?? initialQotd;
            final grid = PixelGrid.of(ctx);
            if (liveQotd == null) {
              return Container(
                margin: EdgeInsets.all(grid.px(2)),
                child: const PixelPanel(
                  key: ValueKey('home_qotd_panel'),
                  style: PixelBoxStyle.wood,
                  padding: 2,
                  child: Text('Loading Question of the Day...'),
                ),
              );
            }
            return SafeArea(
              child: Container(
                margin: EdgeInsets.all(grid.px(2)),
                child: PixelPanel(
                  key: const ValueKey('home_qotd_panel'),
                  style: PixelBoxStyle.wood,
                  padding: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'QUESTION OF THE DAY',
                              style: PixelType.title(
                                ctx,
                                color: PixelPalette.paper,
                              ),
                            ),
                          ),
                          PixelIconButton(
                            icon: DesignerArt.heartUnliked,
                            semanticLabel: 'Close',
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        liveQotd.quizTitle.isNotEmpty
                            ? liveQotd.quizTitle
                            : 'Daily Pangasinan Lore',
                        style: PixelType.small(ctx, color: PixelPalette.cream),
                      ),
                      SizedBox(height: grid.px(2)),
                      Text(
                        liveQotd.questionText.isNotEmpty
                            ? liveQotd.questionText
                            : 'Loading question...',
                        style: PixelType.body(
                          ctx,
                          color: PixelPalette.paper,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: grid.px(2)),
                      for (final option in liveQotd.options) ...[
                        SizedBox(height: grid.px(1)),
                        PixelTappableSlot(
                          key: ValueKey('home_qotd_option_${option.id}'),
                          style: liveQotd.selectedOptionId == option.id
                              ? (liveQotd.correct
                                  ? PixelBoxStyle.green
                                  : PixelBoxStyle.red)
                              : PixelBoxStyle.parchment,
                          padding: 2,
                          onTap: liveQotd.answered
                              ? null
                              : () => ref
                                  .read(homeQotdProvider.notifier)
                                  .answer(option.id),
                          child: Text(
                            option.text,
                            style: PixelType.body(ctx, color: PixelPalette.ink),
                          ),
                        ),
                      ],
                      if (liveQotd.explanation != null) ...[
                        SizedBox(height: grid.px(2)),
                        Text(
                          liveQotd.explanation!,
                          style: PixelType.small(ctx, color: PixelPalette.cream),
                        ),
                      ],
                      SizedBox(height: grid.px(3)),
                      PixelButton(
                        label: 'CLOSE',
                        expand: true,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// SECTION 3: EXPLORER MENU (2×3 LAUNCHER GRID)
// ============================================================================

class _ExplorerMenuGrid extends ConsumerWidget {
  const _ExplorerMenuGrid({required this.nextStopKey});

  final GlobalKey nextStopKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final questsState = ref.watch(questProvider);
    final submissionsState = ref.watch(submissionProvider);
    final user = ref.watch(authProvider).user;
    final nearbyQuizzes = ref.watch(homeNearbyQuizProvider).valueOrNull;

    final quests = withoutTestContent(
      questsState.quests,
      (quest) => quest.isTest,
      showTest: ref.watch(showTestContentProvider),
    );
    final inProgress = quests.where((quest) {
      if (quest.steps.isEmpty) return false;
      return quest.steps.any((s) => s.isVerified) &&
          !quest.steps.every((s) => s.isVerified);
    }).toList();

    final pendingCount = submissionsState.submissions
        .where((s) => s.status == 'pending')
        .length;
    final approvedCount = submissionsState.submissions
        .where((s) => s.status == 'approved')
        .length;

    final quizCount = nearbyQuizzes?.items.length ?? 0;
    final walletAddress = user?.walletAddress;
    final walletPreview = walletAddress != null && walletAddress.length >= 10
        ? 'Verified ${walletAddress.substring(0, 6)}…'
        : 'Off-Chain · Link ›';

    final choiceAsync = ref.watch(choiceOverviewProvider);
    final String choiceSubtitle;
    final VoidCallback choiceOnTap;

    if (choiceAsync.hasError) {
      choiceSubtitle = 'JuanChoice is unavailable.';
      choiceOnTap = () => ref.refresh(choiceOverviewProvider);
    } else {
      final overview = choiceAsync.asData?.value;
      final current = overview?.current;
      final open = current != null &&
          (current.status == 'voting' ||
              overview?.isCampaignOpen(current) == true);
      if (open) {
        choiceSubtitle = 'Voting now: ${current.theme}';
        choiceOnTap = () => context.push('/choice/${current.id}');
      } else if (overview?.previous != null) {
        choiceSubtitle = 'Last results: ${overview!.previous!.periodLabel}';
        choiceOnTap = () => context.push('/choice');
      } else {
        choiceSubtitle = 'Weekly Vote · Vote ›';
        choiceOnTap = () => context.push('/choice');
      }
    }

    return PixelPanel(
      key: const ValueKey('home_explorer_menu'),
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'EXPLORER MENU',
                style: PixelType.title(context, color: PixelPalette.paper),
              ),
              const Spacer(),
              const PixelMicro(PixelMicroArt.sparkle, scale: 2),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Launch into Pangasinan adventures & records',
            style: PixelType.small(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),

          // Row 1: QUEST LOG & JUANCHOICE
          Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: nextStopKey,
                  child: _MenuTile(
                    tileKey: const ValueKey('home_menu_quests'),
                    icon: const PixelSprite(DesignerArt.questMarker, scale: 2),
                    title: 'QUEST LOG',
                    subtitle:
                        '${quests.length} Quests · ${inProgress.length} Active',
                    onTap: () => context.push('/quests'),
                  ),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: _MenuTile(
                  tileKey: const ValueKey('home_menu_choice'),
                  icon: const PixelSprite(DesignerArt.juanChoice, scale: 2),
                  title: 'JUANCHOICE',
                  subtitle: choiceSubtitle,
                  onTap: choiceOnTap,
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),

          // Row 2: PLAZA & RANKS & QUIZZES & FIESTAS
          Row(
            children: [
              Expanded(
                child: _MenuTile(
                  tileKey: const ValueKey('home_menu_plaza'),
                  icon: const PixelMicro(PixelMicroArt.sparkle, scale: 2),
                  title: 'PLAZA & RANKS',
                  subtitle: 'Leaderboard & Feed',
                  onTap: () => context.push('/plaza'),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: _MenuTile(
                  tileKey: const ValueKey('home_menu_quizzes_fiestas'),
                  icon: const PixelMicro(PixelMicroArt.sparkle, scale: 2),
                  title: 'QUIZZES & FIESTA',
                  subtitle: '$quizCount Quizzes · Events',
                  onTap: () => _showQuizzesFiestasSheet(context, ref),
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),

          // Row 3: MY SUBMISSIONS & WEB3 WALLET
          Row(
            children: [
              Expanded(
                child: _MenuTile(
                  tileKey: const ValueKey('home_menu_history'),
                  icon: const PixelSprite(DesignerArt.heartLikedV3, scale: 2),
                  title: 'SUBMISSIONS',
                  subtitle: '$pendingCount Pending · $approvedCount Done',
                  onTap: () => context.push('/history'),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: _MenuTile(
                  tileKey: const ValueKey('home_menu_wallet'),
                  icon: const PixelMicro(PixelMicroArt.coin, scale: 2),
                  title: 'WEB3 WALLET',
                  subtitle: walletPreview,
                  chipLabel: 'Testnet',
                  onTap: () => context.push('/wallet/connect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQuizzesFiestasSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final grid = PixelGrid.of(ctx);
        final quizzesAsync = ref.watch(homeNearbyQuizProvider);
        final events = ref.watch(homeEventsProvider);

        return SafeArea(
          child: Container(
            margin: EdgeInsets.all(grid.px(2)),
            child: PixelPanel(
              style: PixelBoxStyle.wood,
              padding: 2,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'QUIZZES & FIESTAS',
                            style: PixelType.title(
                              ctx,
                              color: PixelPalette.paper,
                            ),
                          ),
                        ),
                        PixelIconButton(
                          icon: DesignerArt.heartUnliked,
                          semanticLabel: 'Close',
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: grid.px(2)),
                    Text(
                      'Cultural Quizzes',
                      style: PixelType.body(ctx, color: PixelPalette.sunLight)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: grid.px(1)),
                    quizzesAsync.when(
                      loading: () => const Text('Looking for nearby quizzes...'),
                      error: (_, __) =>
                          const Text('Quizzes currently unavailable.'),
                      data: (quizzes) => quizzes.items.isEmpty
                          ? Text(
                              'No quizzes ${quizzes.originLabel.toLowerCase()} right now.',
                              style: PixelType.small(ctx,
                                  color: PixelPalette.cream),
                            )
                          : Column(
                              children: [
                                for (final quiz in quizzes.items) ...[
                                  SizedBox(height: grid.px(1)),
                                  PixelTappableSlot(
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      context.push(
                                          '/cultural-quizzes/${quiz.quizId}');
                                    },
                                    child: Text(
                                      quiz.title,
                                      style: PixelType.small(ctx,
                                          color: PixelPalette.ink),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    SizedBox(height: grid.px(3)),
                    Text(
                      'Upcoming Festivals',
                      style: PixelType.body(ctx, color: PixelPalette.sunLight)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: grid.px(1)),
                    for (final event in events.take(3)) ...[
                      SizedBox(height: grid.px(1)),
                      PixelPanel(
                        style: PixelBoxStyle.parchment,
                        padding: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style:
                                  PixelType.small(ctx, color: PixelPalette.ink)
                                      .copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              event.municipality,
                              style: PixelType.small(ctx,
                                  color: PixelPalette.slate),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: grid.px(3)),
                    PixelButton(
                      label: 'DONE',
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.chipLabel,
  });

  final Key tileKey;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? chipLabel;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelTappableSlot(
      key: tileKey,
      style: PixelBoxStyle.parchment,
      padding: 2,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                icon,
                const Spacer(),
                if (chipLabel != null)
                  Flexible(
                    child: PixelChip(
                      chipLabel!,
                      style: PixelBoxStyle.parchment,
                      textColor: PixelPalette.woodMid,
                    ),
                  )
                else
                  const PixelMicro(PixelMicroArt.sparkle, scale: 1),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(
                context,
                color: PixelPalette.ink,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(
                context,
                color: PixelPalette.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEventsRow extends ConsumerWidget {
  const _HomeEventsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignProvider).campaigns;
    if (campaigns.isEmpty) {
      return const SizedBox.shrink();
    }
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: grid.px(3)),
        Text(
          'EVENTS',
          style: PixelType.title(context, color: PixelPalette.woodDeep),
        ),
        SizedBox(height: grid.px(1.5)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < campaigns.length; i++) ...[
                if (i > 0) SizedBox(width: grid.px(2)),
                GestureDetector(
                  key: ValueKey('home_event_${campaigns[i].id}'),
                  onTap: () => context.push(
                    '/quests/campaigns/${campaigns[i].id}',
                    extra: campaigns[i],
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 210,
                    child: PixelPanel(
                      style: PixelBoxStyle.parchment,
                      padding: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            campaigns[i].municipality.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.greenDeep,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            campaigns[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.body(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
