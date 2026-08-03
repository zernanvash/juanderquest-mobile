import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../wallet/providers/wallet_provider.dart';
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
      backgroundColor: const Color(0xFFFAF9F5),
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
                    color: const Color(0xFFD5C4AC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    choice == 'yes' ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                    color: choice == 'yes' ? const Color(0xFF2D6A4F) : const Color(0xFFBC4749),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Confirm Vote (${choice.toUpperCase()})',
                    style: GoogleFonts.epilogue(
                      color: const Color(0xFF582F0E),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Target: "${prop.title}"',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF582F0E),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD5C4AC)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text('Vote Fee:', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF514532)))),
                        Text('$fee mJDQ (${(fee / 1000.0).toStringAsFixed(2)} JDQ)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF7D5800))),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text('Burn Allocation (${config?.burnPercent.toStringAsFixed(0) ?? '20'}%):', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 12))),
                        Text('$burnAmount mJDQ', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFBC4749), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text('Reward Escrow (${config?.escrowPercent.toStringAsFixed(0) ?? '80'}%):', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 12))),
                        Text('$escrowAmount mJDQ', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF2D6A4F), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text('Balance After:', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold))),
                        Text('$remaining mJDQ', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: GoogleFonts.epilogue(color: const Color(0xFF582F0E))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        final success = await ref.read(governanceProvider.notifier).castVote(
                              proposalId: prop.id,
                              choice: choice,
                            );

                        if (!mounted) return;
                        final error = ref.read(governanceProvider).error;

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Vote cast successfully! $fee mJDQ fee processed.'
                                  : 'Vote failed: ${error ?? "Check balance and eligibility."}',
                              style: GoogleFonts.plusJakartaSans(),
                            ),
                            backgroundColor: success ? const Color(0xFF2D6A4F) : const Color(0xFFBC4749),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: choice == 'yes' ? const Color(0xFF2D6A4F) : const Color(0xFFBC4749),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Cast ${choice.toUpperCase()} Vote',
                        style: GoogleFonts.epilogue(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final govState = ref.watch(governanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF582F0E)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'All Proposals',
          style: GoogleFonts.epilogue(
            color: const Color(0xFF582F0E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(governanceProvider.notifier).loadGovernanceData();
        },
        child: govState.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)))
            : govState.proposals.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No community proposals found.',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560)),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: govState.proposals.length,
                    itemBuilder: (context, index) {
                      final prop = govState.proposals[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildProposalCard(prop),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildProposalCard(GovernanceProposalModel prop) {
    final userVote = ref.watch(governanceProvider).userVotes[prop.id];
    final hasVoted = userVote != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEEEA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prop.categoryDisplay,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF837560),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: prop.status == 'approved'
                      ? const Color(0xFF2D6A4F).withValues(alpha: 0.15)
                      : prop.status == 'voting'
                          ? const Color(0xFFFFB703).withValues(alpha: 0.15)
                          : const Color(0xFF837560).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prop.status.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: prop.status == 'approved'
                        ? const Color(0xFF2D6A4F)
                        : prop.status == 'voting'
                            ? const Color(0xFF7D5800)
                            : const Color(0xFF837560),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prop.title,
            style: GoogleFonts.epilogue(
              color: const Color(0xFF582F0E),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            prop.locationName,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            prop.description,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF514532), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.thumb_up_alt_rounded, size: 14, color: Color(0xFF2D6A4F)),
                    const SizedBox(width: 4),
                    Text(
                      'YES: ${prop.yesVotes} (${prop.yesPercentage.toStringAsFixed(0)}%)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2D6A4F)),
                    ),
                  ],
                ),
                Container(width: 1, height: 12, color: const Color(0xFFD5C4AC)),
                Row(
                  children: [
                    const Icon(Icons.thumb_down_alt_rounded, size: 14, color: Color(0xFFBC4749)),
                    const SizedBox(width: 4),
                    Text(
                      'NO: ${prop.noVotes} (${prop.noPercentage.toStringAsFixed(0)}%)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFBC4749)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (hasVoted)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Vote Cast: ${userVote.toUpperCase()}',
                  style: GoogleFonts.epilogue(color: const Color(0xFF2D6A4F), fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showVoteConfirmationDialog(prop, 'yes'),
                    icon: const Icon(Icons.thumb_up_rounded, size: 16),
                    label: Text('Vote YES', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showVoteConfirmationDialog(prop, 'no'),
                    icon: const Icon(Icons.thumb_down_rounded, size: 16),
                    label: Text('Vote NO', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBC4749),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
