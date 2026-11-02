import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_calibration.dart';
import 'package:juanderquest_app/features/ar_experience/widgets/ar_calibration_panel.dart';

class _MemoryStore implements PixelSettingsStore {
  @override
  Future<PixelSettings?> read() async => null;
  @override
  Future<void> write(PixelSettings settings) async {}
}

void main() {
  late DateTime t;
  late ArCalibration c;

  void feed({
    bool tracking = true,
    int planes = 0,
    bool compassUnreliable = false,
    int samples = 0,
    bool headingReady = false,
  }) =>
      c.update(
        tracking: tracking,
        planes: planes,
        compassUnreliable: compassUnreliable,
        headingSamples: samples,
        headingReady: headingReady,
      );

  setUp(() {
    t = DateTime(2026, 11, 2, 19);
    c = ArCalibration(now: () => t);
  });

  test('floor, then look around, then ready', () {
    feed();
    expect(c.step, CalibrationStep.floor);
    expect(c.totalSteps, 2);

    feed(planes: 1);
    t = t.add(const Duration(milliseconds: 500));
    feed(planes: 1);
    expect(c.step, CalibrationStep.floor, reason: 'floor must hold 1 s');
    expect(c.progress, closeTo(0.5, 0.01));
    t = t.add(const Duration(milliseconds: 500));
    feed(planes: 1);
    expect(c.step, CalibrationStep.look);
    expect(c.stepNumber, 2);

    feed(samples: 6);
    expect(c.progress, closeTo(6 / 15, 0.01));
    feed(samples: 15, headingReady: true);
    expect(c.done, isTrue);
    expect(c.headingFallback, isFalse);
  });

  test('a lost floor restarts the hold', () {
    feed(planes: 1);
    t = t.add(const Duration(milliseconds: 800));
    feed(planes: 1, tracking: false);
    t = t.add(const Duration(milliseconds: 800));
    feed(planes: 1);
    expect(c.step, CalibrationStep.floor);
  });

  test('shows the hard-floor tip after 10 s', () {
    feed();
    t = t.add(const Duration(seconds: 9));
    feed();
    expect(c.floorTip, isFalse);
    t = t.add(const Duration(seconds: 1));
    feed();
    expect(c.floorTip, isTrue);
  });

  test('gives up on the heading after 12 s and falls back to aiming', () {
    feed(planes: 1);
    t = t.add(const Duration(seconds: 1));
    feed(planes: 1);
    expect(c.step, CalibrationStep.look);
    t = t.add(const Duration(seconds: 12));
    feed(samples: 4);
    expect(c.done, isTrue);
    expect(c.headingFallback, isTrue);
  });

  test('figure-8 step only when the compass is unreliable', () {
    feed(compassUnreliable: true);
    expect(c.step, CalibrationStep.compass);
    expect(c.totalSteps, 3);
    feed(compassUnreliable: false);
    t = t.add(const Duration(seconds: 1));
    feed(compassUnreliable: false);
    expect(c.step, CalibrationStep.floor);
    expect(c.stepNumber, 2);
  });

  test('compass step gives up after 20 s', () {
    feed(compassUnreliable: true);
    t = t.add(const Duration(seconds: 20));
    feed(compassUnreliable: true);
    expect(c.step, CalibrationStep.floor);
  });

  group('layout', () {
    Future<void> pump(WidgetTester tester, Size size, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pixelSettingsStoreProvider.overrideWithValue(_MemoryStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(body: Stack(fit: StackFit.expand, children: [child])),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
    }

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets('tutorial fits at $size, 2x text, and steps through',
          (tester) async {
        var done = false;
        await pump(tester, size, ArTutorial(onDone: () => done = true));
        expect(tester.takeException(), isNull);
        expect(find.text('TIP 1 OF 3'), findsOneWidget);
        await tester.tap(find.text('NEXT'));
        await tester.pump();
        await tester.tap(find.text('NEXT'));
        await tester.pump();
        expect(find.text('GOT IT'), findsOneWidget);
        await tester.tap(find.text('GOT IT'));
        expect(done, isTrue);
      });

      testWidgets('set-up panel fits at $size, 2x text, with the tip',
          (tester) async {
        feed();
        t = t.add(const Duration(seconds: 11));
        feed();
        await pump(tester, size, ArCalibrationPanel(calibration: c));
        expect(tester.takeException(), isNull);
        expect(find.text('FIND THE FLOOR'), findsOneWidget);
        expect(find.textContaining('Shiny or plain floor'), findsOneWidget);
      });
    }

    testWidgets('SKIP ends the tutorial', (tester) async {
      var done = false;
      await pump(
          tester, const Size(360, 720), ArTutorial(onDone: () => done = true));
      await tester.tap(find.text('SKIP'));
      expect(done, isTrue);
    });
  });
}
