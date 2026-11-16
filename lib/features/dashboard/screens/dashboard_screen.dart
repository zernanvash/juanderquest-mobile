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
import '../../cultural_quizzes/providers/cultural_quiz_provider.dart';
import '../../notifications/providers/local_notifications_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/providers/campaign_provider.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/providers/hidden_gem_provider.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/screens/interests_screen.dart';
import '../../submissions/providers/submission_provider.dart';
import '../home_tips.dart';
import '../providers/home_daily_provider.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/home_qotd_provider.dart';
import '../providers/home_recommended_quest_provider.dart';
import '../widgets/home_adventure_calendar.dart';
import '../widgets/main_menu_panel.dart';
import '../widgets/home_daily_tasks_panel.dart';
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
      ref.read(quizRadarProvider.notifier).refreshFromHome();
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
      ref.read(quizRadarProvider.notifier).refreshFromHome(force: true),
    ]);
    ref.invalidate(homeQotdProvider);
    ref.invalidate(homeNearbyQuizProvider);
    ref.invalidate(hiddenGemProvider);
    ref.invalidate(serverUnreadNotificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final tipsKeys = ref.watch(homeTipsKeysProvider);
    final questsState = ref.watch(questProvider);
    final submissionsState = ref.watch(submissionProvider);
    final dailyAsync = ref.watch(homeDailyProvider);
    final claimState = ref.watch(homeDailyClaimProvider);
    final qotd = ref.watch(homeQotdProvider).asData?.value;
    final gems = ref.watch(hiddenGemProvider).valueOrNull;

    final quests = withoutTestContent(
      questsState.quests,
      (quest) => quest.isTest,
      showTest: ref.watch(showTestContentProvider),
    );
    final inProgress = inProgressQuests(quests, submissionsState);
    final activeQuest = inProgress.isNotEmpty ? inProgress.first : null;
    final recommended =
        activeQuest == null ? ref.watch(homeRecommendedQuestProvider) : null;

    final daily = claimState.latest ?? dailyAsync.valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
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
                    title: 'Home',
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
                      // Owner 2026-11-16: the Map sits right of Search.
                      PixelIconButton(
                        key: const ValueKey('home_appbar_map'),
                        icon: DesignerArt.navMap,
                        semanticLabel: 'Map',
                        iconHeight: 36,
                        onPressed: () => context.go('/map'),
                      ),
                      Tooltip(
                        message: 'Notifications',
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            PixelIconButton(
                              icon: DesignerArt.notifBell,
                              semanticLabel: unread > 0
                                  ? 'Notifications, $unread unread'
                                  : 'Notifications',
                              iconHeight: 36,
                              onPressed: () => context.go('/notifications'),
                            ),
                            if (unread > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: IgnorePointer(
                                  child: PixelChip(
                                    unread > 9 ? '9+' : '$unread',
                                    key: const ValueKey('home_bell_count'),
                                    style: PixelBoxStyle.red,
                                    textColor: PixelPalette.white,
                                  ),
                                ),
                              ),
                          ],
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
                          // Plan 100 WP-5: nearby-quiz alerts moved to the
                          // bell (Notifications); the Map keeps its banner.
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

                          // BAND 2 (main menu) moved to the MENU button in
                          // the bottom bar (owner 2026-11-16).
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

                          // Plan 100 WP-4: today's tasks (they earn the stamps).
                          if (daily != null && daily.missions.isNotEmpty) ...[
                            HomeDailyTasksPanel(
                              missions: daily.missions,
                              onOpen: (m) => switch (m.kind) {
                                'qotd' => _showQotdSheet(context, ref, qotd),
                                'cheer_post' => context.push('/plaza'),
                                _ => context.push('/quests'),
                              },
                            ),
                            SizedBox(height: grid.px(3)),
                          ],

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
