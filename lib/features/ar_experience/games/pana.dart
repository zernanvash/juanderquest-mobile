import 'ar_minigame.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// One arrow, decided at release.
class PanaShot {
  const PanaShot({
    required this.start,
    required this.velocity,
    required this.endS,
    required this.hitOffset,
    required this.bullseye,
  });

  final V3 start;
  final V3 velocity;

  /// Seconds until the arrow hits the bilao, or lands, or flies off.
  final double endS;

  /// Where it stuck, relative to the bilao centre; null = miss.
  final V3? hitOffset;
  final bool bullseye;

  bool get hit => hitOffset != null;

  V3 at(double t) => V3(
        start.x + velocity.x * t,
        start.y + velocity.y * t - 0.5 * PanaGame.gravity * t * t,
        start.z + velocity.z * t,
      );
}

/// "Pana" (Plan 77 `pana`): a woven bilao bullseye floats over the anchor and
/// sways side to side, more after each hit. Hold to draw the bow, aim the circle
/// at the bilao, let go. The arrow flies along the aim and drops a little, so a
/// full draw flies flattest and a moving bilao needs a small lead.
class PanaGame extends ArMiniGame {
  PanaGame({this.targetHits = 3});

  static const gravity = 9.8 * 0.5;
  static const targetHeight = 1.4;
  static const targetScale = 2.0;
  static const targetRadius = 0.3 * targetScale;

  /// Easy mode: how far outside the rim still counts.
  static const hitMargin = 0.1;
  static const bullseyeRadius = 0.18;
  static const drawS = 0.8;
  static const minSpeed = 8.0;
  static const maxSpeed = 22.0;
  static const swayPeriod = 3.2;
  static const swayByHits = [0.0, 0.5, 0.9];
  static const arrowScale = 1.5;

  @override
  final int targetHits;
  @override
  int hits = 0;
  @override
  bool placed = false;
  @override
  bool won = false;

  /// Unit horizontal axis the bilao sways along (across the player's view).
  V3 swayAxis = const V3(1, 0, 0);
  final Swing _swing = Swing(swayPeriod, 0);
  bool _drawing = false;
  double _drawStart = 0;
  PanaShot? shot;
  double _releasedAt = 0;
  bool _resolved = false;
  double _settleUntil = 0;

  /// Arrows already in the bilao, relative to its centre.
  final List<V3> stuck = [];

  @override
  String get title => 'PANA';
  @override
  String get placeLabel => 'PLACE BILAO';
  @override
  String get placeHint => 'Point at open ground 5–6 steps away, then place the target.';
  @override
  String get wonText => 'You hit the bilao $targetHits times.';
  @override
  ArButtonMode get buttonMode => ArButtonMode.hold;

  double get sway => swayByHits[hits.clamp(0, swayByHits.length - 1)];

  /// Bilao centre at [now].
  V3 centre(double now) => const V3(0, targetHeight, 0) + swayAxis * (sway * _swing.sinAt(now));

  double draw(double now) => _drawing ? ((now - _drawStart) / drawS).clamp(0.0, 1.0) : 0;

  @override
  bool canPress(double now) => placed && !won && shot == null;

  @override
  String buttonLabel(double now) => !_drawing ? 'HOLD TO DRAW' : (draw(now) >= 1 ? 'LET GO!' : 'DRAWING…');

  @override
  ArMeter? meter(double now, ArPose? pose) => (value: draw(now), from: 0.9, to: 1.0);

  @override
  String? meterCaption(double now, ArPose? pose) => 'Draw to FULL, put the circle on the bilao, let go.';

  @override
  bool? reticle(double now, ArPose? pose) =>
      pose != null && placed && inReticle(pose, centre(now), radius: targetRadius, coneDeg: 0);

  @override
  String? status(ArPose? pose) {
    final d = ArMiniGame.distance(pose);
    return d == null ? null : 'BILAO ${d.toStringAsFixed(1)} m';
  }

  @override
  String? hint(double now, ArPose? pose) => placed && !won ? turnHint(pose, centre(now)) : null;

  void _faceAxis(ArPose? pose) {
    if (pose == null) return;
    swayAxis = rightOf(V3(-pose.camera.x, 0, -pose.camera.z));
  }

  @override
  void place(double now, ArPose? pose) {
    placed = true;
    shot = null;
    _drawing = false;
    stuck.clear();
    _faceAxis(pose);
    _swing.epoch = now;
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
  void restart(double now, ArPose? pose) {
    hits = 0;
    won = false;
    shot = null;
    stuck.clear();
    _faceAxis(pose);
    _swing.epoch = now;
    show(scene(now));
  }

  @override
  void press(double now, ArPose? pose) {
    if (!canPress(now)) return;
    _drawing = true;
    _drawStart = now;
  }

  @override
  void release(double now, ArPose? pose) {
    if (!_drawing) return;
    final d = draw(now);
    _drawing = false;
    if (pose == null || shot != null) return;
    final s = shoot(now, pose, d);
    shot = s;
    _releasedAt = now;
    _resolved = false;
    buzz(ArHaptic.light);
    show(scene(now, shot: s));
  }

  @override
  void update(double now, ArPose? pose) {
    final s = shot;
    if (s == null) return;
    if (!_resolved && now >= _releasedAt + s.endS) {
      _resolved = true;
      if (s.hit) {
        hits++;
        stuck.add(s.hitOffset!);
        say(s.bullseye ? 'BULLSEYE!' : 'SAPUL!');
        buzz(ArHaptic.heavy);
        _settleUntil = now + 1.0;
      } else {
        say('MINTIS!');
        _settleUntil = now + 0.8;
      }
    }
    if (_resolved && now >= _settleUntil) {
      shot = null;
      if (hits >= targetHits) {
        won = true;
        buzz(ArHaptic.heavy);
      }
      // Hits make the bilao sway further; restart the sway from the middle.
      _swing.epoch = now;
      show(scene(now));
    }
  }

  /// Flies the arrow from the bow along the aim and checks it against the
  /// moving bilao, 240 steps a second.
  PanaShot shoot(double now, ArPose pose, double draw) {
    final f = pose.forward.unit;
    final start = pose.camera + f * 0.3 + const V3(0, -0.12, 0);
    final v = f * (minSpeed + draw.clamp(0.0, 1.0) * (maxSpeed - minSpeed));
    final c0 = centre(now);
    final n = V3(c0.x - start.x, 0, c0.z - start.z).unit;
    final probe = PanaShot(start: start, velocity: v, endS: 3, hitOffset: null, bullseye: false);
    var crossed = (start - c0).dot(n) >= 0;
    for (var t = 0.0; t <= 3; t += 1 / 240) {
      final p = probe.at(t);
      if (p.y <= 0) return PanaShot(start: start, velocity: v, endS: t, hitOffset: null, bullseye: false);
      final c = centre(now + t);
      if (!crossed && (p - c).dot(n) >= 0) {
        crossed = true;
        final off = p - c;
        if (off.length <= targetRadius + hitMargin) {
          return PanaShot(start: start, velocity: v, endS: t, hitOffset: off, bullseye: off.length <= bullseyeRadius);
        }
      }
    }
    return probe;
  }

  /// Bilao (with arrows in it) swaying from [now], plus a flying arrow.
  List<ArSprite> scene(double now, {PanaShot? shot}) {
    final amp = swayAxis * (won ? 0.0 : sway);
    final period = amp.horizontalLength > 0 ? swayPeriod : 0.0;
    ArSprite swaying(String sheet, V3 at, {double scale = 1, double delay = 0}) => ArSprite(sheet,
        x: at.x, y: at.y, z: at.z, scale: scale, delay: delay,
        oscPeriod: period, oscPhase: _swing.phaseAt(now + delay), ox: amp.x, oz: amp.z);
    // Arrows sit a little towards the player so the flat bilao never hides them.
    V3 inFront(V3 off) => const V3(0, targetHeight, 0) + off + _towardPlayer * 0.03;

    final out = <ArSprite>[
      ArSprite('shadow', x: 0, y: 0, z: 0, scale: 6, floor: true,
          oscPeriod: period, oscPhase: _swing.phaseAt(now), ox: amp.x, oz: amp.z),
      swaying('bilao_target', const V3(0, targetHeight, 0), scale: targetScale),
      for (final off in stuck) swaying('arrow_stuck', inFront(off), scale: arrowScale),
    ];
    final s = shot;
    if (s != null) {
      final v = s.velocity;
      out.add(ArSprite('arrow_flight',
          x: s.start.x, y: s.start.y, z: s.start.z, vx: v.x, vy: v.y, vz: v.z, gravity: gravity,
          scale: arrowScale, align: true, life: s.endS));
      final off = s.hitOffset;
      if (off != null) {
        out.addAll([
          swaying('arrow_stuck', inFront(off), scale: arrowScale, delay: s.endS),
          ArSprite('fx_sparkle', x: off.x, y: targetHeight + off.y, z: off.z, scale: 4, fps: 15, delay: s.endS, life: 0.4),
        ]);
      } else if (s.at(s.endS).y <= 0.01) {
        final land = s.at(s.endS);
        out.addAll([
          ArSprite('arrow_stuck', x: land.x, y: 0, z: land.z, scale: arrowScale, delay: s.endS),
          ArSprite('fx_dust', x: land.x, y: 0, z: land.z, scale: 2, fps: 12, delay: s.endS, life: 0.5),
        ]);
      }
    }
    return out;
  }

  /// Unit horizontal direction from the bilao towards where the player stood
  /// when it was placed (the sway axis is across it).
  V3 get _towardPlayer => V3(-swayAxis.z, 0, swayAxis.x);
}
