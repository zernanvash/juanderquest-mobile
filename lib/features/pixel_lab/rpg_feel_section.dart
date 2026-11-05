import 'package:flutter/material.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_rpg.dart';
import '../../core/pixel/pixel_text.dart';

/// Pixel lab: everything Plan 75k added, in one place (owner 2026-11-05).
class RpgFeelSection extends StatefulWidget {
  const RpgFeelSection({super.key});

  @override
  State<RpgFeelSection> createState() => _RpgFeelSectionState();
}

class _RpgFeelSectionState extends State<RpgFeelSection> {
  int _coins = 150;
  int _taps = 0;
  bool _unread = true;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelLorePanel(
          title: 'Capiz Heritage',
          child: PixelText.rich(
            'Banner · {blue:Rare}\n'
            'A window of pearly shell panes.\n\n'
            'Price: {gold:400 mJDQ}\n'
            '{sun:Tap to preview!}',
            style: PixelType.small(context, color: PixelPalette.mist),
          ),
        ),
        SizedBox(height: grid.px(3)),
        PixelTappableSlot(
          key: const ValueKey('lab_rpg_slot'),
          onTap: () => setState(() => _taps++),
          child: Text(
            'Pressable slot · tapped $_taps',
            style: PixelType.body(context),
          ),
        ),
        SizedBox(height: grid.px(3)),
        Wrap(
          spacing: grid.px(4),
          runSpacing: grid.px(2),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const PixelMicro(PixelMicroArt.sparkle, scale: 4),
            const PixelMicro(PixelMicroArt.coin, scale: 4),
            const PixelIdleBob(
              child: PixelSprite(DesignerArt.questMarker, scale: 3),
            ),
            GestureDetector(
              onTap: () => setState(() => _unread = !_unread),
              child: PixelRing(
                active: _unread,
                child: const PixelSprite(DesignerArt.notifBell, scale: 2),
              ),
            ),
          ],
        ),
        SizedBox(height: grid.px(3)),
        Row(
          children: [
            Expanded(
              child: PixelRollingNumber(
                key: const ValueKey('lab_rpg_number'),
                value: _coins,
                style: PixelType.numbers(context),
                format: (v) => '$v mJDQ',
              ),
            ),
            PixelButton(
              label: '+25',
              onPressed: () => setState(() => _coins += 25),
            ),
          ],
        ),
        SizedBox(height: grid.px(3)),
        const PixelProgressBar(value: 0.6, showTipGlint: true),
      ],
    );
  }
}
