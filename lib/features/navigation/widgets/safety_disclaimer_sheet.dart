import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';

class SafetyDisclaimerSheet extends StatelessWidget {
  static const String prefsKey = 'nav_safety_acknowledged';
  static const _storage = FlutterSecureStorage();

  /// Visible for testing to mock safety acceptance in unit tests.
  static bool? testAcknowledgedOverride;

  const SafetyDisclaimerSheet({super.key});

  static Future<bool> ensureSafetyAcknowledged(BuildContext context) async {
    if (testAcknowledgedOverride != null) {
      return testAcknowledgedOverride!;
    }

    try {
      final value = await _storage.read(key: prefsKey).timeout(
            const Duration(milliseconds: 500),
            onTimeout: () => null,
          );
      if (value == 'true') {
        return true;
      }
    } catch (_) {
      // In testing or environments without secure storage, proceed.
    }

    if (!context.mounted) return false;

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SafetyDisclaimerSheet(),
    );

    if (agreed == true) {
      try {
        await _storage.write(key: prefsKey, value: 'true');
      } catch (_) {}
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: PixelPalette.paper,
        border: Border(
          top: BorderSide(color: PixelPalette.woodDeep, width: 3),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(grid.px(3)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const PixelChip('SAFETY FIRST', style: PixelBoxStyle.gold),
                  const Spacer(),
                  PixelButton(
                    key: const ValueKey('nav_safety_close'),
                    label: 'X',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              SizedBox(height: grid.px(2)),
              Text(
                'Let a passenger handle the phone while driving. Keep your eyes on the road.',
                style: PixelType.body(context, color: PixelPalette.woodDeep),
              ),
              SizedBox(height: grid.px(3)),
              PixelButton(
                key: const ValueKey('nav_safety_agree'),
                label: 'I UNDERSTAND · START',
                variant: PixelButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
