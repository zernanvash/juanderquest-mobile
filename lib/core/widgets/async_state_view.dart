import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';

/// AsyncStateView handles loading skeletons, empty states, and retryable errors.
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final String emptyMessage;
  final String emptySubtitle;
  final IconData emptyIcon;
  final VoidCallback? onRetry;
  final Widget content;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    this.errorMessage,
    required this.isEmpty,
    this.emptyMessage = 'No items found',
    this.emptySubtitle = 'Try adjusting your filters or check back later.',
    this.emptyIcon = Icons.explore_off_rounded,
    this.onRetry,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sectionGap),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: AppSpacing.md),
              Text(
                'Discovering Pangasinan...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Connection Issue',
                style: AppTypography.headlineSmall.copyWith(color: AppColors.woodBrown),
              ),
              const SizedBox(height: 6),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 180,
                  child: PrimaryButton(
                    label: 'Try Again',
                    onPressed: onRetry,
                    icon: Icons.refresh_rounded,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 44, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                emptyMessage,
                style: AppTypography.headlineSmall.copyWith(color: AppColors.woodBrown),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 160,
                  child: SecondaryButton(
                    label: 'Refresh',
                    onPressed: onRetry,
                    icon: Icons.refresh_rounded,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return content;
  }
}
