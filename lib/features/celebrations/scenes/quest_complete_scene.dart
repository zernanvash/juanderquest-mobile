import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../celebration_art.dart';
import '../steppers.dart';
import 'stars_component.dart';

/// Flame scene for Quest Complete celebration:
/// Chest shakes at 12 fps -> opens -> 22 coins burst out with gravity and spin.
/// Title types out, quest caption shows, reward counts up in steps of 5.
class QuestCompleteGame extends FlameGame {
  QuestCompleteGame({
    required this.unit,
    required this.font,
    required this.questTitle,
    required this.reward,
    required this.fontScale,
    this.reducedMotion = false,
    this.onHaptic,
  });

  final double unit;
  final String font;
  final String questTitle;
  final int reward;
  final double fontScale;
  final bool reducedMotion;
  final VoidCallback? onHaptic;

  late final _ChestComponent _chest;
  late final _CoinBurstComponent _coins;
  late final TextComponent _title;
  late final TextComponent _questCaption;
  late final TextComponent _counter;

  late final TypewriterStepper _titleStepper;
  late final RewardCounterStepper _rewardStepper;

  static const _fullTitle = 'QUEST COMPLETE!';
  double _t = 0;
  double _typewriterAccumulator = 0;
  double _counterAccumulator = 0;

  bool get isChestOpen => _chest.isOpen;
  int get displayedReward => _rewardStepper.current;

  @override
  Color backgroundColor() => PixelPalette.ink;

  TextPaint _textPaint(
    double size,
    Color color, {
    FontWeight fontWeight = FontWeight.w700,
  }) =>
      TextPaint(
        style: TextStyle(
          fontFamily: font,
          fontSize: (size * fontScale).roundToDouble().clamp(10, 48),
          fontWeight: fontWeight,
          color: color,
          shadows: [
            Shadow(color: PixelPalette.ink, offset: Offset(unit, unit)),
          ],
        ),
      );

  @override
  Future<void> onLoad() async {
    _titleStepper = TypewriterStepper(_fullTitle);
    _rewardStepper = RewardCounterStepper(targetReward: reward, stepSize: 5);

    add(StarsComponent(unit));

    _chest = _ChestComponent(
      unit,
      reducedMotion: reducedMotion,
      onOpen: () {
        onHaptic?.call();
        if (!reducedMotion) {
          _coins.burst(_chest.position);
        }
      },
    );

    _coins = _CoinBurstComponent(unit);

    _title = TextComponent(
      text: reducedMotion ? _fullTitle : '',
      anchor: Anchor.center,
      textRenderer: _textPaint(20, PixelPalette.sun),
    );

    final displayCaption = questTitle.length > 28
        ? '${questTitle.substring(0, 25)}...'
        : questTitle;

    _questCaption = TextComponent(
      text: displayCaption,
      anchor: Anchor.center,
      textRenderer: _textPaint(
        13,
        PixelPalette.paperDim,
        fontWeight: FontWeight.w400,
      ),
    );

    _counter = TextComponent(
      text: reducedMotion ? '+$reward mJDQ' : '',
      anchor: Anchor.center,
      textRenderer: _textPaint(18, PixelPalette.white),
    );

    if (reducedMotion) {
      _titleStepper.complete();
      _rewardStepper.complete();
    }

    addAll([_chest, _coins, _title, _questCaption, _counter]);
    _layout(size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout(size);
  }

  void _layout(Vector2 s) {
    if (s.x <= 0 || s.y <= 0) return;
    final isLandscape = s.x > s.y;
    if (isLandscape) {
      _title.position = Vector2(s.x / 2, s.y * 0.16);
      _questCaption.position = Vector2(s.x / 2, s.y * 0.28);
      _chest.position = Vector2(s.x * 0.35, s.y * 0.58);
      _counter.position = Vector2(s.x * 0.65, s.y * 0.58);
    } else {
      _title.position = Vector2(s.x / 2, s.y * 0.15);
      _questCaption.position = Vector2(s.x / 2, s.y * 0.22);
      _chest.position = Vector2(s.x / 2, s.y * 0.44);
      _counter.position = Vector2(s.x / 2, s.y * 0.64);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (reducedMotion) return;

    _t += dt;

    // Typewriter: starts at t = 0.2s, advances 1 letter every 0.05s
    if (_t >= 0.2 && !_titleStepper.isComplete) {
      _typewriterAccumulator += dt;
      while (_typewriterAccumulator >= 0.05) {
        _typewriterAccumulator -= 0.05;
        _titleStepper.step();
        _title.text = _titleStepper.text;
      }
    }

    // Reward counter: starts once chest opens (t >= 0.9s), steps every 0.08s
    if (_t >= 0.9 && !_rewardStepper.isComplete) {
      _counterAccumulator += dt;
      while (_counterAccumulator >= 0.08) {
        _counterAccumulator -= 0.08;
        _rewardStepper.step();
        _counter.text = '+${_rewardStepper.current} mJDQ';
      }
    }
  }
}

class _ChestComponent extends PositionComponent {
  _ChestComponent(
    this.unit, {
    required this.onOpen,
    this.reducedMotion = false,
  }) : super(anchor: Anchor.center);

  final double unit;
  final VoidCallback onOpen;
  final bool reducedMotion;

  late final ui.Image _closedImg;
  late final ui.Image _openedImg;
  final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  double _t = 0;
  double _stepAcc = 0;
  int _bob = 0;
  int _shake = 0;
  bool _open = false;

  bool get isOpen => _open;

  @override
  Future<void> onLoad() async {
    _closedImg = CelebrationArt.chestClosed.image();
    _openedImg = CelebrationArt.chestOpen.image();
    // Chest is 16x16 art pixels at 4x scale
    size = Vector2.all(16 * unit * 4);
    if (reducedMotion) {
      _open = true;
    }
  }

  @override
  void update(double dt) {
    if (reducedMotion) return;

    _t += dt;
    _stepAcc += dt;

    // Stepped at 12 fps
    const stepDuration = 1.0 / 12.0;
    while (_stepAcc >= stepDuration) {
      _stepAcc -= stepDuration;
      if (!_open) {
        // Shake for 0.8s: alternate -1, 1 art px
        _shake = _t < 0.8 ? (_shake <= 0 ? 1 : -1) : 0;
      } else {
        _bob = (_t * 4).floor() % 2;
      }
    }

    if (!_open && _t >= 0.8) {
      _open = true;
      _shake = 0;
      onOpen();
    }
  }

  @override
  void render(Canvas canvas) {
    final img = _open ? _openedImg : _closedImg;
    final px = unit * 4;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(_shake * unit, -_bob * px * 0.25, size.x, size.y),
      _paint,
    );
  }
}

class _CoinBurstComponent extends Component
    with HasGameReference<QuestCompleteGame> {
  _CoinBurstComponent(this.unit);

  final double unit;
  late final CoinPhysicsStepper _stepper;
  late final ui.Image _coinImg;
  final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  bool _bursting = false;

  @override
  Future<void> onLoad() async {
    _coinImg = CelebrationArt.smallCoin.image();
  }

  void burst(Vector2 from) {
    _stepper = CoinPhysicsStepper(
      unit: unit,
      count: 22,
      originX: from.x,
      originY: from.y,
    );
    _bursting = true;
  }

  @override
  void update(double dt) {
    if (!_bursting) return;
    _stepper.update(dt);
    // Remove coins that fall far below the screen
    _stepper.coins.removeWhere((c) => c.y > game.size.y + 40);
  }

  @override
  void render(Canvas canvas) {
    if (!_bursting) return;
    // Small coin scale: 2x unit (size = 16x16 art units, smaller than chest)
    final s = unit * 2;
    for (final c in _stepper.coins) {
      final x = (c.x / unit).round() * unit;
      final y = (c.y / unit).round() * unit;
      // Spinning coin: edge-on every other frame
      final isEdgeOn = c.frame % 4 == 1 || c.frame % 4 == 3;
      final w = isEdgeOn ? 4 * s : 8 * s;
      canvas.drawImageRect(
        _coinImg,
        const Rect.fromLTWH(0, 0, 8, 8),
        Rect.fromLTWH(x - w / 2, y, w, 8 * s),
        _paint,
      );
    }
  }
}
