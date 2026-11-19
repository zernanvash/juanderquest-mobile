import 'package:flutter/material.dart';

import '../../../../core/l10n/app_language.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_feedback.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';

/// A boxed "combobox" for the studio: shows the chosen value and opens a
/// list of fixed options (team review 2026-11-19: town/province pickers).
class StudioPickerField extends StatelessWidget {
  const StudioPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.hint,
    this.errorText,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final String? hint;
  final String? errorText;

  Future<void> _open(BuildContext context) async {
    final picked = await showPixelDialog<String>(
      context: context,
      title: label,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: PixelButton(
                key: ValueKey('studio_pick_$option'),
                label: option,
                variant: option == value
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                expand: true,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(option),
              ),
            ),
        ],
      ),
      actions: [
        PixelButton(
          label: tr(context, en: 'Cancel', tl: 'Kanselahin'),
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;
    final shown = value ?? hint ?? '';
    // The whole field (label included) opens the list.
    return Semantics(
      button: true,
      label: '$label: $shown',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              SizedBox(height: grid.px(1)),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: PixelPanel(
                  style: PixelBoxStyle.slot.copyWith(
                    fill: hasError ? PixelPalette.redLight : PixelPalette.white,
                    outline: hasError ? PixelPalette.alert : PixelPalette.ink,
                  ),
                  padding: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shown,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: value == null
                              ? PixelType.small(context,
                                  color: PixelPalette.stone)
                              : PixelType.body(context),
                        ),
                      ),
                      SizedBox(width: grid.px(1)),
                      Text(
                        'v',
                        style: PixelType.body(context,
                                color: PixelPalette.greenDark)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasError) ...[
                SizedBox(height: grid.px(0.5)),
                Text(
                  errorText!,
                  style: PixelType.small(context, color: PixelPalette.redDeep),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
