import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_particles.dart';
import 'package:juanderquest_app/core/pixel/pixel_poppers.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';

Widget _app({bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.pixel,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => PixelPoppers.fire(context),
              child: const Text('POP'),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    PixelPoppers.debugRunInTests = true;
    PixelPoppers.debugFired = 0;
  });
  tearDown(() => PixelPoppers.debugRunInTests = false);

  testWidgets('poppers draw confetti, then remove themselves', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byType(PixelParticleOverlay), findsNothing);

    await tester.tap(find.text('POP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(PixelParticleOverlay), findsOneWidget);
    final overlay =
        tester.widget<PixelParticleOverlay>(find.byType(PixelParticleOverlay));
    expect(overlay.system.activeCount, greaterThan(40));

    // The big pop fires a second burst, then everything falls away.
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(find.byType(PixelParticleOverlay), findsNothing);
    expect(PixelPoppers.debugFired, 1);
  });

  testWidgets('poppers do nothing under reduce motion', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.tap(find.text('POP'));
    await tester.pump();
    expect(find.byType(PixelParticleOverlay), findsNothing);
    expect(PixelPoppers.debugFired, 0);
  });

  test('cone confetti heads up and inward from the left corner', () {
    final system = PixelParticleSystem(capacity: 50);
    system.emitCone(
      origin: const Offset(0, 600),
      angle: -1.13,
      spread: 0.3,
      count: 50,
    );
    expect(system.activeCount, 50);
    for (final p in system.particles) {
      expect(p.vy, lessThan(0), reason: 'starts upward');
      expect(p.vx, greaterThan(0), reason: 'starts inward');
    }
  });
}
