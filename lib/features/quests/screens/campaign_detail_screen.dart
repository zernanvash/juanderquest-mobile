import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/campaign_model.dart';
import '../providers/campaign_provider.dart';

class CampaignDetailScreen extends ConsumerStatefulWidget {
  final String campaignId;
  final CampaignModel? initialCampaign;

  const CampaignDetailScreen({
    super.key,
    required this.campaignId,
    this.initialCampaign,
  });

  @override
  ConsumerState<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  bool _isRegistered = false;

  Map<String, int> _calculateTimeRemaining(String dateString) {
    try {
      final target = DateTime.parse(dateString);
      final diff = target.difference(DateTime.now());
      if (diff.isNegative) {
        return {'days': 0, 'hours': 0, 'minutes': 0};
      }
      return {
        'days': diff.inDays,
        'hours': diff.inHours % 24,
        'minutes': diff.inMinutes % 60,
      };
    } catch (_) {
      return {'days': 14, 'hours': 8, 'minutes': 30};
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignState = ref.watch(campaignProvider);
    final campaign = widget.initialCampaign ??
        campaignState.campaigns.firstWhere(
          (c) => c.id == widget.campaignId,
          orElse: () => CampaignNotifier.defaultCampaigns.first,
        );

    final timeLeft = _calculateTimeRemaining(campaign.eventDate);
    final quotaPercent = campaign.maxParticipants > 0
        ? (campaign.reservedParticipants / campaign.maxParticipants).clamp(0.0, 1.0)
        : 0.0;

    return JdqScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.woodBrown),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Event Campaign',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.woodBrown,
            ),
          ),
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Banner Image (Facebook-Style Edge-to-Edge Container)
          Container(
            decoration: BoxDecoration(
              borderRadius: AppSpacing.roundedXl,
              border: Border.all(color: AppColors.borderLowContrast),
              boxShadow: AppSpacing.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    campaign.bannerImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerLow,
                      child: const Center(
                        child: Icon(Icons.festival_rounded, color: AppColors.textMuted, size: 48),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.sunGold,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.woodBrown),
                            const SizedBox(width: 4),
                            Text(
                              '+${campaign.rewardPerParticipantMjdq} mJDQ Reward',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Metadata Chips (Municipality + Host)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        campaign.municipality,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ),
              const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text(
                'Organized by ${campaign.hostName}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            campaign.title,
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.woodBrown,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 12),

          // Countdown Timer Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.borderLowContrast),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 15, color: Color(0xFFE65100)),
                      SizedBox(width: 6),
                      Text(
                        'EVENT COUNTDOWN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE65100),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTimeBox('${timeLeft['days']}', 'DAYS'),
                      const SizedBox(width: 8),
                      _buildTimeBox('${timeLeft['hours']}', 'HOURS'),
                      const SizedBox(width: 8),
                      _buildTimeBox('${timeLeft['minutes']}', 'MINS'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Locked Escrow Pool & Quota Progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.borderLowContrast),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Locked Prize Escrow Pool',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                    ),
                    Text(
                      '${campaign.totalBudgetMjdq} mJDQ',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: AppSpacing.roundedPill,
                  child: LinearProgressIndicator(
                    value: quotaPercent,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceContainerLow,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${campaign.reservedParticipants} / ${campaign.maxParticipants} Pre-Registered',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${(quotaPercent * 100).toInt()}% Quota Filled',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Description & Story
          const Text(
            'About this Event Campaign',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
          ),
          const SizedBox(height: 6),
          Text(
            campaign.description,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.45, fontSize: 13),
          ),

          const SizedBox(height: 14),

          // Pre-Quest Requirements
          if (campaign.preQuestRequirements.isNotEmpty) ...[
            const Text(
              'Campaign Checkpoint Requirements',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
            ),
            const SizedBox(height: 8),
            ...campaign.preQuestRequirements.map((req) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.borderLowContrast),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2F0E8),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.check_rounded, size: 12, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.woodBrown),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          // Action Button (Pre-Register / Attend)
          PrimaryButton(
            label: _isRegistered ? '✓ Pre-Registration Confirmed' : 'Pre-Register for Event (+${campaign.rewardPerParticipantMjdq} mJDQ)',
            onPressed: () {
              setState(() => _isRegistered = !_isRegistered);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isRegistered
                      ? 'Pre-Registration Confirmed! Your check-in ticket has been generated.'
                      : 'Registration cancelled.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.roundedMd,
      ),
      child: Column(
        children: [
          Text(
            value.padLeft(2, '0'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.woodBrown),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
