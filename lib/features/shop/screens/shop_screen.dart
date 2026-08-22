import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/primary_button.dart';
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
            shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
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
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.roundedMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cost Deduction:', style: AppTypography.bodySmall),
                        Text(
                          '-${voucher.costPoints} PTS',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.roundedMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Remaining Balance:', style: AppTypography.bodySmall),
                        Text(
                          '$remainingPoints PTS',
                          style: TextStyle(
                            color: AppColors.primary,
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
                                      .redeemVoucher(voucher.id);

                                  if (dialogCtx.mounted) {
                                    Navigator.of(dialogCtx).pop();
                                  }

                                  if (context.mounted) {
                                    if (result.success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Redeemed "${voucher.offerTitle}"! Code: ${result.code ?? "JDQ-REDEEMED"}'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final points = user?.points ?? user?.demoPoints ?? 1250;
    final voucherState = ref.watch(voucherProvider);

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: const Text('Merchant Voucher Catalog'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          MetricTile(
            label: 'Available Reward Balance',
            value: '$points PTS',
            icon: Icons.stars_rounded,
            iconColor: AppColors.sunGold,
            backgroundColor: AppColors.surfaceContainerLowest,
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          JdqSectionHeader(
            title: 'Pangasinan Partner Merchants',
            subtitle: 'Redeem local vouchers using points earned from verified quests.',
          ),

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

          const SizedBox(height: AppSpacing.sectionGap),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.crowdQuietBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.offerTitle,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voucher.merchantName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.crowdModerateBg,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  '${voucher.costPoints} PTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.woodBrown,
                  ),
                ),
              ),
            ],
          ),
          if (voucher.description != null && voucher.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              voucher.description!,
              style: AppTypography.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: canAfford ? 'Redeem Voucher' : 'Insufficient Points (${voucher.costPoints} required)',
            onPressed: canAfford
                ? () => _showVoucherConfirmationDialog(
                      context: context,
                      voucher: voucher,
                      userPoints: userPoints,
                    )
                : null,
            icon: Icons.confirmation_number_rounded,
          ),
        ],
      ),
    );
  }
}
