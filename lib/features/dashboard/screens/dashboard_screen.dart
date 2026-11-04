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
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../juanchoice/models/juanchoice_models.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../profile/providers/profile_stats_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../../spots/screens/interests_screen.dart';
import '../../submissions/models/submission_model.dart';
import '../../submissions/providers/submission_provider.dart';
import '../home_tips.dart';
import '../providers/home_daily_provider.dart';

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
                                    'Authenticated profile, engagement, destinations, quests, submissions, daily rewards, and JuanChoice APIs',
                                stateNotes:
                                    'API failures are shown as unavailable; no synthetic activity or ranking data',
                                uxNotes:
                                    'Compact hero, Progress / Quests / Collection tabs, and always-visible JuanChoice',
                              ),
                              child: _CompactHero(user: user),
                            ),
                          ),
                          SizedBox(height: grid.px(3)),
                          _JuanChoiceCard(
                            onRetry: () =>
                                ref.invalidate(choiceOverviewProvider),
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

// ------------------------------------------------------------------ hero

class _CompactHero extends StatelessWidget {
  const _CompactHero({required this.user});

  final UserModel? user;

  static Map<String, dynamic>? _cosmeticAsset(
    Map<String, dynamic>? cosmetics,
    String slot,
  ) {
    final item = cosmetics?[slot];
    if (item is! Map || item['asset'] is! Map) return null;
    return Map<String, dynamic>.from(item['asset'] as Map);
  }

  static Color? _cosmeticColor(dynamic value) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse(value.substring(1), radix: 16) | 0xff000000);
  }

  static String _number(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Traveler';
    final handle = user?.handle ?? '@traveler';
    final points = user?.points ?? 0;
    final level = (points ~/ 50) + 1;
    final xpInLevel = points % 50;
    final titleAsset = _cosmeticAsset(user?.cosmetics, 'title');
    final nameColorAsset = _cosmeticAsset(user?.cosmetics, 'nameColor');
    final nameColor = _cosmeticColor(nameColorAsset?['color']);
    final cosmeticTitle = titleAsset?['text']?.toString() ?? '';
    final initial = displayName.isEmpty ? 'J' : displayName[0].toUpperCase();
    final avatarUrl = user?.avatarUrl ?? '';
    final validAvatar = avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                key: const ValueKey('home_hero_profile'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/profile'),
                child: PixelPanel(
                  style: PixelBoxStyle.gold,
                  padding: 1,
                  child: SizedBox(
                    width: grid.px(16),
                    height: grid.px(16),
                    child: ClipRect(
                      child: validAvatar
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  _avatarFallback(context, initial),
                            )
                          : _avatarFallback(context, initial),
                    ),
                  ),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.title(
                        context,
                        color: nameColor ?? PixelPalette.paper,
                      ),
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          PixelType.small(context, color: PixelPalette.cream),
                    ),
                    SizedBox(height: grid.px(1)),
                    Wrap(
                      spacing: grid.px(1),
                      runSpacing: grid.px(1),
                      children: [
                        PixelChip(
                          'Level $level',
                          style: PixelBoxStyle.green,
                          textColor: PixelPalette.white,
                        ),
                        if (cosmeticTitle.isNotEmpty)
                          PixelChip(cosmeticTitle, style: PixelBoxStyle.gold),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          GestureDetector(
            key: const ValueKey('home_hero_level'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go('/profile'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelProgressBar(
                  value: xpInLevel / 50,
                  segments: 10,
                  color: PixelPalette.greenBright,
                ),
                SizedBox(height: grid.px(1)),
                PixelText.rich(
                  '{sun:$xpInLevel / 50 XP} to level {paper:${level + 1}} · {paper:$points total XP}',
                  maxLines: 2,
                  style: PixelType.small(context, color: PixelPalette.cream),
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
          Row(
            children: [
              Expanded(
                child: _WalletStat(
                  key: const ValueKey('home_wallet_mjdq'),
                  label: 'mJDQ',
                  value: _number(user?.mjdqBalance ?? 0),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: _WalletStat(
                  key: const ValueKey('home_wallet_jdq'),
                  label: 'JDQ',
                  value: _number(user?.jdqGovernanceBalance ?? 0),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: _WalletStat(
                  key: const ValueKey('home_wallet_rep'),
                  label: 'Reputation',
                  value: _number(user?.scoutReputation ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String initial) {
    return DitherBackground(
      top: PixelPalette.greenMid,
      bottom: PixelPalette.greenDeep,
      child: Center(
        child: Text(
          initial,
          style: PixelType.title(context, color: PixelPalette.paper),
        ),
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      button: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/profile'),
          child: PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(1)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: PixelType.numbers(
                      context,
                      color: PixelPalette.greenDark,
                    ),
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

// ------------------------------------------------------------- JuanChoice

class _JuanChoiceCard extends ConsumerWidget {
  const _JuanChoiceCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(choiceOverviewProvider);
    return overview.when(
      loading: () => const _LoadingPanel(),
      error: (_, __) => _UnavailablePanel(
        message: 'JuanChoice is unavailable.',
        retryKey: const ValueKey('home_juanchoice_retry'),
        onRetry: onRetry,
      ),
      data: (data) {
        final current = data.current;
        final open = current != null && data.isCampaignOpen(current);
        final detail =
            open ? ref.watch(choiceDetailProvider(current.id)) : null;
        return _JuanChoiceContent(
          overview: data,
          openCampaign: open ? current : null,
          detail: detail,
        );
      },
    );
  }
}

class _JuanChoiceContent extends StatelessWidget {
  const _JuanChoiceContent({
    required this.overview,
    required this.openCampaign,
    required this.detail,
  });

  final ChoiceOverview overview;
  final ChoiceCampaign? openCampaign;
  final AsyncValue<ChoiceDetail>? detail;

  static int _daysLeft(ChoiceOverview overview, ChoiceCampaign campaign) {
    final serverTime = overview.serverTime;
    final receivedAt = overview.receivedAt;
    final DateTime now;
    if (serverTime != null) {
      final elapsed = overview.monotonicClock?.elapsed ??
          (receivedAt == null
              ? Duration.zero
              : DateTime.now().difference(receivedAt));
      now = serverTime.add(elapsed);
    } else {
      now = DateTime.now();
    }
    final remaining = campaign.closesAt.difference(now);
    if (remaining <= Duration.zero) return 0;
    return (remaining.inHours / 24).ceil();
  }

  static String _daysLabel(int days) {
    if (days <= 0) return 'Closes today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final campaign = openCampaign;
    final previous = overview.previous;
    final winners = previous == null
        ? const <ChoiceStanding>[]
        : previous.standings
            .where((standing) => previous.coWinnerIds.contains(
                  standing.candidateId,
                ))
            .toList();
    final title = campaign != null
        ? 'Voting now: ${campaign.theme}'
        : previous != null
            ? 'Last results: ${previous.periodLabel}'
            : 'Community vote';
    final target = campaign != null ? '/choice/${campaign.id}' : '/choice';
    return Semantics(
      container: true,
      button: true,
      label: 'JuanChoice. $title',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('home_juanchoice_card'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(target),
          child: PixelPanel(
            style: PixelBoxStyle.tooltip,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PixelSprite(DesignerArt.juanChoice, scale: 2),
                    SizedBox(width: grid.px(2)),
                    Expanded(
                      child: Text(
                        'JuanChoice',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.title(
                          context,
                          color: PixelPalette.paper,
                        ),
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                    Flexible(
                      child: PixelChip(
                        campaign != null ? 'Vote open' : 'Community',
                        style: campaign != null
                            ? PixelBoxStyle.green
                            : PixelBoxStyle.gold,
                        textColor: campaign != null
                            ? PixelPalette.white
                            : PixelPalette.ink,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: grid.px(2)),
                if (campaign != null) ...[
                  PixelText.rich(
                    'Voting now: {sun:${campaign.theme}}',
                    maxLines: 2,
                    style: PixelType.body(context, color: PixelPalette.paper),
                  ),
                  SizedBox(height: grid.px(1)),
                  PixelText.rich(
                    '{paper:${_daysLabel(_daysLeft(overview, campaign))}} · ${_ballotLabel(detail)}',
                    maxLines: 2,
                    style: PixelType.small(context, color: PixelPalette.cream),
                  ),
                ] else if (previous != null) ...[
                  PixelText.rich(
                    'Last results: {sun:${previous.periodLabel}}',
                    maxLines: 2,
                    style: PixelType.body(context, color: PixelPalette.paper),
                  ),
                  SizedBox(height: grid.px(1)),
                  if (winners.isEmpty)
                    Text(
                      'No winner this round.',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.cream,
                      ),
                    )
                  else
                    for (final winner in winners.take(2))
                      PixelText.rich(
                        '{paper:${winner.spotName}} — {sun:${winner.votes} votes}',
                        maxLines: 2,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.cream,
                        ),
                      ),
                  if (winners.length > 2)
                    Text(
                      '+${winners.length - 2} more winners',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.paperDim,
                      ),
                    ),
                  SizedBox(height: grid.px(1)),
                  Text(
                    '${previous.validBallots} ballots counted',
                    style:
                        PixelType.small(context, color: PixelPalette.paperDim),
                  ),
                ] else
                  Text(
                    'No community vote is open and no results are in yet.',
                    style: PixelType.small(context, color: PixelPalette.cream),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _ballotLabel(AsyncValue<ChoiceDetail>? detail) {
    if (detail == null) return 'you have not voted yet';
    if (detail.isLoading) return 'checking your ballot';
    final value = detail.asData?.value;
    if (value == null) return 'vote status unavailable';
    return value.ballot == null ? 'you have not voted yet' : 'you voted';
  }
}

// ------------------------------------------------------------------ tabs

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

  static final _idleStyle = PixelBoxStyle.wood.copyWith(
    fill: PixelPalette.woodDeep,
    highlight: PixelPalette.wood,
    shade: PixelPalette.woodNight,
  );

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final content = switch (selected) {
      0 => const _ProgressTab(),
      1 => const _QuestsTab(),
      _ => const _CollectionTab(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
        SizedBox(height: grid.px(1)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: content,
        ),
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
          child: PixelPanel(
            style: active ? PixelBoxStyle.wood : _idleStyle,
            padding: 1,
            pressed: !active,
            child: Center(
              child: Text(
                _labels[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.paper),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- progress

class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final engagement = ref.watch(choiceEngagementProvider);
    final submissions = ref.watch(submissionProvider);
    final daily = ref.watch(homeDailyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Travel stats'),
        SizedBox(height: grid.px(1)),
        engagement.when(
          loading: () => const _LoadingPanel(),
          error: (_, __) => _UnavailablePanel(
            message: 'Travel stats are unavailable.',
            retryKey: const ValueKey('home_progress_stats_retry'),
            onRetry: () => ref.invalidate(choiceEngagementProvider),
          ),
          data: (summary) => Column(
            children: [
              _TapStatRow(
                key: const ValueKey('home_stat_streak'),
                label: 'Visit streak',
                value:
                    '${summary.currentStreak} ${summary.currentStreak == 1 ? 'day' : 'days'}',
                onTap: () => context.go('/profile'),
              ),
              _TapStatRow(
                key: const ValueKey('home_stat_visits'),
                label: 'Verified visits',
                value: '${summary.verifiedVisits}',
                onTap: () => context.go('/profile'),
              ),
              _TapStatRow(
                key: const ValueKey('home_stat_destinations'),
                label: 'Destinations',
                value: '${summary.uniqueDestinations}',
                onTap: () => context.go('/profile'),
              ),
              _TapStatRow(
                key: const ValueKey('home_stat_municipalities'),
                label: 'Municipalities',
                value: '${summary.municipalities}',
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(2)),
        const _SectionLabel('Proof submissions'),
        SizedBox(height: grid.px(1)),
        _proofBlock(context, grid, ref, submissions),
        SizedBox(height: grid.px(2)),
        const _SectionLabel('Daily mission'),
        SizedBox(height: grid.px(1)),
        daily.when(
          loading: () => const _LoadingPanel(),
          error: (_, __) => _UnavailablePanel(
            message: 'Daily mission is unavailable.',
            retryKey: const ValueKey('home_progress_daily_retry'),
            onRetry: () => ref.invalidate(homeDailyProvider),
          ),
          data: (state) => _DailyMissionRow(state: state),
        ),
      ],
    );
  }

  Widget _proofBlock(
    BuildContext context,
    PixelGrid grid,
    WidgetRef ref,
    SubmissionState submissions,
  ) {
    if (submissions.isLoading && submissions.submissions.isEmpty) {
      return const _LoadingPanel();
    }
    if (submissions.error != null && submissions.submissions.isEmpty) {
      return _UnavailablePanel(
        message: 'Proof submissions are unavailable.',
        retryKey: const ValueKey('home_progress_proof_retry'),
        onRetry: () =>
            ref.read(submissionProvider.notifier).fetchSubmissions(force: true),
      );
    }
    int count(String status) => submissions.submissions
        .where((item) => item.status.toLowerCase() == status)
        .length;
    final latest =
        submissions.submissions.isEmpty ? null : submissions.submissions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TapStatRow(
          key: const ValueKey('home_proof_pending'),
          label: 'Pending proofs',
          value: '${count('pending')}',
          onTap: () => context.push('/history'),
        ),
        _TapStatRow(
          key: const ValueKey('home_proof_approved'),
          label: 'Approved proofs',
          value: '${count('approved')}',
          onTap: () => context.push('/history'),
        ),
        _TapStatRow(
          key: const ValueKey('home_proof_rejected'),
          label: 'Rejected proofs',
          value: '${count('rejected')}',
          onTap: () => context.push('/history'),
        ),
        if (latest == null) ...[
          SizedBox(height: grid.px(1)),
          Text(
            'No proofs submitted yet.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ] else ...[
          SizedBox(height: grid.px(1)),
          _LatestProof(submission: latest),
        ],
      ],
    );
  }
}

class _DailyMissionRow extends StatelessWidget {
  const _DailyMissionRow({required this.state});

  final HomeDailyState state;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final mission = state.nextMission;
    if (mission == null) {
      return PixelPanel(
        style: PixelBoxStyle.slot,
        padding: 2,
        child: Text(
          'No daily mission today.',
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
      );
    }
    final done = mission.completed || state.allComplete;
    return Semantics(
      button: true,
      label: 'Daily mission: ${mission.title}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('home_daily_mission'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/quests'),
          child: PixelPanel(
            style: PixelBoxStyle.tooltip,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelText.rich(
                  '{sun:${mission.title}}',
                  maxLines: 2,
                  style: PixelType.body(context, color: PixelPalette.paper),
                ),
                SizedBox(height: grid.px(1)),
                PixelText.rich(
                  '{paper:${mission.progress} / ${mission.target}} · ${done ? '{sun:Done}' : '{paper:In progress}'} · {sun:+${mission.stamps} stamps}',
                  maxLines: 2,
                  style: PixelType.small(context, color: PixelPalette.cream),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LatestProof extends StatelessWidget {
  const _LatestProof({required this.submission});

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
      label: 'Latest proof: ${submission.questTitle}, $status',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('home_latest_proof'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/history'),
          child: PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelChip(status, style: style, textColor: textColor),
                    SizedBox(width: grid.px(1)),
                    Expanded(
                      child: Text(
                        submission.createdAt.split('T').first,
                        textAlign: TextAlign.end,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  submission.questTitle,
                  style: PixelType.body(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- quests

class _QuestsTab extends ConsumerWidget {
  const _QuestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final quests = ref.watch(questProvider);
    final submissions = ref.watch(submissionProvider);
    final stats = ref.watch(profileStatsProvider);
    final inProgress = _inProgress(quests.quests, submissions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('In progress'),
        SizedBox(height: grid.px(1)),
        if (quests.isLoading && quests.quests.isEmpty)
          const _LoadingPanel()
        else if (quests.error != null && quests.quests.isEmpty)
          _UnavailablePanel(
            message: 'Quests are unavailable.',
            retryKey: const ValueKey('home_quests_retry'),
            onRetry: () => ref.read(questProvider.notifier).fetchQuests(),
          )
        else if (inProgress.isEmpty)
          Text(
            'No quests in progress yet.',
            style: PixelType.small(context, color: PixelPalette.slate),
          )
        else
          for (var i = 0; i < inProgress.length; i++) ...[
            if (i > 0) SizedBox(height: grid.px(1)),
            _QuestProgressRow(quest: inProgress[i]),
          ],
        SizedBox(height: grid.px(2)),
        _TapStatRow(
          key: const ValueKey('home_completed_quests'),
          label: 'Completed quests',
          value: '${stats.completedQuests}',
          onTap: () => context.push('/quests'),
        ),
        SizedBox(height: grid.px(2)),
        PixelButton(
          key: const ValueKey('home_see_all_quests'),
          label: 'See all quests',
          icon: DesignerArt.questMarker,
          expand: true,
          onPressed: () => context.push('/quests'),
        ),
      ],
    );
  }

  static List<QuestModel> _inProgress(
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
}

class _QuestProgressRow extends StatelessWidget {
  const _QuestProgressRow({required this.quest});

  final QuestModel quest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final total = quest.steps.length;
    final done = quest.steps.where((step) => step.isVerified).length;
    return Semantics(
      button: true,
      label: '${quest.title}, $done of $total tasks done',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_quest_${quest.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/quests/${quest.id}'),
          child: PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  quest.title,
                  style: PixelType.body(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  '$done / $total tasks done',
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(1)),
                PixelProgressBar(
                  value: total == 0 ? 0 : done / total,
                  segments: total == 0 ? 1 : total.clamp(1, 20).toInt(),
                  color: PixelPalette.sun,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- collection

class _CollectionTab extends ConsumerWidget {
  const _CollectionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final daily = ref.watch(homeDailyProvider);
    final stats = ref.watch(profileStatsProvider);
    final spots = ref.watch(spotDiscoveryProvider);
    final earned = [
      stats.ecoPioneerState,
      stats.heritageKeeperState,
      stats.foodExplorerState,
    ].where((state) => state == BadgeState.earned).length;
    final saved = spots.spots.where((spot) => spot.saved).length;
    final badges = <(String, BadgeState, String)>[
      ('Eco Pioneer', stats.ecoPioneerState, 'home_badge_eco'),
      ('Heritage Keeper', stats.heritageKeeperState, 'home_badge_heritage'),
      ('Food Explorer', stats.foodExplorerState, 'home_badge_food'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Passport'),
        SizedBox(height: grid.px(1)),
        daily.when(
          loading: () => const _LoadingPanel(),
          error: (_, __) => _UnavailablePanel(
            message: 'Stamps are unavailable.',
            retryKey: const ValueKey('home_collection_stamps_retry'),
            onRetry: () => ref.invalidate(homeDailyProvider),
          ),
          data: (state) => _TapStatRow(
            key: const ValueKey('home_collection_stamps'),
            label: 'Passport stamps',
            value: '${state.stamps}',
            onTap: () => context.go('/profile'),
          ),
        ),
        SizedBox(height: grid.px(1)),
        _TapStatRow(
          key: const ValueKey('home_collection_badges'),
          label: 'Badges earned',
          value: '$earned of 3',
          onTap: () => context.go('/profile'),
        ),
        SizedBox(height: grid.px(1)),
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final badge in badges)
              PixelChip(
                badge.$1,
                key: ValueKey(badge.$3),
                style: badge.$2 == BadgeState.earned
                    ? PixelBoxStyle.green
                    : PixelBoxStyle.slot,
                textColor: badge.$2 == BadgeState.earned
                    ? PixelPalette.white
                    : PixelPalette.slate,
                onTap: () => context.go('/profile'),
              ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        const _SectionLabel('Places'),
        SizedBox(height: grid.px(1)),
        if (spots.failure != null && spots.spots.isEmpty)
          _UnavailablePanel(
            message: 'Saved spots are unavailable.',
            retryKey: const ValueKey('home_collection_saved_retry'),
            onRetry: () =>
                ref.read(spotDiscoveryProvider.notifier).load(refresh: true),
          )
        else ...[
          _TapStatRow(
            key: const ValueKey('home_collection_saved'),
            label: 'Saved spots',
            value: '$saved',
            onTap: () => context.push('/saved'),
          ),
          if (saved == 0) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'No saved spots yet.',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
        ],
      ],
    );
  }
}

// ------------------------------------------------------------- next stop

class _NextStopPanel extends StatelessWidget {
  const _NextStopPanel();

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
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

// --------------------------------------------------------------- shared

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _TapStatRow extends StatelessWidget {
  const _TapStatRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PixelStatRow(
          label,
          value,
          labelColor: PixelPalette.stone,
          valueColor: PixelPalette.greenDark,
          trailing: onTap == null
              ? null
              : Text(
                  '>',
                  style: PixelType.small(context, color: PixelPalette.woodMid),
                ),
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: row,
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return SizedBox(
      height: grid.px(20),
      child: const Center(child: PixelLoader()),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel({
    required this.message,
    required this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.slot,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelButton(
            key: retryKey,
            label: 'Retry',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
