import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';

/// PermissionStateCard explains location/camera requirements with action button.
class PermissionStateCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  const PermissionStateCard({
    super.key,
    this.title = 'Location Access Required',
    this.description = 'JuanderQuest requires GPS to verify your proximity for quest completions and distance estimates.',
    this.icon = Icons.location_off_rounded,
    this.actionLabel = 'Enable Location',
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.crowdModerateBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.woodBrown),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.headlineSmall.copyWith(color: AppColors.woodBrown),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: actionLabel,
            onPressed: onAction,
            icon: Icons.security_rounded,
          ),
        ],
      ),
    );
  }
}
