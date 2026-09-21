import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/designer_guide.dart';
import '../providers/juanchoice_provider.dart';
import '../../auth/providers/auth_provider.dart';

class JuanChoiceScreen extends ConsumerWidget {
  const JuanChoiceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(choiceCampaignsProvider);
    final supporterQuest = ref.watch(choiceSupporterQuestProvider);
    final engagement = ref.watch(choiceEngagementProvider);
    final claimState = ref.watch(choiceSupporterClaimProvider);
    final authenticated = ref.watch(authProvider).isAuthenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('JuanChoice')),
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(choiceCampaignsProvider),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Community spotlight votes are free and separate from governance voting.'),
          const SizedBox(height: 12),
          if (authenticated) engagement.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
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
            error: (error, stackTrace) => const SizedBox.shrink(),
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
          campaigns.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Column(children: [
              const Text('Campaigns unavailable. Please try again.'),
              PrimaryButton(label: 'Retry', onPressed: () => ref.invalidate(choiceCampaignsProvider)),
            ]),
            data: (items) => items.isEmpty
                ? const Text('No public campaigns are available right now.')
                : Column(children: [for (final campaign in items)
                    Card(child: ListTile(
                      title: Text(campaign.theme),
                      subtitle: Text('${campaign.region} · ${campaign.status}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/choice/${campaign.id}'),
                    ))]),
          ),
        ]),
      )),
    );
  }
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
    final vote = ref.watch(choiceVoteProvider);
    final authenticated = ref.watch(authProvider).isAuthenticated;
    return Scaffold(appBar: AppBar(title: const Text('Community choice')),
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(choiceDetailProvider(widget.campaignId)),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Column(children: [
              const Text('Campaign unavailable. Please try again.'),
              PrimaryButton(label: 'Retry', onPressed: () => ref.invalidate(choiceDetailProvider(widget.campaignId))),
            ]),
            data: (data) => UiSpecContainer(
              spec: const UiSpec(title: 'JuanChoice ballot', figmaLayer: 'Community Choice',
                dimensions: 'Full width, responsive vertical list',
                dataBinding: '/juanchoice/campaigns/:id, /me, /ballot',
                stateNotes: 'Loading, closed, confirmed, conflict and retry',
                uxNotes: 'Free promotional voting distinct from governance', deferred: false),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data.campaign.theme, style: Theme.of(context).textTheme.headlineSmall),
                Text('${data.campaign.region} · ${data.campaign.status}'),
                Text('Closes ${data.campaign.closesAt.toLocal()}'),
                if (data.ballot != null) Text('Your ballot: version ${data.ballot!.version}'),
                if (vote.receipt != null) const Text('Ballot recorded. Participation reward per round: +25 Civic XP and +1 stamp; 0 mJDQ issued.'),
                if (vote.error != null) Text(vote.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                if (!authenticated && data.campaign.isOpen) PrimaryButton(
                  label: 'Sign in to vote',
                  onPressed: () => context.go('/?redirect=${Uri.encodeComponent('/choice/${widget.campaignId}')}'),
                ),
                for (final standing in data.standings) Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(standing.spotName),
                    Text('${standing.votes} provisional votes'),
                    if (authenticated && data.campaign.isOpen) PrimaryButton(
                      label: vote.pending ? 'Submitting…' : data.ballot == null ? 'Vote for this place' : 'Change vote',
                      onPressed: vote.pending ? null : () => _confirm(standing.candidateId,
                        standing.spotName, data.ballot?.version ?? 0)),
                  ]),
                )),
                if (!data.campaign.isOpen) const Text('Voting is closed. No ballot can be queued offline.'),
              ]),
            ),
          ),
        ]),
      )),
    );
  }
}
