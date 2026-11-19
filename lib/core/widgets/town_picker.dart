import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../pixel/generated/pixel_palette.g.dart';
import '../pixel/pixel_text.dart';

/// Province -> town combobox (team review v0.3.10: "make it combobox").
/// JuanderQuest covers one province, so the first box is Pangasinan or
/// "outside Pangasinan", and the second lists its 44 towns and 4 cities.
///
/// [value]: null = nothing picked yet, [TownPicker.outside] (empty string) =
/// not from Pangasinan / visiting, otherwise the town name.
class TownPicker extends StatefulWidget {
  const TownPicker({
    super.key,
    required this.towns,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.allowOutside = true,
  });

  static const outside = '';
  static const province = 'Pangasinan';

  final List<String> towns;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  /// Shows the "outside Pangasinan" province choice.
  final bool allowOutside;

  @override
  State<TownPicker> createState() => _TownPickerState();
}

class _TownPickerState extends State<TownPicker> {
  late bool _inProvince = widget.value != TownPicker.outside;

  @override
  void didUpdateWidget(TownPicker old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && widget.value != null) {
      _inProvince = widget.value != TownPicker.outside;
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: PixelPalette.white,
        isDense: true,
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: PixelPalette.ink),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: PixelPalette.ink, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final style = PixelType.body(context, color: PixelPalette.ink);
    final town = widget.towns.contains(widget.value) ? widget.value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.allowOutside) ...[
          DropdownButtonFormField<bool>(
            key: const ValueKey('town_picker_province'),
            value: _inProvince,
            isExpanded: true,
            style: style,
            decoration:
                _decoration(tr(context, en: 'Province', tl: 'Probinsya')),
            items: [
              const DropdownMenuItem(
                value: true,
                child:
                    Text(TownPicker.province, overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: false,
                child: Text(
                  tr(
                    context,
                    en: 'Outside Pangasinan / visiting',
                    tl: 'Labas ng Pangasinan / bumibisita',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: widget.enabled
                ? (next) {
                    if (next == null || next == _inProvince) return;
                    setState(() => _inProvince = next);
                    widget.onChanged(next ? null : TownPicker.outside);
                  }
                : null,
          ),
          const SizedBox(height: 8),
        ],
        if (_inProvince)
          DropdownButtonFormField<String>(
            key: const ValueKey('town_picker_town'),
            value: town,
            isExpanded: true,
            menuMaxHeight: 320,
            style: style,
            hint: Text(
              tr(context, en: 'Pick a town or city', tl: 'Pumili ng bayan'),
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            decoration: _decoration(
                tr(context, en: 'Town / city', tl: 'Bayan / lungsod')),
            items: [
              for (final t in widget.towns)
                DropdownMenuItem(
                  value: t,
                  child: Text(t, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: widget.enabled ? widget.onChanged : null,
          ),
      ],
    );
  }
}
