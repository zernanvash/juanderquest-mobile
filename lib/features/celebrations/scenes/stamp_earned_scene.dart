import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../steppers.dart';
import 'stars_component.dart';

/// Flame scene for Stamp Earned celebration:
/// Stamp drops from top in 12 fps steps -> lands with 2-frame squash.
/// Ring of red/redSoft ink pixels splats outward once.
/// Title "NEW STAMP!" types out, stamp name caption displayed below.
class StampEarnedGame extends FlameGame {
  StampEarnedGame({
    required this.unit,
    required this.font,
    required this.stampName,
    required this.stamp,
    required this.fontScale,
    this.reducedMotion = false,
    this.onHaptic,
  });

  final double unit;
  final String font;
  final String stampName;
  final PixelArt stamp;
  final double fontScale;
  final bool reducedMotion;
  final VoidCallback? onHaptic;

  late final _StampSpriteComponent _stampComp;
  late final _InkSplatComponent _splatComp;
  late final TextComponent _title;
  late final TextComponent _stampCaption;

  late final TypewriterStepper _titleStepper;

  static const _fullTitle = 'NEW STAMP!';
  double _t = 0;
  double _typewriterAccumulator = 0;

  bool get hasLanded => _stampComp.hasLanded;

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

    add(StarsComponent(unit));

    _stampComp = _StampSpriteComponent(
      unit: unit,
      stamp: stamp,
      reducedMotion: reducedMotion,
      onLand: () {
        onHaptic?.call();
        if (!reducedMotion) {
          _splatComp.splat(_stampComp.position, _stampComp.size.y);
        }
      },
    );

    _splatComp = _InkSplatComponent(unit);

    _title = TextComponent(
      text: reducedMotion ? _fullTitle : '',
      anchor: Anchor.center,
      textRenderer: _textPaint(22, PixelPalette.sun),
    );

    final displayCaption = stampName.length > 28
        ? '${stampName.substring(0, 25)}...'
        : stampName;

    _stampCaption = TextComponent(
      text: displayCaption,
      anchor: Anchor.center,
      textRenderer: _textPaint(
        14,
        PixelPalette.paperDim,
        fontWeight: FontWeight.w400,
      ),
    );

    if (reducedMotion) {
      _titleStepper.complete();
    }

    addAll([_splatComp, _stampComp, _title, _stampCaption]);
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
    final targetY = isLandscape ? s.y * 0.58 : s.y * 0.48;
    _title.position = Vector2(s.x / 2, s.y * 0.16);
    _stampCaption.position = Vector2(
      s.x / 2,
      isLandscape ? s.y * 0.28 : s.y * 0.25,
    );
    _stampComp.targetPosition = Vector2(s.x / 2, targetY);

    if (reducedMotion || _stampComp.hasLanded) {
      _stampComp.position = _stampComp.targetPosition.clone();
    } else {
      _stampComp.position.x = _stampComp.targetPosition.x;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (reducedMotion) return;

    _t += dt;

    // Typewriter
    if (_t >= 0.1 && !_titleStepper.isComplete) {
      _typewriterAccumulator += dt;
      while (_typewriterAccumulator >= 0.05) {
        _typewriterAccumulator -= 0.05;
        _titleStepper.step();
        _title.text = _titleStepper.text;
      }
    }
  }
}

class _StampSpriteComponent extends PositionComponent {
  _StampSpriteComponent({
    required this.unit,
    required this.stamp,
    required this.reducedMotion,
    required this.onLand,
  }) : super(anchor: Anchor.center);

  final double unit;
  final PixelArt stamp;
  final bool reducedMotion;
  final VoidCallback onLand;

  Vector2 targetPosition = Vector2.zero();
  late final ui.Image _img;
  final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  double _stepAcc = 0;
  bool _landed = false;
  int _squashFrame = 0;

  bool get hasLanded => _landed;

  @override
  Future<void> onLoad() async {
    _img = stamp.image();
    final scaleMultiplier = stamp.width <= 32 ? 2.5 : 1.75;
    size = Vector2(
      (stamp.width * unit * scaleMultiplier).roundToDouble(),
      (stamp.height * unit * scaleMultiplier).roundToDouble(),
    );

    if (reducedMotion) {
      _landed = true;
      position = targetPosition.clone();
    } else {
      // Start above screen
      position = Vector2(targetPosition.x, -size.y);
    }
  }

  @override
  void update(double dt) {
    if (reducedMotion) return;

    _stepAcc += dt;
    const stepDuration = 1.0 / 12.0;

    while (_stepAcc >= stepDuration) {
      _stepAcc -= stepDuration;

      if (!_landed) {
        // Drop in 12 fps discrete steps
        final dropStep = 48.0 * unit;
        position.x = targetPosition.x;
        position.y += dropStep;

        if (position.y >= targetPosition.y) {
          position.y = targetPosition.y;
          _landed = true;
          _squashFrame = 1; // start 2-frame squash
          scale = Vector2(1.25, 0.75);
          onLand();
        }
      } else if (_squashFrame == 1) {
        // Frame 2: normal
        _squashFrame = 2;
        scale = Vector2(1.0, 1.0);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawImageRect(
      _img,
      Rect.fromLTWH(0, 0, _img.width.toDouble(), _img.height.toDouble()),
      Rect.fromLTWH(0, 0, size.x, size.y),
      _paint,
    );
  }
}

class _InkSplatComponent extends Component
    with HasGameReference<StampEarnedGame> {
  _InkSplatComponent(this.unit);

  final double unit;
  InkSplatStepper? _stepper;
  bool _active = false;

  final Paint _paintRed = Paint()
    ..isAntiAlias = false
    ..color = PixelPalette.red;

  final Paint _paintRedSoft = Paint()
    ..isAntiAlias = false
    ..color = PixelPalette.redSoft;

  void splat(Vector2 from, double stampHeight) {
    _stepper = InkSplatStepper(
      unit: unit,
      originX: from.x,
      originY: from.y + stampHeight * 0.2,
      count: 16,
    );
    _active = true;
  }

  @override
  void update(double dt) {
    if (!_active || _stepper == null) return;
    _stepper!.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!_active || _stepper == null) return;
    for (final p in _stepper!.particles) {
      final x = (p.x / unit).round() * unit;
      final y = (p.y / unit).round() * unit;
      final s = p.sizePx * unit;
      final paint = p.isSoft ? _paintRedSoft : _paintRed;
      canvas.drawRect(Rect.fromLTWH(x - s / 2, y - s / 2, s, s), paint);
    }
  }
}
