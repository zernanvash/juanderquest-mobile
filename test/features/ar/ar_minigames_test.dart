import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_minigame.dart';
import 'package:juanderquest_app/features/ar_experience/games/palayok.dart';
import 'package:juanderquest_app/features/ar_experience/games/pana.dart';
import 'package:juanderquest_app/features/ar_experience/games/ring_shoot.dart';
import 'package:juanderquest_app/features/ar_experience/games/sipa.dart';
import 'package:juanderquest_app/features/ar_experience/games/tumbang_preso.dart';

// Plan 77, owner 2026-11-06: "build the mini games altogether then we check it all
// at the same time". Pure game logic: time and pose in, hits/scenes out.

/// Pose at [camera] looking at [target].
ArPose look(V3 camera, V3 target) => ArPose(camera, (target - camera).unit);

/// Pose at [camera] turned [deg] degrees right of [target].
ArPose lookOff(V3 camera, V3 target, double deg) {
  final f = (target - camera).unit;
  final a = deg * math.pi / 180;
  return ArPose(camera, V3(f.x * math.cos(a) - f.z * math.sin(a), f.y, f.x * math.sin(a) + f.z * math.cos(a)));
}

void main() {
  group('Ring Shoot', () {
    const cam = V3(0, 1.4, 4.5);
    final atHoop = look(cam, const V3(0, 2, 0));

    test('the sweet spot scores; too soft and too hard miss', () {
      final z = RingShootGame.sweetSpot(cam)!;
      expect(z.to - z.from, inInclusiveRange(0.03, 0.25));
      final mid = (z.from + z.to) / 2;
      expect(RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, power: mid).make, isTrue);
      expect(RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, power: 0).make, isFalse);
      expect(RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, power: 1).make, isFalse);
    });

    test('the ball comes down through rim height at the cross time', () {
      final s = RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, power: 0.4);
      expect(s.at(s.crossS).y, closeTo(RingShootGame.rimHeight, 1e-6));
      expect(s.at(s.endS).y, closeTo(RingShootGame.ballRadius, 1e-6));
      expect(s.endS, greaterThan(s.crossS));
    });

    test('three baskets win; a miss costs nothing', () {
      final g = RingShootGame()..place(0, atHoop);
      expect(g.takeScene()!.map((s) => s.sheet), contains('hoop'));
      final z = RingShootGame.sweetSpot(cam)!;
      final holdS = (z.from + z.to) / 2 * RingShootGame.chargeCycleS / 2;
      var now = 1.0;
      // Miss: let go at once.
      g.press(now, atHoop);
      g.release(now, atHoop);
      expect(g.shot!.make, isFalse);
      g.update(now + 10, atHoop);
      expect(g.takeCallout(), 'MINTIS!');
      g.update(now + 20, atHoop);
      expect((g.hits, g.shot), (0, null));
      for (var i = 1; i <= 3; i++) {
        now += 30;
        g.press(now, atHoop);
        g.release(now + holdS, atHoop);
        expect(g.shot!.make, isTrue);
        g.update(now + 10, atHoop);
        expect(g.hits, i);
        g.update(now + 20, atHoop);
      }
      expect(g.won, isTrue);
      expect(g.canPress(now + 30), isFalse);
      g.restart(now + 30, atHoop);
      expect((g.hits, g.won), (0, false));
    });

    test('a make hides the hoop, swishes the net and drops the ball in front of it', () {
      final z = RingShootGame.sweetSpot(cam)!;
      final s = RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, power: (z.from + z.to) / 2);
      final scene = RingShootGame.scene(shot: s);
      expect(scene.firstWhere((e) => e.sheet == 'hoop').life, s.crossS);
      expect(scene.firstWhere((e) => e.sheet == 'hoop_swish').delay, s.crossS);
      final drop = scene.where((e) => e.sheet == 'ball_spin' && e.delay == s.crossS).single;
      expect(drop.z, greaterThan(0), reason: 'towards the player (who stands at +z)');
    });
  });

  group('Pana', () {
    const cam = V3(0, 1.4, 6);
    const centre = V3(0, PanaGame.targetHeight, 0);

    test('a full draw at the bilao hits; a weak draw drops short; aiming off misses', () {
      final g = PanaGame()..place(0, look(cam, centre));
      expect(g.shoot(0, look(cam, centre), 1).hit, isTrue);
      final weak = g.shoot(0, look(cam, centre), 0);
      expect(weak.hit, isFalse);
      expect(weak.at(weak.endS).y, lessThanOrEqualTo(0.01), reason: 'lands on the ground');
      expect(g.shoot(0, lookOff(cam, centre, 12), 1).hit, isFalse);
    });

    test('holding draws to full in ${PanaGame.drawS} s', () {
      final g = PanaGame()..place(0, look(cam, centre));
      g.press(1, look(cam, centre));
      expect(g.draw(1 + PanaGame.drawS / 2), closeTo(0.5, 1e-9));
      expect(g.draw(1 + PanaGame.drawS * 2), 1);
    });

    test('three hits win, the bilao sways more after each hit and keeps the arrows', () {
      final g = PanaGame()..place(0, look(cam, centre));
      var epoch = 0.0;
      for (var i = 1; i <= 3; i++) {
        // Shoot at the end of a sway (the bilao is still), a little high for the drop.
        final at = epoch + PanaGame.swayPeriod / 4;
        final pose = look(cam, g.centre(at) + const V3(0, 0.2, 0));
        g.press(at - 1, pose);
        g.release(at, pose);
        expect(g.shot!.hit, isTrue, reason: 'shot $i');
        g.update(at + 1, pose);
        expect(g.hits, i);
        expect(g.takeCallout(), anyOf('SAPUL!', 'BULLSEYE!'));
        epoch = at + 3;
        g.update(epoch, pose);
        if (i < 3) expect(g.sway, PanaGame.swayByHits[i]);
      }
      expect(g.won, isTrue);
      expect(g.stuck, hasLength(3));
      expect(g.takeScene()!.where((s) => s.sheet == 'arrow_stuck'), hasLength(3));
    });

    test('the bilao sways across the player\'s view', () {
      final g = PanaGame()..place(0, look(cam, centre));
      expect(g.swayAxis.z.abs(), lessThan(1e-9));
      expect(g.swayAxis.x.abs(), closeTo(1, 1e-9));
    });
  });

  group('Pukpok Palayok', () {
    const near = V3(0, 1.4, 1.8);

    /// Pose at [cam] aimed at the swinging pot at [now].
    ArPose aimAt(PalayokGame g, double now, V3 cam) {
      var pose = look(cam, const V3(0, PalayokGame.pivotHeight - PalayokGame.ropeLength, 0));
      for (var i = 0; i < 3; i++) {
        pose = look(cam, g.pot(now, pose));
      }
      return pose;
    }

    test('hits only when close and the pot is in the circle', () {
      final g = PalayokGame(random: math.Random(1))..place(0, null);
      g.press(0.1, look(const V3(0, 1.4, 4), const V3(0, 1.7, 0)));
      expect((g.hits, g.takeCallout()), (0, 'LAPIT PA!'));
      g.press(1, lookOff(near, g.pot(1, aimAt(g, 1, near)), 30));
      expect((g.hits, g.takeCallout()), (0, 'MINTIS!'));
      g.press(1.1, aimAt(g, 1.1, near));
      expect(g.hits, 0, reason: 'still cooling down after a swing');
      g.press(2, aimAt(g, 2, near));
      expect((g.hits, g.takeCallout()), (1, 'PUKPOK!'));
      expect(g.takeScene()!.map((s) => s.sheet), contains('palayok_crack1'));
    });

    test('three hits break it, the coins fall and the game is won', () {
      final g = PalayokGame(random: math.Random(2))..place(0, null);
      for (final t in [1.0, 2.0, 3.0]) {
        g.press(t, aimAt(g, t, near));
      }
      expect(g.hits, 3);
      expect(g.takeCallout(), 'BASAG!');
      final scene = g.takeScene()!;
      expect(scene.map((s) => s.sheet), contains('palayok_break'));
      expect(scene.where((s) => s.sheet == 'coin_spin'), hasLength(PalayokGame.coins * 2));
      g.update(4, null);
      expect(g.won, isFalse, reason: 'the coins are still falling');
      g.update(5, null);
      expect(g.won, isTrue);
      g.restart(6, null);
      expect((g.hits, g.won), (0, false));
    });

    test('the swing keeps going without a jump when it speeds up', () {
      final s = Swing(2.4, 0);
      final before = s.sinAt(1.3);
      s.retime(1.3, 1.6);
      expect(s.sinAt(1.3), closeTo(before, 1e-9));
    });
  });

  group('Sipa Rally', () {
    const cam = V3(0, 1.4, 2.5);

    /// First time after [from] when the sipa is falling through the kick zone.
    double kickTime(SipaGame g, double from) {
      for (var t = from; t < from + 5; t += 1 / 120) {
        final p = g.at(t);
        if (g.falling(t) && p.y <= 1.6 && p.y >= SipaGame.kickLow) return t;
      }
      fail('never falls into the kick zone');
    }

    test('tap starts it; a kick in the zone and in the circle keeps it up', () {
      final g = SipaGame(random: math.Random(3))..place(0, null);
      g.press(1, look(cam, const V3(0, 0.3, 0)));
      expect((g.flying, g.hits), (true, 0));
      g.press(1.4, look(cam, g.at(1.4)));
      expect((g.hits, g.takeCallout()), (0, 'MAAGA PA!'), reason: 'still rising');
      final t = kickTime(g, 1.5);
      expect(g.reticle(t, look(cam, g.at(t))), isTrue);
      g.press(t, lookOff(cam, g.at(t), 30));
      expect(g.hits, 0, reason: 'circle not on it');
      final t2 = t + SipaGame.tapCooldownS;
      expect(g.kickable(t2, look(cam, g.at(t2))), isTrue);
      g.press(t2, look(cam, g.at(t2)));
      expect((g.hits, g.takeCallout()), (1, 'SIPA! x1'));
    });

    test('a drop ends the rally; five in a row win', () {
      final g = SipaGame(random: math.Random(4))..place(0, null);
      var now = 1.0;
      g.press(now, null);
      g.press(now, look(cam, g.at(now)));
      g.update(now + 10, null);
      expect(g.flying, isFalse);
      now += 10;
      for (var i = 1; i <= 5; i++) {
        g.press(now, look(cam, g.at(now)));
        now = kickTime(g, now + 0.1);
      }
      expect(g.hits, 4);
      g.press(now, look(cam, g.at(now)));
      expect(g.hits, 5);
      expect(g.best, 5);
      g.update(now + 1, null);
      expect(g.won, isTrue);
    });

    test('a drop after kicks resets the rally', () {
      final g = SipaGame(random: math.Random(5))..place(0, null);
      g.press(0, look(cam, g.at(0)));
      final t = kickTime(g, 0.1);
      g.press(t, look(cam, g.at(t)));
      expect(g.hits, 1);
      g.update(t + 10, null);
      expect((g.hits, g.best, g.takeCallout()), (0, 1, 'NAHULOG!'));
    });
  });
}
