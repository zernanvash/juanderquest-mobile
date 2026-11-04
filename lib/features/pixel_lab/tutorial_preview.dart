import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/theme/app_theme.dart';
import '../onboarding/pixel_tutorial.dart';

/// The first-run tutorial lines (owner 2026-11-04), shared by every style.
List<TutorialStep> firstRunSteps({
  GlobalKey? hero,
  GlobalKey? nextStop,
  GlobalKey? hotbar,
}) =>
    [
      const TutorialStep(
        "Hey, I'm Juan! First time in Pangasinan?",
        choices: ['Yes, show me', "No, I'll explore"],
      ),
      TutorialStep(
        'This card is your travel log. Visit places and finish quests to level up.',
        target: hero,
      ),
      TutorialStep(
        'Tap here for your next adventure: places near you, the map, or a quest.',
        target: nextStop,
      ),
      TutorialStep(
        'This bar jumps between Home, Map, Quests, JuanChoice and your Profile. Have fun!',
        target: hotbar,
      ),
    ];

/// Pixel lab: a pretend Home screen with one tutorial style running on top,
/// so the owner can compare the styles on the phone.
class TutorialPreviewScreen extends ConsumerStatefulWidget {
  final TutorialStyle style;

  const TutorialPreviewScreen({super.key, required this.style});

  @override
  ConsumerState<TutorialPreviewScreen> createState() =>
      _TutorialPreviewScreenState();
}

class _TutorialPreviewScreenState extends ConsumerState<TutorialPreviewScreen> {
  final _hero = GlobalKey();
  final _nextStop = GlobalKey();
  final _hotbar = GlobalKey();
  bool _showing = true;
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    return PixelScope(
      settings: ref.watch(pixelSettingsProvider),
      child: Theme(
        data: AppTheme.pixel,
        child: Builder(builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.woodDeep,
            body: Stack(
              children: [
                DitherBackground(
                  top: PixelPalette.green,
                  bottom: PixelPalette.greenDeep,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PixelAppBar(
                          title: widget.style.label,
                          onBack: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.all(grid.px(4)),
                            children: [
                              PixelPanel(
                                key: _hero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('MABUHAY, TRAVELER',
                                        style: PixelType.title(context)),
                                    Text('LEVEL 1 · 0 / 50 XP',
                                        style: PixelType.body(context)),
                                  ],
                                ),
                              ),
                              SizedBox(height: grid.px(4)),
                              PixelPanel(
                                key: _nextStop,
                                style: PixelBoxStyle.gold,
                                child: Text('YOUR NEXT STOP',
                                    style: PixelType.title(context)),
                              ),
                              SizedBox(height: grid.px(4)),
                              if (!_showing)
                                PixelButton(
                                  key: const ValueKey('tutorial-replay'),
                                  label: 'Play again',
                                  expand: true,
                                  onPressed: () => setState(() {
                                    _showing = true;
                                    _run++;
                                  }),
                                ),
                            ],
                          ),
                        ),
                        PixelPanel(
                          key: _hotbar,
                          style: PixelBoxStyle.wood,
                          child: Text(
                            'HOME  MAP  QUESTS  CHOICE  PROFILE',
                            textAlign: TextAlign.center,
                            style: PixelType.small(context,
                                color: PixelPalette.parchment),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showing)
                  Positioned.fill(
                    child: PixelTutorialOverlay(
                      key: ValueKey(_run),
                      style: widget.style,
                      steps: firstRunSteps(
                          hero: _hero, nextStop: _nextStop, hotbar: _hotbar),
                      onDone: () => setState(() => _showing = false),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
