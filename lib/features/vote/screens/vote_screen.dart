import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/governance_proposal_model.dart';
import '../pixel/wave3_art.dart';
import '../providers/governance_provider.dart';

class VoteScreen extends ConsumerStatefulWidget {
  const VoteScreen({super.key});

  @override
  ConsumerState<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends ConsumerState<VoteScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(governanceProvider.notifier).loadGovernanceData();
    });
  }

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
                    title: 'Community Governance',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    actions: [
                      PixelIconButton(
                        icon: Wave3Art.list,
                        semanticLabel: 'View All Proposals',
                        onPressed: () => context.push('/vote/proposals'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: () async {
                        await ref
                            .read(governanceProvider.notifier)
                            .loadGovernanceData();
                        await ref
                            .read(walletProvider.notifier)
                            .fetchWallet();
                      },
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          grid.px(4),
                          grid.px(3),
                          grid.px(4),
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          _retired(context, grid),
                          SizedBox(height: grid.px(3)),
                          PixelButton(
                            key: const ValueKey('vote_choice'),
                            label: 'Go to JuanChoice voting',
                            expand: true,
                            onPressed: () => context.push('/choice'),
                          ),
                          SizedBox(height: grid.px(3)),
                          Text('Historical Proposals (Archive)',
                              style: PixelType.title(context)),
                          SizedBox(height: grid.px(1)),
                          Text(
                            'Past governance proposals recorded for transparency and auditability.',
                            style: PixelType.body(
                              context,
                              color: PixelPalette.slate,
                            ),
                          ),
                          SizedBox(height: grid.px(3)),
                          if (govState.isLoading)
                            const Center(
                                child:
                                    PixelLoader(label: 'Loading proposals'))
                          else if (govState.error != null &&
                              govState.proposals.isEmpty)
                            PixelPanel(
                              style: PixelBoxStyle.red,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      key: const ValueKey('vote_retry'),
                                      label: 'Retry',
                                      onPressed: () => ref
                                          .read(governanceProvider.notifier)
                                          .loadGovernanceData(),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (govState.proposals.isEmpty)
                            const PixelEmptyState(
                              key: ValueKey('vote_empty'),
                              title: 'No active proposals',
                              message:
                                  'Be the first to suggest a new destination spot!',
                            )
                          else
                            for (final proposal in govState.proposals) ...[
                              _proposal(context, grid, proposal),
                              SizedBox(height: grid.px(2)),
                            ],
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

  Widget _retired(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voting System Retired', style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(
            'Destination approval and proposal voting have been retired. All destination posts are published immediately. Community voting is now conducted exclusively in JuanChoice.',
            style: PixelType.body(context, color: PixelPalette.goldDeep),
          ),
        ],
      ),
    );
  }

  Widget _proposal(
      BuildContext context, PixelGrid grid, GovernanceProposalModel prop) {
    final total = prop.yesVotes + prop.noVotes;
    final yesPercent = total > 0 ? prop.yesVotes / total : 0.5;
    return PixelPanel(
      key: ValueKey('proposal_${prop.id}'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelChip(prop.category.toUpperCase()),
              PixelChip(prop.status.toUpperCase(),
                  style: PixelBoxStyle.slot),
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
          PixelProgressBar(value: yesPercent),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              Text(
                'Yes: ${prop.yesVotes} (${(yesPercent * 100).toInt()}%)',
                style: PixelType.small(
                  context,
                  color: PixelPalette.greenDark,
                ),
              ),
              Text(
                'No: ${prop.noVotes} (${(100 - yesPercent * 100).toInt()}%)',
                style: PixelType.small(context, color: PixelPalette.redDeep),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
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
