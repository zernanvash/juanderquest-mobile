import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/app_version_info.dart';
import '../providers/app_update_provider.dart';

class UpdateDialog extends ConsumerWidget {
  final AppVersionInfo versionInfo;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
  });

  static Future<void> show(BuildContext context, AppVersionInfo versionInfo) {
    return showDialog(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !versionInfo.forceUpdate,
        child: UpdateDialog(versionInfo: versionInfo),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final isDownloading = updateState.status == UpdateStatus.downloading;
    final isInstalling = updateState.status == UpdateStatus.installing;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge / Icon
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.sunGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 36,
                  color: AppColors.woodBrown,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              'Update Available!',
              textAlign: TextAlign.center,
              style: AppTypography.displayMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Version info tag
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  'v${updateState.installedVersionName} → v${versionInfo.versionName}',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Changelog Box
            if (versionInfo.changelog.isNotEmpty) ...[
              Text(
                'What\'s New:',
                style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.borderLowContrast),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    versionInfo.changelog,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Progress / Status Message
            if (isDownloading) ...[
              LinearProgressIndicator(
                value: updateState.downloadProgress > 0
                    ? updateState.downloadProgress / 100
                    : null,
                backgroundColor: AppColors.borderLowContrast,
                color: AppColors.primary,
                borderRadius: AppSpacing.roundedPill,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Downloading update: ${updateState.downloadProgress}%',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ] else if (isInstalling) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Preparing installer...'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Error Message
            if (updateState.status == UpdateStatus.error && updateState.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: Text(
                  updateState.errorMessage!,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Action Buttons
            Row(
              children: [
                if (!versionInfo.forceUpdate && !isDownloading && !isInstalling) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  flex: versionInfo.forceUpdate ? 1 : 2,
                  child: ElevatedButton(
                    onPressed: isDownloading || isInstalling
                        ? null
                        : () => ref.read(appUpdateProvider.notifier).startDownloadAndInstall(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    child: Text(
                      isDownloading
                          ? 'Downloading...'
                          : isInstalling
                              ? 'Installing...'
                              : 'Update Now',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onPrimary,
                      ),
                    ),
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
