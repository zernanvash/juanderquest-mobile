import 'dart:math' as math;

import 'ar_minigame.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// "Pukpok Palayok" (Plan 77 `pabitin_palayok`, tuned by Plan 77c): a clay pot
/// hangs at chest height 2.2 m in front of the line and swings. Tap HAMPAS (one
/// tap, one swing of the bamboo stick) when the pot is in the circle. After the
/// first hit you are blindfolded (piring, like the real game): a woven-cloth
/// vignette dims the view but the middle still peeks through, so you time the
/// swing. Three hits crack it open and the coins fall.
class PalayokGame extends ArMiniGame {
  PalayokGame({super.rangeScale, math.Random? random}) : _random = random ?? math.Random();

  static const gravity = 9.8;
  static const potScale = 2.0;

  /// Rope top (the swing point), above the anchor.
  static const pivotHeight = 2.25;

  /// Rope top to the middle of the pot (measured on the sprite: 0.436 m at scale 1).
  static const ropeLength = 0.436 * potScale;
  static const potRadius = 0.125 * potScale;
  static const swingRad = 0.35;
  static const periodByHits = [2.4, 2.0, 1.6];
  static const aimDeg = 5.5;

  /// The stick's swing on the HUD after each strike.
  static const swingS = 0.18;
  static const strikeCooldownS = 0.6;
  static const coins = 14;
  static const _sheets = ['palayok_whole', 'palayok_crack1', 'palayok_crack2'];

  final math.Random _random;

  @override
  final int targetHits = 3;
  @override
  int hits = 0;
  @override
  bool placed = false;
  bool won = false;
  @override
  bool get over => won;
  @override
  bool get passed => won;
  @override
  int get boardScore => won ? ((_brokeAt - _startedAt) * 1000).round() : 0;
  @override
  Map<String, Object> get stats => {'swings': swings};

  final Swing _swing = Swing(periodByHits[0], 0);
  double _nextStrike = 0;
  double _wonAt = double.infinity;
  double _struckAt = -1;
  double _startedAt = 0;
  double _brokeAt = 0;
  int swings = 0;

  @override
  String get title => 'PUKPOK PALAYOK';
  @override
  double get fullDistance => 2.2;
  @override
  String get placeHint =>
      'Stand where you will swing, face open ground, then tap STAND HERE. The palayok hangs ${standDistance.toStringAsFixed(1)} m ahead.';
  @override
  String get endText => 'Broke it in ${(_brokeAt - _startedAt).toStringAsFixed(1)} s with $swings swings. Coins!';
  @override
  ArButtonMode get buttonMode => ArButtonMode.tap;

  /// Blindfolded (the piring vignette) from the second strike on.
  @override
  bool blind(double now) => piring;

  bool get piring => hits >= 1 && !broken;

  bool get broken => hits >= targetHits;

  /// Swing angle (radians, anticlockwise as seen) at [now].
  double angle(double now) => broken ? 0 : swingRad * _swing.sinAt(now);

  /// Middle of the pot at [now], seen from [pose] (the pot swings across the view).
  V3 pot(double now, GamePose pose) {
    final a = angle(now);
    final r = rightOf(pose.forward);
    return const V3(0, pivotHeight, 0) + r * (ropeLength * math.sin(a)) + V3(0, -ropeLength * math.cos(a), 0);
  }

  bool onTarget(double now, GamePose pose) => inReticle(pose, pot(now, pose), radius: potRadius, coneDeg: aimDeg);

  @override
  bool canPress(double now) => placed && !broken && now >= _nextStrike;

  @override
  String buttonLabel(double now) => 'HAMPAS!';

  @override
  ArMeter? meter(double now, GamePose? pose) => null;

  @override
  String? meterCaption(double now, GamePose? pose) {
    if (piring) return 'PIRING! Feel the rhythm: tap HAMPAS as it swings into the middle.';
    return 'Tap HAMPAS when the palayok is in the circle.';
  }

  /// The aim circle, green as the pot crosses it (on every hit).
  @override
  bool? reticle(double now, GamePose? pose) => placed && !broken ? (pose != null && onTarget(now, pose)) : null;

  /// The bamboo stick at the bottom right; it swings across the circle for
  /// [swingS] after each strike.
  @override
  ArProp? prop(double now) {
    if (!placed || broken) return null;
    final t = now - _struckAt;
    final swing = _struckAt >= 0 && t >= 0 && t < swingS ? math.sin(math.pi * t / swingS) : 0.0;
    return (sheet: 'pamalo', frames: 1, frame: 0, x: 0.62, y: 0.95, size: 230.0, dy: 0.0, turn: -0.15 - 1.1 * swing);
  }

  @override
  String? status(GamePose? pose) => 'SWINGS $swings';

  @override
  String? hint(double now, GamePose? pose) {
    if (!placed || broken || pose == null) return null;
    return turnHint(pose, const V3(0, pivotHeight - ropeLength, 0));
  }

  @override
  void place(double now, GamePose? pose) {
    placed = true;
    _startedAt = now;
    _struckAt = -1;
    _swing
      ..period = periodByHits[hits.clamp(0, 2)]
      ..epoch = now;
    show(scene(now));
  }

  @override
  void unplace() {
    placed = false;
    show(const []);
  }

  @override
  void restart(double now, GamePose? pose) {
    hits = 0;
    swings = 0;
    won = false;
    _wonAt = double.infinity;
    place(now, pose);
  }

  @override
  void press(double now, GamePose? pose) {
    if (!canPress(now) || pose == null) return;
    if (!onLine(pose)) {
      say('BALIK SA LINYA!');
      return;
    }
    _nextStrike = now + strikeCooldownS;
    _struckAt = now;
    swings++;
    if (!onTarget(now, pose)) {
      say('MINTIS!');
      buzz(ArHaptic.light);
      return;
    }
    final at = pot(now, pose);
    hits++;
    buzz(ArHaptic.heavy);
    if (broken) {
      _brokeAt = now;
      say('BASAG!');
      _wonAt = now + 1.8;
      show(breakScene(angle: swingRad * _swing.sinAt(now), at: at));
      return;
    }
    say('PUKPOK!');
    _swing.retime(now, periodByHits[hits]);
    show([...scene(now), ArSprite('fx_sparkle', x: at.x, y: at.y, z: at.z, scale: 4, fps: 15, life: 0.4)]);
  }

  @override
  void update(double now, GamePose? pose) {
    if (!won && now >= _wonAt) {
      won = true;
      buzz(ArHaptic.heavy);
    }
  }

  /// The pot swinging from [now].
  List<ArSprite> scene(double now) => [
        lineSprite,
        const ArSprite('shadow', x: 0, y: 0, z: 0, scale: 4, floor: true),
        ArSprite(_sheets[hits.clamp(0, 2)],
            x: 0,
            y: pivotHeight,
            z: 0,
            scale: potScale,
            oscPeriod: _swing.period,
            oscPhase: _swing.phaseAt(now),
            rollAmp: swingRad),
      ];

  /// The pot bursting where it was hit, and the coins falling from [at].
  List<ArSprite> breakScene({required double angle, required V3 at}) {
    final out = <ArSprite>[
      lineSprite,
      const ArSprite('shadow', x: 0, y: 0, z: 0, scale: 4, floor: true),
      ArSprite('palayok_break', x: 0, y: pivotHeight, z: 0, scale: potScale, roll: angle, fps: 12),
      ArSprite('fx_sparkle', x: at.x, y: at.y, z: at.z, scale: 5, fps: 15, life: 0.4),
    ];
    for (var i = 0; i < coins; i++) {
      final dir = _random.nextDouble() * 2 * math.pi;
      final speed = 0.4 + _random.nextDouble() * 1.0;
      final vx = math.cos(dir) * speed, vz = math.sin(dir) * speed;
      final vy = 0.5 + _random.nextDouble() * 2.0;
      const restY = 0.04 * 2;
      final t = timeToFallTo(at.y, vy, gravity, restY)!;
      out.addAll([
        ArSprite('coin_spin',
            x: at.x,
            y: at.y,
            z: at.z,
            vx: vx,
            vy: vy,
            vz: vz,
            gravity: gravity,
            scale: 2,
            fps: 14,
            loop: true,
            delay: 0.15,
            life: t),
        ArSprite('coin_spin', x: at.x + vx * t, y: restY, z: at.z + vz * t, scale: 2, frame: i % 8, delay: 0.15 + t),
      ]);
    }
    return out;
  }
}
