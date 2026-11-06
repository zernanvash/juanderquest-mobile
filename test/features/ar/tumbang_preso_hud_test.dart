import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_sprites.dart';
import 'package:juanderquest_app/features/ar_experience/games/tumbang_preso.dart';
import 'package:juanderquest_app/features/ar_experience/games/tumbang_preso_hud.dart';

// Plan 77 throwing game: the HUD must not overflow on tiny screens with big text
// (AGENTS: 320x568 and 568x320 at 2.0x), and every sprite the game draws must exist.
void main() {
  Widget hud(TumbangPhase phase, {String? callout, double? offAim = 0, bool inView = true, VoidCallback? onHold}) =>
      MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: TumbangPresoHud(
            phase: phase,
            hits: 2,
            targetHits: 3,
            power: 0.6,
            sweetSpot: (from: 0.3, to: 0.42),
            distanceM: 3.4,
            offAimDeg: offAim,
            canInView: inView,
            callout: callout,
            onPlace: () {},
            onMove: () {},
            onRestart: () {},
            onHoldStart: onHold ?? () {},
            onHoldEnd: () {},
          ),
        ),
      );

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()} with 2.0x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final (phase, callout, off, inView) in [
        (TumbangPhase.placing, null, null, false),
        (TumbangPhase.ready, 'BAGSAK!', 25.0, true),
        (TumbangPhase.charging, null, 0.0, true),
        (TumbangPhase.settling, 'MINTIS!', 0.0, false),
        (TumbangPhase.won, null, 0.0, true),
      ]) {
        await tester.pumpWidget(hud(phase, callout: callout, offAim: off, inView: inView));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$phase');
      }
    });
  }

  testWidgets('hold starts a charge; aim hint shows which way to turn', (tester) async {
    var held = false;
    await tester.pumpWidget(hud(TumbangPhase.ready, offAim: -25, onHold: () => held = true));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('throw_button'))));
    expect(held, isTrue);
    await gesture.up();
    expect(find.text('◀ TURN LEFT'), findsOneWidget);
    expect(find.byKey(const ValueKey('hit_pip_2')), findsOneWidget);
  });

  test('every sprite the game draws is in the bundled manifest', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sheets = await ArSpriteSheet.loadManifest(rootBundle);
    const cam = V3(0, 1.4, 3.5);
    final z = TumbangPresoGame.sweetSpot(cam)!;
    final used = {
      for (final s in [
        ...TumbangPresoScene.ready(),
        ...TumbangPresoScene.throwing(
            TumbangPresoGame.throwFrom(camera: cam, forward: const V3(0, -0.3, -1), power: (z.from + z.to) / 2)),
        ...TumbangPresoScene.throwing(TumbangPresoGame.throwFrom(camera: cam, forward: const V3(0, -0.3, -1), power: 0)),
      ])
        s.sheet,
    };
    expect(sheets.keys, containsAll(used));
    for (final s in sheets.values) {
      final png = await s.loadPng(rootBundle);
      expect(png.length, greaterThan(50), reason: s.file);
    }
  });
}
