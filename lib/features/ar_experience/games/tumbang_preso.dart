import 'dart:math' as math;

import 'ar_sprites.dart';

/// Plan 77 throwing game, "Tumbang Preso": knock the tin can (lata) with a
/// slipper (tsinelas). Pure logic, no Flutter: the screen feeds it the camera
/// pose and the time, and sends [TumbangPresoScene] to the native renderer.
///
/// Rules (owner 2026-11-06: "lets try do the throwing game first"):
/// - hold to charge, release to throw; power ping-pongs, so holding never fails;
/// - power sets how far the slipper lands; aiming within [assistDeg] of the can
///   snaps the throw onto it (one-thumb + viewfinder control);
/// - a miss costs nothing: throw again; [targetHits] hits win.
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

enum TumbangPhase { placing, ready, charging, flying, settling, won }

enum TumbangEvent { none, hit, miss, reset, won }

class TumbangPresoGame {
  TumbangPresoGame({this.targetHits = 3});

  // Game-size objects (owner: bigger than life so they're easy to see).
  static const canScale = 2.5;
  static const slipperScale = 2.0;
  static const canHeight = 0.14 * canScale;
  static const canRadius = 0.05 * canScale;

  /// Easy mode: how forgiving a hit is around the can, in metres.
  static const hitMargin = 0.18;
  static const assistDeg = 10.0;
  static const minRange = 0.5;
  static const maxRange = 8.0;

  /// Full charge up and back down takes this long.
  static const chargeCycleS = 1.6;

  final int targetHits;
  TumbangPhase phase = TumbangPhase.placing;
  int hits = 0;
  ThrowShot? shot;
  double _chargeStart = 0;
  double _releasedAt = 0;
  double _settleUntil = 0;
  bool _resolved = false;

  /// The can is anchored: start playing.
  void placed() {
    phase = TumbangPhase.ready;
    shot = null;
  }

  /// The can was removed (move it): back to placing, hits kept.
  void unplaced() {
    phase = TumbangPhase.placing;
    shot = null;
  }

  void restart() {
    hits = 0;
    shot = null;
    phase = TumbangPhase.ready;
  }

  /// Power 0..1 while holding: rises, then falls, then rises again.
  double power(double now) {
    if (phase != TumbangPhase.charging) return 0;
    final c = ((now - _chargeStart) / (chargeCycleS / 2)) % 2;
    return c <= 1 ? c : 2 - c;
  }

  void startCharge(double now) {
    if (phase != TumbangPhase.ready) return;
    phase = TumbangPhase.charging;
    _chargeStart = now;
  }

  /// Lets go without throwing (e.g. the can is out of view).
  void cancelCharge() {
    if (phase == TumbangPhase.charging) phase = TumbangPhase.ready;
  }

  /// Releases the slipper from [camera] (position) aiming along [forward].
  ThrowShot? release(double now, {required V3 camera, required V3 forward}) {
    if (phase != TumbangPhase.charging) return null;
    final s = TumbangPresoGame.throwFrom(camera: camera, forward: forward, power: power(now));
    shot = s;
    phase = TumbangPhase.flying;
    _releasedAt = now;
    _resolved = false;
    return s;
  }

  /// Advances time; returns what just happened (the screen re-sends the scene on reset).
  TumbangEvent update(double now) {
    final s = shot;
    if (phase == TumbangPhase.flying && s != null) {
      final at = _releasedAt + (s.hitS ?? s.flightS);
      if (now >= at && !_resolved) {
        _resolved = true;
        phase = TumbangPhase.settling;
        if (s.hit) {
          hits++;
          _settleUntil = _releasedAt + s.hitS! + TumbangPresoScene.canFlightS + 1.2;
          return TumbangEvent.hit;
        }
        _settleUntil = _releasedAt + s.flightS + 0.8;
        return TumbangEvent.miss;
      }
    }
    if (phase == TumbangPhase.settling && now >= _settleUntil) {
      shot = null;
      if (hits >= targetHits) {
        phase = TumbangPhase.won;
        return TumbangEvent.won;
      }
      phase = TumbangPhase.ready;
      return TumbangEvent.reset;
    }
    return TumbangEvent.none;
  }

  /// The hand: 40 cm in front of the camera, 25 cm lower.
  static V3 handOf(V3 camera, V3 aim) => camera + aim * 0.4 + const V3(0, -0.25, 0);

  /// Unit horizontal aim, snapped onto the can when within [assistDeg].
  static V3 aimDirection(V3 camera, V3 forward) {
    final f = V3(forward.x, 0, forward.z);
    final fl = f.horizontalLength;
    final aim = fl < 1e-6 ? const V3(0, 0, -1) : f * (1 / fl);
    final toCan = V3(-camera.x, 0, -camera.z);
    final cl = toCan.horizontalLength;
    if (cl < 1e-6) return aim;
    final c = toCan * (1 / cl);
    return offAimDegrees(camera, forward).abs() <= assistDeg ? c : aim;
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

  static ThrowShot throwFrom({required V3 camera, required V3 forward, required double power}) {
    final dir = aimDirection(camera, forward);
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
      if (p.horizontalLength <= canRadius + hitMargin && p.y <= canHeight + 0.12 && p.y >= -0.05) {
        hitS = t;
        break;
      }
    }
    return ThrowShot(start: start, land: land, velocity: v, flightS: flight, hitS: hitS, direction: dir);
  }

  /// The powers (0..1) that hit from here when aimed at the can, as (from, to),
  /// or null when no power hits (too close or too far).
  static ({double from, double to})? sweetSpot(V3 camera) {
    final toCan = V3(-camera.x, 0, -camera.z);
    double? lo, hi;
    for (var i = 0; i <= 100; i++) {
      final p = i / 100;
      if (throwFrom(camera: camera, forward: toCan, power: p).hit) {
        lo ??= p;
        hi = p;
      }
    }
    return lo == null ? null : (from: lo, to: hi!);
  }
}

/// What the native renderer draws for each moment of the game.
class TumbangPresoScene {
  static const circleScale = 2.0;
  static const _canShadowScale = 1.8;
  static const _canKickUp = 2.4;
  static const _canKickForward = 2.0;

  /// Time a knocked can flies before it lies on the ground.
  static double get canFlightS {
    const y0 = TumbangPresoGame.canHeight / 2, y1 = TumbangPresoGame.canRadius;
    const g = ThrowShot.gravity;
    return (_canKickUp + math.sqrt(_canKickUp * _canKickUp + 2 * g * (y0 - y1))) / g;
  }

  static List<ArSprite> _ground({double canLife = 0}) => [
        const ArSprite('chalk_circle', x: 0, y: 0, z: 0, scale: circleScale, floor: true),
        ArSprite('shadow', x: 0, y: 0, z: 0, scale: _canShadowScale, floor: true, life: canLife),
        ArSprite('lata_stand', x: 0, y: 0, z: 0, scale: TumbangPresoGame.canScale, life: canLife),
      ];

  /// The can standing in the chalk circle.
  static List<ArSprite> ready() => _ground();

  /// One throw from release; everything after is timed natively.
  static List<ArSprite> throwing(ThrowShot s) {
    final v = s.velocity;
    const g = ThrowShot.gravity;
    final out = <ArSprite>[
      ..._ground(canLife: s.hitS ?? 0),
      ArSprite('tsinelas_spin',
          x: s.start.x, y: s.start.y, z: s.start.z, vx: v.x, vy: v.y, vz: v.z, gravity: g,
          scale: TumbangPresoGame.slipperScale, fps: 16, loop: true, life: s.flightS),
      ArSprite('shadow', x: s.start.x, y: 0, z: s.start.z, vx: v.x, vz: v.z, scale: 1.4, floor: true, life: s.flightS),
      ArSprite('tsinelas_ground',
          x: s.land.x, y: 0, z: s.land.z, scale: TumbangPresoGame.slipperScale, delay: s.flightS),
      ArSprite('fx_dust', x: s.land.x, y: 0, z: s.land.z, scale: 2, fps: 12, delay: s.flightS, life: 0.5),
    ];
    final hitS = s.hitS;
    if (hitS != null) {
      final p = s.at(hitS);
      final d = s.direction;
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
