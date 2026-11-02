import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../steppers.dart';
import 'stars_component.dart';

/// Flame scene for Level Up celebration:
/// Rotating sun-ray burst in 8 discrete steps behind center.
/// Level numeral flips from [fromLevel] to [toLevel] with a 3-frame squash.
/// Juan stands beside it animating at 8 fps. Title "LEVEL UP!" types out.
class LevelUpGame extends FlameGame {
  LevelUpGame({
    required this.unit,
    required this.font,
    required this.fromLevel,
    required this.toLevel,
    required this.fontScale,
    this.reducedMotion = false,
    this.onHaptic,
  });

  final double unit;
  final String font;
  final int fromLevel;
  final int toLevel;
  final double fontScale;
  final bool reducedMotion;
  final VoidCallback? onHaptic;

  late final _SunRaysComponent _sunRays;
  late final _LevelNumeralComponent _numeral;
  late final _JuanComponent _juan;
  late final TextComponent _title;

  late final TypewriterStepper _titleStepper;

  static const _fullTitle = 'LEVEL UP!';
  double _t = 0;
  double _typewriterAccumulator = 0;

  int get displayedLevel => _numeral.currentLevel;

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

    _sunRays = _SunRaysComponent(unit, reducedMotion: reducedMotion);

    _numeral = _LevelNumeralComponent(
      unit: unit,
      font: font,
      fontScale: fontScale,
      fromLevel: fromLevel,
      toLevel: toLevel,
      reducedMotion: reducedMotion,
      onFlipHaptic: onHaptic,
    );

    _juan = _JuanComponent(unit);

    _title = TextComponent(
      text: reducedMotion ? _fullTitle : '',
      anchor: Anchor.center,
      textRenderer: _textPaint(22, PixelPalette.sun),
    );

    if (reducedMotion) {
      _titleStepper.complete();
    }

    addAll([_sunRays, _numeral, _juan, _title]);
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
    final centerPos = isLandscape
        ? Vector2(s.x * 0.45, s.y * 0.52)
        : Vector2(s.x / 2, s.y * 0.46);

    final sunRadius = math.min(s.x, s.y) * 0.32;
    _sunRays.position = centerPos;
    _sunRays.rebuildPictures(centerPos, sunRadius);

    if (isLandscape) {
      _title.position = Vector2(s.x / 2, s.y * 0.16);
      _numeral.position = Vector2(centerPos.x - 24 * unit, centerPos.y);
      _juan.position = Vector2(centerPos.x + 28 * unit, centerPos.y);
    } else {
      _title.position = Vector2(s.x / 2, s.y * 0.16);
      _numeral.position = Vector2(centerPos.x - 24 * unit, centerPos.y);
      _juan.position = Vector2(centerPos.x + 24 * unit, centerPos.y);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (reducedMotion) return;

    _t += dt;

    // Typewriter reveal
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

class _SunRaysComponent extends PositionComponent {
  _SunRaysComponent(this.unit, {this.reducedMotion = false})
      : super(anchor: Anchor.center);

  final double unit;
  final bool reducedMotion;
  final RayRotationStepper _stepper = RayRotationStepper();
  final List<ui.Picture> _pictures = [];
  double _stepAcc = 0;

  void rebuildPictures(Vector2 center, double radius) {
    for (final pic in _pictures) {
      pic.dispose();
    }
    _pictures.clear();

    final paintSun = Paint()
      ..isAntiAlias = false
      ..color = PixelPalette.sun;
    final paintSunLight = Paint()
      ..isAntiAlias = false
      ..color = PixelPalette.sunLight;

    const wedgeCount = 16;
    const wedgeAngle = 2 * math.pi / wedgeCount;

    // Pre-record exactly 8 discrete rotational steps
    for (var step = 0; step < 8; step++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final baseRot = step * (2 * math.pi / 8);

      // Clip wedges into a circular medallion so dark ink sky and stars show around it
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)));

      for (var i = 0; i < wedgeCount; i++) {
        final a1 = baseRot + i * wedgeAngle;
        final a2 = baseRot + (i + 1) * wedgeAngle;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(radius * 1.5 * math.cos(a1), radius * 1.5 * math.sin(a1))
          ..lineTo(radius * 1.5 * math.cos(a2), radius * 1.5 * math.sin(a2))
          ..close();
        canvas.drawPath(path, i % 2 == 0 ? paintSun : paintSunLight);
      }
      canvas.restore();

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 2
        ..color = PixelPalette.ink;
      canvas.drawCircle(Offset.zero, radius, borderPaint);

      _pictures.add(recorder.endRecording());
    }
  }

  @override
  void update(double dt) {
    if (reducedMotion) return;
    _stepAcc += dt;
    // Rotate in 8 discrete steps at 6-12 fps
    const stepDuration = 1.0 / 8.0;
    while (_stepAcc >= stepDuration) {
      _stepAcc -= stepDuration;
      _stepper.step();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_pictures.isEmpty) return;
    final index = reducedMotion ? 0 : _stepper.currentStep;
    canvas.drawPicture(_pictures[index]);
  }

  @override
  void onRemove() {
    for (final pic in _pictures) {
      pic.dispose();
    }
    _pictures.clear();
    super.onRemove();
  }
}

class _LevelNumeralComponent extends PositionComponent {
  _LevelNumeralComponent({
    required this.unit,
    required this.font,
    required this.fontScale,
    required this.fromLevel,
    required this.toLevel,
    required this.reducedMotion,
    this.onFlipHaptic,
  }) : super(anchor: Anchor.center);

  final double unit;
  final String font;
  final double fontScale;
  final int fromLevel;
  final int toLevel;
  final bool reducedMotion;
  final VoidCallback? onFlipHaptic;

  late int _level;
  double _t = 0;
  bool _flipped = false;

  int get currentLevel => _level;

  late final TextPaint _lvlLabelPaint;
  late final TextPaint _numeralPaint;

  @override
  Future<void> onLoad() async {
    _level = reducedMotion ? toLevel : fromLevel;
    size = Vector2(24 * unit, 32 * unit);

    _lvlLabelPaint = TextPaint(
      style: TextStyle(
        fontFamily: font,
        fontSize: (10 * fontScale).roundToDouble().clamp(8, 18),
        fontWeight: FontWeight.w700,
        color: PixelPalette.sun,
        shadows: [
          Shadow(color: PixelPalette.ink, offset: Offset(unit, unit)),
        ],
      ),
    );

    _numeralPaint = TextPaint(
      style: TextStyle(
        fontFamily: font,
        fontSize: (22 * fontScale).roundToDouble().clamp(14, 40),
        fontWeight: FontWeight.w700,
        color: PixelPalette.white,
        shadows: [
          Shadow(color: PixelPalette.ink, offset: Offset(unit * 1.5, unit * 1.5)),
        ],
      ),
    );
  }

  @override
  void update(double dt) {
    if (reducedMotion) return;

    _t += dt;

    // Flip level at t >= 0.7s
    if (_t >= 0.7 && !_flipped) {
      _flipped = true;
      _level = toLevel;
      onFlipHaptic?.call();
    }

    // 3-frame squash at t = 0.6s..0.8s
    if (_t < 0.6) {
      scale = Vector2(1.0, 1.0);
    } else if (_t < 0.7) {
      // Frame 1: tall
      scale = Vector2(0.7, 1.3);
    } else if (_t < 0.8) {
      // Frame 2: wide (flip beat)
      scale = Vector2(1.4, 0.6);
    } else {
      // Frame 3: normal
      scale = Vector2(1.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final plateRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(plateRect, Radius.circular(unit * 2));

    // Dark ink badge background
    final bgPaint = Paint()..color = PixelPalette.ink;
    canvas.drawRRect(rrect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 1.5
      ..color = PixelPalette.woodLight;
    canvas.drawRRect(rrect, borderPaint);

    // "LVL" tag at upper part
    _lvlLabelPaint.render(
      canvas,
      'LVL',
      Vector2(size.x / 2, size.y * 0.28),
      anchor: Anchor.center,
    );

    // Numeral in lower center
    _numeralPaint.render(
      canvas,
      '$_level',
      Vector2(size.x / 2, size.y * 0.68),
      anchor: Anchor.center,
    );
  }
}

class _JuanComponent extends PositionComponent {
  _JuanComponent(this.unit) : super(anchor: Anchor.center);

  final double unit;
  late final List<ui.Image> _frames;
  final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  double _t = 0;

  @override
  Future<void> onLoad() async {
    _frames = DesignerArt.juanIdle.frames.map((f) => f.image()).toList();
    // Juan idle is 16x16 art pixels at 3.5x scale
    size = Vector2.all(16 * unit * 3.5);
  }

  @override
  void update(double dt) {
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    if (_frames.isEmpty) return;
    // 8 fps animation
    final frameIndex = (_t * 8).floor() % _frames.length;
    final img = _frames[frameIndex];
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, size.x, size.y),
      _paint,
    );
  }
}
