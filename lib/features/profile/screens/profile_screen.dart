import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/primary_button.dart';
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
}
