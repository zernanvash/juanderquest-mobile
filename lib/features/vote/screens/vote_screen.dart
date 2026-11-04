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
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'eco';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(governanceProvider.notifier).loadGovernanceData();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showSubmitLocationModal(BuildContext context) async {
    _titleController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _selectedCategory = 'eco';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final grid = PixelGrid.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              grid.px(3),
              grid.px(3),
              grid.px(3),
              grid.px(3) + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: PixelPanel(
                style: PixelBoxStyle.parchment,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Suggest New Location',
                        style: PixelType.title(context)),
                    SizedBox(height: grid.px(1)),
                    Text(
                      'Suggest a destination for community review. The current pilot reviews Pangasinan locations.',
                      style:
                          PixelType.body(context, color: PixelPalette.slate),
                    ),
                    SizedBox(height: grid.px(3)),
                    PixelTextField(
                      key: const ValueKey('suggest_title'),
                      controller: _titleController,
                      label: 'Destination spot title',
                      hint: 'e.g. Patar White Beach Eco Trail',
                    ),
                    SizedBox(height: grid.px(2)),
                    PixelTextField(
                      key: const ValueKey('suggest_location'),
                      controller: _locationController,
                      label: 'Municipality / Location',
                      hint: 'e.g. Municipality, province',
                    ),
                    SizedBox(height: grid.px(2)),
                    Text('Category',
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        )),
                    SizedBox(height: grid.px(1)),
                    PixelSegmented(
                      items: const ['Eco-Tourism', 'Cultural', 'Food'],
                      selectedIndex: _selectedCategory == 'eco'
                          ? 0
                          : _selectedCategory == 'cultural'
                              ? 1
                              : 2,
                      onChanged: (index) => setSheetState(() {
                        _selectedCategory = switch (index) {
                          0 => 'eco',
                          1 => 'cultural',
                          _ => 'food_trade',
                        };
                      }),
                    ),
                    SizedBox(height: grid.px(2)),
                    PixelTextField(
                      key: const ValueKey('suggest_description'),
                      controller: _descriptionController,
                      label: 'Description & significance',
                      hint: 'Describe why this destination should be featured',
                      maxLines: 3,
                    ),
                    SizedBox(height: grid.px(3)),
                    PixelButton(
                      key: const ValueKey('suggest_submit'),
                      label: 'Submit proposal to screening',
                      expand: true,
                      onPressed: () async {
                        if (_titleController.text.trim().isEmpty ||
                            _locationController.text.trim().isEmpty) {
                          showPixelToast(
                            context,
                            'Please fill out the destination title and location.',
                          );
                          return;
                        }

                        final title = _titleController.text.trim();
                        final location = _locationController.text.trim();
                        final desc =
                            _descriptionController.text.trim().isEmpty
                                ? 'Community-suggested destination.'
                                : _descriptionController.text.trim();

                        Navigator.of(sheetContext).pop();

                        final success = await ref
                            .read(governanceProvider.notifier)
                            .createAndSubmitProposal(
                              title: title,
                              locationName: location,
                              category: _selectedCategory,
                              description: desc,
                            );

                        if (!mounted || !context.mounted) return;
                        final err = ref.read(governanceProvider).error;
                        showPixelToast(
                          context,
                          success
                              ? 'Proposal "$title" submitted for admin screening!'
                              : 'Submission failed: ${err ?? "Unknown error."}',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
                        icon: Wave3Art.plus,
                        semanticLabel: 'Suggest Location',
                        onPressed: () => _showSubmitLocationModal(context),
                      ),
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
