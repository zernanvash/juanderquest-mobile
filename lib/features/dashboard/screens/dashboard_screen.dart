import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/models/juanchoice_models.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/screens/interests_screen.dart';
import '../../spots/widgets/hidden_gem_card.dart';
import '../../submissions/models/submission_model.dart';
import '../../submissions/providers/submission_provider.dart';
import '../home_tips.dart';

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
      ref.read(submissionProvider.notifier).fetchSubmissions(force: true),
      ref.read(spotDiscoveryProvider.notifier).load(refresh: true),
      ref.read(questProvider.notifier).fetchQuests(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final engagement = ref.watch(choiceEngagementProvider);
    final overview = ref.watch(choiceOverviewProvider);
    final spots = ref.watch(spotDiscoveryProvider);
    final quests = ref.watch(questProvider);
    final submissions = ref.watch(submissionProvider);
    final tipsKeys = ref.watch(homeTipsKeysProvider);
    final firstName =
        (user?.displayName.trim().split(RegExp(r'\s+')).first ?? 'Traveler');
    final level = ((user?.points ?? 0) ~/ 50) + 1;
    final levelProgress = ((user?.points ?? 0) % 50) / 50;

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
                    actions: [
                      Tooltip(
                        message: 'Search destinations',
                        child: PixelIconButton(
                          icon: DesignerArt.search,
                          semanticLabel: 'Search destinations',
                          iconHeight: 36,
                          onPressed: () => context.go('/explore'),
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
                                    'Authenticated profile, engagement, destinations, quests, submissions, and JuanChoice APIs',
                                stateNotes:
                                    'API failures are shown as unavailable; no synthetic activity or ranking data',
                                uxNotes:
                                    'One-tap shortcuts keep Explore, map, quests, and JuanChoice close at hand',
                              ),
                              child: _HeroCard(
                                firstName: firstName,
                                points: user?.points ?? 0,
                                level: level,
                                progress: levelProgress,
                              ),
                            ),
                          ),
                          SizedBox(height: grid.px(4)),
                          _ImpactSection(
                            engagement: engagement,
                            onProfile: () => context.go('/profile'),
                            onRetry: () =>
                                ref.invalidate(choiceEngagementProvider),
                          ),
                          SizedBox(height: grid.px(4)),
                          KeyedSubtree(
                            key: tipsKeys.nextStop,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SectionHeader(
                                  title: 'Pick your next stop',
                                  action: 'Explore all',
                                  onTap: () => context.go('/explore'),
                                ),
                                SizedBox(height: grid.px(2)),
                                _QuickActions(
                                  onExplore: () => context.go('/explore'),
                                  onMap: () => context.go('/map'),
                                  onQuests: () => context.go('/quests'),
                                ),
                                SizedBox(height: grid.px(2)),
                                if (spots.isInitialLoading &&
                                    spots.spots.isEmpty)
                                  const _PixelLoadingPanel()
                                else if (spots.failure != null &&
                                    spots.spots.isEmpty)
                                  _PixelUnavailablePanel(
                                    message:
                                        'Destinations could not be loaded.',
                                    onRetry: () => ref
                                        .read(spotDiscoveryProvider.notifier)
                                        .load(refresh: true),
                                  )
                                else if (spots.spots.isNotEmpty)
                                  _FeaturedSpot(
                                    spot: _recommendedSpot(spots.spots),
                                    onTap: () => context.push(
                                      '/explore/${Uri.encodeComponent(_recommendedSpot(spots.spots).id)}',
                                    ),
                                  )
                                else
                                  const _PixelEmptyPanel(
                                    message:
                                        'No destinations are available yet. Try again later.',
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: grid.px(4)),
                          const HiddenGemCard(),
                          SizedBox(height: grid.px(4)),
                          _SectionHeader(
                            title: 'JuanChoice',
                            action: 'Open',
                            onTap: () => context.go('/choice'),
                          ),
                          SizedBox(height: grid.px(2)),
                          overview.when(
                            loading: () => const _PixelLoadingPanel(),
                            error: (_, __) => _PixelUnavailablePanel(
                              message: 'JuanChoice status is unavailable.',
                              onRetry: () =>
                                  ref.invalidate(choiceOverviewProvider),
                            ),
                            data: (data) => _JuanChoiceCard(
                              overview: data,
                              onTap: () => context.go('/choice'),
                            ),
                          ),
                          SizedBox(height: grid.px(4)),
                          _SectionHeader(
                            title: 'Your quests',
                            action: 'See all',
                            onTap: () => context.go('/quests'),
                          ),
                          SizedBox(height: grid.px(2)),
                          if (quests.isLoading)
                            const _PixelLoadingPanel()
                          else if (quests.error != null)
                            _PixelUnavailablePanel(
                              message: 'Quest list is unavailable.',
                              onRetry: () => ref
                                  .read(questProvider.notifier)
                                  .fetchQuests(),
                            )
                          else
                            _QuestsSection(quests: quests.quests),
                          SizedBox(height: grid.px(4)),
                          _SectionHeader(
                            title: 'Recent activity',
                            action: 'History',
                            onTap: () => context.push('/history'),
                          ),
                          SizedBox(height: grid.px(2)),
                          if (submissions.isLoading &&
                              submissions.submissions.isEmpty)
                            const _PixelLoadingPanel()
                          else if (submissions.error != null &&
                              submissions.submissions.isEmpty)
                            _PixelUnavailablePanel(
                              message: 'Recent activity is unavailable.',
                              onRetry: () => ref
                                  .read(submissionProvider.notifier)
                                  .fetchSubmissions(force: true),
                            )
                          else if (submissions.submissions.isEmpty)
                            const _PixelEmptyPanel(
                              message:
                                  'Your quest submissions will appear here.',
                            )
                          else
                            ...submissions.submissions
                                .take(3)
                                .map((item) => _ActivityRow(submission: item)),
                          SizedBox(height: grid.px(4)),
                          _PixelInfoRow(
                            key: const ValueKey('dashboard_cultural_quizzes'),
                            icon: DesignerArt.search,
                            title: 'Cultural quizzes',
                            subtitle:
                                'Discover quizzes near participating heritage and cultural destinations.',
                            action: 'Explore',
                            onTap: () => context.go('/explore'),
                          ),
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

  SpotModel _recommendedSpot(List<SpotModel> items) {
    return items.firstWhere(
      (spot) => spot.reasons.isNotEmpty,
      orElse: () => items.first,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.firstName,
    required this.points,
    required this.level,
    required this.progress,
  });

  final String firstName;
  final int points, level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final juanScale = (44 * dpr / DesignerArt.juanIdle.frames.first.height)
        .round()
        .clamp(1, 8)
        .toInt();
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelPanel(
            style: PixelBoxStyle.slot,
            sunken: true,
            padding: 2,
            child: PixelAnimation(DesignerArt.juanIdle, scale: juanScale),
          ),
          SizedBox(width: grid.px(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShadowText(
                  'Welcome back, $firstName',
                  style: PixelType.body(context, color: PixelPalette.paper)
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  'Level $level · $points Explorer XP',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.sun),
                ),
                SizedBox(height: grid.px(2)),
                PixelProgressBar(
                  value: progress,
                  segments: 10,
                  color: PixelPalette.greenBright,
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  '${(progress * 50).round()} / 50 XP to next level',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(
                    context,
                    color: PixelPalette.paperDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactSection extends StatelessWidget {
  const _ImpactSection({
    required this.engagement,
    required this.onProfile,
    required this.onRetry,
  });

  final AsyncValue<ChoiceEngagementSummary> engagement;
  final VoidCallback onProfile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Your impact',
          action: 'View profile',
          onTap: onProfile,
        ),
        SizedBox(height: grid.px(2)),
        engagement.when(
          loading: () => const _PixelLoadingPanel(),
          error: (_, __) => _PixelUnavailablePanel(
            message: 'Your travel stats are temporarily unavailable.',
            onRetry: onRetry,
          ),
          data: (summary) => _ImpactTiles(summary: summary),
        ),
      ],
    );
  }
}

class _ImpactTiles extends StatelessWidget {
  const _ImpactTiles({required this.summary});

  final ChoiceEngagementSummary summary;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final stats = <(String, String)>[
      ('Visit streak', '${summary.currentStreak} days'),
      ('Verified visits', '${summary.verifiedVisits}'),
      ('Destinations', '${summary.uniqueDestinations}'),
      ('Municipalities', '${summary.municipalities}'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = grid.px(2);
        final width =
            ((constraints.maxWidth - gap * 2) / 3).clamp(1.0, 400.0).toDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: PixelPanel(
                  style: PixelBoxStyle.slot,
                  sunken: true,
                  padding: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: grid.px(18),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            stat.$2,
                            style: PixelType.title(context),
                          ),
                        ),
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        stat.$1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onExplore,
    required this.onMap,
    required this.onQuests,
  });

  final VoidCallback onExplore, onMap, onQuests;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PixelButton(
              key: const ValueKey('dashboard_quick_explore'),
              label: 'Explore',
              icon: DesignerArt.navExplore,
              iconScale: 2,
              expand: true,
              onPressed: onExplore,
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: PixelButton(
              key: const ValueKey('dashboard_quick_map'),
              label: 'Map',
              icon: DesignerArt.navExplore,
              iconScale: 2,
              expand: true,
              style: PixelBoxStyle.wood,
              textColor: PixelPalette.white,
              onPressed: onMap,
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: PixelButton(
              key: const ValueKey('dashboard_quick_quests'),
              label: 'Quests',
              icon: DesignerArt.questMarker,
              iconScale: 2,
              expand: true,
              style: PixelBoxStyle.wood,
              textColor: PixelPalette.white,
              onPressed: onQuests,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: grid.px(2),
      runSpacing: grid.px(1),
      children: [
        Text(
          title,
          style: PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
        ),
        Semantics(
          button: true,
          label: action,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    '$action >',
                    style: PixelType.small(
                      context,
                      color: PixelPalette.blueBright,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedSpot extends ConsumerWidget {
  const _FeaturedSpot({required this.spot, required this.onTap});

  final SpotModel spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final iconScale =
        (24 * dpr / DesignerArt.heartLiked.height).round().clamp(1, 8).toInt();
    final crowd = switch (spot.crowdStatus) {
      'quiet' => ('Quiet', PixelBoxStyle.green, PixelPalette.white),
      'busy' || 'crowded' => ('Busy', PixelBoxStyle.red, PixelPalette.white),
      'moderate' => ('Moderate', PixelBoxStyle.gold, PixelPalette.ink),
      _ => null,
    };
    final distance = spot.distanceKm == null
        ? ''
        : ' · ${spot.distanceKm!.toStringAsFixed(1)} km';
    return Semantics(
      container: true,
      button: true,
      label: 'Open ${spot.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PixelPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PixelPanel(
                style: PixelBoxStyle.slot,
                sunken: true,
                padding: 1,
                child: ClipRect(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: spot.imageUrl != null
                        ? Image.network(
                            spot.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _PixelImageFallback(),
                          )
                        : const _PixelImageFallback(),
                  ),
                ),
              ),
              SizedBox(height: grid.px(2)),
              Text(
                spot.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.body(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                '${spot.municipality}$distance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              if (spot.reasons.isNotEmpty) ...[
                SizedBox(height: grid.px(1)),
                Text(
                  spot.reasons.first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      PixelType.small(context, color: PixelPalette.greenBright),
                ),
              ],
              SizedBox(height: grid.px(2)),
              Row(
                children: [
                  if (crowd != null)
                    PixelChip(
                      crowd.$1,
                      style: crowd.$2,
                      textColor: crowd.$3,
                    ),
                  const Spacer(),
                  _SavedHeart(
                    saved: spot.saved,
                    scale: iconScale,
                    onToggle: () async {
                      final failure = await ref
                          .read(spotDiscoveryProvider.notifier)
                          .toggleSaved(spot);
                      if (failure != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(failure.message)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedHeart extends StatefulWidget {
  const _SavedHeart({
    required this.saved,
    required this.scale,
    required this.onToggle,
  });

  final bool saved;
  final int scale;
  final Future<void> Function() onToggle;

  @override
  State<_SavedHeart> createState() => _SavedHeartState();
}

class _SavedHeartState extends State<_SavedHeart> {
  bool _playing = false;
  bool _target = false;

  Future<void> _toggle() async {
    setState(() {
      _target = !widget.saved;
      _playing = true;
    });
    await widget.onToggle();
    if (mounted) setState(() => _playing = false);
  }

  void _done() {
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _playing
        ? null
        : widget.saved
            ? DesignerArt.heartLiked
            : DesignerArt.heartUnliked;
    return Semantics(
      button: true,
      toggled: widget.saved,
      label: widget.saved ? 'Remove saved destination' : 'Save destination',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: _playing
                  ? PixelAnimation(
                      _target
                          ? DesignerArt.heartLikeAnim
                          : DesignerArt.heartUnlikeAnim,
                      scale: widget.scale,
                      loop: false,
                      onDone: _done,
                    )
                  : PixelSprite(icon!, scale: widget.scale),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelImageFallback extends StatelessWidget {
  const _PixelImageFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: PixelPalette.paperDim,
        child: Center(
          child: Text(
            'No photo',
            style: PixelType.small(context, color: PixelPalette.stone),
          ),
        ),
      );
}

class _JuanChoiceCard extends StatelessWidget {
  const _JuanChoiceCard({required this.overview, required this.onTap});

  final ChoiceOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final current = overview.current;
    final label = current != null
        ? 'Current round: ${current.theme}'
        : overview.previous != null
            ? 'Previous result: ${overview.previous!.periodLabel}'
            : 'Community destination voting';
    return Semantics(
      container: true,
      button: true,
      label: 'Open JuanChoice',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PixelPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PixelSprite(DesignerArt.juanChoice, scale: 2),
              SizedBox(width: grid.px(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.body(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      overview.notice ??
                          'See the current round and previous results.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _QuestsSection extends StatelessWidget {
  const _QuestsSection({required this.quests});

  final List<QuestModel> quests;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    if (quests.isEmpty) {
      return _PixelInfoRow(
        icon: DesignerArt.questMarker,
        title: '0 quests available',
        subtitle: 'Visit destinations and complete their activities.',
        action: 'Browse',
        onTap: () => context.go('/quests'),
      );
    }
    final shown = quests.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) SizedBox(height: grid.px(2)),
          _QuestCard(
            quest: shown[i],
            onContinue: () => context.go('/quests'),
          ),
        ],
        if (quests.length > shown.length) ...[
          SizedBox(height: grid.px(1)),
          Text(
            '${quests.length} quests available',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.onContinue});

  final QuestModel quest;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final total = quest.steps.length;
    final done = quest.steps.where((step) => step.isVerified).length;
    final segments = total == 0 ? 1 : total.clamp(1, 20).toInt();
    final value = total == 0 ? 0.0 : done / total;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final scale =
        (24 * dpr / DesignerArt.questMarker.height).round().clamp(1, 8).toInt();
    return Semantics(
      container: true,
      label: quest.title,
      child: PixelPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelSprite(DesignerArt.questMarker, scale: scale),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Text(
                    quest.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.body(context)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            SizedBox(height: grid.px(2)),
            Text(
              '${quest.categoryDisplay} · $total tasks · +${quest.rewardPoints} mJDQ',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            PixelProgressBar(
              value: value,
              segments: segments,
              color: PixelPalette.sun,
            ),
            SizedBox(height: grid.px(1)),
            Text(
              '$done / $total tasks done',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            PixelButton(
              label: 'Continue',
              expand: true,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.submission});

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
    return Padding(
      padding: EdgeInsets.only(bottom: grid.px(2)),
      child: Semantics(
        button: true,
        label: '${submission.questTitle}, $status',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/history'),
          child: PixelPanel(
            padding: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelChip(status, style: style, textColor: textColor),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.questTitle,
                        style: PixelType.body(context),
                      ),
                      SizedBox(height: grid.px(1)),
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

class _PixelInfoRow extends StatelessWidget {
  const _PixelInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final PixelArt icon;
  final String title, subtitle, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final scale = (32 * dpr / icon.height).round().clamp(1, 8).toInt();
    return Semantics(
      container: true,
      button: true,
      label: '$title. $action',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PixelPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelSprite(icon, scale: scale),
              SizedBox(width: grid.px(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PixelType.body(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(2)),
              PixelChip(action, style: PixelBoxStyle.slot),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelLoadingPanel extends StatelessWidget {
  const _PixelLoadingPanel();

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return SizedBox(
      height: grid.px(20),
      child: const Center(child: PixelLoader()),
    );
  }
}

class _PixelUnavailablePanel extends StatelessWidget {
  const _PixelUnavailablePanel({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: 'Retry',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _PixelEmptyPanel extends StatelessWidget {
  const _PixelEmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
      ),
    );
  }
}
