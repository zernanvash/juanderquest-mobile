import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../utils/password_strength.dart';

/// A 4-block strength bar and the rule checklist, updated as the traveler types.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.check});

  final PasswordCheck check;

  static const _blocks = {
    PasswordStrength.empty: 0,
    PasswordStrength.weak: 1,
    PasswordStrength.fair: 2,
    PasswordStrength.good: 3,
    PasswordStrength.strong: 4,
  };

  static const _colors = {
    PasswordStrength.empty: PixelPalette.mist,
    PasswordStrength.weak: PixelPalette.alert,
    PasswordStrength.fair: PixelPalette.amber,
    PasswordStrength.good: PixelPalette.greenBright,
    PasswordStrength.strong: PixelPalette.greenDeep,
  };

  static const _labels = {
    PasswordStrength.empty: 'Strength: -',
    PasswordStrength.weak: 'Strength: weak',
    PasswordStrength.fair: 'Strength: fair',
    PasswordStrength.good: 'Strength: good',
    PasswordStrength.strong: 'Strength: strong',
  };

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final filled = _blocks[check.strength]!;
    final color = _colors[check.strength]!;
    return Column(
      key: const ValueKey('password_strength_meter'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: Container(
                  height: grid.px(3),
                  decoration: BoxDecoration(
                    color: i < filled ? color : PixelPalette.paperDim,
                    border: Border.all(color: PixelPalette.ink, width: grid.unit / 2),
                  ),
                ),
              ),
              if (i < 3) SizedBox(width: grid.px(1)),
            ],
          ],
        ),
        SizedBox(height: grid.px(1)),
        Text(
          _labels[check.strength]!,
          key: const ValueKey('password_strength_label'),
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(1)),
        for (final rule in check.rules)
          Padding(
            padding: EdgeInsets.only(top: grid.px(1) / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: grid.px(7),
                  child: Text(
                    rule.passed ? '✓' : '✗',
                    style: PixelType.small(
                      context,
                      color: rule.passed ? PixelPalette.greenBright : PixelPalette.stone,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rule.label,
                    style: PixelType.small(
                      context,
                      color: rule.passed ? PixelPalette.greenDeep : PixelPalette.slate,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
