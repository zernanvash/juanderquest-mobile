import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_minigame.dart';
import 'package:juanderquest_app/features/ar_experience/games/collect.dart';
import 'package:juanderquest_app/features/ar_experience/games/palayok.dart';
import 'package:juanderquest_app/features/ar_experience/games/pana.dart';
import 'package:juanderquest_app/features/ar_experience/games/ring_shoot.dart';
import 'package:juanderquest_app/features/ar_experience/games/sipa.dart';
import 'package:juanderquest_app/features/ar_experience/games/tumbang_preso.dart';

// Plan 77, owner 2026-11-06: "build the mini games altogether"; 2026-11-07: the
// player stands on a chalk line a fixed distance from the target, and the games
// get harder as you go (wind, moving hoop, piring). Pure game logic.

/// Pose at [camera] looking at [target].
ArPose look(V3 camera, V3 target) => ArPose(camera, (target - camera).unit);

/// Pose at [camera] turned [deg] degrees right of [target].
ArPose lookOff(V3 camera, V3 target, double deg) {
  final f = (target - camera).unit;
  final a = deg * math.pi / 180;
  return ArPose(camera, V3(f.x * math.cos(a) - f.z * math.sin(a), f.y, f.x * math.sin(a) + f.z * math.cos(a)));
}

void main() {
  group('Collect (pixel items)', () {
    const cam = V3(0, 1.4, 2.5);
    CollectGame newGame() => CollectGame(random: math.Random(2))
      ..stand = const V3(0, 0, 2.5)
      ..place(0, null);

    test('aim at the floating item and collect; the next one appears elsewhere', () {
      final g = newGame();
      expect(g.takeScene()!.map((s) => s.sheet), contains('item_token'));
      g.press(1, lookOff(cam, g.at(1), 25));
      expect((g.hits, g.takeCallout()), (0, 'AIM AT IT'));
      g.press(1.2, look(cam, g.at(1.2)));
      expect((g.hits, g.takeCallout()), (1, 'QUEST TOKEN!'));
      expect(g.canPress(1.5), isFalse, reason: 'waiting for the next item');
      g.update(2.5, null);
      expect(g.takeScene()!.map((s) => s.sheet), contains('item_gem'));
      expect(g.spot.x.abs(), greaterThan(0.8), reason: 'somewhere else');
    });

    test('collecting all six ends it; the line rule does not apply', () {
      final g = newGame();
      expect(g.onLine(const ArPose(V3(0, 1.4, 0.5), V3(0, 0, -1))), isTrue);
      var now = 1.0;
      for (var i = 0; i < CollectGame.items.length; i++) {
        g.press(now, look(cam, g.at(now)));
        now += 2;
        g.update(now, null);
      }
      expect((g.hits, g.over, g.passed), (6, true, true));
    });
  });

  test('every game: stepping towards the target leaves the line; sideways or back is fine', () {
    final games = <ArMiniGame>[
      TumbangGame(),
      RingShootGame(),
      PanaGame(),
      PalayokGame(random: math.Random(1)),
      SipaGame(random: math.Random(1)),
    ];
    for (final g in games) {
      final d = g.standDistance;
      g.stand = V3(0, 0, d);
      ArPose at(double x, double z) => ArPose(V3(x, 1.4, z), const V3(0, 0, -1));
      expect(g.onLine(at(0, d)), isTrue, reason: g.title);
      expect(g.onLine(at(0, d - 0.5)), isFalse, reason: '${g.title}: 0.5 m closer');
      expect(g.onLine(at(0.5, d)), isTrue, reason: '${g.title}: sideways');
      expect(g.onLine(at(0, d + 0.5)), isTrue, reason: '${g.title}: back');
    }
  });

  group('Ring Shoot', () {
    const cam = V3(0, 1.4, 4.2);
    final atHoop = look(cam, const V3(0, 2, 0));
    RingShootGame newGame() => RingShootGame()
      ..stand = const V3(0, 0, 4.2)
      ..place(0, atHoop);

    test('the ball goes where the phone points; a forgiving lane, no power to judge', () {
      expect(RingShootGame.shootFrom(camera: cam, forward: atHoop.forward).make, isTrue);
      expect(RingShootGame.shootFrom(camera: cam, forward: lookOff(cam, const V3(0, 2, 0), 6).forward).make, isTrue,
          reason: 'about 6.5 degrees either side still drops in');
      final wide = RingShootGame.shootFrom(camera: cam, forward: lookOff(cam, const V3(0, 2, 0), 12).forward);
      expect(wide.make, isFalse, reason: 'pointing well off the ring misses: aiming is the challenge');
      expect(wide.offset, greaterThan(0.6));
      expect(RingShootGame.shootFrom(camera: cam, forward: lookOff(cam, const V3(0, 2, 0), -12).forward).make, isFalse);
    });

    test('the ball comes down through rim height at the cross time', () {
      final s = RingShootGame.shootFrom(camera: cam, forward: atHoop.forward);
      expect(s.at(s.crossS).y, closeTo(RingShootGame.rimHeight, 1e-6));
      expect(s.at(s.endS).y, closeTo(RingShootGame.ballRadius, 1e-6));
    });

    test('baskets score 2 (swish 3); after 3 the ring slides, faster after 6', () {
      final g = newGame();
      var now = 1.0;
      expect(g.slidePeriod, isNull);
      for (var i = 1; i <= 3; i++) {
        g.swipe(now, atHoop, 0);
        expect(g.shot!.make, isTrue);
        g.update(now + 5, atHoop);
        g.update(now + 10, atHoop);
        now += 20;
      }
      expect(g.hits, 3);
      expect(g.score, inInclusiveRange(6, 9));
      expect(g.slidePeriod, 4.0);
      expect(g.hoop(now - 20 + 5).x.abs(), lessThan(0.05), reason: 'starts sliding from the middle');
      final xs = [for (var t = 0.0; t < 4; t += 0.5) g.hoop(now + t).x];
      expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(1.0), reason: 'the hoop slides side to side');
      g.hits = 6;
      expect(g.slidePeriod, 2.5);
    });

    test('a moving ring must be timed: the same swipe misses when the ring has moved away', () {
      final s1 = RingShootGame.shootFrom(camera: cam, forward: atHoop.forward);
      final s2 = RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, hoopAt: (t) => V3(0.8 * t, 0, 0));
      expect((s1.make, s2.make), (true, false));
    });

    test('10 balls, then it is over; off the line does not shoot', () {
      final g = newGame();
      g.swipe(0.5, look(const V3(0, 1.4, 3.6), const V3(0, 2, 0)), 0);
      expect((g.shot, g.takeCallout()), (null, 'BALIK SA LINYA!'));
      var now = 1.0;
      final wide = lookOff(cam, const V3(0, 2, 0), 40);
      for (var i = 0; i < RingShootGame.balls; i++) {
        g.swipe(now, wide, 0);
        g.update(now + 5, wide);
        g.update(now + 10, wide);
        now += 20;
      }
      expect((g.over, g.passed, g.left), (true, false, 0));
    });

    test('a make swishes the net and drops the ball in front of the hoop', () {
      final g = newGame();
      g.swipe(1, atHoop, 0);
      final s = g.shot!;
      final scene = g.takeScene()!;
      expect(scene.firstWhere((e) => e.sheet == 'hoop').life, s.crossS);
      expect(scene.firstWhere((e) => e.sheet == 'hoop_swish').delay, s.crossS);
      final drop = scene.where((e) => e.sheet == 'ball_spin' && e.delay == s.crossS).single;
      expect(drop.z, greaterThan(0), reason: 'towards the player (who stands at +z)');
    });
  });

  group('Pana', () {
    const cam = V3(0, 1.4, 5.5);
    const centre = V3(0, PanaGame.targetHeight, 0);
    PanaGame newGame({int seed = 1}) => PanaGame(random: math.Random(seed))
      ..stand = const V3(0, 0, 5.5)
      ..place(0, look(cam, centre));

    test('pulling the string sets the draw; a full draw at the bullseye scores 10', () {
      final g = newGame();
      final pose = look(cam, centre);
      g.press(1, pose);
      g.pull(1.2, 0.5);
      expect(g.draw(1.2), 0.5);
      g.pull(1.3, 1.4);
      expect(g.draw(1.3), 1.0);
      g.release(1.4, pose);
      expect(g.shot!.points, 10);
      expect(g.draw(1.5), 0);
    });

    test('a tap or a short pull relaxes the bow and keeps the arrow', () {
      final g = newGame();
      final pose = look(cam, centre);
      g.press(1, pose);
      g.pull(1.1, 0.2);
      g.release(1.2, pose);
      expect((g.shot, g.hits, g.takeCallout()), (null, 0, 'PULL FURTHER DOWN!'));
      // Pulling down and back up again also cancels.
      g.press(2, pose);
      g.pull(2.1, 0.8);
      g.pull(2.2, 0.1);
      g.release(2.3, pose);
      expect((g.shot, g.hits), (null, 0));
    });

    test('the arrow leaves the bow hand (low right) and flies to where the sight looks', () {
      final g = newGame();
      final s = g.shoot(0, look(cam, centre), 1);
      expect(s.start.x, greaterThan(cam.x + 0.1), reason: 'right of the eye');
      expect(s.start.y, lessThan(cam.y - 0.1), reason: 'below the eye');
      expect(s.velocity.x, lessThan(0), reason: 'converges towards the middle');
    });

    test('rings score 10/8/6/4 and the woven edge 2', () {
      expect([
        for (final d in [0.05, 0.15, 0.25, 0.35, 0.5, 0.7]) PanaGame.pointsAt(d)
      ], [
        10,
        8,
        6,
        4,
        2,
        0
      ]);
    });

    test('a weak draw drops; the sight pin shows how far, so aiming by it wins it back', () {
      final g = newGame();
      expect(g.shoot(0, look(cam, centre), 0.3).points, lessThan(10));
      final full = g.pin(1), weak = g.pin(0.3);
      expect(weak.down, greaterThan(full.down * 3));
      final s = g.shoot(0, look(cam, centre + V3(0, weak.down, 0)), 0.3);
      expect(s.points, greaterThanOrEqualTo(8));
    });

    test('wind pushes the arrow sideways; aiming by the pin wins the points back', () {
      final g = newGame()..wind = 2;
      final plain = g.shoot(0, look(cam, centre), 1);
      expect(plain.points, lessThan(10));
      final p = g.pin(1);
      expect(p.right, greaterThan(0.15), reason: 'about one ring per windsock step');
      final into = g.shoot(0, look(cam, centre + V3(-p.right, p.down, 0)), 1);
      expect(into.points, 10);
    });

    test('6 arrows: 1-2 still, 3-4 sway (bangus may swim), 5-6 sway more in wind; then it is over', () {
      final g = newGame(seed: 7);
      var now = 1.0;
      final winds = <int>[], sways = <double>[];
      for (var i = 0; i < PanaGame.arrows; i++) {
        winds.add(g.wind);
        sways.add(g.sway);
        if (i < 2 || i >= 4) expect(g.bangusOut, isFalse, reason: 'arrow ${i + 1}');
        final pose = look(cam, centre);
        g.press(now, pose);
        g.pull(now + 0.5, 1);
        g.release(now + 1, pose);
        g.update(now + 5, pose);
        g.update(now + 10, pose);
        now += 20;
      }
      expect(sways, [0, 0, 0.45, 0.45, 0.70, 0.70]);
      expect(winds.take(4), everyElement(0));
      expect(winds.skip(4), everyElement(isNot(0)));
      expect(winds.every((w) => w.abs() <= 2), isTrue);
      expect(g.over, isTrue);
      expect(g.passed, g.score >= PanaGame.passScore);
    });

    test('the golden bangus is worth 15', () {
      final g = newGame()..hits = 2;
      g.bangusOut = true;
      // The fish swims fast: lead it by the arrow's flight time.
      final lead = (g.fish(0) - cam).length / PanaGame.maxSpeed;
      final s = g.shoot(0, look(cam, g.fish(lead) + const V3(0, 0.03, 0)), 1);
      expect((s.bangus, s.points), (true, PanaGame.bangusPoints));
    });

    test('the bilao sways across the player\'s view', () {
      final g = newGame()..hits = 2;
      final a = g.centre(PanaGame.swayPeriod / 4), b = g.centre(3 * PanaGame.swayPeriod / 4);
      expect((a - b).x.abs(), closeTo(0.9, 1e-9));
      expect((a - b).z.abs(), lessThan(1e-9));
    });

    test('the sight: draw, nocked arrow, landing pin', () {
      final g = newGame();
      final pose = look(cam, centre);
      expect(g.sight(1, pose)!.draw, 0);
      g.press(1, pose);
      g.pull(1.1, 0.95);
      final s = g.sight(1.1, pose)!;
      expect((s.draw, s.loaded, s.onTarget), (0.95, true, true));
      expect(s.pinDownDeg, greaterThan(0));
      g.release(1.2, pose);
      expect(g.sight(1.25, pose)!.loaded, isFalse, reason: 'empty bow while the arrow flies');
    });
  });

  group('Pukpok Palayok', () {
    const cam = V3(0, 1.4, 1.5);
    PalayokGame newGame() => PalayokGame(random: math.Random(1))
      ..stand = const V3(0, 0, 1.5)
      ..place(0, null);

    /// Pose at the line aimed at the swinging pot at [now].
    ArPose aimAt(PalayokGame g, double now) {
      var pose = look(cam, const V3(0, PalayokGame.pivotHeight - PalayokGame.ropeLength, 0));
      for (var i = 0; i < 3; i++) {
        pose = look(cam, g.pot(now, pose));
      }
      return pose;
    }

    test('first strike by sight; off the line or off the pot does not count', () {
      final g = newGame();
      g.press(0.1, look(const V3(2, 1.4, 1.5), const V3(0, 1.7, 0)));
      expect((g.hits, g.takeCallout()), (0, 'BALIK SA LINYA!'));
      g.press(1, lookOff(cam, g.pot(1, aimAt(g, 1)), 30));
      expect((g.hits, g.takeCallout()), (0, 'MINTIS!'));
      g.press(2, aimAt(g, 2));
      expect((g.hits, g.takeCallout(), g.swings), (1, 'PUKPOK!', 2));
    });

    test('after the first hit you play blindfolded (piring)', () {
      final g = newGame();
      g.press(1, aimAt(g, 1));
      expect(g.piring, isTrue);
      expect(g.buttonLabel(2), contains('PIRING'));
      g.press(2, aimAt(g, 2));
      expect((g.blind(2.1), g.takeCallout(), g.hits), (true, 'PIRING!', 1));
      expect(g.reticle(2.1, aimAt(g, 2.1)), isNull, reason: 'no aim circle while blind');
      g.press(3, aimAt(g, 3));
      expect((g.hits, g.blind(3.01)), (2, false));
      // Waiting too long blind takes the blindfold off without a swing.
      g.press(4, aimAt(g, 4));
      g.update(4 + PalayokGame.blindS + 0.1, null);
      expect((g.blind(7), g.takeCallout(), g.hits), (false, 'MINTIS!', 2));
    });

    test('three hits break it, coins fall, the game is won', () {
      final g = newGame();
      g.press(1, aimAt(g, 1));
      for (final t in [2.0, 4.0]) {
        g.press(t, aimAt(g, t));
        g.press(t + 1, aimAt(g, t + 1));
      }
      expect(g.hits, 3);
      expect(g.takeCallout(), 'BASAG!');
      final scene = g.takeScene()!;
      expect(scene.map((s) => s.sheet), contains('palayok_break'));
      expect(scene.where((s) => s.sheet == 'coin_spin'), hasLength(PalayokGame.coins * 2));
      g.update(5.5, null);
      expect(g.over, isFalse, reason: 'the coins are still falling');
      g.update(7, null);
      expect((g.over, g.passed), (true, true));
    });

    test('the swing keeps going without a jump when it speeds up', () {
      final s = Swing(2.4, 0);
      final before = s.sinAt(1.3);
      s.retime(1.3, 1.6);
      expect(s.sinAt(1.3), closeTo(before, 1e-9));
    });
  });

  group('Sipa Rally', () {
    const cam = V3(0, 1.4, 2.0);
    SipaGame newGame(int seed) => SipaGame(random: math.Random(seed))
      ..stand = const V3(0, 0, 2.0)
      ..place(0, null);

    /// First time after [from] when the sipa is falling through the kick zone.
    double kickTime(SipaGame g, double from) {
      for (var t = from; t < from + 5; t += 1 / 120) {
        final p = g.at(t);
        if (g.falling(t) && p.y <= 1.6 && p.y >= SipaGame.kickLow) return t;
      }
      fail('never falls into the kick zone');
    }

    test('tap starts it; a kick in the zone and in the circle keeps it up', () {
      final g = newGame(3);
      g.press(1, look(cam, const V3(0, 0.3, 0)));
      expect((g.flying, g.hits), (true, 0));
      g.press(1.4, look(cam, g.at(1.4)));
      expect((g.hits, g.takeCallout()), (0, 'MAAGA PA!'));
      final t = kickTime(g, 1.5);
      expect(g.reticle(t, look(cam, g.at(t))), isTrue);
      g.press(t, lookOff(cam, g.at(t), 30));
      expect(g.hits, 0, reason: 'circle not on it');
      final t2 = t + SipaGame.tapCooldownS;
      g.press(t2, look(cam, g.at(t2)));
      expect((g.hits, g.takeCallout()), (1, 'SIPA! x1'));
    });

    test('off the line does not kick', () {
      final g = newGame(3);
      g.press(1, look(const V3(2, 1.4, 2), const V3(0, 0.3, 0)));
      expect((g.flying, g.takeCallout()), (false, 'BALIK SA LINYA!'));
    });

    test('five in a row win; a drop resets the rally', () {
      final g = newGame(4);
      var now = 1.0;
      g.press(now, look(cam, g.at(now)));
      final t = kickTime(g, now + 0.1);
      g.press(t, look(cam, g.at(t)));
      g.update(t + 10, null);
      expect((g.hits, g.best, g.takeCallout()), (0, 1, 'NAHULOG!'));
      now = t + 10;
      for (var i = 1; i <= 5; i++) {
        g.press(now, look(cam, g.at(now)));
        now = kickTime(g, now + 0.1);
      }
      g.press(now, look(cam, g.at(now)));
      expect((g.hits, g.best), (5, 5));
      g.update(now + 1, null);
      expect((g.over, g.passed), (true, true));
    });
  });
}
