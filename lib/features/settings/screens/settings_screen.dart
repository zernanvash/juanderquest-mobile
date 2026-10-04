import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../app_update/widgets/update_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildAvatarWidget(String? avatarUrl) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    if (isValidUrl) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.surfaceContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return const CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.sunGold,
      child: Icon(Icons.person_rounded, size: 32, color: AppColors.woodBrown),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final updateState = ref.watch(appUpdateProvider);
    final isChecking = updateState.status == UpdateStatus.checking;
    final isGuideEnabled = ref.watch(designerGuideProvider);

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: const Text('Explorer Settings'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          // User Identity Card
          UiSpecContainer(
            spec: const UiSpec(
              title: 'Explorer Identity & Account Card',
              figmaLayer: '#Settings_User_Card',
              dimensions: 'Full width, Padding: 16dp',
              dataBinding: 'authProvider.user (displayName, email, seedId)',
              stateNotes: 'Displays logged-in traveler credentials and profile link',
              uxNotes: 'Wood brown typography with warm stone accents.',
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(color: AppColors.borderLowContrast),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sunGold,
                    ),
                    child: _buildAvatarWidget(user?.avatarUrl),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Juan Dela Cruz',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'juan@juanderquest.ph',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pangasinan Explorer #${user != null ? (user.id.length > 8 ? user.id.substring(0, 8) : user.id) : 'demo'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

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
                                  'App Version',
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

          // Augmented Reality & Calibration Studio
          const JdqSectionHeader(
            title: 'Augmented Reality Studio',
            subtitle: 'Calibrate spatial sensors and test 3D parametric meshes.',
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
              child: Column(
                children: [
                  ListTile(
                    onTap: () => context.push('/ar-calibration?returnTo=/settings'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F).withOpacity(0.12),
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: Color(0xFF2D6A4F),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'Sensor & Compass Calibration',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '3-step calibration: Magnetometer figure-8, spirit level, and GPS sync.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                  const Divider(height: 1, color: AppColors.borderLowContrast),
                  ListTile(
                    onTap: () => context.push('/ar-test'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.sunGold.withOpacity(0.18),
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: const Icon(
                        Icons.view_in_ar_rounded,
                        color: AppColors.woodBrown,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'AR Spatial Viewfinder Testbed',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Live camera feed, 3D object summoner, and sensor HUD.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                  const Divider(height: 1, color: AppColors.borderLowContrast),
                  ListTile(
                    onTap: () => context.push('/ar-playground'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: const Icon(
                        Icons.token_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'AR 3D Geometry Studio',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Parametric meshes (Token, Gem, Box, Beacon) with Lambertian lighting.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Developer & UI Designer Tools
          const JdqSectionHeader(
            title: 'Developer & UI Designer Mode',
            subtitle: 'Inspect Figma component boundaries and semantic spec overlays.',
          ),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: isGuideEnabled ? const Color(0xFF0096C7) : AppColors.borderLowContrast,
              ),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
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
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Session Sign Out
          DestructiveButton(
            label: 'Log Out of Account',
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
