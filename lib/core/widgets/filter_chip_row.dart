import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class FilterChipOption {
  final String key;
  final String label;
  final IconData? icon;

  const FilterChipOption({
    required this.key,
    required this.label,
    this.icon,
  });
}

/// Horizontally scrollable chip row with clear selected states.
class FilterChipRow extends StatelessWidget {
  final List<FilterChipOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: options.map((option) {
          final isSelected = option.key == selectedKey;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Material(
              color: isSelected ? AppColors.primary : AppColors.surfaceContainer,
              borderRadius: AppSpacing.roundedPill,
              child: InkWell(
                onTap: () => onSelected(option.key),
                borderRadius: AppSpacing.roundedPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: AppSpacing.roundedPill,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLowContrast,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (option.icon != null) ...[
                        Icon(
                          option.icon,
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
