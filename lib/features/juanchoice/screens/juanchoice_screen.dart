import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
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
import '../pixel/juanchoice_pixel_art.dart';
import '../pixel/juanchoice_theme_spec.dart';
import '../utils/juanchoice_dates.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/juanchoice_provider.dart';

class JuanChoiceScreen extends ConsumerStatefulWidget {
  const JuanChoiceScreen({super.key});
  @override
  ConsumerState<JuanChoiceScreen> createState() => _JuanChoiceScreenState();
}

class _JuanChoiceScreenState extends ConsumerState<JuanChoiceScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(choiceOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = ref.watch(authProvider).isAuthenticated;
    final overview = ref.watch(choiceOverviewProvider);
    final supporterQuest = ref.watch(choiceSupporterQuestProvider);
    final engagement = authenticated ? ref.watch(choiceEngagementProvider) : null;
    final claimState = ref.watch(choiceSupporterClaimProvider);
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'JuanChoice',
                    onBack: () => canPop
                        ? Navigator.of(context).maybePop()
                        : context.go('/dashboard'),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: () async =>
                          ref.invalidate(choiceOverviewProvider),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          grid.px(4),
                          grid.px(3),
                          grid.px(4),
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          _hero(context, grid),
                          SizedBox(height: grid.px(3)),
                          overview.when(
                            loading: () => const Center(
                                child: PixelLoader(label: 'Loading votes')),
                            error: (_, __) => _errorCard(
                              context,
                              grid,
                              'Community voting is temporarily unavailable.',
                              'Retry',
                              () => ref.invalidate(choiceOverviewProvider),
                            ),
                            data: (data) => _overview(context, grid, data),
                          ),
                          SizedBox(height: grid.px(3)),
                          if (authenticated)
                            engagement!.when(
                              loading: () => const Center(
                                  child: PixelLoader(label: 'Loading journey')),
                              error: (_, __) => _errorCard(
                                context,
                                grid,
                                'Your community journey could not be loaded.',
                                'Retry journey',
                                () => ref
                                    .invalidate(choiceEngagementProvider),
                              ),
                              data: (summary) =>
                                  _journey(context, grid, summary),
                            ),
                          SizedBox(height: grid.px(3)),
                          supporterQuest.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => _errorCard(
                              context,
                              grid,
                              'Visit rewards could not be checked.',
                              'Retry visit rewards',
                              () => ref
                                  .invalidate(choiceSupporterQuestProvider),
                            ),
                            data: (quest) => quest == null
                                ? const SizedBox.shrink()
                                : _supporterQuest(
                                    context, grid, quest, authenticated, claimState),
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

  Widget _hero(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PixelSprite(DesignerArt.juanChoice, scale: 2),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Text(
                  'Community Choice',
                  style: PixelType.title(context, color: PixelPalette.paper),
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Community spotlight votes are free and separate from governance voting.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: const [
              PixelChip('FREE BALLOT', style: PixelBoxStyle.parchment),
              PixelChip('+25 CIVIC XP', style: PixelBoxStyle.gold),
              PixelChip('+1 STAMP', style: PixelBoxStyle.parchment),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overview(BuildContext context, PixelGrid grid, dynamic data) {
    final current = data.current;
    final currentSpec =
        current != null ? JuanChoiceThemeSpec.fromTheme(current.theme) : null;
    final previous = data.previous;
    final int prevTotal = previous == null
        ? 0
        : previous.standings.fold<int>(
            0,
            (int sum, dynamic s) => sum + ((s.votes as int?) ?? 0),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current != null && currentSpec != null)
          GestureDetector(
            key: const ValueKey('choice_current'),
            onTap: () => context.push('/choice/${current.id}'),
            child: PixelPanel(
              style: PixelBoxStyle.parchment,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: grid.px(1),
                    runSpacing: grid.px(1),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PixelSprite(currentSpec.emblem, scale: 2),
                      PixelChip(
                        currentSpec.badgeLabel,
                        style: currentSpec.headerStyle,
                        textColor: currentSpec.headerTitleColor,
                      ),
                      const PixelChip(
                        'LIVE BALLOT',
                        style: PixelBoxStyle.green,
                        textColor: PixelPalette.paper,
                      ),
                    ],
                  ),
                  SizedBox(height: grid.px(1)),
                  Text(current.theme, style: PixelType.title(context)),
                  SizedBox(height: grid.px(1)),
                  Text(
                    'Voting ends ${choiceVotingEnds(current.closesAt)}',
                    style: PixelType.body(
                      context,
                      color: PixelPalette.slate,
                    ),
                  ),
                  SizedBox(height: grid.px(2)),
                  PixelPanel(
                    style: PixelBoxStyle.gold,
                    padding: 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'OPEN BALLOT',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.ink,
                            ),
                          ),
                        ),
                        Text(
                          '›',
                          style: PixelType.title(
                            context,
                            color: PixelPalette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next community vote', style: PixelType.title(context)),
                SizedBox(height: grid.px(1)),
                Text(
                  data.nextOpensAt == null
                      ? 'The next date has not been confirmed yet.'
                      : 'Opens ${choiceDate(data.nextOpensAt!)}',
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
                if (data.nextClosesAt != null)
                  Text(
                    'Voting ends ${choiceVotingEnds(data.nextClosesAt!)}',
                    style: PixelType.body(context, color: PixelPalette.slate),
                  ),
                if (data.nextTheme != null)
                  Text(data.nextTheme!,
                      style: PixelType.body(context, color: PixelPalette.slate)),
              ],
            ),
          ),
        if (data.notice != null) ...[
          SizedBox(height: grid.px(2)),
          PixelPanel(
            style: PixelBoxStyle.gold,
            child: Text(data.notice!, style: PixelType.body(context)),
          ),
        ],
        SizedBox(height: grid.px(3)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Previous results', style: PixelType.title(context)),
              SizedBox(height: grid.px(1)),
              if (data.previous == null)
                Text(
                  'Results will appear after the first community round.',
                  style: PixelType.body(context, color: PixelPalette.slate),
                )
              else ...[
                PixelStatRow(
                  'Round',
                  '${data.previous!.periodLabel} (${data.previous!.validBallots} ballots)',
                  style: PixelType.small(context),
                  labelColor: PixelPalette.slate,
                  valueColor: PixelPalette.ink,
                ),
                SizedBox(height: grid.px(1)),
                for (final standing in data.previous!.standings) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (data.previous!.coWinnerIds
                          .contains(standing.candidateId)) ...[
                        const PixelSprite(DesignerArt.plazaTrophy, scale: 2),
                        SizedBox(width: grid.px(1)),
                      ],
                      Expanded(
                        child: PixelStatRow(
                          '${data.previous!.coWinnerIds.contains(standing.candidateId) ? '* ' : ''}${standing.spotName}',
                          '${standing.votes ?? 0} votes',
                          style: PixelType.body(context),
                          labelColor: data.previous!.coWinnerIds
                                  .contains(standing.candidateId)
                              ? PixelPalette.greenDark
                              : PixelPalette.ink,
                          valueColor: PixelPalette.gold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: grid.px(1)),
                  PixelProgressBar(
                    value: prevTotal > 0
                        ? ((standing.votes ?? 0) / prevTotal).clamp(0.0, 1.0)
                        : 0.0,
                    color: data.previous!.coWinnerIds
                            .contains(standing.candidateId)
                        ? PixelPalette.sun
                        : PixelPalette.green,
                    height: 4,
                  ),
                  SizedBox(height: grid.px(1)),
                ],
                if (data.previous!.coWinnerIds.isEmpty)
                  Text(
                    'No winner this round.',
                    style: PixelType.body(context, color: PixelPalette.slate),
                  ),
                SizedBox(height: grid.px(1)),
                Text(
                  'Community support is popularity, not a visitor rating.',
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _journey(BuildContext context, PixelGrid grid, dynamic summary) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your community journey', style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          PixelText.rich(
            'Streak: {green:${summary.currentStreak} rounds} · Longest: {gold:${summary.longestStreak}}',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          if (summary.nextMilestone != null) ...[
            SizedBox(height: grid.px(1)),
            PixelText.rich(
              '{sun:${summary.nextMilestone! - summary.currentStreak}} more official round(s) to next badge',
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            if (summary.nextMilestone! > 0) ...[
              SizedBox(height: grid.px(1)),
              PixelProgressBar(
                value: (summary.currentStreak / summary.nextMilestone!)
                    .clamp(0.0, 1.0),
                color: PixelPalette.sun,
                showTipGlint: true,
                height: 4,
              ),
            ],
          ],
          SizedBox(height: grid.px(1)),
          PixelText.rich(
            '{gold:${summary.verifiedVisits}} verified visits · {green:${summary.uniqueDestinations}} destinations · {blue:${summary.municipalities}} municipalities',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          if (summary.challenges.isNotEmpty) ...[
            SizedBox(height: grid.px(2)),
            for (final challenge in summary.challenges.take(2)) ...[
              Text(
                '${challenge.complete ? 'Done' : 'Next'}: ${challenge.title}: ${challenge.progress}/${challenge.target}',
                style: PixelType.body(context),
              ),
              SizedBox(height: grid.px(1)),
              PixelProgressBar(
                value: challenge.target > 0
                    ? (challenge.progress / challenge.target).clamp(0.0, 1.0)
                    : 1.0,
                color:
                    challenge.complete ? PixelPalette.green : PixelPalette.sun,
                height: 3,
              ),
              SizedBox(height: grid.px(1)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _supporterQuest(
    BuildContext context,
    PixelGrid grid,
    dynamic quest,
    bool authenticated,
    AsyncValue<dynamic> claimState,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visit the community winner',
            style: PixelType.title(context, color: PixelPalette.white),
          ),
          SizedBox(height: grid.px(1)),
          Text(quest.spotName,
              style: PixelType.title(context, color: PixelPalette.cream)),
          Text(
            quest.questDescription,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          Text(
            '+${quest.explorerXp} Explorer XP · expires ${choiceDate(quest.expiresAt)}',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),
          if (quest.claimed)
            Text(
              'Visit reward claimed',
              style: PixelType.body(context, color: PixelPalette.cream),
            )
          else ...[
            PixelButton(
              key: const ValueKey('choice_open_quest'),
              label: 'Open destination quest',
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: () => context.push('/quests/${quest.questId}'),
            ),
            SizedBox(height: grid.px(2)),
            if (authenticated)
              PixelButton(
                key: const ValueKey('choice_claim_reward'),
                label: 'Claim verified visit reward',
                expand: true,
                loading: claimState.isLoading,
                onPressed: () => ref
                    .read(choiceSupporterClaimProvider.notifier)
                    .claim(quest.campaignId),
              )
            else
              PixelButton(
                label: 'Sign in to claim after your visit',
                expand: true,
                onPressed: () => context.go(
                    '/?redirect=${Uri.encodeComponent('/choice')}'),
              ),
            if (claimState.hasError) ...[
              SizedBox(height: grid.px(2)),
              Text(
                '${claimState.error}',
                style: PixelType.body(context, color: PixelPalette.redLight),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _errorCard(
    BuildContext context,
    PixelGrid grid,
    String message,
    String retryLabel,
    VoidCallback retry,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: PixelType.body(context, color: PixelPalette.white),
          ),
          SizedBox(height: grid.px(2)),
          Align(
            alignment: Alignment.centerRight,
            child: PixelButton(
              label: retryLabel,
              variant: PixelButtonVariant.secondary,
              onPressed: retry,
            ),
          ),
        ],
      ),
    );
  }
}

class JuanChoiceDetailScreen extends ConsumerStatefulWidget {
  const JuanChoiceDetailScreen(
      {super.key, required this.campaignId, this.focusCandidateId});
  final String campaignId;

  /// Shared candidate link (`/choice/:id/candidates/:candidateId`): that
  /// candidate is highlighted and scrolled into view.
  final String? focusCandidateId;
  @override
  ConsumerState<JuanChoiceDetailScreen> createState() =>
      _JuanChoiceDetailScreenState();
}

class _JuanChoiceDetailScreenState extends ConsumerState<JuanChoiceDetailScreen>
    with WidgetsBindingObserver {
  final GlobalKey _focusKey = GlobalKey();
  bool _scrolledToFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _scrollToFocusOnce() {
    if (_scrolledToFocus || widget.focusCandidateId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusKey.currentContext;
      if (ctx == null || _scrolledToFocus) return;
      _scrolledToFocus = true;
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350), alignment: 0.2);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(choiceDetailProvider(widget.campaignId));
      ref.invalidate(choiceOverviewProvider);
    }
  }

  Future<void> _confirm(
    String candidateId,
    String name,
    int version,
    JuanChoiceThemeSpec themeSpec,
  ) async {
    final accepted = await showPixelDialog<bool>(
      context: context,
      title: 'Confirm JuanChoice vote',
      message:
          'Vote for $name? This free promotional vote gives the same participation reward regardless of the winner. No mJDQ is spent.',
      content: Builder(
        builder: (dialogContext) {
          final grid = PixelGrid.of(dialogContext);
          return Padding(
            padding: EdgeInsets.only(top: grid.px(2)),
            child: Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                PixelChip(
                  themeSpec.badgeLabel,
                  style: PixelBoxStyle.gold,
                  icon: themeSpec.emblem,
                  iconScale: 2,
                ),
                const PixelChip(
                  '+25 CIVIC XP',
                  style: PixelBoxStyle.green,
                  textColor: PixelPalette.white,
                ),
                const MjdqChip(
                  0,
                  prefix: '+1 STAMP · ',
                  style: PixelBoxStyle.parchment,
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        PixelButton(
          label: 'Cancel',
          variant: PixelButtonVariant.secondary,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PixelButton(
          key: const ValueKey('choice_confirm_vote'),
          label: 'Confirm vote',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (accepted == true && mounted) {
      await ref
          .read(choiceVoteProvider.notifier)
          .submit(widget.campaignId, candidateId, version);
    }
  }

  @override
  Widget build(BuildContext context) {
    _scrollToFocusOnce();
    ref.listen<ChoiceVoteState>(choiceVoteProvider, (previous, next) {
      if (previous?.receipt == null && next.receipt != null) {
        if (GameAudio.instance.buttonSounds.value) {
          GameAudio.instance.playSfx('stamp');
        }
      }
    });
    final detail = ref.watch(choiceDetailProvider(widget.campaignId));
    final overview = ref.watch(choiceOverviewProvider).asData?.value;
    final vote = ref.watch(choiceVoteProvider);
    final authenticated = ref.watch(authProvider).isAuthenticated;
    final screenTheme = detail.asData?.value != null
        ? JuanChoiceThemeSpec.fromTheme(detail.asData!.value.campaign.theme)
        : JuanChoiceThemeSpec.spotlight;
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: screenTheme.ditherTop,
              bottom: screenTheme.ditherBottom,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'JuanChoice',
                    onBack: () => canPop
                        ? Navigator.of(context).maybePop()
                        : context.go('/dashboard'),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: () async {
                        ref.invalidate(choiceOverviewProvider);
                        ref.invalidate(
                            choiceDetailProvider(widget.campaignId));
                      },
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          grid.px(4),
                          grid.px(3),
                          grid.px(4),
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          detail.when(
                            loading: () => const Center(
                                child: PixelLoader(label: 'Loading ballot')),
                            error: (error, stackTrace) => PixelPanel(
                              style: PixelBoxStyle.red,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Campaign unavailable. Please try again.',
                                    style: PixelType.body(
                                      context,
                                      color: PixelPalette.white,
                                    ),
                                  ),
                                  SizedBox(height: grid.px(2)),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: PixelButton(
                                      label: 'Retry',
                                      variant:
                                          PixelButtonVariant.secondary,
                                      onPressed: () {
                                        ref.invalidate(
                                            choiceOverviewProvider);
                                        ref.invalidate(choiceDetailProvider(
                                            widget.campaignId));
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            data: (data) => _ballot(
                              context,
                              grid,
                              data,
                              overview,
                              vote,
                              authenticated,
                            ),
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

  Widget _ballot(
    BuildContext context,
    PixelGrid grid,
    dynamic data,
    dynamic overview,
    dynamic vote,
    bool authenticated,
  ) {
    final themeSpec = JuanChoiceThemeSpec.fromTheme(data.campaign.theme);
    final bool isOpen = overview?.isCampaignOpen(data.campaign) == true;
    final bool tallyHidden = data.campaign.tallyHidden == true;
    final int totalVotes = tallyHidden
        ? 0
        : (data.standings as List).fold<int>(
            0,
            (int sum, dynamic s) => sum + ((s.votes as int?) ?? 0),
          );
    final int maxVotes = tallyHidden
        ? 0
        : (data.standings as List).fold<int>(0, (int m, dynamic s) {
            final int v = (s.votes as int?) ?? 0;
            return v > m ? v : m;
          });
    final String? myCandidateId =
        vote.receipt?.candidateId ?? data.ballot?.candidateId;
    String? mySpotName;
    if (myCandidateId != null) {
      for (final s in data.standings as List) {
        if (s.candidateId == myCandidateId) {
          mySpotName = s.spotName as String?;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelPanel(
          key: const ValueKey('choice_week_header'),
          style: themeSpec.headerStyle,
          // Full width: a short theme left the panel narrower than the page.
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: grid.px(1),
                  runSpacing: grid.px(1),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PixelSprite(themeSpec.emblem, scale: 2),
                    PixelChip(
                      themeSpec.badgeLabel,
                      style: PixelBoxStyle.gold,
                      textColor: PixelPalette.ink,
                    ),
                    PixelChip(
                      isOpen ? 'LIVE BALLOT' : 'CLOSED',
                      style: isOpen ? PixelBoxStyle.green : PixelBoxStyle.stone,
                      textColor: PixelPalette.white,
                    ),
                  ],
                ),
                SizedBox(height: grid.px(2)),
                Text(
                  data.campaign.theme,
                  style: PixelType.title(
                    context,
                    color: themeSpec.headerTitleColor,
                  ),
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  '${data.campaign.region} · ${isOpen ? 'Voting open' : data.campaign.status}',
                  style: PixelType.body(
                    context,
                    color: themeSpec.headerBodyColor,
                  ),
                ),
                Text(
                  'Voting ends ${choiceVotingEnds(data.campaign.closesAt)}',
                  style: PixelType.body(
                    context,
                    color: themeSpec.headerBodyColor,
                  ),
                ),
                SizedBox(height: grid.px(2)),
                Wrap(
                  spacing: grid.px(1),
                  runSpacing: grid.px(1),
                  children: const [
                    PixelChip(
                      '+25 CIVIC XP',
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white,
                    ),
                    PixelChip(
                      '+1 STAMP · FREE',
                      style: PixelBoxStyle.parchment,
                      textColor: PixelPalette.ink,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: grid.px(3)),
        if (data.ballot != null || vote.receipt != null) ...[
          PixelPanel(
            key: const ValueKey('choice_ballot_banner'),
            style: PixelBoxStyle.green,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PixelSprite(JuanChoicePixelArt.stampSeal, scale: 2),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mySpotName != null)
                        Text(
                          mySpotName,
                          style: PixelType.title(
                            context,
                            color: PixelPalette.white,
                          ),
                        ),
                      if (data.ballot != null)
                        Text(
                          'Your ballot: version ${data.ballot!.version}',
                          style: PixelType.body(
                            context,
                            color: PixelPalette.cream,
                          ),
                        ),
                      if (vote.receipt != null)
                        Text(
                          'Ballot recorded. Participation reward per round: +25 Civic XP and +1 stamp; 0 mJDQ issued.',
                          style: PixelType.body(
                            context,
                            color: PixelPalette.cream,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
        if (authenticated && data.eligibility?.reason == 'ACCOUNT_TOO_NEW')
          Text(
            'Voting unlocks after ${data.eligibility!.eligibleAt?.toLocal() ?? 'your account is 72 hours old'} or after one approved destination visit.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        if (authenticated &&
            data.eligibility == null &&
            isOpen)
          Text(
            'Voting eligibility could not be confirmed. Pull to retry.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        if (vote.error != null)
          Text(
            vote.error!,
            style: PixelType.body(context, color: PixelPalette.redDeep),
          ),
        if (!authenticated && isOpen)
          PixelButton(
            key: const ValueKey('choice_sign_in'),
            label: 'Sign in to vote',
            expand: true,
            onPressed: () => context.go(
                '/?redirect=${Uri.encodeComponent('/choice/${widget.campaignId}')}'),
          ),
        if (tallyHidden)
          Text(
            key: const ValueKey('choice_tally_hidden'),
            'Final hours: vote counts are hidden until the round closes. You can still vote or change your vote.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        SizedBox(height: grid.px(2)),
        for (final entry in (data.standings as List).asMap().entries) ...[
          Builder(
            builder: (context) {
              final int index = entry.key;
              final dynamic standing = entry.value;
              final int? votes = standing.votes as int?;
              final bool isMyVote = myCandidateId == standing.candidateId;
              final bool isFocused =
                  standing.candidateId == widget.focusCandidateId;
              final bool isLeader =
                  !tallyHidden && maxVotes > 0 && votes == maxVotes;
              final bool isFirstRank = !tallyHidden && index == 0 && maxVotes > 0;
              final PixelBoxStyle cardStyle = isFocused || isMyVote
                  ? PixelBoxStyle.gold.copyWith(
                      fill: PixelPalette.cream,
                      outline: PixelPalette.goldDeep,
                    )
                  : PixelBoxStyle.parchment;
              final int sharePct = (!tallyHidden && votes != null && totalVotes > 0)
                  ? ((votes * 100) / totalVotes).round()
                  : 0;

              return PixelPanel(
                key: isFocused
                    ? _focusKey
                    : ValueKey('choice_candidate_${standing.candidateId}'),
                style: cardStyle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ranks only mean something once a vote is in; at 0 the
                    // API order is just candidate id.
                    if ((!tallyHidden && maxVotes > 0) || isMyVote) ...[
                      Wrap(
                        spacing: grid.px(1),
                        runSpacing: grid.px(1),
                        children: [
                          if (!tallyHidden && maxVotes > 0)
                            PixelChip(
                              '#${index + 1}',
                              style: isFirstRank
                                  ? PixelBoxStyle.gold
                                  : PixelBoxStyle.stone,
                              icon: isFirstRank ? DesignerArt.plazaTrophy : null,
                              iconScale: 2,
                              textColor: isFirstRank
                                  ? PixelPalette.ink
                                  : PixelPalette.white,
                            ),
                          if (isMyVote)
                            const PixelChip(
                              'YOUR VOTE',
                              style: PixelBoxStyle.green,
                              icon: JuanChoicePixelArt.stampSeal,
                              iconScale: 2,
                              textColor: PixelPalette.white,
                            ),
                        ],
                      ),
                      SizedBox(height: grid.px(1)),
                    ],
                    Text(
                      standing.spotName,
                      maxLines: 2,
                      style: PixelType.title(context),
                    ),
                    SizedBox(height: grid.px(1)),
                    PixelStatRow(
                      'Provisional votes',
                      tallyHidden || votes == null ? 'Hidden' : '$votes',
                      style: PixelType.body(context),
                      labelColor: PixelPalette.slate,
                      valueColor: PixelPalette.gold,
                    ),
                    if (!tallyHidden && votes != null) ...[
                      SizedBox(height: grid.px(1)),
                      PixelProgressBar(
                        value: totalVotes > 0 ? votes / totalVotes : 0.0,
                        segments: 10,
                        color: isLeader
                            ? themeSpec.leadBarColor
                            : themeSpec.barColor,
                        height: 4,
                        showTipGlint: isLeader || isMyVote,
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        '$sharePct% share',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                    if (authenticated &&
                        overview?.current?.id == data.campaign.id &&
                        isOpen &&
                        data.eligibility?.canVoteNow == true) ...[
                      SizedBox(height: grid.px(2)),
                      PixelButton(
                        label: vote.pending
                            ? 'Submitting'
                            : data.ballot == null
                                ? 'Vote for this place'
                                : 'Change vote',
                        expand: true,
                        loading: vote.pending,
                        onPressed: vote.pending
                            ? null
                            : () => _confirm(
                                  standing.candidateId,
                                  standing.spotName,
                                  data.ballot?.version ?? 0,
                                  themeSpec,
                                ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          SizedBox(height: grid.px(2)),
        ],
        if (overview == null || !overview.votingEnabled)
          Text(
            'Voting is temporarily unavailable.',
            style: PixelType.body(context, color: PixelPalette.slate),
          )
        else if (!isOpen)
          Text(
            'Voting is closed or not yet open. No ballot can be queued offline.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
      ],
    );
  }
}
