import 'dart:math' as math;

/// Stepped typewriter reveal for celebration titles.
/// Advances one letter per step.
class TypewriterStepper {
  TypewriterStepper(this.fullText);

  final String fullText;
  int _letters = 0;

  int get revealedLength => _letters;
  String get text => fullText.substring(0, _letters);
  bool get isComplete => _letters >= fullText.length;

  void step() {
    if (_letters < fullText.length) {
      _letters++;
    }
  }

  void complete() {
    _letters = fullText.length;
  }
}

/// Stepped reward counter: increments by [stepSize] (default 5) on each step
/// and lands exactly on [targetReward], even when target is not a multiple of [stepSize].
class RewardCounterStepper {
  RewardCounterStepper({required this.targetReward, this.stepSize = 5});

  final int targetReward;
  final int stepSize;
  int _current = 0;

  int get current => _current;
  bool get isComplete => _current >= targetReward;

  void step() {
    if (_current < targetReward) {
      if (_current + stepSize <= targetReward) {
        _current += stepSize;
      } else {
        _current = targetReward;
      }
    }
  }

  void complete() {
    _current = targetReward;
  }
}

/// Rotates rays in exactly 8 discrete steps (45° per step, 12 fps feel).
class RayRotationStepper {
  int _step = 0;

  int get currentStep => _step % 8;
  double get angle => (_step % 8) * (2 * math.pi / 8);

  void step() {
    _step++;
  }

  void reset() {
    _step = 0;
  }
}

/// A single coin particle for the quest complete coin burst.
class CoinParticle {
  CoinParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  double x;
  double y;
  double vx;
  double vy;
  int frame = 0;
}

/// Deterministic 12 fps coin physics stepper with seeded RNG.
class CoinPhysicsStepper {
  CoinPhysicsStepper({
    required this.unit,
    int count = 22,
    int seed = 7,
    double originX = 0,
    double originY = 0,
  }) {
    final rng = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.6;
      final speed = (260 + rng.nextDouble() * 220) * unit / 3;
      coins.add(CoinParticle(
        x: originX,
        y: originY,
        vx: math.cos(a) * speed,
        vy: math.sin(a) * speed,
      ));
    }
  }

  final double unit;
  final List<CoinParticle> coins = [];
  double _accumulator = 0;
  int tickCount = 0;
  static const double stepDuration = 1.0 / 12.0;

  void update(double dt) {
    _accumulator += dt;
    while (_accumulator >= stepDuration) {
      _accumulator -= stepDuration;
      step();
    }
  }

  void step() {
    tickCount++;
    const gravity = 900.0;
    for (final c in coins) {
      c.vy += gravity * unit / 3 * stepDuration;
      c.x += c.vx * stepDuration;
      c.y += c.vy * stepDuration;
      c.frame++;
    }
  }
}

/// Ink splat particle for the stamp landing ring.
class InkSplatParticle {
  InkSplatParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isSoft,
    required this.sizePx,
  });

  double x;
  double y;
  double vx;
  double vy;
  final bool isSoft;
  final int sizePx;
}

/// Stepped ink splat stepper (12 fps, max 20 particles).
class InkSplatStepper {
  InkSplatStepper({
    required this.unit,
    required double originX,
    required double originY,
    int count = 16,
    int seed = 42,
  }) {
    final rng = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (rng.nextDouble() - 0.5) * 0.2;
      final speed = (90 + rng.nextDouble() * 70) * unit / 2;
      particles.add(InkSplatParticle(
        x: originX,
        y: originY,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        isSoft: i % 2 == 1,
        sizePx: rng.nextBool() ? 2 : 1,
      ));
    }
  }

  final double unit;
  final List<InkSplatParticle> particles = [];
  double _accumulator = 0;
  int tickCount = 0;
  static const double stepDuration = 1.0 / 12.0;

  void update(double dt) {
    _accumulator += dt;
    while (_accumulator >= stepDuration) {
      _accumulator -= stepDuration;
      step();
    }
  }

  void step() {
    tickCount++;
    // Decelerate ink splat particles over 6-8 frames.
    for (final p in particles) {
      if (tickCount <= 8) {
        p.x += p.vx * stepDuration;
        p.y += p.vy * stepDuration;
        p.vx *= 0.75;
        p.vy *= 0.75;
      }
    }
  }
}
