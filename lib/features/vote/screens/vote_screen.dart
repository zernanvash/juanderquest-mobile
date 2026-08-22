import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/primary_button.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/governance_proposal_model.dart';
import '../providers/governance_provider.dart';
import '../../../core/widgets/designer_guide.dart';

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

  void _showVoteConfirmationDialog(GovernanceProposalModel prop, String choice) {
    final walletAsync = ref.read(walletProvider);
    final wallet = walletAsync.asData?.value;
    final currentBalance = wallet?.balanceMjdq ?? 1000;
    final config = ref.read(governanceProvider).config;
    final fee = config?.voteFeeMjdq ?? 10;
    final burnAmount = (fee * (config?.burnPercent ?? 20) / 100).round();
    final escrowAmount = fee - burnAmount;
    final remaining = currentBalance - fee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLowContrast,
                    borderRadius: AppSpacing.roundedPill,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    choice == 'yes' ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                    color: choice == 'yes' ? AppColors.success : AppColors.danger,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Confirm Vote (${choice.toUpperCase()})',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.woodBrown,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Proposal: "${prop.title}"',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.woodBrown,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedMd,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Voting Fee:', style: AppTypography.bodySmall),
                        Text('$fee mJDQ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Burned (Permanent):', style: AppTypography.bodySmall),
                        Text('$burnAmount mJDQ', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Treasury Escrow:', style: AppTypography.bodySmall),
                        Text('$escrowAmount mJDQ', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Remaining Balance:', style: AppTypography.bodySmall),
                        Text('$remaining mJDQ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Cast Vote ($fee mJDQ Fee)',
                onPressed: currentBalance < fee
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);

                        final success = await ref
                            .read(governanceProvider.notifier)
                            .voteOnProposal(proposalId: prop.id, voteType: choice);

                        await ref.read(walletProvider.notifier).fetchWallet();

                        if (!mounted) return;
                        final err = ref.read(governanceProvider).error;

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? 'Vote cast successfully for "${prop.title}"!' : 'Voting failed: ${err ?? "Unknown error"}',
                            ),
                            backgroundColor: success ? AppColors.success : AppColors.danger,
                          ),
                        );
                      },
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmitLocationModal(BuildContext context) {
    _titleController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _selectedCategory = 'eco';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLowContrast,
                    borderRadius: AppSpacing.roundedPill,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggest New Location',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.woodBrown,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Submit a new Pangasinan tourist destination for community governance screening.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Destination Spot Title',
                  hintText: 'e.g. Patar White Beach Eco Trail',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Municipality / Location',
                  hintText: 'e.g. Bolinao, Pangasinan',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'eco', child: Text('Eco-Tourism')),
                  DropdownMenuItem(value: 'cultural', child: Text('Cultural Heritage')),
                  DropdownMenuItem(value: 'food_trade', child: Text('Food & Culinary')),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val ?? 'eco'),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description & Significance',
                  hintText: 'Describe why this destination should be featured...',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              PrimaryButton(
                label: 'Submit Proposal to Screening',
                onPressed: () async {
                  if (_titleController.text.trim().isEmpty || _locationController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill out the destination title and location.')),
                    );
                    return;
                  }

                  final title = _titleController.text.trim();
                  final location = _locationController.text.trim();
                  final desc = _descriptionController.text.trim().isEmpty
                      ? 'Community suggested Pangasinan destination.'
                      : _descriptionController.text.trim();

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);

                  final success = await ref.read(governanceProvider.notifier).createAndSubmitProposal(
                        title: title,
                        locationName: location,
                        category: _selectedCategory,
                        description: desc,
                      );

                  if (!mounted) return;
                  final err = ref.read(governanceProvider).error;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Proposal "$title" submitted for admin screening!'
                            : 'Submission failed: ${err ?? "Unknown error."}',
                      ),
                      backgroundColor: success ? AppColors.success : AppColors.danger,
                    ),
                  );
                },
                icon: Icons.send_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final govState = ref.watch(governanceProvider);
    final walletAsync = ref.watch(walletProvider);
    final wallet = walletAsync.asData?.value;

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: const Text('Community Governance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary),
            tooltip: 'Suggest Location',
            onPressed: () => _showSubmitLocationModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, color: AppColors.woodBrown),
            tooltip: 'View All Proposals',
            onPressed: () => context.push('/vote/proposals'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(governanceProvider.notifier).loadGovernanceData();
          await ref.read(walletProvider.notifier).fetchWallet();
        },
        color: AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),

            // Wallet Balance Header
            UiSpecContainer(
              spec: const UiSpec(
                title: 'DAO Voting Weight Header',
                figmaLayer: '#DAO_Voting_Weight_Card',
                dimensions: 'Full width, Height: ~80dp, Padding: 16dp',
                dataBinding: 'walletProvider.balanceMjdq (or demo balance)',
                stateNotes: 'Dynamic token balance -> Calculates quadratic voting power',
                uxNotes: 'Emerald primary icon with wood brown typography.',
                deferred: true,
              ),
              child: MetricTile(
                label: 'Off-chain Prototype Voting Weight',
                value: '${wallet?.balanceMjdq ?? 1000} mJDQ',
                icon: Icons.how_to_vote_rounded,
                iconColor: AppColors.primary,
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            JdqSectionHeader(
              title: 'Active Community Proposals',
              subtitle: 'Vote on new destinations and quest features for Pangasinan.',
            ),

            AsyncStateView(
              isLoading: govState.isLoading,
              errorMessage: govState.error,
              isEmpty: govState.proposals.isEmpty,
              emptyMessage: 'No Active Proposals',
              emptySubtitle: 'Be the first to suggest a new destination spot!',
              emptyIcon: Icons.how_to_vote_rounded,
              onRetry: () => ref.read(governanceProvider.notifier).loadGovernanceData(),
              content: Column(
                children: govState.proposals.map((prop) {
                  return _buildProposalCard(prop);
                }).toList(),
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGap),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalCard(GovernanceProposalModel prop) {
    final yesPercent = (prop.yesVotes + prop.noVotes) > 0
        ? (prop.yesVotes / (prop.yesVotes + prop.noVotes)) * 100
        : 50.0;

    return UiSpecContainer(
      spec: const UiSpec(
        title: 'DAO Governance Proposal Card',
        figmaLayer: '#DAO_Proposal_Card_Item',
        dimensions: 'Full width, Height: auto (~180dp), Radius: 16dp',
        dataBinding: 'api/v1/proposals (title, category, yesVotes, noVotes, status)',
        stateNotes: 'Active (Green/Red split meter) -> Passed -> Rejected -> Voting confirmation dialog',
        uxNotes: 'Includes Quorum progress bar and yes/no vote buttons with mJDQ fee deduction.',
        deferred: true,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(color: AppColors.borderLowContrast),
          boxShadow: AppSpacing.cardShadow,
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  prop.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                prop.status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prop.title,
            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            prop.locationName,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            prop.description,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),

          // Voting Bar Progress
          ClipRRect(
            borderRadius: AppSpacing.roundedPill,
            child: LinearProgressIndicator(
              value: yesPercent / 100,
              minHeight: 8,
              backgroundColor: AppColors.dangerBg,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Yes: ${prop.yesVotes} (${yesPercent.toInt()}%)',
                  style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'No: ${prop.noVotes} (${(100 - yesPercent).toInt()}%)',
                  style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Vote YES',
                  onPressed: () => _showVoteConfirmationDialog(prop, 'yes'),
                  icon: Icons.thumb_up_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SecondaryButton(
                  label: 'Vote NO',
                  onPressed: () => _showVoteConfirmationDialog(prop, 'no'),
                  icon: Icons.thumb_down_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }
}
