import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/designer_guide.dart';
import '../providers/juanchoice_provider.dart';
import '../../auth/providers/auth_provider.dart';

class JuanChoiceScreen extends ConsumerStatefulWidget {
  const JuanChoiceScreen({super.key});
  @override
  ConsumerState<JuanChoiceScreen> createState() => _JuanChoiceScreenState();
}

class _JuanChoiceScreenState extends ConsumerState<JuanChoiceScreen> with WidgetsBindingObserver {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
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
    return Scaffold(
      appBar: AppBar(title: const Text('JuanChoice')),
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(choiceOverviewProvider),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Community spotlight votes are free and separate from governance voting.'),
          const SizedBox(height: 12),
          overview.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Community voting is temporarily unavailable.'),
                SecondaryButton(label: 'Retry', onPressed: () => ref.invalidate(choiceOverviewProvider)),
              ]))),
            data: (data) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (data.current != null) Card(child: ListTile(
                title: Text(data.current!.theme),
                subtitle: Text('Voting closes ${_manilaDate(data.current!.closesAt)} PHT'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/choice/${data.current!.id}'),
              )) else Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Next community vote', style: Theme.of(context).textTheme.titleMedium),
                  Text(data.nextOpensAt == null ? 'The next date has not been confirmed yet.'
                      : 'Opens ${_manilaDate(data.nextOpensAt!)} PHT'),
                  if (data.nextClosesAt != null) Text('Closes ${_manilaDate(data.nextClosesAt!)} PHT'),
                  if (data.nextTheme != null) Text(data.nextTheme!),
                ],
              ))),
              if (data.notice != null) Padding(padding: const EdgeInsets.all(8), child: Text(data.notice!)),
              const SizedBox(height: 8),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Previous results', style: Theme.of(context).textTheme.titleMedium),
                  if (data.previous == null) const Text('Results will appear after the first community round.')
                  else ...[
                    Text('${data.previous!.periodLabel} · ${data.previous!.validBallots} valid ballots'),
                    for (final standing in data.previous!.standings) Text(
                      '${data.previous!.coWinnerIds.contains(standing.candidateId) ? '★ ' : ''}${standing.spotName}: ${standing.votes} votes'),
                    if (data.previous!.coWinnerIds.isEmpty) const Text('No winner this round.'),
                    const Text('Community support is popularity, not a visitor rating.'),
                  ],
                ],
              ))),
            ]),
          ),
          const SizedBox(height: 12),
          if (authenticated) engagement!.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your community journey could not be loaded.'),
                SecondaryButton(label: 'Retry journey', onPressed: () => ref.invalidate(choiceEngagementProvider)),
              ]))),
            data: (summary) => Card(
              child: Padding(padding: const EdgeInsets.all(12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your community journey', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${summary.currentStreak} round streak · longest ${summary.longestStreak}'),
                  if (summary.nextMilestone != null)
                    Text('${summary.nextMilestone! - summary.currentStreak} more official round(s) to your next badge'),
                  Text('${summary.verifiedVisits} verified visits · ${summary.uniqueDestinations} destinations · ${summary.municipalities} municipalities'),
                  if (summary.challenges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final challenge in summary.challenges.take(2))
                      Text('${challenge.complete ? '✓' : '•'} ${challenge.title}: ${challenge.progress}/${challenge.target}'),
                  ],
                ],
              )),
            ),
          ),
          const SizedBox(height: 12),
          supporterQuest.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Visit rewards could not be checked.'),
                SecondaryButton(label: 'Retry visit rewards', onPressed: () => ref.invalidate(choiceSupporterQuestProvider)),
              ]))),
            data: (quest) => quest == null ? const SizedBox.shrink() : Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(padding: const EdgeInsets.all(12),child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,children:[
                  const Text('Visit the community winner',style:TextStyle(fontWeight:FontWeight.bold)),
                  Text(quest.spotName),
                  Text(quest.questDescription,maxLines:3,overflow:TextOverflow.ellipsis),
                  Text('+${quest.explorerXp} Explorer XP · expires ${quest.expiresAt.toLocal()}'),
                  const SizedBox(height:8),
                  if (quest.claimed) const Text('Visit reward claimed') else ...[
                    SecondaryButton(label:'Open destination quest',icon:Icons.directions_walk_rounded,
                      onPressed:()=>context.push('/quests/${quest.questId}')),
                    const SizedBox(height:8),
                    if (authenticated) PrimaryButton(label:'Claim verified visit reward',isLoading:claimState.isLoading,
                      onPressed:()=>ref.read(choiceSupporterClaimProvider.notifier).claim(quest.campaignId))
                    else PrimaryButton(label:'Sign in to claim after your visit',
                      onPressed:()=>context.go('/?redirect=${Uri.encodeComponent('/choice')}')),
                    if (claimState.hasError) Padding(padding:const EdgeInsets.only(top:8),
                      child:Text('${claimState.error}',style:TextStyle(color:Theme.of(context).colorScheme.error))),
                  ],
                ],
              )),
            ),
          ),
          const SizedBox(height: 12),
        ]),
      )),
    );
  }

  String _manilaDate(DateTime value) => value.toUtc().add(const Duration(hours: 8))
      .toIso8601String().substring(0, 16).replaceFirst('T', ' ');
}

class JuanChoiceDetailScreen extends ConsumerStatefulWidget {
  const JuanChoiceDetailScreen({super.key, required this.campaignId});
  final String campaignId;
  @override
  ConsumerState<JuanChoiceDetailScreen> createState() => _JuanChoiceDetailScreenState();
}

class _JuanChoiceDetailScreenState extends ConsumerState<JuanChoiceDetailScreen>
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
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(choiceDetailProvider(widget.campaignId));
      ref.invalidate(choiceOverviewProvider);
    }
  }

  Future<void> _confirm(String candidateId, String name, int version) async {
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm JuanChoice vote'),
      content: Text('Vote for $name? This free promotional vote gives the same participation reward regardless of the winner. No mJDQ is spent.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm vote')),
      ],
    ));
    if (accepted == true && mounted) {
      await ref.read(choiceVoteProvider.notifier).submit(widget.campaignId, candidateId, version);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(choiceDetailProvider(widget.campaignId));
    final overview = ref.watch(choiceOverviewProvider).asData?.value;
    final vote = ref.watch(choiceVoteProvider);
    final authenticated = ref.watch(authProvider).isAuthenticated;
    return Scaffold(appBar: AppBar(title: const Text('Community choice')),
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(choiceOverviewProvider);
          ref.invalidate(choiceDetailProvider(widget.campaignId));
        },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Column(children: [
              const Text('Campaign unavailable. Please try again.'),
              PrimaryButton(label: 'Retry', onPressed: () {
                ref.invalidate(choiceOverviewProvider);
                ref.invalidate(choiceDetailProvider(widget.campaignId));
              }),
            ]),
            data: (data) => UiSpecContainer(
              spec: const UiSpec(title: 'JuanChoice ballot', figmaLayer: 'Community Choice',
                dimensions: 'Full width, responsive vertical list',
                dataBinding: '/juanchoice/campaigns/:id, /me, /ballot',
                stateNotes: 'Loading, closed, confirmed, conflict and retry',
                uxNotes: 'Free promotional voting distinct from governance', deferred: false),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data.campaign.theme, style: Theme.of(context).textTheme.headlineSmall),
                Text('${data.campaign.region} · ${overview?.isCampaignOpen(data.campaign) == true ? 'Voting open' : data.campaign.status}'),
                Text('Closes ${data.campaign.closesAt.toLocal()}'),
                if (data.ballot != null) Text('Your ballot: version ${data.ballot!.version}'),
                if (authenticated && data.eligibility?.reason == 'ACCOUNT_TOO_NEW')
                  Text('Voting unlocks after ${data.eligibility!.eligibleAt?.toLocal() ?? 'your account is 72 hours old'} or after one approved destination visit.'),
                if (authenticated && data.eligibility == null && overview?.isCampaignOpen(data.campaign) == true)
                  const Text('Voting eligibility could not be confirmed. Pull to retry.'),
                if (vote.receipt != null) const Text('Ballot recorded. Participation reward per round: +25 Civic XP and +1 stamp; 0 mJDQ issued.'),
                if (vote.error != null) Text(vote.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                if (!authenticated && overview?.isCampaignOpen(data.campaign) == true) PrimaryButton(
                  label: 'Sign in to vote',
                  onPressed: () => context.go('/?redirect=${Uri.encodeComponent('/choice/${widget.campaignId}')}'),
                ),
                for (final standing in data.standings) Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(standing.spotName),
                    Text('${standing.votes} provisional votes'),
                    if (authenticated && overview?.current?.id == data.campaign.id &&
                        overview?.isCampaignOpen(data.campaign) == true &&
                        data.eligibility?.canVoteNow == true) PrimaryButton(
                      label: vote.pending ? 'Submitting…' : data.ballot == null ? 'Vote for this place' : 'Change vote',
                      onPressed: vote.pending ? null : () => _confirm(standing.candidateId,
                        standing.spotName, data.ballot?.version ?? 0)),
                  ]),
                )),
                if (overview == null || !overview.votingEnabled) const Text('Voting is temporarily unavailable.')
                else if (!overview.isCampaignOpen(data.campaign))
                  const Text('Voting is closed or not yet open. No ballot can be queued offline.'),
              ]),
            ),
          ),
        ]),
      )),
    );
  }
}
