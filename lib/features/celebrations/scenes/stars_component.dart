import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';

/// Twinkling 1-art-px background stars on the art-pixel grid.
/// Preallocates paints to satisfy the zero-allocation render rule.
class StarsComponent extends Component with HasGameReference<FlameGame> {
  StarsComponent(this.unit, {int seed = 3, this.count = 36})
      : _rng = math.Random(seed);

  final double unit;
  final int count;
  final math.Random _rng;
  late final List<(double, double, int)> _stars;
  double _t = 0;

  final Paint _paintHalo = Paint()
    ..isAntiAlias = false
    ..color = PixelPalette.blueLight;

  final Paint _paintCore = Paint()
    ..isAntiAlias = false
    ..color = PixelPalette.white;

  @override
  Future<void> onLoad() async {
    _stars = List.generate(
      count,
      (_) => (_rng.nextDouble(), _rng.nextDouble(), _rng.nextInt(6)),
    );
  }

  @override
  void update(double dt) {
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final tick = (_t * 6).floor();
    final u = unit;
    for (final (fx, fy, phase) in _stars) {
      if ((tick + phase) % 6 >= 4) continue;
      final x = (fx * game.size.x / u).floor() * u;
      final y = (fy * game.size.y / u).floor() * u;

      // 4-pixel cross halo (1 art px)
      canvas.drawRect(Rect.fromLTWH(x - u, y, u, u), _paintHalo);
      canvas.drawRect(Rect.fromLTWH(x + u, y, u, u), _paintHalo);
      canvas.drawRect(Rect.fromLTWH(x, y - u, u, u), _paintHalo);
      canvas.drawRect(Rect.fromLTWH(x, y + u, u, u), _paintHalo);
      // Center star core (1 art px)
      canvas.drawRect(Rect.fromLTWH(x, y, u, u), _paintCore);
    }
  }
}
