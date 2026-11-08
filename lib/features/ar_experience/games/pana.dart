import 'dart:math' as math;

import 'ar_minigame.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// One arrow, decided at release.
class PanaShot {
  const PanaShot({
    required this.start,
    required this.velocity,
    required this.wind,
    required this.endS,
    this.hitOffset,
    this.points = 0,
    this.bangus = false,
  });

  final V3 start;
  final V3 velocity;

  /// Sideways push of the wind, m/s².
  final V3 wind;

  /// Seconds until the arrow hits, lands, or flies off.
  final double endS;

  /// Where it stuck, relative to the bilao centre; null = not in the bilao.
  final V3? hitOffset;
  final int points;

  /// Hit the golden bangus.
  final bool bangus;

  bool get hit => points > 0;

  V3 at(double t) => V3(
        start.x + velocity.x * t + 0.5 * wind.x * t * t,
        start.y + velocity.y * t - 0.5 * PanaGame.gravity * t * t,
        start.z + velocity.z * t + 0.5 * wind.z * t * t,
      );
}

/// "Pana" (Plan 77 `pana`, tuned by Plan 77b): from the line, 5.5 m from a woven
/// bilao bullseye. Drag down anywhere to pull the string, aim with the phone, let
/// go (owner 2026-11-07: "sling back pulling the bow action"); a pull under
/// [minDraw] relaxes the bow without using an arrow. The arrow leaves the bow
/// hand (low right) towards the point the sight looks at, drops a little (a
/// full draw flies flattest) and drifts with the wind; the sight pin shows where
/// it will land. 6 arrows: 1–2 still, 3–4 the bilao sways and a golden bangus
/// may swim past (15), 5–6 it sways more in wind (Archery King: about one ring
/// into the wind per step). Rings score 10/8/6/4, the woven edge 2. 28 points pass.
class PanaGame extends ArMiniGame {
  PanaGame({super.rangeScale, math.Random? random}) : _random = random ?? math.Random();

  static const gravity = 9.8 * 0.25;
  static const targetHeight = 1.4;
  static const targetScale = 2.0;
  static const targetRadius = 0.3 * targetScale;

  /// Painted rings (radius in metres at targetScale) and their points; the
  /// woven edge out to [targetRadius] is worth 2.
  static const rings = [(0.10, 10), (0.20, 8), (0.30, 6), (0.40, 4), (targetRadius, 2)];
  static const minSpeed = 8.0;
  static const maxSpeed = 22.0;
  static const swayPeriod = 3.2;
  static const arrows = 6;
  static const passScore = 28;
  static const arrowScale = 0.85;

  /// A pull shorter than this relaxes the bow without shooting.
  static const minDraw = 0.25;

  /// The bow hand, from the eye: right, down and ahead (metres).
  static const handRight = 0.16, handDown = 0.18, handAhead = 0.35;

  /// Wind push per windsock step, m/s² (about one ring at 5.5 m).
  static const windPerStep = 3.5;
  static const bangusChance = 0.5;
  static const bangusHeight = 2.3;
  static const bangusFront = 0.4;
  static const bangusSway = 1.6;
  static const bangusPeriod = 5.0;
  static const bangusScale = 1.5;
  static const bangusPoints = 15;

  final math.Random _random;

  @override
  String get title => 'PANA';
  @override
  double get fullDistance => 5.5;
  @override
  String get placeHint =>
      'Stand where you will shoot, face open ground, then tap STAND HERE. The bilao appears ${standDistance.toStringAsFixed(1)} m ahead.';
  @override
  String get endText => '$score points from $arrows arrows.';
  @override
  int get targetHits => arrows;

  /// Arrows shot so far (the pips).
  @override
  int hits = 0;
  int score = 0;
  @override
  bool placed = false;
  @override
  bool over = false;
  @override
  bool get passed => score >= passScore;
  @override
  int get boardScore => score;
  @override
  ArButtonMode get buttonMode => ArButtonMode.pull;

  final Swing _swing = Swing(swayPeriod, 0);
  final Swing _fish = Swing(bangusPeriod, 0);
  bool _drawing = false;
  double _pull = 0;
  PanaShot? shot;
  double _releasedAt = 0;
  bool _resolved = false;
  double _settleUntil = 0;

  /// Wind for the next arrow: -3..3 windsock steps (+ = blowing to the right).
  int wind = 0;
  bool bangusOut = false;

  /// Arrows already in the bilao, relative to its centre.
  final List<V3> stuck = [];

  double get sway => hits >= 4 ? 0.70 : (hits >= 2 ? 0.45 : 0.0);

  /// Bilao centre at [now].
  V3 centre(double now) => const V3(0, targetHeight, 0) + across * (sway * _swing.sinAt(now));

  /// Golden bangus at [now] (when out).
  V3 fish(double now) =>
      downrange * (-bangusFront) + across * (bangusSway * _fish.sinAt(now)) + const V3(0, bangusHeight, 0);

  V3 get windPush => across * (windPerStep * wind);

  /// How far the string is pulled back now (0..1).
  double draw(double now) => _drawing ? _pull : 0;

  @override
  bool canPress(double now) => placed && !over && shot == null;

  @override
  String buttonLabel(double now) => !_drawing ? 'PULL DOWN TO DRAW' : (draw(now) >= 0.9 ? 'LET GO!' : 'PULL MORE…');

  @override
  ArMeter? meter(double now, GamePose? pose) => (value: draw(now), from: 0.9, to: 1.0);

  @override
  String? meterCaption(double now, GamePose? pose) {
    if (wind == 0) return 'Pull the bow down to FULL, aim at the bullseye, let go.';
    final arrows = (wind > 0 ? '▶' : '◀') * wind.abs();
    return 'WIND $arrows  Aim into the wind.';
  }

  @override
  bool? reticle(double now, GamePose? pose) =>
      pose != null && placed && !over && inReticle(pose, centre(now), radius: targetRadius, coneDeg: 0);

  @override
  ArSight? sight(double now, GamePose? pose) {
    if (!placed || over) return null;
    final d = draw(now);
    // At rest the pin shows a full draw; while pulling, the draw so far.
    final p = pin(d > 0 ? math.max(d, minDraw) : 1.0);
    double deg(double m) => math.atan(m / standDistance) * 180 / math.pi;
    return (
      draw: d,
      loaded: shot == null,
      sinceRelease: sinceRelease(now),
      pinRightDeg: deg(p.right),
      pinDownDeg: deg(p.down),
      wind: wind,
      onTarget: reticle(now, pose) ?? false,
    );
  }

  @override
  String? status(GamePose? pose) => 'ARROWS ${arrows - hits} · $score PTS';

  @override
  String? hint(double now, GamePose? pose) => placed && !over ? turnHint(pose, centre(now)) : null;

  void _nextArrow(double now) {
    if (hits >= 4) {
      wind = (1 + _random.nextInt(2)) * (_random.nextBool() ? 1 : -1);
    } else {
      wind = 0;
    }
    bangusOut = (hits == 2 || hits == 3) && _random.nextDouble() < bangusChance;
    if (bangusOut) _fish.epoch = now;
  }

  @override
  void place(double now, GamePose? pose) {
    placed = true;
    shot = null;
    _drawing = false;
    _swing.epoch = now;
    _nextArrow(now);
    show(scene(now));
  }

  @override
  void unplace() {
    placed = false;
    shot = null;
    _drawing = false;
    show(const []);
  }

  @override
  void restart(double now, GamePose? pose) {
    hits = 0;
    score = 0;
    over = false;
    stuck.clear();
    place(now, pose);
  }

  @override
  void press(double now, GamePose? pose) {
    if (!canPress(now)) return;
    if (pose != null && !onLine(pose)) {
      say('BALIK SA LINYA!');
      return;
    }
    _drawing = true;
    _pull = 0;
  }

  @override
  void pull(double now, double amount) {
    if (_drawing) _pull = amount.clamp(0.0, 1.0);
  }

  @override
  void release(double now, GamePose? pose) {
    if (!_drawing) return;
    final d = draw(now);
    _drawing = false;
    if (pose == null || shot != null) return;
    if (d < minDraw) {
      // A tap or a short pull: relax the string, keep the arrow.
      say('PULL FURTHER DOWN!');
      return;
    }
    final s = shoot(now, pose, d);
    shot = s;
    hits++;
    _releasedAt = now;
    _resolved = false;
    buzz(ArHaptic.light);
    show(scene(now, shot: s));
  }

  /// Seconds since the last arrow left the bow (for the HUD's recoil).
  double sinceRelease(double now) => now - _releasedAt;

  /// Arrow speed for a draw.
  static double speedFor(double draw) => minSpeed + draw.clamp(0.0, 1.0) * (maxSpeed - minSpeed);

  /// Where an arrow drawn to [draw] lands relative to where the sight looks, at
  /// the target's distance: metres to the right (wind) and down (drop). Shown as
  /// the sight pin.
  ({double right, double down}) pin(double draw) {
    final t = standDistance / speedFor(draw);
    return (right: 0.5 * windPerStep * wind * t * t, down: 0.5 * gravity * t * t);
  }

  @override
  void update(double now, GamePose? pose) {
    final s = shot;
    if (s == null) return;
    if (!_resolved && now >= _releasedAt + s.endS) {
      _resolved = true;
      score += s.points;
      if (s.bangus) {
        say('GINTONG BANGUS! +${s.points}');
        buzz(ArHaptic.heavy);
      } else if (s.hitOffset != null) {
        stuck.add(s.hitOffset!);
        say(s.points == 10 ? 'BULLSEYE! +10' : 'SAPUL! +${s.points}');
        buzz(ArHaptic.heavy);
      } else {
        say('MINTIS!');
      }
      _settleUntil = now + 1.0;
    }
    if (_resolved && now >= _settleUntil) {
      shot = null;
      if (hits >= arrows) {
        over = true;
        buzz(ArHaptic.heavy);
      } else {
        // The sway may have grown: restart it from the middle.
        _swing.epoch = now;
        _nextArrow(now);
      }
      show(scene(now));
    }
  }

  /// Points for an arrow [distance] metres from the bullseye (0 = missed the bilao).
  static int pointsAt(double distance) {
    for (final (r, pts) in rings) {
      if (distance <= r) return pts;
    }
    return 0;
  }

  /// Flies the arrow from the bow along the aim (drop + wind), 240 steps a
  /// second, against the golden bangus and then the moving bilao.
  PanaShot shoot(double now, GamePose pose, double draw) {
    final f = pose.forward.unit;
    // From the bow hand (low right) towards the point the sight looks at, at the
    // target's distance: the arrow is seen flying from the bow into the scene.
    final start = pose.camera + rightOf(f) * handRight + f * handAhead - const V3(0, handDown, 0);
    final aim = pose.camera + f * standDistance;
    final v = (aim - start).unit * speedFor(draw);
    final w = windPush;
    final n = downrange;
    final probe = PanaShot(start: start, velocity: v, wind: w, endS: 3);
    var pastFish = !bangusOut, pastBilao = false;
    for (var t = 0.0; t <= 3; t += 1 / 240) {
      final p = probe.at(t);
      if (p.y <= 0) return PanaShot(start: start, velocity: v, wind: w, endS: t);
      if (!pastFish) {
        final b = fish(now + t);
        if ((p - b).dot(n) >= 0) {
          pastFish = true;
          final off = p - b;
          if (off.dot(across).abs() <= 0.35 * bangusScale / 1.5 && off.y.abs() <= 0.18) {
            return PanaShot(start: start, velocity: v, wind: w, endS: t, points: bangusPoints, bangus: true);
          }
        }
      }
      if (!pastBilao) {
        final c = centre(now + t);
        if ((p - c).dot(n) >= 0) {
          pastBilao = true;
          final off = p - c;
          final pts = pointsAt(off.length);
          if (pts > 0) return PanaShot(start: start, velocity: v, wind: w, endS: t, hitOffset: off, points: pts);
        }
      }
    }
    return probe;
  }

  /// The line, windsock, bilao (with arrows in it) swaying from [now], the
  /// bangus when out, plus a flying arrow.
  List<ArSprite> scene(double now, {PanaShot? shot}) {
    final amp = across * (over ? 0.0 : sway);
    final period = amp.horizontalLength > 0 ? swayPeriod : 0.0;
    ArSprite swaying(String sheet, V3 at, {double scale = 1, double delay = 0}) => ArSprite(sheet,
        x: at.x,
        y: at.y,
        z: at.z,
        scale: scale,
        delay: delay,
        oscPeriod: period,
        oscPhase: _swing.phaseAt(now + delay),
        ox: amp.x,
        oz: amp.z);
    // Arrows sit a little towards the player so the flat bilao never hides them.
    V3 inFront(V3 off) => const V3(0, targetHeight, 0) + off - downrange * 0.03;
    final sock = across * 1.3;
    final out = <ArSprite>[
      lineSprite,
      ArSprite('windsock', x: sock.x, y: 0, z: sock.z, frame: wind.abs(), flipX: wind < 0),
      ArSprite('shadow',
          x: 0,
          y: 0,
          z: 0,
          scale: 6,
          floor: true,
          oscPeriod: period,
          oscPhase: _swing.phaseAt(now),
          ox: amp.x,
          oz: amp.z),
      swaying('bilao_target', const V3(0, targetHeight, 0), scale: targetScale),
      for (final off in stuck) swaying('arrow_stuck', inFront(off), scale: arrowScale),
    ];
    final s = shot;
    final fishLife = s != null && s.bangus ? s.endS : 0.0;
    if (bangusOut && !over) {
      final base = downrange * (-bangusFront) + const V3(0, bangusHeight, 0);
      final fa = across * bangusSway;
      out.add(ArSprite('bangus_target',
          x: base.x,
          y: base.y,
          z: base.z,
          scale: bangusScale,
          life: fishLife,
          oscPeriod: bangusPeriod,
          oscPhase: _fish.phaseAt(now),
          ox: fa.x,
          oz: fa.z,
          oscFlip: true));
    }
    if (s == null) return out;
    final v = s.velocity;
    out.add(ArSprite('arrow_flight',
        x: s.start.x,
        y: s.start.y,
        z: s.start.z,
        vx: v.x,
        vy: v.y,
        vz: v.z,
        gravity: gravity,
        ax: s.wind.x,
        az: s.wind.z,
        scale: arrowScale,
        align: true,
        life: s.endS));
    final end = s.at(s.endS);
    final off = s.hitOffset;
    if (s.bangus) {
      out.addAll([
        ArSprite('bangus_wiggle', x: end.x, y: end.y, z: end.z, scale: bangusScale, fps: 10, delay: s.endS, life: 0.8),
        ArSprite('fx_sparkle', x: end.x, y: end.y, z: end.z, scale: 5, fps: 15, delay: s.endS, life: 0.4),
      ]);
    } else if (off != null) {
      out.addAll([
        swaying('arrow_stuck', inFront(off), scale: arrowScale, delay: s.endS),
        ArSprite('fx_sparkle', x: end.x, y: end.y, z: end.z, scale: 4, fps: 15, delay: s.endS, life: 0.4),
      ]);
    } else if (end.y <= 0.01) {
      out.addAll([
        ArSprite('arrow_stuck', x: end.x, y: 0, z: end.z, scale: arrowScale, delay: s.endS),
        ArSprite('fx_dust', x: end.x, y: 0, z: end.z, scale: 2, fps: 12, delay: s.endS, life: 0.5),
      ]);
    }
    return out;
  }
}
