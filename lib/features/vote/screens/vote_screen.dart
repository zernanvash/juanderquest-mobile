import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/governance_proposal_model.dart';
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

  void _showSubmitLocationModal(BuildContext context) {
    _titleController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _selectedCategory = 'eco';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F5),
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
                    color: const Color(0xFFD5C4AC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.add_location_alt_rounded, color: Color(0xFF7D5800), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Suggest New Location',
                    style: GoogleFonts.epilogue(
                      color: const Color(0xFF582F0E),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Submit a new Pangasinan tourist destination for community governance screening.',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF514532), fontSize: 13),
              ),
              const SizedBox(height: 20),

              Text(
                'Destination Spot Title',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Patar White Beach Eco Trail',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5C4AC))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Municipality / Location',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Bolinao, Pangasinan',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5C4AC))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Category',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: const [
                  DropdownMenuItem(value: 'eco', child: Text('Eco-Tourism')),
                  DropdownMenuItem(value: 'cultural', child: Text('Cultural Heritage')),
                  DropdownMenuItem(value: 'food_trade', child: Text('Food & Culinary')),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val ?? 'eco'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5C4AC))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Description & Significance',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe why this destination should be featured as a community quest...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5C4AC))),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
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
                        style: GoogleFonts.plusJakartaSans(),
                      ),
                      backgroundColor: success ? const Color(0xFF2D6A4F) : const Color(0xFFBC4749),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: Text('Submit Proposal to Screening', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: const Color(0xFF6B4B00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
    final walletAsync = ref.watch(walletProvider);
    final wallet = walletAsync.asData?.value;
    final config = govState.config;
    final fee = config?.voteFeeMjdq ?? 10;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Tourism Spot Voting',
          style: GoogleFonts.epilogue(
            color: const Color(0xFF582F0E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF7D5800)),
            tooltip: 'Suggest Location',
            onPressed: () => _showSubmitLocationModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, color: Color(0xFF582F0E)),
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Live Wallet Balance
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFB703)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB703).withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'COMMUNITY GOVERNANCE',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF7D5800),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D6A4F).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF2D6A4F)),
                                  const SizedBox(width: 4),
                                  Text(
                                    wallet != null ? '${wallet.balanceMjdq} mJDQ' : '1,000 mJDQ',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF2D6A4F),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Govern Pangasinan Tourism Spots',
                      style: GoogleFonts.epilogue(
                        color: const Color(0xFF582F0E),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cast paid binary votes ($fee mJDQ per vote) to approve destination proposals. ${config?.burnPercent.toStringAsFixed(0) ?? '20'}% is burned, ${config?.escrowPercent.toStringAsFixed(0) ?? '80'}% enters community reward escrow.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF514532),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showSubmitLocationModal(context),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: Text('Suggest New Location', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB703),
                        foregroundColor: const Color(0xFF6B4B00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Active Proposals',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.epilogue(
                        color: const Color(0xFF0D1B2A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/vote/proposals'),
                    icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF7D5800)),
                    label: Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF7D5800),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (govState.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFFFFB703))))
              else if (govState.proposals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD5C4AC)),
                  ),
                  child: Center(
                    child: Text(
                      'No active proposals available at the moment.',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560)),
                    ),
                  ),
                )
              else
                ...govState.proposals.map((prop) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildProposalCard(prop),
                )),
            ],
          ),
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEEEA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    prop.categoryDisplay,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF837560),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
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
                    overflow: TextOverflow.ellipsis,
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
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.thumb_up_alt_rounded, size: 14, color: Color(0xFF2D6A4F)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'YES: ${prop.yesVotes} (${prop.yesPercentage.toStringAsFixed(0)}%)',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2D6A4F)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 12, color: const Color(0xFFD5C4AC)),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.thumb_down_alt_rounded, size: 14, color: Color(0xFFBC4749)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'NO: ${prop.noVotes} (${prop.noPercentage.toStringAsFixed(0)}%)',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFBC4749)),
                        ),
                      ),
                    ],
                  ),
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
