import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/games/tumbang_preso.dart';

// Plan 77, owner 2026-11-06: "lets try do the throwing game first".
void main() {
  // Standing 3.5 m from the can (can at the origin), phone 1.4 m up, looking at it.
  const cam = V3(0, 1.4, 3.5);
  const atCan = V3(0, -0.3, -1);

  double sweetMid() {
    final z = TumbangPresoGame.sweetSpot(cam)!;
    return (z.from + z.to) / 2;
  }

  group('throw', () {
    test('a power in the sweet spot hits; too little falls short, too much flies over', () {
      final zone = TumbangPresoGame.sweetSpot(cam);
      expect(zone, isNotNull);
      expect(TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: sweetMid()).hit, isTrue);
      final short = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: 0);
      expect(short.hit, isFalse);
      expect(short.land.z, greaterThan(0.5), reason: 'lands between the player and the can');
      final long = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: 1);
      expect(long.hit, isFalse);
      expect(long.land.z, lessThan(-2), reason: 'lands well past the can');
    });

    test('the sweet spot is wide enough to be fair but not everything', () {
      final z = TumbangPresoGame.sweetSpot(cam)!;
      expect(z.to - z.from, inInclusiveRange(0.04, 0.25));
    });

    test('aim within 10 degrees snaps onto the can; 30 degrees off misses', () {
      const a8 = 8 * math.pi / 180;
      final near = V3(math.sin(a8), -0.3, -math.cos(a8));
      expect(TumbangPresoGame.offAimDegrees(cam, near), closeTo(-8, 0.5));
      expect(TumbangPresoGame.throwFrom(camera: cam, forward: near, power: sweetMid()).hit, isTrue);
      const a30 = 30 * math.pi / 180;
      final wide = V3(math.sin(a30), -0.3, -math.cos(a30));
      expect(TumbangPresoGame.throwFrom(camera: cam, forward: wide, power: sweetMid()).hit, isFalse);
    });

    test('the arc starts at the hand and lands on the floor at the end of the flight', () {
      final s = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: 0.5);
      expect(s.at(0).y, closeTo(1.15, 0.01));
      expect(s.at(s.flightS).y, closeTo(0, 1e-6));
      expect(s.at(s.flightS).x, closeTo(s.land.x, 1e-6));
      expect(s.at(s.flightS).z, closeTo(s.land.z, 1e-6));
    });
  });

  group('game', () {
    test('power rises, falls and rises again while holding', () {
      final g = TumbangPresoGame()..placed();
      g.startCharge(10);
      expect(g.power(10), 0);
      expect(g.power(10.4), closeTo(0.5, 1e-9));
      expect(g.power(10.8), closeTo(1, 1e-9));
      expect(g.power(11.2), closeTo(0.5, 1e-9));
      expect(g.power(11.6), closeTo(0, 1e-9));
    });

    test('a miss costs nothing; three hits win', () {
      final g = TumbangPresoGame()..placed();
      var now = 0.0;

      // Miss: release at once (power 0).
      g.startCharge(now);
      final miss = g.release(now, camera: cam, forward: atCan)!;
      expect(miss.hit, isFalse);
      expect(g.update(now + miss.flightS + 0.01), TumbangEvent.miss);
      expect(g.hits, 0);
      expect(g.update(now + miss.flightS + 1.0), TumbangEvent.reset);
      expect(g.phase, TumbangPhase.ready);

      // Hold until the power is in the sweet spot, three times.
      final holdS = sweetMid() * TumbangPresoGame.chargeCycleS / 2;
      for (var i = 1; i <= 3; i++) {
        now += 10;
        g.startCharge(now);
        final s = g.release(now + holdS, camera: cam, forward: atCan)!;
        expect(s.hit, isTrue);
        expect(g.update(now + holdS + s.hitS! + 0.01), TumbangEvent.hit);
        expect(g.hits, i);
        expect(g.update(now + holdS + 10), i < 3 ? TumbangEvent.reset : TumbangEvent.won);
      }
      expect(g.phase, TumbangPhase.won);
      g.restart();
      expect((g.hits, g.phase), (0, TumbangPhase.ready));
    });

    test('cannot throw before the can is placed or while a throw is flying', () {
      final g = TumbangPresoGame();
      g.startCharge(0);
      expect(g.release(0.5, camera: cam, forward: atCan), isNull);
      g.placed();
      g.startCharge(1);
      expect(g.release(1.5, camera: cam, forward: atCan), isNotNull);
      g.startCharge(1.6);
      expect(g.phase, TumbangPhase.flying);
    });
  });

  group('scene', () {
    test('ready shows the can in its chalk circle', () {
      expect([for (final s in TumbangPresoScene.ready()) s.sheet], ['chalk_circle', 'shadow', 'lata_stand']);
    });

    test('a hit hides the standing can at the hit and knocks it over', () {
      final s = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: sweetMid());
      final sprites = TumbangPresoScene.throwing(s);
      final stand = sprites.firstWhere((e) => e.sheet == 'lata_stand');
      expect(stand.life, s.hitS);
      final tumble = sprites.firstWhere((e) => e.sheet == 'lata_tumble');
      expect(tumble.delay, s.hitS);
      final down = sprites.firstWhere((e) => e.sheet == 'lata_down');
      expect(down.delay, closeTo(s.hitS! + TumbangPresoScene.canFlightS, 1e-9));
    });

    test('a miss leaves the can standing and the slipper on the ground', () {
      final s = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: 0);
      final sprites = TumbangPresoScene.throwing(s);
      expect(sprites.firstWhere((e) => e.sheet == 'lata_stand').life, 0);
      expect(sprites.where((e) => e.sheet == 'lata_tumble'), isEmpty);
      expect(sprites.firstWhere((e) => e.sheet == 'tsinelas_ground').delay, s.flightS);
    });
  });
}
