import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class DemoLoginScreen extends ConsumerStatefulWidget {
  const DemoLoginScreen({super.key});

  @override
  ConsumerState<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends ConsumerState<DemoLoginScreen> {
  String _selectedRole = 'traveler';

  String get _selectedSeed => _selectedRole == 'admin' ? 'admin-1' : 'user-1';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return JdqScaffold(
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // Logo Header
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: const BoxDecoration(
                      color: AppColors.sunGold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.explore_rounded, size: 48, color: AppColors.woodBrown),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'JuanderQuest',
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.woodBrown,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Value Proposition Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.borderLowContrast),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Column(
              children: [
                const Text(
                  "PANGASINAN'S HERITAGE QUEST",
                  style: TextStyle(
                    color: AppColors.woodBrown,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A gamified tourism platform for discovering hidden destinations, exploring quiet alternatives, and playing verified quests in Pangasinan.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Seeded Demo Role Selector
          Row(
            children: [
              Expanded(
                child: _buildRoleCard(
                  role: 'traveler',
                  title: 'Traveler',
                  subtitle: 'Explore & Play Quests',
                  icon: Icons.map_rounded,
                  bgColor: AppColors.crowdQuietBg,
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildRoleCard(
                  role: 'admin',
                  title: 'Admin',
                  subtitle: 'Manage Submissions',
                  icon: Icons.admin_panel_settings_rounded,
                  bgColor: AppColors.crowdModerateBg,
                  iconColor: AppColors.secondary,
                ),
              ),
            ],
          ),

          if (authState.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      authState.error!,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Primary CTA Button
          PrimaryButton(
            label: 'Start Demo Experience',
            isLoading: authState.isLoading,
            onPressed: () {
              ref.read(authProvider.notifier).loginWithSeed(_selectedSeed);
            },
            icon: Icons.rocket_launch_rounded,
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Prototype Disclosure Footer
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'PROTOTYPE BUILD V0.4.2',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Demonstration prototype build. Real blockchain, wallet connections, and live occupancy tracking are deferred.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(
            color: isSelected ? AppColors.sunGold : AppColors.borderLowContrast,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected ? AppSpacing.floatingShadow : AppSpacing.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
