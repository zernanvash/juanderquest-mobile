import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../app_update/widgets/update_dialog.dart';
import '../providers/profile_stats_provider.dart';
import '../../../core/widgets/designer_guide.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Widget _buildAvatarWidget(String? avatarUrl) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    if (isValidUrl) {
      return CircleAvatar(
        radius: 38,
        backgroundColor: AppColors.surfaceContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return const CircleAvatar(
      radius: 38,
      backgroundColor: AppColors.sunGold,
      child: Icon(Icons.person_rounded, size: 44, color: AppColors.woodBrown),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final stats = ref.watch(profileStatsProvider);

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: const Text('Explorer Profile'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          // User Header Card
          UiSpecContainer(
            spec: const UiSpec(
              title: 'Explorer Identity & Web3 Profile Header',
              figmaLayer: '#Profile_Header_Card',
              dimensions: 'Full width, Padding: 20dp, Avatar: 76x76dp circular',
              dataBinding: 'authProvider.user (displayName, email, avatarUrl, demoPoints)',
              stateNotes: 'Logged In -> PANGASINAN EXPLORER pill -> Avatar with Gold ring',
              uxNotes: 'Wood brown typography with Epilogue display headers.',
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(color: AppColors.borderLowContrast),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sunGold,
                    ),
                    child: _buildAvatarWidget(user?.avatarUrl),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    user?.displayName ?? 'Juan Dela Cruz',
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? 'juan@juanderquest.ph',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: AppSpacing.roundedPill,
                    ),
                    child: const Text(
                      'PANGASINAN EXPLORER',
                      style: TextStyle(
                        color: AppColors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Stats Metrics Overview
          JdqSectionHeader(
            title: 'Traveler Statistics',
            subtitle: 'Your adventure points and destination contributions.',
          ),

          UiSpecContainer(
            spec: const UiSpec(
              title: 'Traveler Points & Proofs Overview Grid',
              figmaLayer: '#Profile_Stats_Metrics_Grid',
              dimensions: 'Full width metric tile + 2-column split tiles (~88dp height)',
              dataBinding: 'profileStatsProvider (pointsBalance, completedQuests, totalSubmissions)',
              stateNotes: 'Real-time updated point balance & verified quest count',
              uxNotes: 'Sun gold icon for reward points, emerald green for verified completions.',
            ),
            child: Column(
              children: [
                MetricTile(
                  label: 'Reward Points Balance',
                  value: '${user?.points ?? stats.pointsBalance} PTS',
                  icon: Icons.stars_rounded,
                  iconColor: AppColors.sunGold,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Completed',
                        value: '${stats.completedQuests}',
                        icon: Icons.check_circle_rounded,
                        iconColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricTile(
                        label: 'Submissions',
                        value: '${stats.totalSubmissions}',
                        icon: Icons.fact_check_rounded,
                        iconColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // History & Submissions Action Card
          JdqSectionHeader(
            title: 'Activity & History',
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
                onTap: () => context.push('/history'),
                borderRadius: AppSpacing.roundedLg,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submission History',
                              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'View status of your quest & spot submissions',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // App Updates & Version Card
          JdqSectionHeader(
            title: 'App System & Updates',
          ),

          Consumer(
            builder: (context, ref, _) {
              final updateState = ref.watch(appUpdateProvider);
              final isChecking = updateState.status == UpdateStatus.checking;

              return Container(
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
                                      'You are running the latest version (v${current.installedVersionName}).',
                                    ),
                                    backgroundColor: AppColors.primary,
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
                              color: AppColors.sunGold.withValues(alpha: 0.15),
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
                                      'App Version',
                                      style: AppTypography.labelLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerHigh,
                                        borderRadius: AppSpacing.roundedPill,
                                      ),
                                      child: Text(
                                        'v${updateState.installedVersionName}',
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
                                  updateState.hasUpdate
                                      ? 'New version available (v${updateState.latestVersion?.versionName})'
                                      : 'Tap to check for latest updates',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: updateState.hasUpdate
                                        ? AppColors.primary
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
                              decoration: BoxDecoration(
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
              );
            },
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Developer & Designer Tools
          JdqSectionHeader(
            title: 'Developer & UI Designer Tools',
            subtitle: 'Toggle live visual blueprints, Figma specs, and wireframe tags.',
          ),

          Consumer(
            builder: (context, ref, _) {
              final isGuideEnabled = ref.watch(designerGuideProvider);
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(
                    color: isGuideEnabled ? const Color(0xFF0096C7) : AppColors.borderLowContrast,
                  ),
                  boxShadow: AppSpacing.cardShadow,
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isGuideEnabled
                          ? const Color(0xFF0096C7).withOpacity(0.15)
                          : AppColors.surfaceContainerHigh,
                      borderRadius: AppSpacing.roundedMd,
                    ),
                    child: Icon(
                      Icons.design_services_rounded,
                      color: isGuideEnabled ? const Color(0xFF0096C7) : AppColors.woodBrown,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Designer Guide Mode',
                    style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isGuideEnabled
                        ? 'Blueprint outlines and Figma component tags are ACTIVE.'
                        : 'Show UI wireframe boundaries and Figma element specs.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  value: isGuideEnabled,
                  activeColor: const Color(0xFF0096C7),
                  onChanged: (val) {
                    ref.read(designerGuideProvider.notifier).state = val;
                  },
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Separated Logout Action
          DestructiveButton(
            label: 'Log Out of Demo Account',
            icon: Icons.logout_rounded,
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/');
            },
          ),

          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }
}
