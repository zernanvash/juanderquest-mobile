import 'dart:math' as math;

import 'ar_minigame.dart';
import 'ar_sprites.dart';

/// Plan 77 throwing game, "Tumbang Preso": knock the tin can (lata) with a
/// slipper (tsinelas). Pure logic, no Flutter: the screen feeds it the camera
/// pose and the time, and sends the scenes to the native renderer.
///
/// Rules (owner 2026-11-06: "lets try do the throwing game first"; 2026-11-07:
/// "more challenging ... without it being too hard"):
/// - stand on the chalk line, 5 m from the can; hold to charge, release to throw;
/// - power sets how far the slipper lands; only a near-perfect aim snaps on;
/// - 10 slippers; every knock-down in a row speeds the meter up and narrows the
///   green; from the 3rd knock-down the taya walks in front of the can and blocks;
/// - 4 knock-downs pass; the score counts streaks.
///
/// Coordinates: metres relative to the can's anchor (world axes, y up, the can
/// stands at the origin).
class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;
  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double get horizontalLength => math.sqrt(x * x + z * z);
  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// One throw, decided at release: a ballistic arc from [start] landing at [land].
class ThrowShot {
  const ThrowShot({
    required this.start,
    required this.land,
    required this.velocity,
    required this.flightS,
    required this.hitS,
    required this.direction,
  });

  static const gravity = 9.8;

  final V3 start;
  final V3 land;
  final V3 velocity;
  final double flightS;

  /// Seconds after release when the slipper reaches the can; null = miss.
  final double? hitS;

  /// Unit horizontal direction of the throw.
  final V3 direction;

  bool get hit => hitS != null;

  V3 at(double t) => V3(
        start.x + velocity.x * t,
        start.y + velocity.y * t - 0.5 * gravity * t * t,
        start.z + velocity.z * t,
      );
}

/// Throw maths for Tumbang Preso (the can stands at the origin).
class TumbangPresoGame {
  // Game-size objects (owner: bigger than life so they're easy to see).
  static const canScale = 2.5;
  static const slipperScale = 2.0;
  static const canHeight = 0.14 * canScale;
  static const canRadius = 0.05 * canScale;

  /// How forgiving a hit is around the can, in metres (shrinks with a streak).
  static const hitMargin = 0.18;

  /// Aim help: throws within this many degrees of the can snap onto it.
  static const assistDeg = 3.0;
  static const minRange = 0.5;
  static const maxRange = 8.0;

  /// Full charge up and back down takes this long (shortens with a streak).
  static const chargeCycleS = 1.6;

  /// The hand: 40 cm in front of the camera, 25 cm lower.
  static V3 handOf(V3 camera, V3 aim) => camera + aim * 0.4 + const V3(0, -0.25, 0);

  /// Unit horizontal aim, snapped onto the can when within [assist] degrees.
  static V3 aimDirection(V3 camera, V3 forward, {double assist = assistDeg}) {
    final f = V3(forward.x, 0, forward.z);
    final fl = f.horizontalLength;
    final aim = fl < 1e-6 ? const V3(0, 0, -1) : f * (1 / fl);
    final toCan = V3(-camera.x, 0, -camera.z);
    final cl = toCan.horizontalLength;
    if (cl < 1e-6) return aim;
    final c = toCan * (1 / cl);
    return offAimDegrees(camera, forward).abs() <= assist ? c : aim;
  }

  /// Signed horizontal angle from the aim to the can (degrees, + = can is to the right).
  static double offAimDegrees(V3 camera, V3 forward) {
    final a = math.atan2(forward.x, -forward.z);
    final c = math.atan2(-camera.x, camera.z);
    var d = (c - a) * 180 / math.pi;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }

  static ThrowShot throwFrom({
    required V3 camera,
    required V3 forward,
    required double power,
    double margin = hitMargin,
    double assist = assistDeg,
  }) {
    final dir = aimDirection(camera, forward, assist: assist);
    final start = handOf(camera, dir);
    final range = minRange + power.clamp(0.0, 1.0) * (maxRange - minRange);
    final land = V3(start.x + dir.x * range, 0, start.z + dir.z * range);
    final flight = 0.45 + 0.09 * range;
    final v = V3(
      (land.x - start.x) / flight,
      (land.y - start.y) / flight + 0.5 * ThrowShot.gravity * flight,
      (land.z - start.z) / flight,
    );
    final probe = ThrowShot(start: start, land: land, velocity: v, flightS: flight, hitS: null, direction: dir);
    double? hitS;
    for (var t = 0.0; t <= flight; t += 1 / 120) {
      final p = probe.at(t);
      if (p.horizontalLength <= canRadius + margin && p.y <= canHeight + 0.12 && p.y >= -0.05) {
        hitS = t;
        break;
      }
    }
    return ThrowShot(start: start, land: land, velocity: v, flightS: flight, hitS: hitS, direction: dir);
  }

  /// The powers (0..1) that hit from here when aimed at the can, as (from, to),
  /// or null when no power hits (too close or too far).
  static ({double from, double to})? sweetSpot(V3 camera, {double margin = hitMargin}) {
    final toCan = V3(-camera.x, 0, -camera.z);
    double? lo, hi;
    for (var i = 0; i <= 100; i++) {
      final p = i / 100;
      if (throwFrom(camera: camera, forward: toCan, power: p, margin: margin).hit) {
        lo ??= p;
        hi = p;
      }
    }
    return lo == null ? null : (from: lo, to: hi!);
  }
}

/// One leg of the taya's route: from [a] at [t0] to [b] at [t1] (a == b: standing
/// guard; [smack]: swatting a tsinelas back).
typedef TayaLeg = ({double t0, double t1, V3 a, V3 b, bool smack});

/// The taya's random guarding route (owner 2026-11-07: "make the taya move not
/// just left and right create a random pattern"): quick dashes between random
/// spots in front of the can, sideways and nearer/further, with short stops.
/// Built ahead of time so the native renderer can draw it from one scene.
class TayaPath {
  TayaPath(this.random);
  final math.Random random;
  final List<TayaLeg> legs = [];

  /// Picks the next spot: [lateral] metres either side, [nearFrom]..[nearTo]
  /// metres in front of the can.
  late V3 Function(double lateral, double front) toWorld;
  double lateral = 1.1;
  double nearFrom = 0.7, nearTo = 1.9;

  V3 _spot() => toWorld((random.nextDouble() * 2 - 1) * lateral, nearFrom + random.nextDouble() * (nearTo - nearFrom));

  void start(double now) {
    legs.clear();
    final p = _spot();
    legs.add((t0: now, t1: now + 0.5, a: p, b: p, smack: false));
  }

  /// Makes sure the route reaches [until].
  void extend(double until) {
    while (legs.last.t1 < until) {
      final from = legs.last.b;
      final to = _spot();
      final speed = 0.9 + random.nextDouble() * 0.9;
      final t0 = legs.last.t1;
      final t1 = t0 + math.max(0.25, (to - from).horizontalLength / speed);
      legs.add((t0: t0, t1: t1, a: from, b: to, smack: false));
      if (random.nextBool()) legs.add((t0: t1, t1: t1 + 0.15 + random.nextDouble() * 0.65, a: to, b: to, smack: false));
    }
  }

  /// The taya stops at [time] for [seconds] to swat a tsinelas back; the route
  /// carries on from there afterwards.
  void smackAt(double time, double seconds) {
    final p = at(time);
    legs.removeWhere((l) => l.t0 >= time);
    if (legs.isNotEmpty && legs.last.t1 > time) {
      final l = legs.removeLast();
      legs.add((t0: l.t0, t1: time, a: l.a, b: p, smack: l.smack));
    }
    legs.add((t0: time, t1: time + seconds, a: p, b: p, smack: true));
  }

  V3 at(double now) {
    if (legs.isEmpty) return const V3(0, 0, 0);
    extend(now);
    for (final l in legs) {
      if (now <= l.t1) {
        if (now <= l.t0) return l.a;
        final f = (now - l.t0) / (l.t1 - l.t0);
        return l.a + (l.b - l.a) * f;
      }
    }
    return legs.last.b;
  }
}

/// One slipper, decided at release, with the taya maybe in the way.
class TumbangThrow {
  const TumbangThrow(this.shot, this.blockS);
  final ThrowShot shot;

  /// Seconds after release when the taya blocks it; null = not blocked.
  final double? blockS;

  bool get knocks => shot.hit && blockS == null;

  /// When the throw is decided (knock, block, or landing).
  double get endS => blockS ?? shot.hitS ?? shot.flightS;
}

class TumbangGame extends ArMiniGame {
  TumbangGame({super.rangeScale, math.Random? random}) : path = TayaPath(random ?? math.Random());

  static const slippers = 10;
  static const passHits = 4;

  /// The taya guards with arms spread; forgiving: this wide either side, this tall.
  static const tayaHalfWidth = 0.55;
  static const tayaHeight = 1.45;

  /// The swat (taya_smack, 4 frames at 12 fps) starts this long before the
  /// tsinelas arrives so the swing meets it, and lasts [smackS].
  static const smackLeadS = 1 / 12;
  static const smackS = 0.5;

  /// A swatted tsinelas flies back towards the player this fast.
  static const smackBackSpeed = 4.5;

  /// How far ahead the native scene draws the route; resent before it runs out.
  static const _horizonS = 30.0;

  /// Knock-downs before the taya comes in.
  static const tayaAfter = 2;
  static const _canShadowScale = 1.8;
  static const _canKickUp = 2.4;
  static const _canKickForward = 2.0;

  @override
  String get title => 'TUMBANG PRESO';
  @override
  double get fullDistance => 5.0;
  @override
  String get placeHint =>
      'Stand where you will throw, face open ground, then tap STAND HERE. The lata appears ${standDistance.toStringAsFixed(1)} m ahead.';
  @override
  String get endText => '$hits knock-downs, $score points.';
  @override
  int get targetHits => passHits;
  @override
  int hits = 0;
  int score = 0;
  int streak = 0;
  int left = slippers;
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
  TumbangThrow? current;
  double _releasedAt = 0;
  bool _resolved = false;
  double _settleUntil = 0;
  final TayaPath path;
  double _sceneUntil = 0;

  int get _level => math.min(streak, 4);
  double get chargeCycle => TumbangPresoGame.chargeCycleS * math.pow(0.88, _level);
  double get margin => TumbangPresoGame.hitMargin - 0.03 * _level;
  bool get tayaOn => hits >= tayaAfter;

  /// Middle of the taya at [now] (on the ground).
  V3 taya(double now) {
    if (path.legs.isEmpty) _startTaya(now);
    return path.at(now);
  }

  void _startTaya(double now) {
    path
      ..toWorld = ((lateral, front) => downrange * (-front * rangeScale) + across * lateral)
      ..start(now);
  }

  double power(double now) {
    if (!_charging) return 0;
    final c = ((now - _chargeStart) / (chargeCycle / 2)) % 2;
    return c <= 1 ? c : 2 - c;
  }

  @override
  bool canPress(double now) => placed && !over && current == null;

  @override
  String buttonLabel(double now) => _charging ? 'RELEASE TO THROW!' : 'HOLD TO THROW';

  ({double from, double to})? _sweet;
  double _sweetAt = -1;
  double _sweetMargin = -1;

  /// The green zone costs ~100 simulated throws, so it is refreshed 4 times a
  /// second (or when a streak changes it), not every frame.
  @override
  ArMeter? meter(double now, ArPose? pose) {
    if (pose != null && (now - _sweetAt >= 0.25 || now < _sweetAt || _sweetMargin != margin)) {
      _sweet = TumbangPresoGame.sweetSpot(pose.camera, margin: margin);
      _sweetAt = now;
      _sweetMargin = margin;
    }
    final z = pose == null ? null : _sweet;
    return (value: power(now), from: z?.from, to: z?.to);
  }

  @override
  String? meterCaption(double now, ArPose? pose) =>
      tayaOn ? 'Release in the GREEN when the taya is out of the way.' : 'Release in the GREEN to hit the lata.';

  @override
  bool? reticle(double now, ArPose? pose) => null;

  @override
  String? status(ArPose? pose) => 'TSINELAS $left · $score PTS';

  @override
  String? hint(double now, ArPose? pose) {
    if (!placed || over || pose == null) return null;
    final off = TumbangPresoGame.offAimDegrees(pose.camera, pose.forward);
    if (off.abs() <= 6) return null;
    return off < 0 ? '◀ AIM LEFT' : 'AIM RIGHT ▶';
  }

  @override
  void place(double now, ArPose? pose) {
    placed = true;
    current = null;
    _charging = false;
    path.legs.clear();
    show(scene(now));
  }

  @override
  void unplace() {
    placed = false;
    current = null;
    _charging = false;
    show(const []);
  }

  @override
  void restart(double now, ArPose? pose) {
    hits = 0;
    score = 0;
    streak = 0;
    left = slippers;
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
    if (pose == null || current != null) return;
    final t = throwAt(now, pose, p);
    final blockS = t.blockS;
    if (blockS != null) path.smackAt(now + math.max(0, blockS - smackLeadS), smackS);
    current = t;
    left--;
    _releasedAt = now;
    _resolved = false;
    buzz(ArHaptic.light);
    show(scene(now, t));
  }

  /// The throw from [pose] at [power], checked against the walking taya.
  TumbangThrow throwAt(double now, ArPose pose, double power) {
    final s = TumbangPresoGame.throwFrom(camera: pose.camera, forward: pose.forward, power: power, margin: margin);
    if (!tayaOn) return TumbangThrow(s, null);
    final end = s.hitS ?? s.flightS;
    final d = downrange;
    for (var t = 0.0; t <= end; t += 1 / 120) {
      final p = s.at(t);
      final k = taya(now + t);
      if ((p - k).dot(d) >= 0) {
        // The slipper reaches the taya's line now: blocked if the taya is in the way.
        if ((p - k).dot(across).abs() <= tayaHalfWidth && p.y <= tayaHeight) return TumbangThrow(s, t);
        break;
      }
    }
    return TumbangThrow(s, null);
  }

  @override
  void update(double now, ArPose? pose) {
    final t = current;
    if (t == null) {
      // Keep the taya's route drawn ahead while waiting for a throw.
      if (placed && !over && tayaOn && now > _sceneUntil - 10) show(scene(now));
      return;
    }
    if (!_resolved && now >= _releasedAt + t.endS) {
      _resolved = true;
      if (t.knocks) {
        hits++;
        streak++;
        score += 10 + 5 * (streak - 1);
        say(streak > 1 ? 'BAGSAK! x$streak' : 'BAGSAK!');
        buzz(ArHaptic.heavy);
        _settleUntil = now + canFlightS + 1.2;
      } else {
        streak = 0;
        final blocked = t.blockS != null;
        say(blocked ? 'PALO! HARANG!' : 'MINTIS!');
        if (blocked) buzz(ArHaptic.heavy);
        // A swatted tsinelas is still flying back towards the player.
        _settleUntil = now + (blocked ? 1.4 : 0.9);
      }
    }
    if (_resolved && now >= _settleUntil) {
      current = null;
      if (left <= 0) {
        over = true;
        buzz(ArHaptic.heavy);
      }
      show(scene(now));
    }
  }

  /// Time a knocked can flies before it lies on the ground.
  static double get canFlightS {
    const y0 = TumbangPresoGame.canHeight / 2, y1 = TumbangPresoGame.canRadius;
    const g = ThrowShot.gravity;
    return (_canKickUp + math.sqrt(_canKickUp * _canKickUp + 2 * g * (y0 - y1))) / g;
  }

  /// The can in its circle, the line, the taya (when on), plus one throw.
  List<ArSprite> scene(double now, [TumbangThrow? t]) {
    final shot = t?.shot;
    final canLife = t != null && t.knocks ? shot!.hitS! : 0.0;
    const g = ThrowShot.gravity;
    final out = <ArSprite>[
      lineSprite,
      const ArSprite('chalk_circle', x: 0, y: 0, z: 0, scale: 2.0, floor: true),
      ArSprite('shadow', x: 0, y: 0, z: 0, scale: _canShadowScale, floor: true, life: canLife),
      ArSprite('lata_stand', x: 0, y: 0, z: 0, scale: TumbangPresoGame.canScale, life: canLife),
    ];
    if (tayaOn && !over) {
      taya(now);
      path.extend(now + _horizonS);
      _sceneUntil = now + _horizonS;
      for (final l in path.legs) {
        if (l.t1 <= now || l.t0 >= now + _horizonS) continue;
        final from = math.max(l.t0, now);
        final p = path.at(from);
        final dur = l.t1 - from;
        final v = (l.b - l.a) * (1 / (l.t1 - l.t0));
        final moving = v.horizontalLength > 1e-6;
        final delay = from - now;
        out.addAll([
          ArSprite('shadow', x: p.x, y: 0, z: p.z, vx: v.x, vz: v.z, scale: 4, floor: true, delay: delay, life: dur),
          if (l.smack)
            ArSprite('taya_smack', x: p.x, y: 0, z: p.z, fps: 12, delay: delay, life: dur)
          else
            ArSprite('taya_guard', x: p.x, y: 0, z: p.z, vx: v.x, vz: v.z, scale: 1.0,
                fps: moving ? 8 : 0, loop: moving, delay: delay, life: dur),
        ]);
      }
    }
    if (t == null || shot == null) return out;
    final v = shot.velocity;
    final flyS = t.endS;
    out.addAll([
      ArSprite('tsinelas_spin',
          x: shot.start.x, y: shot.start.y, z: shot.start.z, vx: v.x, vy: v.y, vz: v.z, gravity: g,
          scale: TumbangPresoGame.slipperScale, fps: 16, loop: true, life: flyS),
      ArSprite('shadow', x: shot.start.x, y: 0, z: shot.start.z, vx: v.x, vz: v.z, scale: 1.4, floor: true, life: flyS),
    ]);
    final blockS = t.blockS;
    if (blockS != null) {
      // The taya swats it: it flies back towards the player and lands near the line.
      final p = shot.at(blockS);
      final d = shot.direction;
      const back = smackBackSpeed;
      final fall = timeToFallTo(p.y, 2.2, g, 0)!;
      final land = V3(p.x - d.x * back * fall, 0, p.z - d.z * back * fall);
      out.addAll([
        ArSprite('fx_sparkle', x: p.x, y: p.y, z: p.z, scale: 4, fps: 15, delay: blockS, life: 0.4),
        ArSprite('tsinelas_spin', x: p.x, y: p.y, z: p.z, vx: -d.x * back, vy: 2.2, vz: -d.z * back, gravity: g,
            scale: TumbangPresoGame.slipperScale, fps: 20, loop: true, delay: blockS, life: fall),
        ArSprite('shadow', x: p.x, y: 0, z: p.z, vx: -d.x * back, vz: -d.z * back, scale: 1.4, floor: true, delay: blockS, life: fall),
        ArSprite('tsinelas_ground', x: land.x, y: 0, z: land.z, scale: TumbangPresoGame.slipperScale, delay: blockS + fall),
      ]);
      return out;
    }
    out.addAll([
      ArSprite('tsinelas_ground',
          x: shot.land.x, y: 0, z: shot.land.z, scale: TumbangPresoGame.slipperScale, delay: shot.flightS),
      ArSprite('fx_dust', x: shot.land.x, y: 0, z: shot.land.z, scale: 2, fps: 12, delay: shot.flightS, life: 0.5),
    ]);
    if (t.knocks) {
      final hitS = shot.hitS!;
      final p = shot.at(hitS);
      final d = shot.direction;
      const y0 = TumbangPresoGame.canHeight / 2;
      final tl = canFlightS;
      final landX = d.x * _canKickForward * tl, landZ = d.z * _canKickForward * tl;
      out.addAll([
        ArSprite('fx_sparkle', x: p.x, y: p.y, z: p.z, scale: 3, fps: 15, delay: hitS, life: 0.4),
        ArSprite('lata_tumble',
            x: 0, y: y0, z: 0, vx: d.x * _canKickForward, vy: _canKickUp, vz: d.z * _canKickForward, gravity: g,
            scale: TumbangPresoGame.canScale, fps: 14, loop: true, delay: hitS, life: tl),
        ArSprite('lata_down', x: landX, y: 0, z: landZ, scale: TumbangPresoGame.canScale, delay: hitS + tl),
        ArSprite('fx_dust', x: landX, y: 0, z: landZ, scale: 2.5, fps: 12, delay: hitS + tl, life: 0.5),
      ]);
    }
    return out;
  }
}
