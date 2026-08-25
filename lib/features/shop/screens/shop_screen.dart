import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';
import '../../../core/widgets/designer_guide.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _selectedTab = 0; // 0 = Browse Offers, 1 = My Vouchers

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
    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer(
        builder: (context, ref, _) {
          final isRedeeming = ref.watch(voucherProvider).isRedeeming;

          return Dialog(
            shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
            backgroundColor: AppColors.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.crowdQuietBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Redeem Voucher?',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.woodBrown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You are about to redeem "${voucher.offerTitle}" from ${voucher.merchantName}.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.roundedMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cost Deduction:', style: AppTypography.bodySmall),
                        Text(
                          '-${voucher.costPoints} PTS',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Cancel',
                          onPressed: isRedeeming ? null : () => Navigator.of(dialogCtx).pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Confirm',
                          isLoading: isRedeeming,
                          onPressed: isRedeeming
                              ? null
                              : () async {
                                  final result = await ref
                                      .read(voucherProvider.notifier)
                                      .redeemVoucher(voucher);

                                  if (dialogCtx.mounted) {
                                    Navigator.of(dialogCtx).pop();
                                  }

                                  if (context.mounted) {
                                    if (result.success && result.redeemed != null) {
                                      _showRedeemedVoucherModal(context, result.redeemed!);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(result.error ?? ref.read(voucherProvider).error ?? 'Redemption failed.'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRedeemedVoucherModal(BuildContext context, RedeemedVoucherModel redeemed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.borderLowContrast,
                  borderRadius: AppSpacing.roundedPill,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.crowdQuietBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Voucher Ready to Use!',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.woodBrown,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                redeemed.offerTitle,
                textAlign: TextAlign.center,
                style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text(
                redeemed.merchantName,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Code Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.sunGold, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text(
                      'MERCHANT REDEMPTION CODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      redeemed.code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: AppColors.woodBrown,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: redeemed.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Voucher code copied to clipboard!'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Copy Code',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Simulated QR / Barcode Display
              UiSpecContainer(
                spec: const UiSpec(
                  title: 'In-Person Store Cashier Barcode & QR Box',
                  figmaLayer: '#Voucher_QR_Redemption_Box',
                  dimensions: 'Width: 100%, Height: ~80dp, Padding: 12dp',
                  dataBinding: 'redeemedVoucher.code / expirationTimestamp',
                  stateNotes: 'Displays 1D barcode stripes & QR scan box for retail cashier terminal',
                  uxNotes: 'Ensure screen backlight brightness is sufficient for optical scanners.',
                  deferred: true,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.borderLowContrast),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          24,
                          (index) => Container(
                            width: index % 3 == 0 ? 3 : (index % 2 == 0 ? 2 : 1),
                            height: 38,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Present this barcode/code to the store cashier',
                        style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              PrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(modalCtx).pop(),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final points = user?.points ?? user?.demoPoints ?? 1250;
    final voucherState = ref.watch(voucherProvider);

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: const Text('Rewards & Vouchers'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),

          // Balance Card
          UiSpecContainer(
            spec: const UiSpec(
              title: 'Available Reward Points Balance',
              figmaLayer: '#Shop_Points_Balance_Card',
              dimensions: 'Full width, Height: ~80dp, Padding: 16dp',
              dataBinding: 'authProvider.user.points (or demoPoints fallback)',
              stateNotes: 'Dynamic points balance -> Updates instantly on voucher redemption',
              uxNotes: 'Sun Gold icon with wood brown typography.',
            ),
            child: MetricTile(
              label: 'Available Reward Balance',
              value: '$points PTS',
              icon: Icons.stars_rounded,
              iconColor: AppColors.sunGold,
              backgroundColor: AppColors.surfaceContainerLowest,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Tab Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.roundedPill,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppColors.surfaceContainerLowest : Colors.transparent,
                        borderRadius: AppSpacing.roundedPill,
                        boxShadow: _selectedTab == 0 ? AppSpacing.cardShadow : null,
                      ),
                      child: Text(
                        'Partner Merchants',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                          color: _selectedTab == 0 ? AppColors.woodBrown : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppColors.surfaceContainerLowest : Colors.transparent,
                        borderRadius: AppSpacing.roundedPill,
                        boxShadow: _selectedTab == 1 ? AppSpacing.cardShadow : null,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'My Vouchers',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                              color: _selectedTab == 1 ? AppColors.woodBrown : AppColors.textSecondary,
                            ),
                          ),
                          if (voucherState.redeemedVouchers.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryDark,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${voucherState.redeemedVouchers.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          if (_selectedTab == 0) ...[
            // Partner Merchants List
            AsyncStateView(
              isLoading: voucherState.isLoading,
              errorMessage: voucherState.error,
              isEmpty: voucherState.vouchers.isEmpty,
              emptyMessage: 'No Active Vouchers',
              emptySubtitle: 'Check back soon for new partner merchant offers.',
              emptyIcon: Icons.storefront_rounded,
              onRetry: () => ref.read(voucherProvider.notifier).fetchVouchers(),
              content: Column(
                children: voucherState.vouchers.map((voucher) {
                  return _buildVoucherCard(
                    context: context,
                    voucher: voucher,
                    userPoints: points,
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            // My Redeemed Vouchers Wallet
            if (voucherState.redeemedVouchers.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.borderLowContrast),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Redeemed Vouchers Yet',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete quests to earn points and redeem exclusive discounts from partner Pangasinan stores!',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SecondaryButton(
                      label: 'Browse Merchant Offers',
                      onPressed: () => setState(() => _selectedTab = 0),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Column(
                children: voucherState.redeemedVouchers.map((redeemed) {
                  return _buildRedeemedCard(context, redeemed);
                }).toList(),
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }

  Widget _buildRedeemedCard(BuildContext context, RedeemedVoucherModel redeemed) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.sunGold, width: 1.2),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.crowdQuietBg,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: const Text(
                  'ACTIVE VOUCHER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Text(
                'Expires in 30 days',
                style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            redeemed.offerTitle,
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.woodBrown,
            ),
          ),
          Text(
            redeemed.merchantName,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.borderLowContrast),
                ),
                child: Text(
                  redeemed.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Show Barcode',
                icon: Icons.qr_code_rounded,
                onPressed: () => _showRedeemedVoucherModal(context, redeemed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard({
    required BuildContext context,
    required VoucherModel voucher,
    required int userPoints,
  }) {
    final canAfford = userPoints >= voucher.costPoints;

    return Container(
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  voucher.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: canAfford ? AppColors.sunGold.withOpacity(0.2) : AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.sunGold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${voucher.costPoints} PTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: canAfford ? AppColors.woodBrown : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            voucher.offerTitle,
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.woodBrown,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  voucher.merchantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  voucher.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          if (voucher.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              voucher.description,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: canAfford ? 'Redeem Voucher' : 'Insufficient Points (${voucher.costPoints - userPoints} needed)',
              onPressed: canAfford
                  ? () => _showVoucherConfirmationDialog(
                        context: context,
                        voucher: voucher,
                        userPoints: userPoints,
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
