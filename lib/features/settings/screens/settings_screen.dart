import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../../core/services/push_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cosmetics/widgets/cosmetic_avatar.dart';
import '../../../core/app_release.dart';
import '../../dashboard/home_tips.dart';

/// Settings home: short categories that open their own pages, so a new
/// setting adds a row here instead of growing one long screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildAvatarWidget(String? avatarUrl, String name, Map<String, dynamic>? cosmetics) =>
      CosmeticAvatar(name: name, imageUrl: avatarUrl, size: 56,
        frame: cosmetics?['frame']?['asset'] as Map<String, dynamic>?);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final updateState = ref.watch(appUpdateProvider);
    final version = '${versionLabel(updateState.installedVersionName)} (${updateState.installedVersionCode})';

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
                    child: _buildAvatarWidget(user?.avatarUrl, user?.displayName ?? 'Traveler', user?.cosmetics),
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

          _SettingsGroup(title: 'Account', tiles: [
            _SettingsTile(
              key: const ValueKey('settings_appearance'),
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'Profile banners, frames, titles and name colours',
              onTap: () => context.push('/settings/appearance'),
            ),
            _SettingsTile(
              key: const ValueKey('settings_interests'),
              icon: Icons.interests_rounded,
              title: 'Travel interests',
              subtitle: 'Tune which destinations we recommend',
              onTap: () => context.push('/onboarding/interests'),
            ),
          ]),

          _SettingsGroup(title: 'Activity', tiles: [
            _SettingsTile(
              key: const ValueKey('settings_submissions'),
              icon: Icons.history_rounded,
              title: 'My submissions',
              subtitle: 'Status of your quest and spot submissions',
              onTap: () => context.push('/history'),
            ),
            _SettingsTile(
              key: const ValueKey('settings_affiliate'),
              icon: Icons.store_mall_directory_outlined,
              title: 'Merchant affiliate',
              subtitle: 'Apply to take part in tourism promotions',
              onTap: () => context.push('/affiliate'),
            ),
          ]),

          _SettingsGroup(title: 'App', tiles: [
            // Owner 2026-11-04: run the first-run tutorial again on Home.
            _SettingsTile(
              key: const ValueKey('settings_replay_tutorial'),
              icon: Icons.school_rounded,
              title: 'Replay tutorial',
              subtitle: 'Juan shows you around Home again',
              onTap: () async {
                await ref
                    .read(homeTipsControllerProvider.notifier)
                    .resetForReplay();
                if (context.mounted) context.go('/dashboard');
              },
            ),
            _SettingsTile(
              key: const ValueKey('settings_updates'),
              icon: Icons.system_update_rounded,
              title: 'App updates',
              subtitle: updateState.hasUpdate ? '$version · update available' : version,
              highlight: updateState.hasUpdate,
              onTap: () => context.push('/settings/updates'),
            ),
            _SettingsTile(
              key: const ValueKey('settings_developer'),
              icon: Icons.design_services_rounded,
              title: 'Developer tools',
              subtitle: ref.watch(designerGuideProvider)
                  ? 'Designer guide is on'
                  : 'Designer guide and diagnostics',
              onTap: () => context.push('/settings/developer'),
            ),
          ]),

          _SettingsGroup(title: 'About', tiles: [
            _SettingsTile(
              key: const ValueKey('settings_about'),
              icon: Icons.school_rounded,
              title: 'About JuanDerQuest & team',
              subtitle: 'Universidad de Dagupan capstone authors',
              onTap: () => context.push('/about'),
            ),
            _SettingsTile(
              key: const ValueKey('settings_governance'),
              icon: Icons.how_to_vote_rounded,
              title: 'Governance prototype',
              subtitle: 'Separate from JuanChoice community voting',
              onTap: () => context.push('/vote'),
            ),
          ]),

          const SizedBox(height: AppSpacing.sectionGap),

          // Session Sign Out
          DestructiveButton(
            label: 'Log Out of Account',
            icon: Icons.logout_rounded,
            onPressed: () async {
              // Stop this phone receiving the account's notifications first,
              // while the session can still authenticate the request.
              await ref.read(pushServiceProvider).unregisterDevice();
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) children.add(const Divider(height: 1, color: AppColors.borderLowContrast));
      children.add(tiles[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
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
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: highlight ? AppColors.primary : AppColors.textSecondary,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          )),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }
}
