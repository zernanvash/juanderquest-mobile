import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_minigame.dart';
import 'package:juanderquest_app/features/ar_experience/games/tumbang_preso.dart';

// Plan 77, owner 2026-11-06: "lets try do the throwing game first"; 2026-11-07:
// "more challenging ... without it being too hard" and "spawn point is where the
// player should be against the target".
void main() {
  // On the line, 5 m from the can (can at the origin), phone 1.4 m up, looking at it.
  const cam = V3(0, 1.4, 5);
  const atCan = V3(0, -0.27, -1);
  const pose = GamePose(cam, atCan);

  double sweetMid({double margin = TumbangPresoGame.hitMargin}) {
    final z = TumbangPresoGame.sweetSpot(cam, margin: margin)!;
    return (z.from + z.to) / 2;
  }

  TumbangGame newGame() => TumbangGame()
    ..stand = const V3(0, 0, 5)
    ..place(0, pose);

  /// Holds the button from [now] until the power reaches [power], then lets go.
  void throwAt(TumbangGame g, double now, double power, {GamePose at = pose}) {
    g.press(now, at);
    g.release(now + power * g.chargeCycle / 2, at);
  }

  group('throw', () {
    test('a power in the sweet spot hits; too little falls short, too much flies over', () {
      expect(TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: sweetMid()).hit, isTrue);
      final short = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: 0);
      expect(short.hit, isFalse);
      expect(short.land.z, greaterThan(0.5));
      final long = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: 1);
      expect(long.hit, isFalse);
      expect(long.land.z, lessThan(-2));
    });

    test('the sweet spot is fair but narrows when the margin shrinks', () {
      final wide = TumbangPresoGame.sweetSpot(cam)!;
      final narrow = TumbangPresoGame.sweetSpot(cam, margin: 0.06)!;
      expect(wide.to - wide.from, inInclusiveRange(0.03, 0.2));
      expect(narrow.to - narrow.from, lessThan(wide.to - wide.from));
    });

    test('aim help snaps within 4.5 degrees; 8 degrees off misses', () {
      GamePose turned(double deg) {
        final a = deg * math.pi / 180;
        return GamePose(cam, V3(math.sin(a), -0.27, -math.cos(a)));
      }

      expect(TumbangPresoGame.throwFrom(camera: cam, forward: turned(2).forward, power: sweetMid()).hit, isTrue);
      expect(TumbangPresoGame.throwFrom(camera: cam, forward: turned(8).forward, power: sweetMid()).hit, isFalse);
    });

    test('the arc starts at the hand and lands on the floor at the end of the flight', () {
      final s = TumbangPresoGame.throwFrom(camera: cam, forward: atCan, power: 0.5);
      expect(s.at(0).y, closeTo(1.15, 0.01));
      expect(s.at(s.flightS).y, closeTo(0, 1e-6));
    });
  });

  group('game', () {
    test('a throw only counts from the chalk line', () {
      final g = newGame();
      g.press(1, const GamePose(V3(2, 1.4, 5), atCan));
      expect(g.takeCallout(), 'BALIK SA LINYA!');
      g.release(1.5, const GamePose(V3(2, 1.4, 5), atCan));
      expect((g.current, g.left), (null, TumbangGame.slippers));
    });

    test('a streak speeds the meter up and narrows the green; a miss resets it', () {
      final g = newGame();
      var now = 1.0;
      for (var i = 1; i <= 2; i++) {
        throwAt(g, now, sweetMid(margin: g.margin));
        expect(g.current!.knocks, isTrue, reason: 'knock $i');
        g.update(now + 5, pose);
        g.update(now + 10, pose);
        now += 20;
      }
      expect((g.hits, g.streak, g.score), (2, 2, 10 + 15));
      expect(g.chargeCycle, lessThan(TumbangPresoGame.chargeCycleS));
      expect(g.margin, lessThan(TumbangPresoGame.hitMargin));
      throwAt(g, now, 0);
      g.update(now + 5, pose);
      expect(g.takeCallout(), 'MINTIS!');
      expect(g.streak, 0);
      expect(g.margin, TumbangPresoGame.hitMargin);
    });

    test('from the 3rd knock-down the taya guards in front of the can and blocks some throws', () {
      final g = newGame()..hits = TumbangGame.tayaAfter;
      expect(g.tayaOn, isTrue);
      expect(g.takeScene()!.map((s) => s.sheet), isNot(contains('taya_guard')));
      g.place(0, pose);
      expect(g.takeScene()!.map((s) => s.sheet), contains('taya_guard'));
      var blocked = 0, clear = 0;
      for (var t = 0.0; t < 20; t += 0.05) {
        final th = g.throwAt(t, pose, sweetMid());
        if (th.blockS != null) {
          blocked++;
        } else if (th.knocks) {
          clear++;
        }
      }
      expect(blocked, greaterThan(0));
      expect(clear, greaterThan(0), reason: 'timing it right gets past the taya');
    });

    test('the taya roams at random: sideways and nearer/further, always between you and the can', () {
      final g = newGame()..hits = TumbangGame.tayaAfter;
      final spots = [for (var t = 0.0; t < 30; t += 0.25) g.taya(t)];
      final xs = spots.map((p) => p.x), zs = spots.map((p) => p.z);
      expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(1.2));
      expect(zs.reduce(math.max) - zs.reduce(math.min), greaterThan(0.5));
      expect(spots.every((p) => p.z > 0.6 && p.z < 2.0 && p.x.abs() <= 1.1 + 1e-9), isTrue);
      // Not a fixed back-and-forth: the moves differ in length.
      final legs = g.path.legs.where((l) => (l.b - l.a).horizontalLength > 0).map((l) => (l.b - l.a).horizontalLength);
      expect(legs.toSet().length, greaterThan(3));
    });

    test('a tsinelas that hits the taya gets smacked back towards you', () {
      final g = newGame()..hits = TumbangGame.tayaAfter;
      g.place(0, pose);
      g.takeScene();
      // Find a moment when the taya is in the way, then throw then.
      var t0 = 0.0;
      while (g.throwAt(t0, pose, sweetMid(margin: g.margin)).blockS == null) {
        t0 += 0.05;
        expect(t0, lessThan(30));
      }
      throwAt(g, t0 - sweetMid(margin: g.margin) * g.chargeCycle / 2, sweetMid(margin: g.margin));
      final th = g.current!;
      expect(th.blockS, isNotNull);
      final scene = g.takeScene()!;
      final smack = scene.where((s) => s.sheet == 'taya_smack').single;
      expect(smack.delay, closeTo(th.blockS! - TumbangGame.smackLeadS, 0.02));
      final back = scene.where((s) => s.sheet == 'tsinelas_spin' && s.delay == th.blockS).single;
      expect(back.vz, greaterThan(3), reason: 'flies back towards the player (at +z)');
      g.update(t0 + 5, pose);
      expect((g.takeCallout(), g.streak), ('PALO! HARANG!', 0));
    });

    test('the sight: green within 5 degrees, amber with HARANG! WAIT when the taya is in the lane', () {
      final g = newGame();
      GamePose turned(double deg) {
        final a = deg * math.pi / 180;
        return GamePose(cam, V3(math.sin(a), -0.27, -math.cos(a)));
      }

      expect(g.tone(1, turned(4)), ArTone.on);
      expect(g.tone(1, turned(8)), ArTone.idle);
      expect(TumbangPresoGame.throwFrom(camera: cam, forward: turned(4).forward, power: sweetMid()).hit, isTrue,
          reason: 'green sight + green power = a hit');
      g.hits = TumbangGame.tayaAfter;
      var blockedAt = -1.0, clearAt = -1.0;
      for (var t = 0.0; t < 30 && (blockedAt < 0 || clearAt < 0); t += 0.05) {
        if (g.laneBlocked(t)) {
          blockedAt = t;
        } else {
          clearAt = t;
        }
      }
      expect(blockedAt, greaterThanOrEqualTo(0));
      expect((g.tone(blockedAt, pose), g.toneBadge(blockedAt, pose)), (ArTone.blocked, 'HARANG! WAIT'));
      expect(g.toneBadge(clearAt, pose), isNull);
    });

    test('the tsinelas is held at the bottom right, pulled back as you charge, gone while it flies', () {
      final g = newGame();
      expect(g.prop(1)!.dy, 0);
      g.press(1, pose);
      expect(g.prop(1.4)!.dy, greaterThan(5));
      g.release(1.4, pose);
      expect(g.prop(1.5), isNull);
    });

    test('the taya route keeps being drawn while you wait', () {
      final g = newGame()..hits = TumbangGame.tayaAfter;
      g.place(0, pose);
      g.takeScene();
      g.update(5, pose);
      expect(g.takeScene(), isNull);
      g.update(25, pose);
      expect(g.takeScene()!.map((s) => s.sheet), contains('taya_guard'));
    });

    test('10 slippers, then the session is over; 4 knock-downs pass', () {
      final g = newGame();
      var now = 1.0;
      for (var i = 0; i < TumbangGame.slippers; i++) {
        throwAt(g, now, 0);
        g.update(now + 5, pose);
        g.update(now + 10, pose);
        now += 20;
      }
      expect((g.over, g.passed, g.left), (true, false, 0));
      expect(g.canPress(now), isFalse);
      g.restart(now, pose);
      expect((g.over, g.hits, g.left), (false, 0, TumbangGame.slippers));
    });

    test('a knock hides the standing can at the hit and knocks it over', () {
      final g = newGame();
      throwAt(g, 1, sweetMid());
      final scene = g.takeScene()!;
      final hitS = g.current!.shot.hitS!;
      expect(scene.firstWhere((e) => e.sheet == 'lata_stand').life, hitS);
      expect(scene.firstWhere((e) => e.sheet == 'lata_tumble').delay, hitS);
      expect(scene.map((e) => e.sheet), contains('chalk_line'));
    });
  });
}
