import 'package:flutter/material.dart';
import '../../features/spots/models/spot_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'crowd_status_chip.dart';
import 'trust_badge.dart';

/// Primary Destination Card for destination discovery.
class DestinationCard extends StatelessWidget {
  final SpotModel spot;
  final VoidCallback onTap;
  final bool isFeatured;

  const DestinationCard({
    super.key,
    required this.spot,
    required this.onTap,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = spot.photos.isNotEmpty ? spot.photos.first.url : null;
    final isValidUrl = photoUrl != null &&
        photoUrl.isNotEmpty &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'));

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
              // Hero Photo / Header Image
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: isFeatured ? 16 / 9 : 16 / 10,
                    child: isValidUrl
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),

                  // Top Left Category & Trust
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getCategoryIcon(spot.category), size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                _formatCategory(spot.category),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TrustBadge(sourceName: spot.sourceName),
                      ],
                    ),
                  ),

                  // Top Right Quest Badge
                  if (spot.questId != null)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sunGold,
                          borderRadius: AppSpacing.roundedPill,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 13, color: AppColors.woodBrown),
                            SizedBox(width: 4),
                            Text(
                              'Quest Available',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.woodBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Content Section
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
                            spot.name,
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CrowdStatusChip(crowdStatus: spot.crowdStatus, compact: true),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            spot.distanceKm != null
                                ? '${spot.municipality} · ${spot.distanceKm!.toStringAsFixed(1)} km away'
                                : spot.municipality,
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

                    if (spot.reasons.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: spot.reasons.take(2).map((reason) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: AppSpacing.roundedSm,
                            ),
                            child: Text(
                              reason,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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
      color: AppColors.surfaceContainerHigh,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getCategoryIcon(spot.category), size: 40, color: AppColors.textMuted),
            const SizedBox(height: 6),
            Text(
              spot.municipality,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'eat_drink':
      case 'food':
        return Icons.restaurant_rounded;
      case 'nature_outdoors':
      case 'eco':
        return Icons.park_rounded;
      case 'culture_heritage':
      case 'cultural':
        return Icons.museum_rounded;
      case 'activities_wellness':
      case 'activity':
        return Icons.fitness_center_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static String _formatCategory(String category) {
    if (category.isEmpty) return 'Destination';
    return category.replaceAll('_', ' ').split(' ').map((str) {
      return str.isNotEmpty ? str[0].toUpperCase() + str.substring(1) : '';
    }).join(' ');
  }
}
