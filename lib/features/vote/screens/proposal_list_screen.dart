import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/governance_proposal_model.dart';
import '../providers/governance_provider.dart';

class ProposalListScreen extends ConsumerStatefulWidget {
  const ProposalListScreen({super.key});

  @override
  ConsumerState<ProposalListScreen> createState() => _ProposalListScreenState();
}

class _ProposalListScreenState extends ConsumerState<ProposalListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(governanceProvider.notifier).loadGovernanceData();
    });
  }

  Future<void> _reload() =>
      ref.read(governanceProvider.notifier).loadGovernanceData();

  @override
  Widget build(BuildContext context) {
    final govState = ref.watch(governanceProvider);
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
                    title: 'All Proposals',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    actions: [
                      PixelButton(
                        label: 'Refresh',
                        variant: PixelButtonVariant.secondary,
                        onPressed: _reload,
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: _reload,
                      child: govState.isLoading
                          ? ListView(
                              children: [
                                SizedBox(height: grid.px(20)),
                                const Center(
                                    child: PixelLoader(
                                        label: 'Loading proposals')),
                              ],
                            )
                          : govState.error != null && govState.proposals.isEmpty
                              ? ListView(
                                  padding: EdgeInsets.all(grid.px(4)),
                                  children: [
                                    PixelPanel(
                                      style: PixelBoxStyle.red,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            govState.error!,
                                            style: PixelType.body(
                                              context,
                                              color: PixelPalette.white,
                                            ),
                                          ),
                                          SizedBox(height: grid.px(2)),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: PixelButton(
                                              key: const ValueKey(
                                                  'proposals_retry'),
                                              label: 'Retry',
                                              onPressed: _reload,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : govState.proposals.isEmpty
                                  ? ListView(
                                      children: [
                                        SizedBox(height: grid.px(12)),
                                        const PixelEmptyState(
                                          key: ValueKey('proposals_empty'),
                                          title: 'No community proposals',
                                          message:
                                              'No community proposals found.',
                                        ),
                                      ],
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.fromLTRB(
                                        grid.px(4),
                                        grid.px(3),
                                        grid.px(4),
                                        grid.px(8) +
                                            MediaQuery.paddingOf(context)
                                                .bottom,
                                      ),
                                      itemCount: govState.proposals.length,
                                      itemBuilder: (context, index) {
                                        final prop =
                                            govState.proposals[index];
                                        return Padding(
                                          padding: EdgeInsets.only(
                                              bottom: grid.px(2)),
                                          child: _proposalCard(
                                              context, grid, prop),
                                        );
                                      },
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

  Widget _proposalCard(
      BuildContext context, PixelGrid grid, GovernanceProposalModel prop) {
    final userVote = ref.watch(governanceProvider).userVotes[prop.id];
    final hasVoted = userVote != null;
    final statusStyle = prop.status == 'approved'
        ? PixelBoxStyle.green
        : prop.status == 'voting'
            ? PixelBoxStyle.gold
            : PixelBoxStyle.slot;
    return PixelPanel(
      key: ValueKey('proposal_card_${prop.id}'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelChip(prop.categoryDisplay),
              PixelChip(
                prop.status.toUpperCase(),
                style: statusStyle,
                textColor: prop.status == 'approved'
                    ? PixelPalette.white
                    : PixelPalette.ink,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(prop.title, style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(
            prop.locationName,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Text(
            prop.description,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(3),
            runSpacing: grid.px(1),
            children: [
              Text(
                'YES: ${prop.yesVotes} (${prop.yesPercentage.toStringAsFixed(0)}%)',
                style: PixelType.small(
                  context,
                  color: PixelPalette.greenDark,
                ),
              ),
              Text(
                'NO: ${prop.noVotes} (${prop.noPercentage.toStringAsFixed(0)}%)',
                style: PixelType.small(context, color: PixelPalette.redDeep),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          PixelProgressBar(
            value: prop.yesPercentage / 100,
            color: PixelPalette.greenBright,
          ),
          SizedBox(height: grid.px(2)),
          if (hasVoted)
            PixelPanel(
              style: PixelBoxStyle.green,
              child: Text(
                'Vote Cast: ${userVote.toUpperCase()}',
                textAlign: TextAlign.center,
                style: PixelType.body(context, color: PixelPalette.white),
              ),
            )
          else
            PixelPanel(
              style: PixelBoxStyle.slot,
              padding: 2,
              child: Text(
                'Archived Proposal · Voting Closed',
                textAlign: TextAlign.center,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            ),
        ],
      ),
    );
  }
}
