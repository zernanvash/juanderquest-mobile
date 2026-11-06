import 'dart:math' as math;

import 'ar_minigame.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// "Sipa Rally" (Plan 77 `sipa`): keep the sipa up. It floats up and falls
/// slowly over the anchor, drifting a little each time; follow it with the
/// circle and tap SIPA when it turns green (falling, low enough, in the circle).
/// A drop resets the rally; [targetHits] kicks in a row win.
class SipaGame extends ArMiniGame {
  SipaGame({this.targetHits = 5, math.Random? random}) : _random = random ?? math.Random();

  /// Floaty gravity: plastic plumes slow the real sipa down.
  static const gravity = 3.0;
  static const kickSpeed = 3.3;
  static const scale = 2.5;
  static const radius = 0.08 * scale;

  /// Height of the sipa's middle when it lies on the ground.
  static const restY = 0.3;
  static const kickLow = 0.45;
  static const kickHigh = 1.7;
  static const aimDeg = 9.0;
  static const tapCooldownS = 0.3;
  static const maxDrift = 0.45;
  static const leash = 0.6;

  final math.Random _random;

  @override
  final int targetHits;

  /// Kicks in the current rally.
  @override
  int hits = 0;
  int best = 0;
  @override
  bool placed = false;
  @override
  bool won = false;

  V3 _start = const V3(0, restY, 0);
  V3 _velocity = const V3(0, 0, 0);
  double _kickedAt = 0;
  bool flying = false;
  double _nextTap = 0;
  double _landS = 0;
  double _wonAt = double.infinity;

  @override
  String get title => 'SIPA RALLY';
  @override
  String get placeLabel => 'PLACE SIPA';
  @override
  String get placeHint => 'Point at open ground 2–3 steps away, then place the sipa.';
  @override
  String get wonText => '$targetHits kicks in a row!';
  @override
  ArButtonMode get buttonMode => ArButtonMode.tap;

  V3 at(double now) {
    if (!flying) return _start;
    final t = now - _kickedAt;
    return V3(
      _start.x + _velocity.x * t,
      _start.y + _velocity.y * t - 0.5 * gravity * t * t,
      _start.z + _velocity.z * t,
    );
  }

  bool falling(double now) => flying && _velocity.y - gravity * (now - _kickedAt) < 0;

  /// Kickable now: on the ground (to start), or falling through the kick zone in the circle.
  bool kickable(double now, ArPose pose) {
    if (!flying) return true;
    final p = at(now);
    return falling(now) && p.y >= kickLow && p.y <= kickHigh && inReticle(pose, p, radius: radius, coneDeg: aimDeg);
  }

  @override
  bool canPress(double now) => placed && !won && now >= _nextTap;

  @override
  String buttonLabel(double now) => flying ? 'SIPA!' : 'SIPA! (START)';

  @override
  ArMeter? meter(double now, ArPose? pose) => null;

  @override
  String? meterCaption(double now, ArPose? pose) =>
      flying ? 'Tap SIPA when the circle turns green.' : 'Tap SIPA to kick it up.';

  @override
  bool? reticle(double now, ArPose? pose) => placed && !won ? (pose != null && flying && kickable(now, pose)) : null;

  @override
  String? status(ArPose? pose) => 'BEST $best';

  @override
  String? hint(double now, ArPose? pose) => placed && !won ? turnHint(pose, at(now)) : null;

  @override
  void place(double now, ArPose? pose) {
    placed = true;
    flying = false;
    _start = const V3(0, restY, 0);
    show(scene(now));
  }

  @override
  void unplace() {
    placed = false;
    flying = false;
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
    _nextTap = now + tapCooldownS;
    if (!kickable(now, pose)) {
      final p = at(now);
      say(!falling(now) || p.y > kickHigh ? 'MAAGA PA!' : 'MINTIS!');
      return;
    }
    final wasFlying = flying;
    kick(now);
    if (wasFlying) {
      hits++;
      best = math.max(best, hits);
      say('SIPA! x$hits');
      buzz(ArHaptic.heavy);
      if (hits >= targetHits) _wonAt = now + 0.8;
    } else {
      buzz(ArHaptic.light);
    }
  }

  /// Sends the sipa up from where it is, drifting a little (back towards the
  /// middle when it has wandered off).
  void kick(double now) {
    final p = at(now);
    final drift = math.min(maxDrift, 0.15 + 0.05 * hits);
    var dir = _random.nextDouble() * 2 * math.pi;
    if (p.horizontalLength > leash) dir = math.atan2(-p.z, -p.x);
    _start = p;
    _velocity = V3(math.cos(dir) * drift, kickSpeed, math.sin(dir) * drift);
    _kickedAt = now;
    flying = true;
    _landS = timeToFallTo(p.y, kickSpeed, gravity, restY)!;
    show(scene(now));
  }

  @override
  void update(double now, ArPose? pose) {
    if (!won && now >= _wonAt) {
      won = true;
      buzz(ArHaptic.heavy);
    }
    if (flying && now >= _kickedAt + _landS) {
      final p = at(_kickedAt + _landS);
      flying = false;
      _start = V3(p.x, restY, p.z);
      if (!won && _wonAt == double.infinity) {
        if (hits > 0) say('NAHULOG!');
        hits = 0;
      }
      show([...scene(now), ArSprite('fx_dust', x: p.x, y: 0, z: p.z, scale: 2, fps: 12, life: 0.5)]);
    }
  }

  /// The sipa resting, or flying from its last kick (sent at the kick).
  List<ArSprite> scene(double now) {
    final p = _start;
    if (!flying) {
      return [
        ArSprite('shadow', x: p.x, y: 0, z: p.z, scale: 1.6, floor: true),
        ArSprite('sipa', x: p.x, y: p.y, z: p.z, scale: scale),
      ];
    }
    final v = _velocity;
    return [
      ArSprite('shadow', x: p.x, y: 0, z: p.z, vx: v.x, vz: v.z, scale: 1.6, floor: true, life: _landS),
      ArSprite('sipa', x: p.x, y: p.y, z: p.z, vx: v.x, vy: v.y, vz: v.z, gravity: gravity,
          scale: scale, fps: 10, loop: true, life: _landS),
      ArSprite('fx_sparkle', x: p.x, y: p.y, z: p.z, scale: 3, fps: 15, life: 0.4),
    ];
  }
}
