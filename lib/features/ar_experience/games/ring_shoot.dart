import 'dart:math' as math;

import 'ar_minigame.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// One ball shot, decided at release.
class RingShot {
  const RingShot({
    required this.start,
    required this.direction,
    required this.velocity,
    required this.crossS,
    required this.endS,
    required this.offset,
  });

  final V3 start;

  /// Unit horizontal direction of the shot.
  final V3 direction;
  final V3 velocity;

  /// Seconds until the ball comes down through rim height.
  final double crossS;

  /// Seconds until the ball reaches the ground on its arc.
  final double endS;

  /// Horizontal distance from the rim centre where the ball comes down.
  final double offset;

  bool get make => offset <= RingShootGame.rimRadius + RingShootGame.makeMargin;
  bool get swish => offset <= RingShootGame.swishRadius;

  V3 at(double t) => V3(
        start.x + velocity.x * t,
        start.y + velocity.y * t - 0.5 * RingShootGame.gravity * t * t,
        start.z + velocity.z * t,
      );
}

/// "Barangay Ring Shoot" (Plan 77 `shooting_hoop`): hold to charge, release in
/// the green to arc the ball through the ring. Same one-thumb control as
/// Tumbang Preso: power sets the distance, aiming near the hoop snaps onto it.
class RingShootGame extends ArMiniGame {
  RingShootGame({this.targetHits = 3});

  static const gravity = 9.8;
  static const rimHeight = 2.0;
  static const rimRadius = 0.21;

  /// Easy mode: how far off the rim centre still drops in.
  static const makeMargin = 0.15;
  static const swishRadius = 0.10;
  static const ballScale = 1.2;
  static const ballRadius = 0.12 * ballScale;
  static const minRange = 1.0;
  static const maxRange = 8.0;
  static const chargeCycleS = 1.6;

  @override
  final int targetHits;
  @override
  int hits = 0;
  @override
  bool placed = false;
  @override
  bool won = false;

  bool _charging = false;
  double _chargeStart = 0;
  RingShot? shot;
  double _releasedAt = 0;
  bool _resolved = false;
  double _settleUntil = 0;

  @override
  String get title => 'RING SHOOT';
  @override
  String get placeLabel => 'PLACE RING';
  @override
  String get placeHint => 'Point at open ground 3–5 steps away, then place the ring.';
  @override
  String get wonText => 'You made $targetHits baskets.';
  @override
  ArButtonMode get buttonMode => ArButtonMode.hold;

  bool get flying => shot != null;

  @override
  bool canPress(double now) => placed && !won && shot == null;

  @override
  String buttonLabel(double now) => _charging ? 'RELEASE TO SHOOT!' : 'HOLD TO SHOOT';

  double power(double now) {
    if (!_charging) return 0;
    final c = ((now - _chargeStart) / (chargeCycleS / 2)) % 2;
    return c <= 1 ? c : 2 - c;
  }

  @override
  ArMeter? meter(double now, ArPose? pose) {
    final z = pose == null ? null : sweetSpot(pose.camera);
    return (value: power(now), from: z?.from, to: z?.to);
  }

  @override
  String? meterCaption(double now, ArPose? pose) =>
      pose != null && sweetSpot(pose.camera) == null ? 'Too close or too far: move 2–7 m from the ring.' : 'Release in the GREEN to shoot.';

  @override
  bool? reticle(double now, ArPose? pose) => null;

  @override
  String? status(ArPose? pose) {
    final d = ArMiniGame.distance(pose);
    return d == null ? null : 'RING ${d.toStringAsFixed(1)} m';
  }

  @override
  String? hint(double now, ArPose? pose) {
    if (!placed || won || pose == null) return null;
    final off = TumbangPresoGame.offAimDegrees(pose.camera, pose.forward);
    if (off.abs() <= TumbangPresoGame.assistDeg) return null;
    return off < 0 ? '◀ TURN LEFT' : 'TURN RIGHT ▶';
  }

  @override
  void place(double now, ArPose? pose) {
    placed = true;
    shot = null;
    _charging = false;
    show(scene());
  }

  @override
  void unplace() {
    placed = false;
    shot = null;
    _charging = false;
    show(const []);
  }

  @override
  void restart(double now, ArPose? pose) {
    hits = 0;
    won = false;
    shot = null;
    _charging = false;
    show(scene());
  }

  @override
  void press(double now, ArPose? pose) {
    if (!canPress(now)) return;
    _charging = true;
    _chargeStart = now;
  }

  @override
  void release(double now, ArPose? pose) {
    if (!_charging) return;
    final p = power(now);
    _charging = false;
    if (pose == null || shot != null) return;
    final s = shootFrom(camera: pose.camera, forward: pose.forward, power: p);
    shot = s;
    _releasedAt = now;
    _resolved = false;
    buzz(ArHaptic.light);
    show(scene(shot: s));
  }

  @override
  void update(double now, ArPose? pose) {
    final s = shot;
    if (s == null) return;
    if (!_resolved && now >= _releasedAt + (s.make ? s.crossS : s.endS)) {
      _resolved = true;
      if (s.make) {
        hits++;
        say(s.swish ? 'SWISH!' : 'SHOOT!');
        buzz(ArHaptic.heavy);
        _settleUntil = _releasedAt + s.crossS + _dropS + 1.0;
      } else {
        say('MINTIS!');
        _settleUntil = _releasedAt + s.endS + 0.8;
      }
    }
    if (_resolved && now >= _settleUntil) {
      shot = null;
      if (hits >= targetHits) {
        won = true;
        buzz(ArHaptic.heavy);
      } else {
        show(scene());
      }
    }
  }

  /// Time a made ball takes to drop from the rim to the ground.
  static double get _dropS => timeToFallTo(rimHeight, -1.5, gravity, ballRadius)!;

  static RingShot shootFrom({required V3 camera, required V3 forward, required double power}) {
    final dir = TumbangPresoGame.aimDirection(camera, forward);
    final start = TumbangPresoGame.handOf(camera, dir);
    final range = minRange + power.clamp(0.0, 1.0) * (maxRange - minRange);
    final apex = math.max(rimHeight + 0.9, start.y + 0.5);
    final vy = math.sqrt(2 * gravity * (apex - start.y));
    final cross = timeToFallTo(start.y, vy, gravity, rimHeight)!;
    final v = V3(dir.x * range / cross, vy, dir.z * range / cross);
    final down = V3(start.x + dir.x * range, rimHeight, start.z + dir.z * range);
    return RingShot(
      start: start,
      direction: dir,
      velocity: v,
      crossS: cross,
      endS: timeToFallTo(start.y, vy, gravity, ballRadius)!,
      offset: down.horizontalLength,
    );
  }

  /// The powers (0..1) that score from here when aimed at the ring, or null.
  static ({double from, double to})? sweetSpot(V3 camera) {
    final toRing = V3(-camera.x, 0, -camera.z);
    double? lo, hi;
    for (var i = 0; i <= 100; i++) {
      final p = i / 100;
      if (shootFrom(camera: camera, forward: toRing, power: p).make) {
        lo ??= p;
        hi = p;
      }
    }
    return lo == null ? null : (from: lo, to: hi!);
  }

  static const _swishS = 4 / 12;

  /// The hoop, plus one shot when given.
  static List<ArSprite> scene({RingShot? shot}) {
    final s = shot;
    if (s == null) return const [ArSprite('shadow', x: 0, y: 0, z: 0, scale: 3, floor: true), ArSprite('hoop', x: 0, y: 0, z: 0)];
    final v = s.velocity;
    final out = <ArSprite>[
      const ArSprite('shadow', x: 0, y: 0, z: 0, scale: 3, floor: true),
      ArSprite('hoop', x: 0, y: 0, z: 0, life: s.make ? s.crossS : 0),
    ];
    final flightS = s.make ? s.crossS : s.endS;
    out.addAll([
      ArSprite('ball_spin',
          x: s.start.x, y: s.start.y, z: s.start.z, vx: v.x, vy: v.y, vz: v.z, gravity: gravity,
          scale: ballScale, fps: 12, loop: true, life: flightS),
      ArSprite('shadow', x: s.start.x, y: 0, z: s.start.z, vx: v.x, vz: v.z, scale: 1.2, floor: true, life: flightS),
    ]);
    if (s.make) {
      // Drop through the net a little in front of the hoop picture, so the
      // flat hoop never hides the ball.
      final fx = -s.direction.x * 0.08, fz = -s.direction.z * 0.08;
      final drop = _dropS;
      final at = s.crossS;
      out.addAll([
        ArSprite('hoop_swish', x: 0, y: 0, z: 0, fps: 12, delay: at, life: _swishS),
        ArSprite('hoop', x: 0, y: 0, z: 0, delay: at + _swishS),
        ArSprite('ball_spin',
            x: fx, y: rimHeight, z: fz, vy: -1.5, gravity: gravity, scale: ballScale, fps: 12, loop: true, delay: at, life: drop),
        ArSprite('fx_sparkle', x: fx, y: rimHeight, z: fz, scale: 4, fps: 15, delay: at, life: 0.4),
        ArSprite('ball_spin', x: fx, y: ballRadius, z: fz, scale: ballScale, delay: at + drop),
        ArSprite('fx_dust', x: fx, y: 0, z: fz, scale: 2, fps: 12, delay: at + drop, life: 0.5),
      ]);
    } else {
      final land = s.at(s.endS);
      out.addAll([
        ArSprite('ball_spin', x: land.x, y: ballRadius, z: land.z, scale: ballScale, delay: s.endS),
        ArSprite('fx_dust', x: land.x, y: 0, z: land.z, scale: 2, fps: 12, delay: s.endS, life: 0.5),
      ]);
    }
    return out;
  }
}
