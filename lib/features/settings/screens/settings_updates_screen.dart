import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../app_update/widgets/update_dialog.dart';
import '../../../core/app_release.dart';

/// Settings -> App updates: over-the-air APK check and the installed build.
class SettingsUpdatesScreen extends ConsumerWidget {
  const SettingsUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final isChecking = updateState.status == UpdateStatus.checking;

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(title: const Text('App updates')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          // App System & Updates
          const JdqSectionHeader(
            title: 'App System & Updates',
            subtitle: 'Over-the-air APK releases and build version management.',
          ),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.borderLowContrast),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isChecking
                    ? null
                    : () async {
                        final hasUpdate = await ref
                            .read(appUpdateProvider.notifier)
                            .checkForUpdates(silent: false);
                        if (context.mounted) {
                          final current = ref.read(appUpdateProvider);
                          if (hasUpdate && current.latestVersion != null) {
                            UpdateDialog.show(context, current.latestVersion!);
                          } else if (current.status == UpdateStatus.upToDate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'App is up to date (${versionLabel(current.installedVersionName)} · Build ${current.installedVersionCode}).',
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          } else if (current.status == UpdateStatus.readyToInstall && current.latestVersion != null) {
                            UpdateDialog.show(context, current.latestVersion!);
                          } else if (current.status == UpdateStatus.error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  current.errorMessage ?? 'Unable to check for updates. Please try again.',
                                ),
                                backgroundColor: AppColors.danger,
                                action: SnackBarAction(
                                  label: 'Retry',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    ref.read(appUpdateProvider.notifier).checkForUpdates(silent: false);
                                  },
                                ),
                              ),
                            );
                          }
                        }
                      },
                borderRadius: AppSpacing.roundedLg,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.sunGold.withOpacity(0.15),
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: AppColors.woodBrown,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Check for updates',
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceContainerHigh,
                                    borderRadius: AppSpacing.roundedPill,
                                  ),
                                  child: Text(
                                    '${versionLabel(updateState.installedVersionName)} (${updateState.installedVersionCode})',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isChecking
                                  ? 'Checking server for updates...'
                                  : updateState.hasUpdate
                                      ? 'New version available (v${updateState.latestVersion?.versionName})'
                                      : updateState.status == UpdateStatus.error
                                          ? (updateState.errorMessage ?? 'Update check failed. Tap to retry.')
                                          : updateState.lastCheckedAt != null
                                              ? 'Up to date · Checked today'
                                              : 'Tap to check for latest updates',
                              style: AppTypography.bodySmall.copyWith(
                                color: updateState.hasUpdate
                                    ? AppColors.primary
                                    : updateState.status == UpdateStatus.error
                                        ? AppColors.danger
                                        : AppColors.textSecondary,
                                fontWeight: updateState.hasUpdate
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isChecking)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (updateState.hasUpdate)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: Text(
                            'UPDATE',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }
}
