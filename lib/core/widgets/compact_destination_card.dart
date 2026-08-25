import 'package:flutter/material.dart';
import '../../features/spots/models/spot_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'crowd_status_chip.dart';

/// CompactDestinationCard for horizontal alternative lists and nearby recommendations.
class CompactDestinationCard extends StatelessWidget {
  final SpotModel spot;
  final VoidCallback onTap;

  const CompactDestinationCard({
    super.key,
    required this.spot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.roundedMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Spot thumbnail
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  child: spot.photos.isNotEmpty
                      ? ClipRRect(
                          borderRadius: AppSpacing.roundedSm,
                          child: Image.network(
                            spot.photos.first.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.place_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.place_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                ),

                const SizedBox(width: AppSpacing.md),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              spot.name,
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          CrowdStatusChip(crowdStatus: spot.crowdStatus, compact: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${spot.municipality}${spot.distanceKm == null ? '' : ' · ${spot.distanceKm!.toStringAsFixed(1)} km'}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (spot.reasons.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          spot.reasons.take(2).join(' · '),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
