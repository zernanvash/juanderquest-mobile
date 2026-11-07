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
    required this.rim,
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

  /// Rim centre (on the ground) when the ball comes down.
  final V3 rim;

  bool get make => offset <= RingShootGame.rimRadius + RingShootGame.makeMargin;
  bool get swish => offset <= RingShootGame.swishRadius;

  V3 at(double t) => V3(
        start.x + velocity.x * t,
        start.y + velocity.y * t - 0.5 * RingShootGame.gravity * t * t,
        start.z + velocity.z * t,
      );
}

/// "Barangay Ring Shoot" (Plan 77 `shooting_hoop`): from the line, hold to charge
/// and release in the green to arc the ball through the ring. 10 balls; after 3
/// baskets the hoop starts sliding side to side, faster after 6 (like Messenger's
/// basketball). A basket is 2 points, a swish 3; 4 baskets pass.
class RingShootGame extends ArMiniGame {
  RingShootGame({super.rangeScale});

  static const gravity = 9.8;
  static const rimHeight = 2.0;
  static const rimRadius = 0.21;

  /// How far off the rim centre still drops in.
  static const makeMargin = 0.12;
  static const swishRadius = 0.10;
  static const ballScale = 1.2;
  static const ballRadius = 0.12 * ballScale;
  static const minRange = 1.0;
  static const maxRange = 8.0;
  static const chargeCycleS = 1.6;
  static const balls = 10;
  static const passHits = 4;
  static const slide = 0.8;

  @override
  String get title => 'RING SHOOT';
  @override
  double get fullDistance => 4.2;
  @override
  String get placeHint =>
      'Stand where you will shoot, face open ground, then tap STAND HERE. The ring appears ${standDistance.toStringAsFixed(1)} m ahead.';
  @override
  String get endText => '$hits baskets, $score points.';
  @override
  int get targetHits => passHits;
  @override
  int hits = 0;
  int score = 0;
  int left = balls;
  @override
  bool placed = false;
  @override
  bool over = false;
  @override
  bool get passed => hits >= passHits;
  @override
  ArButtonMode get buttonMode => ArButtonMode.hold;

  bool _charging = false;
  double _chargeStart = 0;
  RingShot? shot;
  double _releasedAt = 0;
  bool _resolved = false;
  double _settleUntil = 0;
  final Swing _swing = Swing(4.0, 0);

  /// Hoop slide period for the current score: still, then 4 s, then 2.5 s.
  double? get slidePeriod => hits >= 6 ? 2.5 : (hits >= 3 ? 4.0 : null);

  /// Hoop (rim centre on the ground) at [now].
  V3 hoop(double now) {
    final p = slidePeriod;
    return p == null ? const V3(0, 0, 0) : across * (slide * _swing.sinAt(now));
  }

  double power(double now) {
    if (!_charging) return 0;
    final c = ((now - _chargeStart) / (chargeCycleS / 2)) % 2;
    return c <= 1 ? c : 2 - c;
  }

  @override
  bool canPress(double now) => placed && !over && shot == null;

  @override
  String buttonLabel(double now) => _charging ? 'RELEASE TO SHOOT!' : 'HOLD TO SHOOT';

  @override
  ArMeter? meter(double now, ArPose? pose) {
    final z = pose == null ? null : sweetSpot(pose.camera);
    return (value: power(now), from: z?.from, to: z?.to);
  }

  @override
  String? meterCaption(double now, ArPose? pose) =>
      slidePeriod == null ? 'Release in the GREEN to shoot.' : 'The ring moves: shoot where it will be.';

  @override
  bool? reticle(double now, ArPose? pose) => null;

  @override
  String? status(ArPose? pose) => 'BALLS $left · $score PTS';

  @override
  String? hint(double now, ArPose? pose) => placed && !over ? turnHint(pose, hoop(now) + const V3(0, rimHeight, 0)) : null;

  @override
  void place(double now, ArPose? pose) {
    placed = true;
    shot = null;
    _charging = false;
    _swing.epoch = now;
    show(scene(now));
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
    score = 0;
    left = balls;
    over = false;
    place(now, pose);
  }

  @override
  void press(double now, ArPose? pose) {
    if (!canPress(now)) return;
    if (pose != null && !onLine(pose)) {
      say('BALIK SA LINYA!');
      return;
    }
    _charging = true;
    _chargeStart = now;
  }

  @override
  void release(double now, ArPose? pose) {
    if (!_charging) return;
    final p = power(now);
    _charging = false;
    if (pose == null || shot != null) return;
    final s = shootFrom(camera: pose.camera, forward: pose.forward, power: p, hoopAt: (t) => hoop(now + t));
    shot = s;
    left--;
    _releasedAt = now;
    _resolved = false;
    buzz(ArHaptic.light);
    show(scene(now, shot: s));
  }

  @override
  void update(double now, ArPose? pose) {
    final s = shot;
    if (s == null) return;
    if (!_resolved && now >= _releasedAt + (s.make ? s.crossS : s.endS)) {
      _resolved = true;
      if (s.make) {
        hits++;
        score += s.swish ? 3 : 2;
        say(s.swish ? 'SWISH!' : 'SHOOT!');
        buzz(ArHaptic.heavy);
        // Start sliding from the middle; later just speed up without a jump.
        if (hits == 3) {
          _swing
            ..period = slidePeriod!
            ..epoch = now;
        }
        if (hits == 6) _swing.retime(now, slidePeriod!);
        _settleUntil = now + _dropS + 1.0;
      } else {
        say('MINTIS!');
        _settleUntil = now + 0.8;
      }
    }
    if (_resolved && now >= _settleUntil) {
      shot = null;
      if (left <= 0) {
        over = true;
        buzz(ArHaptic.heavy);
      }
      show(scene(now));
    }
  }

  /// Time a made ball takes to drop from the rim to the ground.
  static double get _dropS => timeToFallTo(rimHeight, -1.5, gravity, ballRadius)!;

  /// A shot from [camera] along [forward]; [hoopAt] is where the rim centre is
  /// [t] seconds after release (still hoop by default). Aiming within a few
  /// degrees of the hoop as it is now snaps the throw onto it.
  static RingShot shootFrom({
    required V3 camera,
    required V3 forward,
    required double power,
    V3 Function(double t)? hoopAt,
  }) {
    final at = hoopAt ?? (_) => const V3(0, 0, 0);
    final h0 = at(0);
    final rel = camera - h0;
    final dir = TumbangPresoGame.aimDirection(rel, forward, assist: 6);
    final start = TumbangPresoGame.handOf(camera, dir);
    final range = minRange + power.clamp(0.0, 1.0) * (maxRange - minRange);
    final apex = math.max(rimHeight + 0.9, start.y + 0.5);
    final vy = math.sqrt(2 * gravity * (apex - start.y));
    final cross = timeToFallTo(start.y, vy, gravity, rimHeight)!;
    final v = V3(dir.x * range / cross, vy, dir.z * range / cross);
    final down = V3(start.x + dir.x * range, 0, start.z + dir.z * range);
    final rim = at(cross);
    return RingShot(
      start: start,
      direction: dir,
      velocity: v,
      crossS: cross,
      endS: timeToFallTo(start.y, vy, gravity, ballRadius)!,
      offset: (down - rim).horizontalLength,
      rim: rim,
    );
  }

  /// The powers (0..1) that score from here at a still ring, or null.
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

  /// The line and the hoop (sliding when it should), plus one shot.
  List<ArSprite> scene(double now, {RingShot? shot}) {
    final p = slidePeriod;
    final amp = p == null ? const V3(0, 0, 0) : across * slide;
    ArSprite sliding(String sheet, {double scale = 1, bool floor = false, double fps = 0, double delay = 0, double life = 0}) =>
        ArSprite(sheet,
            x: 0, y: 0, z: 0, scale: scale, floor: floor, fps: fps, delay: delay, life: life,
            oscPeriod: p ?? 0, oscPhase: _swing.phaseAt(now + delay), ox: amp.x, oz: amp.z);
    final s = shot;
    final out = <ArSprite>[
      lineSprite,
      sliding('shadow', scale: 3, floor: true),
      sliding('hoop', life: s != null && s.make ? s.crossS : 0),
    ];
    if (s == null) return out;
    final v = s.velocity;
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
      final r = s.rim;
      final bx = -s.direction.x * 0.08, bz = -s.direction.z * 0.08;
      final drop = _dropS;
      final at = s.crossS;
      final rest = hoop(now + at + drop);
      out.addAll([
        sliding('hoop_swish', fps: 12, delay: at, life: _swishS),
        sliding('hoop', delay: at + _swishS),
        // The ball drops through the net (moving with the hoop), a little in
        // front of the flat hoop picture so it never hides the ball.
        ArSprite('ball_spin',
            x: bx, y: rimHeight, z: bz, vy: -1.5, gravity: gravity, scale: ballScale, fps: 12, loop: true,
            delay: at, life: drop, oscPeriod: p ?? 0, oscPhase: _swing.phaseAt(now + at), ox: amp.x, oz: amp.z),
        ArSprite('fx_sparkle', x: r.x + bx, y: rimHeight, z: r.z + bz, scale: 4, fps: 15, delay: at, life: 0.4),
        ArSprite('ball_spin', x: rest.x + bx, y: ballRadius, z: rest.z + bz, scale: ballScale, delay: at + drop),
        ArSprite('fx_dust', x: rest.x + bx, y: 0, z: rest.z + bz, scale: 2, fps: 12, delay: at + drop, life: 0.5),
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
