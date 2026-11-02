import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_grid.dart';
import 'celebration_button.dart';
import 'celebration_models.dart';
import 'scenes/level_up_scene.dart';
import 'scenes/quest_complete_scene.dart';
import 'scenes/stamp_earned_scene.dart';

export 'celebration_art.dart';
export 'celebration_models.dart';

/// Displays a full-screen celebration scene (Quest complete, Level up, Stamp earned).
/// Completes when the traveler taps the action button or presses Back.
Future<void> showCelebration(BuildContext context, Celebration c) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, __) => CelebrationPage(celebration: c),
    ),
  );
}

/// Full-screen host page for celebration scenes with Flutter overlay action button.
class CelebrationPage extends StatefulWidget {
  const CelebrationPage({super.key, required this.celebration});

  final Celebration celebration;

  @override
  State<CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<CelebrationPage>
    with WidgetsBindingObserver {
  late final FlameGame _game;
  bool _gameCreated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceForScreenReader();
    });
  }

  void _announceForScreenReader() {
    final message = switch (widget.celebration) {
      QuestComplete qc => 'Quest complete. ${qc.reward} mJDQ.',
      LevelUp lu => 'Level up. Level ${lu.toLevel}.',
      StampEarned se => 'New stamp. ${se.stampName}.',
    };
    SemanticsService.announce(message, TextDirection.ltr);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_gameCreated) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _game.pauseEngine();
    } else if (state == AppLifecycleState.resumed) {
      _game.resumeEngine();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _triggerHaptic(BuildContext context) {
    if (PixelScope.of(context).haptics) {
      HapticFeedback.selectionClick();
    }
  }

  FlameGame _createGame(
    BuildContext context,
    PixelGrid grid,
    PixelSettings settings,
    bool reducedMotion,
  ) {
    final c = widget.celebration;
    switch (c) {
      case QuestComplete():
        return QuestCompleteGame(
          unit: grid.unit,
          font: settings.font,
          questTitle: c.questTitle,
          reward: c.reward,
          fontScale: settings.fontScale(),
          reducedMotion: reducedMotion,
          onHaptic: () => _triggerHaptic(context),
        );
      case LevelUp():
        return LevelUpGame(
          unit: grid.unit,
          font: settings.font,
          fromLevel: c.fromLevel,
          toLevel: c.toLevel,
          fontScale: settings.fontScale(),
          reducedMotion: reducedMotion,
          onHaptic: () => _triggerHaptic(context),
        );
      case StampEarned():
        return StampEarnedGame(
          unit: grid.unit,
          font: settings.font,
          stampName: c.stampName,
          stamp: c.stamp,
          fontScale: settings.fontScale(),
          reducedMotion: reducedMotion,
          onHaptic: () => _triggerHaptic(context),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final settings = PixelScope.of(context);
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    if (!_gameCreated) {
      _game = _createGame(context, grid, settings, reducedMotion);
      _gameCreated = true;
    }

    final (buttonLabel, buttonStyle, buttonTextColor) =
        switch (widget.celebration) {
      QuestComplete() => (
          'Claim reward',
          PixelBoxStyle.gold,
          PixelPalette.ink,
        ),
      LevelUp() => (
          'Continue',
          PixelBoxStyle.green,
          PixelPalette.white,
        ),
      StampEarned() => (
          'Add to passport',
          PixelBoxStyle.wood,
          PixelPalette.white,
        ),
    };

    return Scaffold(
      backgroundColor: PixelPalette.ink,
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'actionButton': (context, game) => Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: grid.px(6),
                      vertical: grid.px(4),
                    ),
                    child: CelebrationButton(
                      label: buttonLabel,
                      style: buttonStyle,
                      textColor: buttonTextColor,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
        },
        initialActiveOverlays: const ['actionButton'],
      ),
    );
  }
}
