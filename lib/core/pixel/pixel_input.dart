import 'package:flutter/material.dart';

import 'generated/pixel_palette.g.dart';
import 'pixel_box.dart';
import 'pixel_grid.dart';
import 'pixel_text.dart';

class PixelTextField extends StatefulWidget {
  const PixelTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
    this.autofillHints,
    this.autofocus = false,
    this.autovalidateMode,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSaved;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final AutovalidateMode? autovalidateMode;

  @override
  State<PixelTextField> createState() => _PixelTextFieldState();
}

class _PixelTextFieldState extends State<PixelTextField> {
  late TextEditingController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  void _attachController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(PixelTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _attachController();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return FormField<String>(
      initialValue: _controller.text,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.disabled,
      onSaved: widget.onSaved == null
          ? null
          : (value) {
              if (value != null) widget.onSaved!(value);
            },
      builder: (field) {
        final error = widget.errorText ?? field.errorText;
        final hasError = error != null && error.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              SizedBox(height: grid.px(1)),
            ],
            PixelPanel(
              style: PixelBoxStyle.slot.copyWith(
                fill: hasError ? PixelPalette.redLight : PixelPalette.white,
                outline: hasError ? PixelPalette.alert : PixelPalette.ink,
              ),
              sunken: true,
              padding: 2,
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                autofillHints: widget.autofillHints,
                autofocus: widget.autofocus,
                maxLines: widget.maxLines,
                cursorColor: PixelPalette.ink,
                cursorWidth: grid.unit,
                cursorRadius: Radius.zero,
                style: PixelType.body(context),
                onChanged: (value) {
                  field.didChange(value);
                  widget.onChanged?.call(value);
                },
                decoration: InputDecoration.collapsed(
                  hintText: widget.hint,
                  hintStyle: PixelType.body(context, color: PixelPalette.stone),
                ),
              ),
            ),
            if (hasError) ...[
              SizedBox(height: grid.px(1)),
              Text(
                error,
                style: PixelType.small(context, color: PixelPalette.alert),
              ),
            ] else if (widget.helperText != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                widget.helperText!,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            ],
          ],
        );
      },
    );
  }
}
