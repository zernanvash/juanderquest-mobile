import 'dart:math' as math;

import 'ar_minigame.dart';
import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// The object-collection AR task in the games' pixel style (owner 2026-11-07:
/// "the object collection should now be the same style from the games"). A
/// spinning, bobbing item floats ahead; put it in the circle and tap COLLECT.
/// In the AR Lab the six items come one after another at random spots so you can
/// see them all.
class CollectGame extends ArMiniGame {
  CollectGame({super.rangeScale, math.Random? random}) : _random = random ?? math.Random();

  /// Quest AR objects (`verification.object`) and their sprites.
  static const items = ['token', 'gem', 'crate', 'beacon', 'orb', 'pyramid'];
  static const names = {
    'token': 'QUEST TOKEN',
    'gem': 'EXPLORER GEM',
    'crate': 'RELIC BOX',
    'beacon': 'GEO BEACON',
    'orb': 'GEODESIC ORB',
    'pyramid': 'HERITAGE PYRAMID',
  };
  static const height = 1.2;
  static const scale = 2.0;
  static const radius = 0.16 * scale;
  static const bob = 0.08;
  static const bobPeriod = 2.0;
  static const aimDeg = 6.0;

  final math.Random _random;

  @override
  String get title => 'COLLECT';
  @override
  double get fullDistance => 2.5;
  @override
  String get placeHint => 'Stand anywhere, face open ground, then tap STAND HERE. The first item appears ahead.';
  @override
  String get endText => 'You collected all ${items.length} items.';
  @override
  int get targetHits => items.length;
  @override
  int hits = 0;
  @override
  bool placed = false;
  @override
  bool over = false;
  @override
  bool get passed => over;
  @override
  ArButtonMode get buttonMode => ArButtonMode.tap;

  /// Where the current item floats (its middle), relative to the anchor.
  V3 spot = const V3(0, height, 0);
  final Swing _bob = Swing(bobPeriod, 0);
  double _nextAt = double.infinity;
  bool _waiting = false;

  String get item => items[hits.clamp(0, items.length - 1)];

  /// The item's middle at [now] (it bobs).
  V3 at(double now) => spot + V3(0, bob * _bob.sinAt(now), 0);

  /// No throwing line: you may walk up to the item.
  @override
  bool onLine(ArPose pose) => true;

  bool onTarget(double now, ArPose pose) => inReticle(pose, at(now), radius: radius, coneDeg: aimDeg);

  @override
  bool canPress(double now) => placed && !over && !_waiting;

  @override
  String buttonLabel(double now) => 'COLLECT';

  @override
  ArMeter? meter(double now, ArPose? pose) => null;

  @override
  String? meterCaption(double now, ArPose? pose) =>
      _waiting ? 'Look around for the next one…' : 'Put the ${names[item]} in the circle, then tap COLLECT.';

  @override
  bool? reticle(double now, ArPose? pose) => canPress(now) ? (pose != null && onTarget(now, pose)) : null;

  @override
  String? status(ArPose? pose) => 'ITEMS $hits/${items.length}';

  @override
  String? hint(double now, ArPose? pose) => canPress(now) ? turnHint(pose, at(now)) : null;

  @override
  void place(double now, ArPose? pose) {
    placed = true;
    _waiting = false;
    _nextAt = double.infinity;
    spot = const V3(0, height, 0);
    _bob.epoch = now;
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
    over = false;
    place(now, pose);
  }

  @override
  void press(double now, ArPose? pose) {
    if (!canPress(now) || pose == null) return;
    if (!onTarget(now, pose)) {
      say('AIM AT IT');
      return;
    }
    final p = at(now);
    final got = item;
    hits++;
    say('${names[got]}!');
    buzz(ArHaptic.heavy);
    show([
      ArSprite('item_$got', x: p.x, y: p.y, z: p.z, vy: 2.5, scale: scale, fps: 30, loop: true, life: 0.45),
      ArSprite('fx_sparkle', x: p.x, y: p.y, z: p.z, scale: 5, fps: 15, life: 0.4),
    ]);
    if (hits >= items.length) {
      over = true;
      return;
    }
    _waiting = true;
    _nextAt = now + 1.0;
  }

  @override
  void update(double now, ArPose? pose) {
    if (!_waiting || now < _nextAt) return;
    _waiting = false;
    _nextAt = double.infinity;
    // Next item somewhere else ahead: 1–2.2 m to either side, 0–1.5 m further.
    final side = (0.9 + _random.nextDouble() * 1.3) * (_random.nextBool() ? 1 : -1);
    final further = _random.nextDouble() * 1.5 * rangeScale;
    final g = across * side + downrange * further;
    spot = V3(g.x, height, g.z);
    _bob.epoch = now;
    show(scene(now));
  }

  /// The current item spinning and bobbing over its shadow.
  List<ArSprite> scene(double now) => [
        ArSprite('shadow', x: spot.x, y: 0, z: spot.z, scale: 3, floor: true),
        ArSprite('item_$item',
            x: spot.x,
            y: spot.y,
            z: spot.z,
            scale: scale,
            fps: 10,
            loop: true,
            oscPeriod: bobPeriod,
            oscPhase: _bob.phaseAt(now),
            oy: bob),
      ];
}
