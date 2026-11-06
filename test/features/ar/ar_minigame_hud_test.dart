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
  final pose = ArPose(cam, (const V3(-3, 1.5, 0) - cam).unit); // far off to the left: shows a turn hint

  final makers = <String, ArMiniGame Function()>{
    'ring': RingShootGame.new,
    'pana': PanaGame.new,
    'palayok': () => PalayokGame(random: math.Random(1)),
    'sipa': () => SipaGame(random: math.Random(1)),
  };

  Widget hud(ArMiniGame g, {String? callout, ArPose? at, VoidCallback? onPress}) => MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ArMiniGameHud(
            game: g,
            now: 1,
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

  /// The game placed (state A), mid-play with a callout (B), and won (C).
  List<(ArMiniGame, String?, ArPose?)> states(ArMiniGame Function() make) {
    final placing = make();
    final playing = make()..place(0, pose);
    final won = make()..place(0, pose);
    // Every game keeps won/hits as plain fields; set them to show the PANALO panel.
    (won as dynamic)
      ..won = true
      ..hits = won.targetHits;
    return [(placing, null, null), (playing, 'BULLSEYE!', pose), (playing, null, null), (won, null, pose)];
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
          expect(tester.takeException(), isNull, reason: '${e.key} placed=${g.placed} won=${g.won}');
        }
      }
    });
  }

  testWidgets('placing shows the game\'s place button; playing shows the button, hint and aim circle', (tester) async {
    final g = PalayokGame(random: math.Random(1));
    await tester.pumpWidget(hud(g));
    expect(find.text('HANG PALAYOK'), findsOneWidget);
    g.place(0, pose);
    var pressed = false;
    await tester.pumpWidget(hud(g, at: pose, onPress: () => pressed = true));
    expect(find.byKey(const ValueKey('reticle_false')), findsOneWidget);
    expect(find.byKey(const ValueKey('aim_hint')), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('game_button'))));
    await gesture.up();
    expect(pressed, isTrue);
    expect(find.byKey(const ValueKey('hit_pip_2')), findsOneWidget);
  });

  test('every sprite the games draw is in the bundled manifest', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sheets = await ArSpriteSheet.loadManifest(rootBundle);
    final used = <String>{};
    void take(ArMiniGame g) => used.addAll([...?g.takeScene()].map((s) => s.sheet));

    // Ring: idle, a make and a miss.
    final rz = RingShootGame.sweetSpot(const V3(0, 1.4, 4.5))!;
    for (final p in [(rz.from + rz.to) / 2, 0.0]) {
      used.addAll(RingShootGame.scene(
              shot: RingShootGame.shootFrom(camera: const V3(0, 1.4, 4.5), forward: const V3(0, 0.1, -1), power: p))
          .map((s) => s.sheet));
    }
    // Pana: a hit (with an arrow stuck) and a miss into the ground.
    final pana = PanaGame()..place(0, const ArPose(V3(0, 1.4, 6), V3(0, 0, -1)));
    take(pana);
    final hit = pana.shoot(0, const ArPose(V3(0, 1.4, 6), V3(0, 0.02, -1)), 1);
    final miss = pana.shoot(0, const ArPose(V3(0, 1.4, 6), V3(0, -0.3, -1)), 0.5);
    expect((hit.hit, miss.hit), (true, false));
    for (final s in [hit, miss]) {
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
    final sipa = SipaGame(random: math.Random(1))..place(0, null);
    take(sipa);
    sipa.press(0, const ArPose(V3(0, 1.4, 2.5), V3(0, -0.4, -1)));
    take(sipa);
    sipa.update(10, null);
    take(sipa);

    expect(used, containsAll(['hoop', 'hoop_swish', 'ball_spin', 'bilao_target', 'arrow_flight', 'arrow_stuck',
        'palayok_whole', 'palayok_crack1', 'palayok_crack2', 'palayok_break', 'coin_spin', 'sipa']));
    expect(sheets.keys, containsAll(used));
    for (final s in sheets.values) {
      final png = await s.loadPng(rootBundle);
      expect(png.length, greaterThan(50), reason: s.file);
    }
  });
}
