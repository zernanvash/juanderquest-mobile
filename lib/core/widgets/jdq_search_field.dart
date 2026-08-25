import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standard search field with submit, clear, and optional filter trigger.
class JdqSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClear;

  const JdqSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search destinations, coffee, beaches...',
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasText)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () {
                      controller.clear();
                      if (onClear != null) onClear!();
                      if (onSubmitted != null) onSubmitted!('');
                    },
                  ),
                if (onFilterTap != null)
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                    onPressed: onFilterTap,
                  ),
              ],
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: const OutlineInputBorder(
              borderRadius: AppSpacing.roundedLg,
              borderSide: BorderSide(color: AppColors.borderLowContrast),
            ),
          ),
        );
      },
    );
  }
}
