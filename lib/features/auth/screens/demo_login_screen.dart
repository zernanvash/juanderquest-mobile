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

  void _showSimulatedWalletDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController(text: 'password123');
    bool isSubmitting = false;
    String? formError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
            backgroundColor: AppColors.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6851B).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF6851B), size: 24),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Simulated Web3 Login',
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.woodBrown,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Create or enter your test traveler identity',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Starter Pack Banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.crowdQuietBg,
                      borderRadius: AppSpacing.roundedMd,
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: AppColors.primaryDark, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Demo Starter Pack: 100,000 mJDQ + 15 JDQ Governance Tokens included!',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Traveler Name / Username',
                      hintText: 'e.g. Prof. Ramos, Juan, Jane',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.roundedMd,
                        borderSide: BorderSide(color: AppColors.borderLowContrast),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.roundedMd,
                        borderSide: BorderSide(color: AppColors.borderLowContrast),
                      ),
                    ),
                  ),

                  if (formError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formError!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Cancel',
                          onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Connect',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final username = usernameController.text.trim();
                                  final password = passwordController.text.trim();

                                  if (username.length < 2) {
                                    setDialogState(() => formError = 'Please enter at least 2 characters.');
                                    return;
                                  }

                                  setDialogState(() {
                                    isSubmitting = true;
                                    formError = null;
                                  });

                                  final ok = await ref.read(authProvider.notifier).loginWithSimulatedWallet(
                                        username: username,
                                        password: password,
                                      );

                                  if (dialogCtx.mounted) {
                                    if (ok) {
                                      Navigator.of(dialogCtx).pop();
                                    } else {
                                      setDialogState(() {
                                        isSubmitting = false;
                                        formError = ref.read(authProvider).error ?? 'Login failed.';
                                      });
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
                    'JuanDerQuest',
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
                const SizedBox(height: 8),
                Text(
                  'Explore Hidden Gems, Earn Verified Rewards',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.woodBrown,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Discover tranquil tourist destinations across Pangasinan, beat overcrowding, and support local MSME merchants.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Quick Role Cards
          Text(
            'SELECT DEMO ACCOUNT',
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              Expanded(
                child: _buildRoleCard(
                  role: 'traveler',
                  title: 'Traveler',
                  subtitle: 'Explore & Quests',
                  icon: Icons.person_rounded,
                  bgColor: AppColors.crowdQuietBg,
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildRoleCard(
                  role: 'admin',
                  title: 'LGU Admin',
                  subtitle: 'Curate & Validate',
                  icon: Icons.admin_panel_settings_rounded,
                  bgColor: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                ),
              ),
            ],
          ),

          if (authState.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
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

          // Primary Quick Login Button
          PrimaryButton(
            label: 'Start as ${_selectedRole == "admin" ? "LGU Admin" : "Traveler"}',
            isLoading: authState.isLoading,
            onPressed: () {
              ref.read(authProvider.notifier).loginWithSeed(_selectedSeed);
            },
            icon: Icons.rocket_launch_rounded,
          ),

          const SizedBox(height: AppSpacing.md),

          // Simulated Custom Wallet Login Option
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
              side: const BorderSide(color: AppColors.sunGold, width: 1.5),
            ),
            icon: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF6851B)),
            label: const Text(
              'Custom Name / Simulated Wallet Login',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.woodBrown),
            ),
            onPressed: () => _showSimulatedWalletDialog(context),
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
                'Demonstration prototype build for Pangasinan tourist destination promotion.',
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
