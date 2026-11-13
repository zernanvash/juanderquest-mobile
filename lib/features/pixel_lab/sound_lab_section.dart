import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';

/// Pixel lab: Plan 84 sample sounds. Every effect is synthesized by
/// `tool/audio/make_sfx.py` (original work; see assets/licenses/credits.json).
class SoundLabSection extends StatefulWidget {
  const SoundLabSection({super.key});

  @override
  State<SoundLabSection> createState() => _SoundLabSectionState();
}

class _SoundLabSectionState extends State<SoundLabSection> {
  final _audio = GameAudio.instance;

  static const _groups = {
    'UI': ['tap', 'back', 'toggle_on', 'toggle_off', 'tab', 'sheet_open', 'error'],
    'REWARDS': ['coin', 'stamp', 'unlock', 'quest_complete', 'level_up'],
    'NAVIGATION': ['go', 'turn_chime', 'reroute', 'checkin', 'trail_complete'],
    'AR GAMES': ['ar_hit', 'ar_miss', 'ar_countdown', 'ar_win', 'ar_lose'],
    'MAP & PLAZA': ['pin_select', 'cheer'],
  };
  static const _varied = {'tap', 'coin', 'ar_hit'};

  @override
  void dispose() {
    _audio.stopAll();
    super.dispose();
  }

  Widget _stepper(String label, ValueNotifier<double> value, ValueChanged<double> onChanged, String keyName) {
    return ValueListenableBuilder<double>(
      valueListenable: value,
      builder: (context, v, _) => Row(
        children: [
          Expanded(
            child: Text('$label ${(v * 100).round()}%', style: PixelType.body(context)),
          ),
          PixelButton(
            key: ValueKey('${keyName}_down'),
            label: '-',
            variant: PixelButtonVariant.secondary,
            onPressed: v <= 0 ? null : () => onChanged((v - 0.2).clamp(0.0, 1.0)),
          ),
          const SizedBox(width: 8),
          PixelButton(
            key: ValueKey('${keyName}_up'),
            label: '+',
            variant: PixelButtonVariant.secondary,
            onPressed: v >= 1 ? null : () => onChanged((v + 0.2).clamp(0.0, 1.0)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Forest style: soft plucks, bells, wood, water and birds, with jazz chords. All made by script; nothing is downloaded.',
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(3)),
        ValueListenableBuilder<bool>(
          valueListenable: _audio.buttonSounds,
          builder: (context, on, _) => PixelButton(
            key: const ValueKey('lab_sound_buttons_toggle'),
            label: on ? 'Tap sound on every button: ON' : 'Tap sound on every button: OFF',
            variant: on ? PixelButtonVariant.primary : PixelButtonVariant.secondary,
            onPressed: () {
              _audio.buttonSounds.value = !on;
              _audio.playSfx(on ? 'toggle_off' : 'toggle_on');
            },
          ),
        ),
        SizedBox(height: grid.px(2)),
        _stepper('Effects volume', _audio.sfxVolume, (v) {
          _audio.sfxVolume.value = v;
          _audio.playSfx('tap');
        }, 'lab_sfx_volume'),
        SizedBox(height: grid.px(3)),
        for (final g in _groups.entries) ...[
          Text(g.key, style: PixelType.body(context)),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in g.value)
                PixelButton(
                  key: ValueKey('lab_sfx_$name'),
                  label: name.replaceAll('_', ' '),
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => _audio.playSfx(name, vary: _varied.contains(name)),
                ),
            ],
          ),
          SizedBox(height: grid.px(3)),
        ],
      ],
    );
  }
}
