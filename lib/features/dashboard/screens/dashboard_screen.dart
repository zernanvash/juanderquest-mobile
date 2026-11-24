import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_poppers.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../cultural_quizzes/providers/cultural_quiz_provider.dart';
import '../../notifications/providers/local_notifications_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/providers/campaign_provider.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/screens/interests_screen.dart';
import '../../submissions/providers/submission_provider.dart';
import '../home_tips.dart';
import '../pixel/home_pixel_art.dart';
import '../providers/home_daily_provider.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/home_qotd_provider.dart';
import '../providers/home_recommended_quest_provider.dart';
import '../widgets/main_menu_panel.dart';
import '../widgets/home_daily_tasks_panel.dart';
import '../widgets/home_qotd_panel.dart';
import '../widgets/home_around_panels.dart';
import '../widgets/home_dual_bento_row.dart';
import '../widgets/home_hero.dart';
import '../widgets/home_promo_panel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _tipsRequested = false;
  final _qotdKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(choiceEngagementProvider.future);
      ref.read(choiceOverviewProvider.future);
      ref.read(homeDailyProvider.future);
      ref.read(homeQotdProvider);
      ref.read(submissionProvider.notifier).fetchSubmissions();
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
      ref.read(questProvider.notifier).fetchQuests(),
      ref.read(campaignProvider.notifier).fetchCampaigns(forceRefresh: true),
      ref.read(quizRadarProvider.notifier).refreshFromHome(force: true),
      ref.read(appUpdateProvider.notifier).checkForUpdates(silent: true),
    ]);
    ref.invalidate(homeNearbySpotsProvider);
    ref.invalidate(companionBusySpotsProvider);
    ref.invalidate(homeQotdProvider);
    ref.invalidate(homeNearbyQuizProvider);
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

    // Party poppers (owner 2026-11-16): the stamp was just claimed, a daily
    // task was just finished, or the last one was.
    ref.listen(homeDailyClaimProvider, (prev, next) {
      if (next.latest?.claimToday == true && prev?.latest?.claimToday != true) {
        PixelPoppers.fire(context);
      }
    });
    ref.listen(homeDailyProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final after = next.valueOrNull;
      if (before == null || after == null || before.date != after.date) return;
      int done(HomeDailyState s) => s.missions.where((m) => m.completed).length;
      if (done(after) <= done(before)) return;
      PixelPoppers.fire(
        context,
        size: after.allComplete ? PixelPopperSize.big : PixelPopperSize.small,
      );
    });
    final unread = ref.watch(unreadNotificationCountProvider);

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
                // Owner 2026-11-17: subtle scatter on Home's panels (trial).
                child: PixelPanelTexture(
                  child: Column(
                    children: [
                      PixelAppBar(
                        title: 'JuanderQuest',
                        isTab: true,
                        // Owner 2026-11-16: the logo instead of "HOME".
                        // Owner 2026-11-17: the currencies sit in the top bar.
                        titleWidget: Image.asset(
                          'assets/images/logo.png',
                          key: const ValueKey('home_logo'),
                          height: 44,
                          filterQuality: FilterQuality.medium,
                        ),
                        actions: [
                          // The strip takes most of the bar and shrinks to fit.
                          // Expanded, not Flexible: a loose Flexible left its
                          // unused width after the bell, so the bell and the
                          // currencies sat off the right edge (owner
                          // 2026-11-17). The strip aligns itself right.
                          const Expanded(flex: 3, child: HomePurseStrip()),
                          Tooltip(
                            message: 'QR Scanner & My QR',
                            child: PixelIconButton(
                              key: const ValueKey('home_qr_button'),
                              icon: HomePixelArt.qrCode,
                              semanticLabel: 'QR Scanner and My QR',
                              iconHeight: 24,
                              boxed: false,
                              onPressed: () => context.push('/qr'),
                            ),
                          ),
                          // Owner 2026-11-16: only the bell on Home (Search is on
                          // Explore, the Map in the menu, Settings on Profile).
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
                                  // App-bar icons share one size (owner 2026-11-17).
                                  iconHeight: 24,
                                  // Owner 2026-11-17: no box behind the bell.
                                  boxed: false,
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
                        ],
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: PixelPalette.green,
                          backgroundColor: PixelPalette.parchment,
                          onRefresh: _refresh,
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              grid.gutter,
                              grid.px(3),
                              grid.gutter,
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
                              SizedBox(height: grid.px(5)),

                              const HomePromoPanel(),

                              // Plan 100 WP-4: today's tasks (they earn the stamps); owner
                              // 2026-11-16: right under the player card.
                              // Owner 2026-11-17: always on Home (it hid when
                              // today's list was empty).
                              HomeDailyTasksPanel(
                                missions: daily?.missions ?? const [],
                                daily: daily,
                                loading: daily == null && dailyAsync.isLoading,
                                onOpen: (m) => switch (m.kind) {
                                  'qotd' => Scrollable.ensureVisible(
                                      _qotdKey.currentContext!,
                                      duration:
                                          const Duration(milliseconds: 300),
                                    ),
                                  'cheer_post' => context.push('/plaza'),
                                  _ => context.push('/quests'),
                                },
                              ),
                              SizedBox(height: grid.px(5)),

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
                              ),
                              SizedBox(height: grid.px(5)),
                              // Owner 2026-11-17: the question is open on Home.
                              HomeQotdPanel(key: _qotdKey),
                              SizedBox(height: grid.px(5)),
                              // Owner 2026-11-17: places near you and the next
                              // Almanac event.
                              const HomeNearbyPanel(),
                              SizedBox(height: grid.px(5)),
                              const HomeNextEventPanel(),
                              SizedBox(height: grid.px(5)),

                              // The Almanac moved to the main menu (owner 2026-11-16).
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          );
        },
      ),
    );
  }
}
