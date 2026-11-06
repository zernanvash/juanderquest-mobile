import 'dart:math' as math;

import 'ar_minigame.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// "Pukpok Palayok" (Plan 77 `pabitin_palayok`): a clay pot hangs on a rope over
/// the anchor and swings. Walk close, keep the circle where the pot passes and
/// tap HAMPAS when it is inside. Three hits crack it open and the coins fall.
class PalayokGame extends ArMiniGame {
  PalayokGame({math.Random? random}) : _random = random ?? math.Random();

  static const gravity = 9.8;
  static const potScale = 2.0;

  /// Rope top (the swing point), above the anchor.
  static const pivotHeight = 2.6;

  /// Rope top to the middle of the pot (measured on the sprite: 0.436 m at scale 1).
  static const ropeLength = 0.436 * potScale;
  static const potRadius = 0.125 * potScale;
  static const swingRad = 0.35;
  static const periodByHits = [2.4, 2.0, 1.6];
  static const reachM = 2.5;
  static const aimDeg = 4.0;
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
  @override
  bool won = false;

  final Swing _swing = Swing(periodByHits[0], 0);
  double _nextStrike = 0;
  double _wonAt = double.infinity;

  @override
  String get title => 'PUKPOK PALAYOK';
  @override
  String get placeLabel => 'HANG PALAYOK';
  @override
  String get placeHint => 'Point at open ground 2 steps away, then hang the palayok.';
  @override
  String get wonText => 'The palayok broke open. Coins!';
  @override
  ArButtonMode get buttonMode => ArButtonMode.tap;

  bool get broken => hits >= targetHits;

  /// Swing angle (radians, anticlockwise as seen) at [now].
  double angle(double now) => broken ? 0 : swingRad * _swing.sinAt(now);

  /// Middle of the pot at [now], seen from [pose] (the pot swings across the view).
  V3 pot(double now, ArPose pose) {
    final a = angle(now);
    final r = rightOf(pose.forward);
    return const V3(0, pivotHeight, 0) + r * (ropeLength * math.sin(a)) + V3(0, -ropeLength * math.cos(a), 0);
  }

  bool close(ArPose pose) => pose.camera.horizontalLength <= reachM;

  bool onTarget(double now, ArPose pose) =>
      close(pose) && inReticle(pose, pot(now, pose), radius: potRadius, coneDeg: aimDeg);

  @override
  bool canPress(double now) => placed && !broken && now >= _nextStrike;

  @override
  String buttonLabel(double now) => 'HAMPAS!';

  @override
  ArMeter? meter(double now, ArPose? pose) => null;

  @override
  String? meterCaption(double now, ArPose? pose) =>
      pose != null && !close(pose) ? 'Walk closer: within ${reachM.toStringAsFixed(1)} m.' : 'Tap HAMPAS when the palayok is in the circle.';

  @override
  bool? reticle(double now, ArPose? pose) => placed && !broken ? (pose != null && onTarget(now, pose)) : null;

  @override
  String? status(ArPose? pose) {
    final d = ArMiniGame.distance(pose);
    return d == null ? null : 'PALAYOK ${d.toStringAsFixed(1)} m';
  }

  @override
  String? hint(double now, ArPose? pose) {
    if (!placed || broken || pose == null) return null;
    return turnHint(pose, const V3(0, pivotHeight - ropeLength, 0));
  }

  @override
  void place(double now, ArPose? pose) {
    placed = true;
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
  void restart(double now, ArPose? pose) {
    hits = 0;
    won = false;
    _wonAt = double.infinity;
    place(now, pose);
  }

  @override
  void press(double now, ArPose? pose) {
    if (!canPress(now) || pose == null) return;
    _nextStrike = now + strikeCooldownS;
    if (!close(pose)) {
      say('LAPIT PA!');
      return;
    }
    if (!onTarget(now, pose)) {
      say('MINTIS!');
      buzz(ArHaptic.light);
      return;
    }
    final at = pot(now, pose);
    hits++;
    buzz(ArHaptic.heavy);
    if (broken) {
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
  void update(double now, ArPose? pose) {
    if (!won && now >= _wonAt) {
      won = true;
      buzz(ArHaptic.heavy);
    }
  }

  /// The pot swinging from [now].
  List<ArSprite> scene(double now) => [
        const ArSprite('shadow', x: 0, y: 0, z: 0, scale: 4, floor: true),
        ArSprite(_sheets[hits.clamp(0, 2)],
            x: 0, y: pivotHeight, z: 0, scale: potScale,
            oscPeriod: _swing.period, oscPhase: _swing.phaseAt(now), rollAmp: swingRad),
      ];

  /// The pot bursting where it was hit, and the coins falling from [at].
  List<ArSprite> breakScene({required double angle, required V3 at}) {
    final out = <ArSprite>[
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
            x: at.x, y: at.y, z: at.z, vx: vx, vy: vy, vz: vz, gravity: gravity,
            scale: 2, fps: 14, loop: true, delay: 0.15, life: t),
        ArSprite('coin_spin', x: at.x + vx * t, y: restY, z: at.z + vz * t, scale: 2, frame: i % 8, delay: 0.15 + t),
      ]);
    }
    return out;
  }
}
