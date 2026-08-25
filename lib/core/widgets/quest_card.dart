import 'package:flutter/material.dart';
import '../../features/quests/models/quest_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// QuestCard displays playable quest cards with categories, reward badges, and status.
class QuestCard extends StatelessWidget {
  final QuestModel quest;
  final String status;
  final VoidCallback onTap;
  final bool isFeatured;

  const QuestCard({
    super.key,
    required this.quest,
    required this.status,
    required this.onTap,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'COMPLETED':
        statusColor = AppColors.success;
        break;
      case 'PENDING REVIEW':
        statusColor = AppColors.warning;
        break;
      case 'REJECTED':
        statusColor = AppColors.danger;
        break;
      default:
        statusColor = AppColors.primary;
    }

    final hasImage = quest.imageUrl != null &&
        quest.imageUrl!.isNotEmpty &&
        (quest.imageUrl!.startsWith('http://') || quest.imageUrl!.startsWith('https://'));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.roundedLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero photo / gradient container
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: isFeatured ? 16 / 9 : 16 / 10,
                    child: hasImage
                        ? Image.network(
                            quest.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),

                  // Category Pill Top Left
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getCategoryIcon(quest.categoryDisplay), size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            quest.categoryDisplay,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reward Points Badge Top Right
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.92),
                        borderRadius: AppSpacing.roundedPill,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: AppColors.sunGold),
                          const SizedBox(width: 4),
                          Text(
                            '+${quest.rewardPoints} pts',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.woodBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Content Area
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            quest.title,
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: AppSpacing.roundedSm,
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            quest.allowedRadiusMeters > 0
                                ? '${quest.locationName} · ${quest.allowedRadiusMeters}m radius'
                                : quest.locationName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getCategoryIcon(quest.categoryDisplay), size: 40, color: AppColors.sunGold),
            const SizedBox(height: 6),
            Text(
              quest.locationName,
              style: AppTypography.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'eco':
      case 'nature':
        return Icons.eco_rounded;
      case 'cultural':
      case 'heritage':
        return Icons.museum_rounded;
      case 'food':
      case 'culinary':
        return Icons.restaurant_rounded;
      default:
        return Icons.explore_rounded;
    }
  }
}
