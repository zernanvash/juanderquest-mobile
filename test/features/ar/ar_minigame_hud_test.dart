import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_minigame.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_minigame_hud.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_sprites.dart';
import 'package:juanderquest_app/features/ar_experience/games/palayok.dart';
import 'package:juanderquest_app/features/ar_experience/games/pana.dart';
import 'package:juanderquest_app/features/ar_experience/games/ring_shoot.dart';
import 'package:juanderquest_app/features/ar_experience/games/sipa.dart';
import 'package:juanderquest_app/features/ar_experience/games/tumbang_preso.dart';

// Plan 77 mini-games: the shared HUD must not overflow on tiny screens with big
// text (AGENTS: 320x568 and 568x320 at 2.0x), and every sprite a game draws must
// be bundled.
void main() {
  const cam = V3(0.8, 1.4, 2.4);
  // Off the chalk line and turned far to the left: shows the line and turn hints.
  final pose = ArPose(cam, (const V3(-3, 1.5, 0) - cam).unit);

  final makers = <String, ArMiniGame Function()>{
    'tumbang': TumbangGame.new,
    'ring': RingShootGame.new,
    'pana': () => PanaGame(random: math.Random(1)),
    'palayok': () => PalayokGame(random: math.Random(1)),
    'sipa': () => SipaGame(random: math.Random(1)),
  };

  /// Ends the session as if it was played out.
  void finish(ArMiniGame g) {
    switch (g) {
      case TumbangGame g:
        g.over = true;
      case RingShootGame g:
        g.over = true;
      case PanaGame g:
        g.over = true;
      case PalayokGame g:
        g.won = true;
      case SipaGame g:
        g.won = true;
    }
  }

  Widget hud(ArMiniGame g, {String? callout, ArPose? at, double now = 1, VoidCallback? onPress}) => MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ArMiniGameHud(
            game: g,
            now: now,
            pose: at,
            callout: callout,
            onPlace: () {},
            onMove: () {},
            onRestart: () {},
            onPress: onPress ?? () {},
            onRelease: () {},
          ),
        ),
      );

  /// Placing, mid-play with a callout and hints, lost tracking, and finished.
  List<(ArMiniGame, String?, ArPose?)> states(ArMiniGame Function() make) {
    final placing = make();
    final playing = make()..place(0, pose);
    final done = make()..place(0, pose);
    finish(done);
    return [(placing, null, null), (playing, 'BULLSEYE! +10', pose), (playing, null, null), (done, null, pose)];
  }

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()} with 2.0x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final e in makers.entries) {
        for (final (g, callout, at) in states(e.value)) {
          await tester.pumpWidget(hud(g, callout: callout, at: at));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${e.key} placed=${g.placed} over=${g.over}');
        }
      }
    });
  }

  testWidgets('placing asks where you stand; playing shows the button, line hint and aim circle', (tester) async {
    final g = PalayokGame(random: math.Random(1))..stand = const V3(0, 0, 1.5);
    await tester.pumpWidget(hud(g));
    expect(find.text('STAND HERE'), findsOneWidget);
    g.place(0, pose);
    var pressed = false;
    await tester.pumpWidget(hud(g, at: pose, onPress: () => pressed = true));
    expect(find.byKey(const ValueKey('reticle_false')), findsOneWidget);
    expect(find.byKey(const ValueKey('line_hint')), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('game_button'))));
    await gesture.up();
    expect(pressed, isTrue);
    expect(find.byKey(const ValueKey('hit_pip_2')), findsOneWidget);
  });

  testWidgets('Ring Shoot: swipe up on the pad throws; a downward drag does not', (tester) async {
    final g = RingShootGame()..place(0, null);
    final swipes = <double>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home: Scaffold(
        body: ArMiniGameHud(
          game: g,
          now: 1,
          pose: pose,
          callout: null,
          onPlace: () {},
          onMove: () {},
          onRestart: () {},
          onPress: () {},
          onRelease: () {},
          onSwipe: swipes.add,
        ),
      ),
    ));
    final pad = find.byKey(const ValueKey('game_button'));
    await tester.drag(pad, const Offset(0, 120));
    expect(swipes, isEmpty);
    await tester.drag(pad, const Offset(30, -150));
    expect(swipes, hasLength(1));
    expect(swipes.single, closeTo(11.3, 0.5));
  });

  testWidgets('Pana: drag the bow down to pull, let go to shoot', (tester) async {
    final g = PanaGame(random: math.Random(1))..place(0, null);
    final events = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home: Scaffold(
        body: ArMiniGameHud(
          game: g,
          now: 1,
          pose: pose,
          callout: null,
          onPlace: () {},
          onMove: () {},
          onRestart: () {},
          onPress: () => events.add('press'),
          onRelease: () => events.add('release'),
          onPull: (v) => events.add('pull ${v.toStringAsFixed(1)}'),
        ),
      ),
    ));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('game_button'))));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
    }
    await gesture.up();
    expect(events.first, 'press');
    expect(events, contains('pull 1.0'));
    expect(events.last, 'release');
  });

  testWidgets('piring darkens the screen; the end panel says whether you passed', (tester) async {
    const onLine = V3(0, 1.4, 1.5);
    final g = PalayokGame(random: math.Random(1))
      ..stand = const V3(0, 0, 1.5)
      ..place(0, null)
      ..hits = 1;
    g.press(1, const ArPose(onLine, V3(0, 0, -1)));
    expect(g.blind(1.5), isTrue);
    await tester.pumpWidget(hud(g, at: const ArPose(onLine, V3(0, 0, -1)), now: 1.5));
    expect(find.byKey(const ValueKey('blindfold')), findsOneWidget);

    final t = TumbangGame()..over = true;
    await tester.pumpWidget(hud(t, at: pose));
    expect(find.text('TAPOS NA!'), findsOneWidget);
    t.hits = TumbangGame.passHits;
    await tester.pumpWidget(hud(t, at: pose));
    expect(find.text('PANALO!'), findsOneWidget);
  });

  test('every sprite the games draw is in the bundled manifest', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sheets = await ArSpriteSheet.loadManifest(rootBundle);
    final used = <String>{};
    void take(ArMiniGame g) => used.addAll([...?g.takeScene()].map((s) => s.sheet));

    // Tumbang: a knock, a miss, and a throw blocked by the taya.
    const tCam = ArPose(V3(0, 1.4, 5), V3(0, -0.27, -1));
    final tz = TumbangPresoGame.sweetSpot(tCam.camera)!;
    final tum = TumbangGame()
      ..stand = const V3(0, 0, 5)
      ..place(0, tCam)
      ..hits = TumbangGame.tayaAfter;
    take(tum);
    for (var t = 0.0; t < 20; t += 0.1) {
      used.addAll(tum.scene(t, tum.throwAt(t, tCam, (tz.from + tz.to) / 2)).map((s) => s.sheet));
    }
    used.addAll(tum.scene(0, tum.throwAt(0, tCam, 0)).map((s) => s.sheet));
    // Ring: a make and a miss.
    final ring = RingShootGame()..place(0, null);
    take(ring);
    const rCam = V3(0, 1.4, 4.2);
    for (final f in [const V3(0, 0.1, -1), const V3(1, 0.1, -1)]) {
      used.addAll(ring.scene(0, shot: RingShootGame.shootFrom(camera: rCam, forward: f)).map((s) => s.sheet));
    }
    // Pana: a hit, a miss into the ground, and the golden bangus.
    final pana = PanaGame(random: math.Random(1))
      ..stand = const V3(0, 0, 8)
      ..place(0, null)
      ..bangusOut = true;
    final fish = pana.fish((pana.fish(0) - const V3(0, 1.4, 8)).length / PanaGame.maxSpeed);
    for (final (aim, draw) in [
      (const V3(0, 1.56, 0), 1.0),
      (const V3(0, 0, 4), 0.5),
      (fish + const V3(0, 0.06, 0), 1.0)
    ]) {
      final s = pana.shoot(0, ArPose(const V3(0, 1.4, 8), (aim - const V3(0, 1.4, 8)).unit), draw);
      used.addAll(pana.scene(0, shot: s).map((e) => e.sheet));
    }
    // Palayok: whole, cracked and broken.
    final pot = PalayokGame(random: math.Random(1))..place(0, null);
    take(pot);
    for (var i = 1; i <= 3; i++) {
      pot.hits = i - 1;
      used.addAll(pot.scene(0).map((s) => s.sheet));
    }
    used.addAll(pot.breakScene(angle: 0.1, at: const V3(0, 1.7, 0)).map((s) => s.sheet));
    // Sipa: resting, kicked, landed.
    final sipa = SipaGame(random: math.Random(1))
      ..stand = const V3(0, 0, 2.5)
      ..place(0, null);
    take(sipa);
    sipa.press(0, const ArPose(V3(0, 1.4, 2.5), V3(0, -0.4, -1)));
    take(sipa);
    sipa.update(10, null);
    take(sipa);

    expect(
        used,
        containsAll([
          'chalk_line',
          'taya_guard',
          'lata_tumble',
          'hoop_swish',
          'windsock',
          'bilao_target',
          'arrow_flight',
          'arrow_stuck',
          'bangus_target',
          'bangus_wiggle',
          'palayok_break',
          'coin_spin',
          'sipa'
        ]));
    expect(sheets.keys, containsAll(used));
    for (final s in sheets.values) {
      final png = await s.loadPng(rootBundle);
      expect(png.length, greaterThan(50), reason: s.file);
    }
  });
}
