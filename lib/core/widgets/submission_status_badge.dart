import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// SubmissionStatusBadge displays Pending, Approved, or Rejected state.
class SubmissionStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const SubmissionStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusLower = status.toLowerCase();
    Color bgColor;
    Color fgColor;
    IconData icon;
    String label;

    switch (statusLower) {
      case 'approved':
        bgColor = AppColors.successBg;
        fgColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        label = 'Approved';
        break;
      case 'rejected':
        bgColor = AppColors.dangerBg;
        fgColor = AppColors.danger;
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        break;
      case 'pending':
      default:
        bgColor = AppColors.warningBg;
        fgColor = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        label = 'Pending Review';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.roundedPill,
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
