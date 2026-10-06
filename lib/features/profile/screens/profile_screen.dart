import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_stats_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isFollowing = false;

  Widget _buildAvatarWidget(String? avatarUrl, String displayName) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    if (isValidUrl) {
      return CircleAvatar(
        radius: 42,
        backgroundColor: AppColors.surfaceContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'J';
    return CircleAvatar(
      radius: 42,
      backgroundColor: AppColors.sunGold,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.woodBrown,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final stats = ref.watch(profileStatsProvider);

    final isMine = widget.username == null ||
        widget.username == currentUser?.id ||
        widget.username == currentUser?.seedId ||
        (currentUser != null &&
            widget.username == currentUser.handle.replaceFirst('@', ''));

    final displayName = isMine
        ? (currentUser?.displayName ?? 'Juan Dela Cruz')
        : (widget.username ?? 'Pangasinan Explorer');

    final displayHandle = isMine
        ? (currentUser?.handle ?? '@demo-traveler')
        : '@${widget.username}';

    final pointsBalance = currentUser?.points ?? stats.pointsBalance;
    final level = (pointsBalance / 50).floor() + 1;

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: Text(isMine ? 'Traveler Passport' : 'Explorer Profile'),
        actions: [
          if (isMine)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Explorer Settings',
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Traveler Identity Passport Header Card
          UiSpecContainer(
            spec: const UiSpec(
              title: 'Traveler Passport Identity Header',
              figmaLayer: '#Profile_Header_Card',
              dimensions: 'Full width, Padding: 20dp, Avatar: 84x84dp circular',
              dataBinding: 'authProvider.user (displayName, handle, points, badges)',
              stateNotes: 'Logged In -> LEVEL pill -> Avatar with Gold ring',
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
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sunGold,
                    ),
                    child: _buildAvatarWidget(
                      isMine ? currentUser?.avatarUrl : null,
                      displayName,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    displayName,
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayHandle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: Text(
                          'LEVEL $level EXPLORER',
                          style: const TextStyle(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sunGold.withOpacity(0.18),
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: Text(
                          '$pointsBalance mJDQ',
                          style: const TextStyle(
                            color: AppColors.woodBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (!isMine) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: 160,
                      child: PrimaryButton(
                        label: _isFollowing ? 'Following' : 'Follow Scout',
                        icon: _isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                        onPressed: () {
                          setState(() => _isFollowing = !_isFollowing);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_isFollowing
                                  ? 'Now following $displayName.'
                                  : 'Unfollowed $displayName.'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Stats Metrics Overview (Exclusive to owner)
          if (isMine) ...[
            const JdqSectionHeader(
              title: 'Web3 & Blockchain Identity',
              subtitle: 'Link MetaMask or EVM address to preserve your passport across devices.',
            ),

            _buildWalletCard(context, currentUser),

            const SizedBox(height: AppSpacing.sectionGap),

            const JdqSectionHeader(
              title: 'Traveler Statistics',
              subtitle: 'Your quest completions, submissions, and reward points balance.',
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
                    value: '$pointsBalance PTS',
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
            const JdqSectionHeader(
              title: 'Activity & History',
              subtitle: 'Track GPS-verified proof submissions and review statuses.',
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
          ],

          // Community & Project Links
          const JdqSectionHeader(
            title: 'Community & Ecosystem',
            subtitle: 'Compete in regional sprints and explore research pillars.',
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
                    onTap: () => context.push('/leaderboard'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.sunGold.withOpacity(0.2),
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: const Icon(Icons.military_tech_rounded, color: AppColors.woodBrown, size: 22),
                    ),
                    title: Text(
                      'Scout Hall of Fame',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'View top explorers, rankings, and sprint leaderboards.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                  const Divider(height: 1, color: AppColors.borderLowContrast),
                  ListTile(
                    onTap: () => context.push('/about'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                    ),
                    title: Text(
                      'About JuanDerQuest & Team',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Universidad de Dagupan capstone research authors & flywheel pillars.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ),
                  if (isMine) ...[
                    const Divider(height: 1, color: AppColors.borderLowContrast),
                    ListTile(
                      onTap: () => context.push('/settings'),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.settings_rounded, color: AppColors.woodBrown, size: 22),
                      ),
                      title: Text(
                        'Explorer Settings',
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Configure preferences, AR calibration, and app updates.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, UserModel? user) {
    if (user == null) return const SizedBox.shrink();
    final hasWallet = user.hasBoundWallet;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(
          color: hasWallet ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLowContrast,
        ),
        boxShadow: AppSpacing.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasWallet
                      ? AppColors.success.withValues(alpha: 0.12)
                      : const Color(0xFFF6851B).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasWallet ? Icons.verified_user_rounded : Icons.account_balance_wallet_rounded,
                  color: hasWallet ? AppColors.success : const Color(0xFFF6851B),
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasWallet ? 'Web3 Passport Linked' : 'Off-Chain Demo Account',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      hasWallet ? 'Base L2 / Sepolia Verified' : 'No Web3 Wallet Linked Yet',
                      style: AppTypography.bodySmall.copyWith(
                        color: hasWallet ? AppColors.success : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasWallet
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.sunGold.withValues(alpha: 0.2),
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  hasWallet ? 'VERIFIED' : 'OFF-CHAIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasWallet ? AppColors.success : AppColors.woodBrown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasWallet) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: AppColors.borderLowContrast),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.formattedWalletAddress ?? user.walletAddress ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.woodBrown,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy full EVM address',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: user.walletAddress ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wallet address copied to clipboard.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your passport and rewards are bound to this address. You can log into any device using MetaMask.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmUnbindWallet(context),
                icon: const Icon(Icons.link_off_rounded, size: 16, color: AppColors.danger),
                label: const Text('Unlink Wallet', style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            ),
          ] else ...[
            Text(
              'You are playing using local demo points (\$mJDQ). You can link MetaMask or any EVM wallet at any time to preserve your identity and unlock DAO governance voting.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Link MetaMask / EVM Wallet',
              icon: Icons.account_balance_wallet_rounded,
              onPressed: () => _showWalletBindingModal(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showWalletBindingModal(BuildContext context) {
    final addressController = TextEditingController();
    bool isSubmitting = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + bottomInset),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.borderLowContrast,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6851B).withValues(alpha: 0.15),
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
                              'Link MetaMask Wallet',
                              style: AppTypography.headlineSmall.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Progressive Web3 Passport Binding',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.crowdQuietBg,
                      borderRadius: AppSpacing.roundedMd,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Binding your wallet links your current passport stats and demo points to your sovereign blockchain identity without gas fees.',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.primaryDark, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                      side: const BorderSide(color: Color(0xFFF6851B), width: 1.5),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFFF6851B)),
                    label: const Text(
                      'Open MetaMask Mobile App',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF6851B)),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('https://metamask.app.link/dapp/juanderquest.app');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        setSheetState(() => modalError = 'MetaMask app link could not be opened. Please enter your address below.');
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.borderLowContrast)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('OR ENTER ADDRESS', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: AppColors.borderLowContrast)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'EVM Wallet Address',
                      hintText: '0x...',
                      prefixIcon: Icon(Icons.fingerprint_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.roundedMd,
                        borderSide: BorderSide(color: AppColors.borderLowContrast),
                      ),
                    ),
                  ),
                  if (modalError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(modalError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Bind Wallet to Passport',
                    icon: Icons.link_rounded,
                    isLoading: isSubmitting,
                    onPressed: isSubmitting ? null : () async {
                      final addr = addressController.text.trim();
                      if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(addr)) {
                        setSheetState(() => modalError = 'Please enter a valid 42-character EVM address (0x...)');
                        return;
                      }

                      setSheetState(() {
                        isSubmitting = true;
                        modalError = null;
                      });

                      final challenge = await ref.read(authProvider.notifier).requestWalletChallenge(addr);
                      final sig = '0x_simulated_sig_for_${addr.substring(2, 10)}';
                      final ok = await ref.read(authProvider.notifier).bindWallet(
                        address: addr,
                        signature: challenge != null ? sig : '0x_local_signature',
                      );

                      if (sheetCtx.mounted) {
                        if (ok) {
                          Navigator.of(sheetCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('MetaMask wallet successfully linked to your passport!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else {
                          setSheetState(() {
                            isSubmitting = false;
                            modalError = ref.read(authProvider).error ?? 'Failed to bind wallet.';
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmUnbindWallet(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Unlink Web3 Wallet?'),
        content: const Text(
          'Your account will revert to off-chain mode. You can link this or another wallet at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await ref.read(authProvider.notifier).unbindWallet();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Wallet unlinked successfully.' : 'Failed to unlink wallet.'),
                  ),
                );
              }
            },
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }
}
