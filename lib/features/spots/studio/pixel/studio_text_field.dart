import 'package:flutter/material.dart';

import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';

/// A square pixel input for the studio, with the same limits as the old
/// fields (max length, line counts) and the kit's slot frame.
class StudioTextField extends StatelessWidget {
  const StudioTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(1)),
        PixelPanel(
          style: PixelBoxStyle.slot.copyWith(
            fill: hasError ? PixelPalette.redLight : PixelPalette.white,
            outline: hasError ? PixelPalette.alert : PixelPalette.ink,
          ),
          sunken: true,
          padding: 2,
          child: TextField(
            controller: controller,
            maxLength: maxLength,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            style: PixelType.body(context),
            cursorColor: PixelPalette.green,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: PixelType.small(context, color: PixelPalette.stone),
              border: InputBorder.none,
              isDense: true,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (helperText != null && helperText!.isNotEmpty) ...[
          SizedBox(height: grid.px(0.5)),
          Text(
            helperText!,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
        if (hasError) ...[
          SizedBox(height: grid.px(0.5)),
          Text(
            errorText!,
            style: PixelType.small(context, color: PixelPalette.redDeep),
          ),
        ],
      ],
    );
  }
}
