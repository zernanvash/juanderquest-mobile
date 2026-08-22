import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// TrustBadge displays data source provenance (LGU verified, editorial, open data, reviewed community).
class TrustBadge extends StatelessWidget {
  final String sourceName;
  final bool compact;

  const TrustBadge({
    super.key,
    required this.sourceName,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final nameLower = sourceName.toLowerCase();
    Color bgColor;
    Color fgColor;
    IconData icon;
    String label;

    if (nameLower.contains('lgu') || nameLower.contains('official') || nameLower.contains('verified')) {
      bgColor = AppColors.lguVerifiedBg;
      fgColor = AppColors.lguVerified;
      icon = Icons.verified_rounded;
      label = 'LGU Verified';
    } else if (nameLower.contains('editorial') || nameLower.contains('curated') || nameLower.contains('juanderquest')) {
      bgColor = AppColors.editorialBg;
      fgColor = AppColors.editorial;
      icon = Icons.star_rounded;
      label = 'Editorial';
    } else if (nameLower.contains('osm') || nameLower.contains('open') || nameLower.contains('map')) {
      bgColor = AppColors.openDataBg;
      fgColor = AppColors.openData;
      icon = Icons.public_rounded;
      label = 'Open Data';
    } else {
      bgColor = AppColors.surfaceContainerHigh;
      fgColor = AppColors.textSecondary;
      icon = Icons.groups_rounded;
      label = sourceName.isNotEmpty ? sourceName : 'Community';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.roundedPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: fgColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
