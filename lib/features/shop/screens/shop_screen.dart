import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(voucherProvider.notifier).fetchVouchers();
    });
  }

  void _showVoucherConfirmationDialog({
    required BuildContext context,
    required VoucherModel voucher,
    required int userPoints,
  }) {
    final remainingPoints = userPoints - voucher.costPoints;

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer(
        builder: (context, ref, _) {
          final isRedeeming = ref.watch(voucherProvider).isRedeeming;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFFFAF9F5),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBEEAD1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF2D6A4F), size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Redeem Voucher?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.epilogue(
                        color: const Color(0xFF582F0E),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are about to redeem "${voucher.offerTitle}" from ${voucher.merchantName}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF514532),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Cost Deduction:',
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 12),
                            ),
                          ),
                          Text(
                            '-${voucher.costPoints} PTS',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFBC4749),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Remaining Balance:',
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 12),
                            ),
                          ),
                          Text(
                            '$remainingPoints PTS',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF7D5800),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isRedeeming ? null : () => Navigator.of(dialogCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFD5C4AC)),
                            ),
                            child: Text('Cancel', style: GoogleFonts.epilogue(color: const Color(0xFF514532))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isRedeeming
                                ? null
                                : () async {
                                    final res = await ref
                                        .read(voucherProvider.notifier)
                                        .redeemVoucher(voucher.id);

                                    if (!context.mounted) return;
                                    Navigator.of(dialogCtx).pop();

                                    final messenger = ScaffoldMessenger.of(context);
                                    if (res.success) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Voucher "${voucher.offerTitle}" redeemed! Present code ${res.code} to merchant.',
                                            style: GoogleFonts.plusJakartaSans(),
                                          ),
                                          backgroundColor: const Color(0xFF2D6A4F),
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Redemption failed: ${res.error}',
                                            style: GoogleFonts.plusJakartaSans(),
                                          ),
                                          backgroundColor: const Color(0xFFBC4749),
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB703),
                              foregroundColor: const Color(0xFF6B4B00),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isRedeeming
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B4B00)),
                                  )
                                : Text('Confirm', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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
    final user = ref.watch(authProvider).user;
    final points = user?.demoPoints ?? 0;
    final voucherState = ref.watch(voucherProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Merchant Voucher Store',
          style: GoogleFonts.epilogue(
            color: const Color(0xFF582F0E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Points Balance Banner
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVAILABLE REWARDS',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF837560),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Demo Points Balance',
                          style: GoogleFonts.epilogue(
                            color: const Color(0xFF582F0E),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/jdq-token.png',
                          width: 24,
                          height: 24,
                          errorBuilder: (_, __, ___) => const Icon(Icons.stars, color: Color(0xFFFFB703), size: 24),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$points PTS',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.epilogue(
                              color: const Color(0xFF7D5800),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Pangasinan Partner Merchants',
              style: GoogleFonts.epilogue(
                color: const Color(0xFF0D1B2A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (voucherState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                ),
              )
            else if (voucherState.error != null && voucherState.vouchers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD5C4AC)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFBC4749)),
                      const SizedBox(height: 8),
                      Text(
                        voucherState.error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.read(voucherProvider.notifier).fetchVouchers(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB703),
                          foregroundColor: const Color(0xFF6B4B00),
                        ),
                        child: Text('Retry', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              )
            else if (voucherState.vouchers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD5C4AC)),
                ),
                child: Center(
                  child: Text(
                    'No active merchant vouchers available right now.',
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560)),
                  ),
                ),
              )
            else
              ...voucherState.vouchers.map(
                (voucher) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildVoucherCard(
                    context: context,
                    voucher: voucher,
                    userPoints: points,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherCard({
    required BuildContext context,
    required VoucherModel voucher,
    required int userPoints,
  }) {
    final canAfford = userPoints >= voucher.costPoints;
    final isRedeeming = ref.watch(voucherProvider).isRedeeming;

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
                    color: const Color(0xFF3F6653).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    voucher.category.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF3F6653),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/jdq-token.png',
                      width: 16,
                      height: 16,
                      errorBuilder: (_, __, ___) => const Icon(Icons.stars, color: Color(0xFFFFB703), size: 14),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${voucher.costPoints} PTS',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF7D5800),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            voucher.offerTitle,
            style: GoogleFonts.epilogue(
              color: const Color(0xFF582F0E),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            voucher.merchantName,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1B1C1A), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            voucher.location,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: (canAfford && !isRedeeming)
                ? () => _showVoucherConfirmationDialog(
                      context: context,
                      voucher: voucher,
                      userPoints: userPoints,
                    )
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: const Color(0xFF6B4B00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              canAfford ? 'Redeem Voucher' : 'Insufficient Demo Points',
              style: GoogleFonts.epilogue(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
