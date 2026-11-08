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
GamePose look(V3 camera, V3 target) => GamePose(camera, (target - camera).unit);

/// Pose at [camera] turned [deg] degrees right of [target].
GamePose lookOff(V3 camera, V3 target, double deg) {
  final f = (target - camera).unit;
  final a = deg * math.pi / 180;
  return GamePose(camera, V3(f.x * math.cos(a) - f.z * math.sin(a), f.y, f.x * math.sin(a) + f.z * math.cos(a)));
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
      expect(g.spot.x.abs(), greaterThan(0.6), reason: 'somewhere else');
    });

    test('a quest task collects its one item', () {
      final g = CollectGame(onlyItem: 'beacon', random: math.Random(2))
        ..stand = const V3(0, 0, 2.5)
        ..place(0, null);
      expect(g.takeScene()!.map((s) => s.sheet), contains('item_beacon'));
      expect(g.targetHits, 1);
      g.press(1, look(cam, g.at(1)));
      expect((g.hits, g.over, g.passed), (1, true, true));
    });

    test('indoors (short range) the next items stay close', () {
      final g = CollectGame(rangeScale: 0.5, random: math.Random(3))
        ..stand = const V3(0, 0, 1.25)
        ..place(0, null);
      var now = 1.0;
      for (var i = 0; i < 5; i++) {
        g.press(now, look(const V3(0, 1.4, 1.25), g.at(now)));
        now += 2;
        g.update(now, null);
        expect(g.spot.x.abs(), lessThanOrEqualTo(0.91), reason: 'item ${i + 2}');
      }
    });

    test('collecting all six ends it; the line rule does not apply', () {
      final g = newGame();
      expect(g.onLine(const GamePose(V3(0, 1.4, 0.5), V3(0, 0, -1))), isTrue);
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
      GamePose at(double x, double z) => GamePose(V3(x, 1.4, z), const V3(0, 0, -1));
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

    test('a moving ring: swiping as it crosses the line scores; swiping when it is off the line misses', () {
      // Crosses the middle now and slides on 0.8 m during the flight: still in.
      final crossing = RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, hoopAt: (t) => V3(0.8 * t, 0, 0));
      expect(crossing.make, isTrue);
      expect(crossing.rim.x, greaterThan(0.5), reason: 'the ball follows the ring in');
      // Off to the side now (and sliding away): the ball goes where you point.
      final off = RingShootGame.shootFrom(camera: cam, forward: atHoop.forward, hoopAt: (t) => V3(0.8 + 0.8 * t, 0, 0));
      expect(off.make, isFalse);
    });

    test('the centre lane lights up when lined up; the ball is held until thrown', () {
      final g = newGame();
      expect(g.tone(1, atHoop), ArTone.on);
      expect(g.tone(1, lookOff(cam, const V3(0, 2, 0), 15)), ArTone.idle);
      expect(g.prop(1)!.sheet, 'ball_spin');
      g.swipe(1, atHoop, 0);
      expect(g.prop(1.1), isNull);
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
    const cam = V3(0, 1.4, 2.2);
    PalayokGame newGame() => PalayokGame(random: math.Random(1))
      ..stand = const V3(0, 0, 2.2)
      ..place(0, null);

    /// Pose at the line aimed at the swinging pot at [now].
    GamePose aimAt(PalayokGame g, double now) {
      var pose = look(cam, const V3(0, PalayokGame.pivotHeight - PalayokGame.ropeLength, 0));
      for (var i = 0; i < 3; i++) {
        pose = look(cam, g.pot(now, pose));
      }
      return pose;
    }

    test('the pot hangs at chest height, 2.2 m out', () {
      expect(PalayokGame.pivotHeight - PalayokGame.ropeLength, closeTo(1.38, 0.02));
      expect(newGame().standDistance, 2.2);
    });

    test('one tap, one swing: off the line or off the pot does not count', () {
      final g = newGame();
      g.press(0.1, look(const V3(0, 1.4, 1.5), const V3(0, 1.4, 0)));
      expect((g.hits, g.takeCallout()), (0, 'BALIK SA LINYA!'));
      g.press(1, lookOff(cam, g.pot(1, aimAt(g, 1)), 30));
      expect((g.hits, g.takeCallout()), (0, 'MINTIS!'));
      g.press(1.1, aimAt(g, 1.1));
      expect(g.hits, 0, reason: 'still cooling down after a swing');
      g.press(2, aimAt(g, 2));
      expect((g.hits, g.takeCallout(), g.swings), (1, 'PUKPOK!', 2));
    });

    test('piring after the first hit: a see-through vignette, still one tap per swing, circle still works', () {
      final g = newGame();
      expect(g.blind(0.5), isFalse);
      g.press(1, aimAt(g, 1));
      expect((g.hits, g.blind(1.5), g.buttonLabel(1.5)), (1, true, 'HAMPAS!'));
      expect(g.reticle(2, aimAt(g, 2)), isTrue, reason: 'the circle still turns green');
      g.press(2, aimAt(g, 2));
      expect(g.hits, 2, reason: 'no separate blindfold tap');
      g.press(3, aimAt(g, 3));
      expect(g.hits, 3);
    });

    test('the stick swings on the HUD after each strike', () {
      final g = newGame();
      final rest = g.prop(0.5)!;
      g.press(1, aimAt(g, 1));
      final mid = g.prop(1 + PalayokGame.swingS / 2)!;
      expect(mid.sheet, 'pamalo');
      expect(mid.turn, lessThan(rest.turn - 0.8), reason: 'swung across');
      expect(g.prop(1 + PalayokGame.swingS + 0.05)!.turn, rest.turn);
    });

    test('three hits break it, coins fall, the game is won', () {
      final g = newGame();
      for (final t in [1.0, 2.0, 3.0]) {
        g.press(t, aimAt(g, t));
      }
      expect(g.hits, 3);
      expect(g.takeCallout(), 'BASAG!');
      final scene = g.takeScene()!;
      expect(scene.map((s) => s.sheet), contains('palayok_break'));
      expect(scene.where((s) => s.sheet == 'coin_spin'), hasLength(PalayokGame.coins * 2));
      g.update(4, null);
      expect(g.over, isFalse, reason: 'the coins are still falling');
      g.update(5, null);
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
        if (g.falling(t) && p.y <= SipaGame.kickHigh && p.y >= SipaGame.kickLow) return t;
      }
      fail('never falls into the kick zone');
    }

    /// Highest point of the current flight after [from].
    double apex(SipaGame g, double from) {
      var top = 0.0;
      for (var t = from; t < from + 3; t += 1 / 120) {
        top = math.max(top, g.at(t).y);
      }
      return top;
    }

    test('green on the resting sipa; tap starts it; gold while it rises, green when you can kick', () {
      final g = newGame(3);
      expect(g.tone(0.5, look(cam, g.at(0.5))), ArTone.on);
      g.press(1, look(cam, const V3(0, 0.3, 0)));
      expect((g.flying, g.hits), (true, 0));
      expect(g.tone(1.2, look(cam, g.at(1.2))), ArTone.wait);
      final t = kickTime(g, 1.3);
      expect(g.tone(t, look(cam, g.at(t))), ArTone.on);
    });

    test('an early tap costs nothing: the real kick right after still counts', () {
      final g = newGame(3);
      g.press(1, look(cam, g.at(1)));
      g.press(1.4, look(cam, g.at(1.4)));
      expect((g.hits, g.takeCallout()), (0, 'MAAGA PA!'));
      final t = kickTime(g, 1.4);
      g.press(t, look(cam, g.at(t)));
      expect((g.hits, g.takeCallout()), (1, 'SIPA! x1'));
    });

    test('every kick peaks at the same height (no climbing off the screen)', () {
      final g = newGame(4);
      var now = 1.0;
      g.press(now, look(cam, g.at(now)));
      for (var i = 0; i < 4; i++) {
        expect(apex(g, now), lessThanOrEqualTo(1.9), reason: 'kick ${i + 1}');
        // Kick high in the zone, the worst case for a climbing apex.
        now = kickTime(g, now + 0.1);
        g.press(now, look(cam, g.at(now)));
      }
      expect(apex(g, now), lessThanOrEqualTo(1.9));
    });

    test('off the line does not kick', () {
      final g = newGame(3);
      g.press(1, look(const V3(0, 1.4, 1), const V3(0, 0.3, 0)));
      expect((g.flying, g.takeCallout()), (false, 'BALIK SA LINYA!'));
    });

    test('a drop costs one kick and a life; five passes; the third drop ends it (Plan 77)', () {
      final g = newGame(5);
      var now = 1.0;
      g.press(now, look(cam, g.at(now)));
      for (var i = 0; i < 2; i++) {
        now = kickTime(g, now + 0.1);
        g.press(now, look(cam, g.at(now)));
      }
      expect(g.hits, 2);
      g.update(now + 10, null);
      expect((g.hits, g.best, g.drops, g.takeCallout()), (1, 2, 1, 'NAHULOG! 2 LEFT'));
      now += 10;
      g.press(now, look(cam, g.at(now)));
      for (var i = 0; i < 4; i++) {
        now = kickTime(g, now + 0.1);
        g.press(now, look(cam, g.at(now)));
      }
      expect((g.hits, g.passed, g.over), (5, true, false));
      // Playing on after passing: the best rally keeps counting for the board.
      now = kickTime(g, now + 0.1);
      g.press(now, look(cam, g.at(now)));
      expect(g.best, 6);
      g.update(now + 10, null);
      now += 10;
      g.press(now, look(cam, g.at(now)));
      g.update(now + 10, null);
      expect((g.drops, g.over, g.passed, g.takeCallout()), (3, true, true, 'TAPOS!'));
      expect(g.canPress(now + 11), isFalse);
      g.restart(now + 12, null);
      expect((g.drops, g.best, g.over), (0, 0, false));
    });
  });
}
