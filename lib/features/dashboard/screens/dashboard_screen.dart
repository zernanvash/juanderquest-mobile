import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
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
import '../../quests/pixel/saved_quests.dart';
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
import '../providers/home_recommended_quest_provider.dart';
import '../widgets/home_adventure_calendar.dart';
import '../widgets/home_command_grid.dart';
import '../widgets/home_dual_bento_row.dart';
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
    final questsState = ref.watch(questProvider);
    final savedIds = ref.watch(savedQuestsProvider);
    final submissionsState = ref.watch(submissionProvider);
    final nearbyQuizzes = ref.watch(homeNearbyQuizProvider).valueOrNull;
    final choiceOverview = ref.watch(choiceOverviewProvider).asData?.value;
    final dailyAsync = ref.watch(homeDailyProvider);
    final claimState = ref.watch(homeDailyClaimProvider);
    final qotd = ref.watch(homeQotdProvider).asData?.value;
    final gems = ref.watch(hiddenGemProvider).valueOrNull;

    final quests = withoutTestContent(
      questsState.quests,
      (quest) => quest.isTest,
      showTest: ref.watch(showTestContentProvider),
    );
    final inProgress = _inProgressQuests(quests, submissionsState);
    final activeQuest = inProgress.isNotEmpty ? inProgress.first : null;
    final recommended =
        activeQuest == null ? ref.watch(homeRecommendedQuestProvider) : null;

    final currentChoice = choiceOverview?.current;
    final voteLive = currentChoice != null &&
        (currentChoice.status == 'voting' ||
            choiceOverview?.isCampaignOpen(currentChoice) == true);
    final daily = claimState.latest ?? dailyAsync.valueOrNull;
    final firstGem = (gems != null && gems.isNotEmpty) ? gems.first : null;

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
                        message: 'Search',
                        child: PixelIconButton(
                          key: const ValueKey('home_appbar_search'),
                          icon: DesignerArt.search,
                          semanticLabel: 'Search',
                          iconHeight: 36,
                          onPressed: () => context.push('/search'),
                        ),
                      ),
                      Tooltip(
                        message: 'Notifications',
                        child: PixelIconButton(
                          icon: DesignerArt.notifBell,
                          semanticLabel: 'Notifications',
                          iconHeight: 36,
                          onPressed: () => context.go('/notifications'),
                        ),
                      ),
                      Tooltip(
                        message: 'Settings',
                        child: PixelIconButton(
                          key: const ValueKey('home_appbar_settings'),
                          icon: DesignerArt.navSettings,
                          semanticLabel: 'Settings',
                          iconHeight: 36,
                          onPressed: () => context.push('/settings'),
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
                          // BAND 1: CONDENSED HERO, PURSE & NUMBERS
                          KeyedSubtree(
                            key: tipsKeys.hero,
                            child: UiSpecContainer(
                              spec: const UiSpec(
                                title: 'Traveler dashboard',
                                figmaLayer: 'Mobile / Dashboard / Home',
                                dimensions:
                                    'Responsive, single-page RPG status menu and command center',
                                dataBinding:
                                    'Authenticated profile, daily passport check-in, QOTD, active quest, command grid, and adventure calendar',
                                stateNotes:
                                    'Real-time stats from backend; zero synthetic rankings or unverified counts',
                                uxNotes:
                                    'Concept B: condensed hero, 4x2 icon-first command matrix, dual bento mission/stamp row, and week/month almanac',
                              ),
                              child: HomeHero(user: user),
                            ),
                          ),
                          SizedBox(height: grid.px(3)),

                          // BAND 2: TOP 4x2 COMMAND GRID
                          KeyedSubtree(
                            key: tipsKeys.nextStop,
                            child: HomeCommandGrid(
                              activeQuestsCount: inProgress.length,
                              savedCount: savedIds.length,
                              nearbyQuizCount: nearbyQuizzes?.items.length ?? 0,
                              voteLive: voteLive,
                              onOpenQuizzes: () =>
                                  _showQuizzesFiestasSheet(context, ref),
                            ),
                          ),
                          SizedBox(height: grid.px(3)),

                          // BAND 3: DUAL BENTO (MISSION + DAILY STAMP + QOTD/GEM)
                          HomeDualBentoRow(
                            activeQuest: activeQuest,
                            recommendedQuest: recommended?.quest,
                            recommendedReason: recommended?.reason,
                            dailyState: daily,
                            claimingDaily: claimState.claiming,
                            onClaimDaily: daily == null
                                ? null
                                : () => ref
                                    .read(homeDailyClaimProvider.notifier)
                                    .claim(daily),
                            qotdDone: qotd?.answered == true,
                            onTapQotd: () => _showQotdSheet(context, ref, qotd),
                            gemName: firstGem?.name,
                            gemSlug: firstGem?.id,
                          ),
                          SizedBox(height: grid.px(3)),

                          // BAND 4: PANGASINAN CHRONO-ALMANAC CALENDAR
                          const HomeAdventureCalendar(),
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

List<QuestModel> _inProgressQuests(
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
