import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
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
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
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
          Text(
            'Community Choice',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Community spotlight votes are free and separate from governance voting.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
        ],
      ),
    );
  }

  Widget _overview(BuildContext context, PixelGrid grid, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.current != null)
          GestureDetector(
            key: const ValueKey('choice_current'),
            onTap: () => context.push('/choice/${data.current!.id}'),
            child: PixelPanel(
              style: PixelBoxStyle.parchment,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.current!.theme,
                            style: PixelType.title(context)),
                        SizedBox(height: grid.px(1)),
                        Text(
                          'Voting closes ${_manilaDate(data.current!.closesAt)} PHT',
                          style: PixelType.body(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: grid.px(2)),
                  Text('>',
                      style: PixelType.title(
                        context,
                        color: PixelPalette.woodMid,
                      )),
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
                      : 'Opens ${_manilaDate(data.nextOpensAt!)} PHT',
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
                if (data.nextClosesAt != null)
                  Text(
                    'Closes ${_manilaDate(data.nextClosesAt!)} PHT',
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
                  PixelStatRow(
                    '${data.previous!.coWinnerIds.contains(standing.candidateId) ? '* ' : ''}${standing.spotName}',
                    '${standing.votes} votes',
                    style: PixelType.body(context),
                    labelColor: data.previous!.coWinnerIds
                            .contains(standing.candidateId)
                        ? PixelPalette.greenDark
                        : PixelPalette.ink,
                    valueColor: PixelPalette.gold,
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
          ],
          SizedBox(height: grid.px(1)),
          PixelText.rich(
            '{gold:${summary.verifiedVisits}} verified visits · {green:${summary.uniqueDestinations}} destinations · {blue:${summary.municipalities}} municipalities',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          if (summary.challenges.isNotEmpty) ...[
            SizedBox(height: grid.px(2)),
            for (final challenge in summary.challenges.take(2))
              Text(
                '${challenge.complete ? 'Done' : 'Next'}: ${challenge.title}: ${challenge.progress}/${challenge.target}',
                style: PixelType.body(context),
              ),
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
            '+${quest.explorerXp} Explorer XP · expires ${quest.expiresAt.toLocal()}',
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

  String _manilaDate(DateTime value) => value
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 16)
      .replaceFirst('T', ' ');
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

  Future<void> _confirm(String candidateId, String name, int version) async {
    final accepted = await showPixelDialog<bool>(
      context: context,
      title: 'Confirm JuanChoice vote',
      message:
          'Vote for $name? This free promotional vote gives the same participation reward regardless of the winner. No mJDQ is spent.',
      actions: [
        PixelButton(
          label: 'Cancel',
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PixelButton(
          key: const ValueKey('choice_confirm_vote'),
          label: 'Confirm vote',
          onPressed: () => Navigator.of(context).pop(true),
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
    final detail = ref.watch(choiceDetailProvider(widget.campaignId));
    final overview = ref.watch(choiceOverviewProvider).asData?.value;
    final vote = ref.watch(choiceVoteProvider);
    final authenticated = ref.watch(authProvider).isAuthenticated;
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
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelPanel(
          style: PixelBoxStyle.wood,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.campaign.theme,
                style: PixelType.title(context, color: PixelPalette.paper),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                '${data.campaign.region} · ${overview?.isCampaignOpen(data.campaign) == true ? 'Voting open' : data.campaign.status}',
                style: PixelType.body(context, color: PixelPalette.cream),
              ),
              Text(
                'Closes ${data.campaign.closesAt.toLocal()}',
                style: PixelType.body(context, color: PixelPalette.cream),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        if (data.ballot != null)
          Text(
            'Your ballot: version ${data.ballot!.version}',
            style: PixelType.body(context),
          ),
        if (authenticated && data.eligibility?.reason == 'ACCOUNT_TOO_NEW')
          Text(
            'Voting unlocks after ${data.eligibility!.eligibleAt?.toLocal() ?? 'your account is 72 hours old'} or after one approved destination visit.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        if (authenticated &&
            data.eligibility == null &&
            overview?.isCampaignOpen(data.campaign) == true)
          Text(
            'Voting eligibility could not be confirmed. Pull to retry.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        if (vote.receipt != null)
          Text(
            'Ballot recorded. Participation reward per round: +25 Civic XP and +1 stamp; 0 mJDQ issued.',
            style: PixelType.body(context, color: PixelPalette.greenDark),
          ),
        if (vote.error != null)
          Text(
            vote.error!,
            style: PixelType.body(context, color: PixelPalette.redDeep),
          ),
        if (!authenticated && overview?.isCampaignOpen(data.campaign) == true)
          PixelButton(
            key: const ValueKey('choice_sign_in'),
            label: 'Sign in to vote',
            expand: true,
            onPressed: () => context.go(
                '/?redirect=${Uri.encodeComponent('/choice/${widget.campaignId}')}'),
          ),
        SizedBox(height: grid.px(2)),
        for (final standing in data.standings) ...[
          PixelPanel(
            key: standing.candidateId == widget.focusCandidateId
                ? _focusKey
                : ValueKey('choice_candidate_${standing.candidateId}'),
            style: standing.candidateId == widget.focusCandidateId
                ? PixelBoxStyle.gold
                : PixelBoxStyle.parchment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standing.spotName,
                  maxLines: 2,
                  style: PixelType.title(context),
                ),
                SizedBox(height: grid.px(1)),
                PixelStatRow(
                  'Provisional votes',
                  '${standing.votes}',
                  style: PixelType.body(context),
                  labelColor: PixelPalette.slate,
                  valueColor: PixelPalette.gold,
                ),
                if (authenticated &&
                    overview?.current?.id == data.campaign.id &&
                    overview?.isCampaignOpen(data.campaign) == true &&
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
                        : () => _confirm(standing.candidateId,
                            standing.spotName, data.ballot?.version ?? 0),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
        if (overview == null || !overview.votingEnabled)
          Text(
            'Voting is temporarily unavailable.',
            style: PixelType.body(context, color: PixelPalette.slate),
          )
        else if (!overview.isCampaignOpen(data.campaign))
          Text(
            'Voting is closed or not yet open. No ballot can be queued offline.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
      ],
    );
  }
}
