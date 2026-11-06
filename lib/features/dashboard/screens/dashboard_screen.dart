import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/providers/hidden_gem_provider.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/screens/interests_screen.dart';
import '../../submissions/providers/submission_provider.dart';
import '../home_tips.dart';
import '../providers/home_daily_provider.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/home_qotd_provider.dart';
import '../widgets/home_collection_tab.dart';
import '../widgets/home_hero.dart';
import '../widgets/home_progress_tab.dart';
import '../widgets/home_quests_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _tipsRequested = false;
  int _tab = 0;

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
                          KeyedSubtree(
                            key: tipsKeys.hero,
                            child: UiSpecContainer(
                              spec: const UiSpec(
                                title: 'Traveler dashboard',
                                figmaLayer: 'Mobile / Dashboard / Home',
                                dimensions:
                                    'Responsive, vertically scrollable mobile dashboard',
                                dataBinding:
                                    'Authenticated profile, engagement, destinations, quests, submissions, daily rewards, Question of the Day, proposals, quizzes, events and hidden gems',
                                stateNotes:
                                    'API panels show loading, empty and unavailable states with retries; no synthetic activity or ranking data',
                                uxNotes:
                                    'Pixel lab layout B: compact hero, Progress / Quests / Collection wood tabs, tight bordered stat slots',
                              ),
                              child: HomeHero(user: user),
                            ),
                          ),
                          SizedBox(height: grid.px(3)),
                          _QuestLogTabs(
                            selected: _tab,
                            nextStopKey: tipsKeys.nextStop,
                            onSelect: (value) => setState(() => _tab = value),
                          ),
                          SizedBox(height: grid.px(3)),
                          const _NextStopPanel(),
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

class _QuestLogTabs extends StatelessWidget {
  const _QuestLogTabs({
    required this.selected,
    required this.nextStopKey,
    required this.onSelect,
  });

  final int selected;
  final GlobalKey nextStopKey;
  final ValueChanged<int> onSelect;

  static const _labels = ['Progress', 'Quests', 'Collection'];

  /// Plan 75k: the active tab is the panel's own tab: sun-lit top edge, no
  /// shadow, and it sits 1 art px into the panel so they read as one piece.
  static final _activeStyle = PixelBoxStyle.wood.copyWith(
    highlight: PixelPalette.sun,
    corner: 1,
    shadowPx: 0,
  );

  static final _idleStyle = PixelBoxStyle.wood.copyWith(
    fill: PixelPalette.woodDeep,
    highlight: PixelPalette.wood,
    shade: PixelPalette.woodNight,
  );

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final content = switch (selected) {
      0 => const HomeProgressTab(),
      1 => const HomeQuestsTab(),
      _ => const HomeCollectionTab(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0) SizedBox(width: grid.px(1)),
              Expanded(
                child: KeyedSubtree(
                  key: i == 1 ? nextStopKey : null,
                  child: _tab(context, grid, i),
                ),
              ),
            ],
          ],
        ),
        PixelPanel(style: PixelBoxStyle.parchment, child: content),
      ],
    );
  }

  Widget _tab(BuildContext context, PixelGrid grid, int index) {
    final active = index == selected;
    return Semantics(
      button: true,
      selected: active,
      label: _labels[index],
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_tab_${_labels[index].toLowerCase()}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(index),
          child: Transform.translate(
            offset: Offset(0, active ? grid.unit : 0),
            child: PixelPanel(
              style: active ? _activeStyle : _idleStyle,
              padding: active ? 2 : 1,
              pressed: !active,
              child: Center(
                child: Text(
                  _labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(
                    context,
                    color: active ? PixelPalette.sunLight : PixelPalette.paper,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextStopPanel extends StatelessWidget {
  const _NextStopPanel();

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const ValueKey('home_next_stop_panel'),
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pick your next stop',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Questing is the main way to earn XP. Explore and the map are in the bar below.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('home_next_stop_quests'),
            label: 'Quests',
            icon: DesignerArt.questMarker,
            expand: true,
            variant: PixelButtonVariant.secondary,
            onPressed: () => context.push('/quests'),
          ),
        ],
      ),
    );
  }
}
