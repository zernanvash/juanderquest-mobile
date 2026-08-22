import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// CrowdStatusChip presents destination activity pressure estimates.
///
/// Status options: quiet, moderate, estimated_busy, unknown.
/// MANDATORY: Never call this live occupancy! Busy state must say "Estimated busy".
class CrowdStatusChip extends StatelessWidget {
  final String crowdStatus;
  final bool compact;

  const CrowdStatusChip({
    super.key,
    required this.crowdStatus,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = crowdStatus.toLowerCase();
    Color bgColor;
    Color fgColor;
    IconData icon;
    String label;

    switch (status) {
      case 'quiet':
        bgColor = AppColors.crowdQuietBg;
        fgColor = AppColors.crowdQuiet;
        icon = Icons.nature_people_rounded;
        label = 'Quiet';
        break;
      case 'moderate':
        bgColor = AppColors.crowdModerateBg;
        fgColor = AppColors.crowdModerate;
        icon = Icons.groups_rounded;
        label = 'Moderate';
        break;
      case 'estimated_busy':
      case 'busy':
        bgColor = AppColors.crowdBusyBg;
        fgColor = AppColors.crowdBusy;
        icon = Icons.thermostat_rounded;
        label = 'Estimated busy';
        break;
      default:
        bgColor = AppColors.crowdUnknownBg;
        fgColor = AppColors.crowdUnknown;
        icon = Icons.help_outline_rounded;
        label = 'Crowd unknown';
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppSpacing.roundedPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fgColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fgColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.roundedPill,
        border: Border.all(color: fgColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
