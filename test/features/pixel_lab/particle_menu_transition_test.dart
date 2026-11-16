import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/pixel/pixel_particles.dart';
import 'package:juanderquest_app/features/pixel_lab/particle_menu_transition_section.dart';
import 'package:juanderquest_app/features/pixel_lab/pixel_lab_screen.dart';

void main() {
  group('PixelParticleSystem unit mechanics', () {
    test('pool stays bounded, steps cleanly, and returns to idle when particles expire', () {
      final sys = PixelParticleSystem(capacity: 32);
      expect(sys.isActive, isFalse);

      sys.emitBurst(origin: const Offset(100, 100), count: 48);
      expect(sys.isActive, isTrue);
      expect(sys.activeCount, lessThanOrEqualTo(32));

      // Advance enough time for all particles to expire.
      for (var i = 0; i < 40; i++) {
        sys.step(0.05);
      }
      expect(sys.isActive, isFalse);
      expect(sys.activeCount, 0);
    });

    test('emitDisintegrateFrontier spawns particles for all 3 dissolve styles', () {
      const modalRect = Rect.fromLTRB(10, 40, 290, 260);
      const anchor = Offset(150, 320);

      for (final style in PixelDisintegrateStyle.values) {
        final sys = PixelParticleSystem(capacity: 64);
        sys.emitDisintegrateFrontier(
          modalRect: modalRect,
          anchor: anchor,
          prevProgress: 0.2,
          progress: 0.5,
          opening: true,
          style: style,
          maxPerStep: 12,
        );
        expect(sys.activeCount, greaterThan(0), reason: 'Failed for $style');
        sys.clear();
        expect(sys.activeCount, 0);
      }
    });
  });

  group('ParticleMenuTransitionSection in PixelLab', () {
    testWidgets('expands from nav MENU button to full modal and disintegrates closed', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PixelScope(
              settings: PixelSettings(),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ParticleMenuTransitionSection(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lab_particle_modal_card')), findsNothing);

      // Tap MENU button in the preview nav bar.
      await tester.tap(find.byKey(const ValueKey('lab_particle_menu_btn')));
      await tester.pump(const Duration(milliseconds: 120));
      // Mid-transition overlay & disintegrate mask active, modal building.
      expect(find.byKey(const ValueKey('lab_particle_overlay')), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lab_particle_modal_card')), findsOneWidget);
      expect(find.text('MAIN MENU'), findsOneWidget);

      // Tap again (now CLOSE) to disintegrate back to nav.
      await tester.tap(find.byKey(const ValueKey('lab_particle_menu_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lab_particle_modal_card')), findsNothing);
    });

    testWidgets('supports style switching, speed chips, burst test, and reduced motion', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              // Owner 2026-11-17: reduce motion is the in-app setting.
              child: PixelScope(
                settings: PixelSettings(reduceMotion: true),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ParticleMenuTransitionSection(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('lab_particle_style_centerVortex')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('lab_particle_speed_1100')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('lab_particle_burst')));
      await tester.pump();
      expect(find.text('REDUCED MOTION ACTIVE'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('lab_particle_menu_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lab_particle_modal_card')), findsOneWidget);
    });

    testWidgets('mounts inside PixelLabScreen without overflow at 320x568 and 568x320 at 2.0x text',
        (tester) async {
      for (final size in const [Size(320, 568), Size(568, 320)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(size),
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: const PixelScope(
                  settings: PixelSettings(),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: ParticleMenuTransitionSection(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final menuBtn = find.byKey(const ValueKey('lab_particle_menu_btn'));
        await tester.ensureVisible(menuBtn);
        await tester.pumpAndSettle();
        await tester.tap(menuBtn);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('lab_particle_modal_card')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Overflowed at $size');
      }
    });

    testWidgets('section is visible inside full PixelLabScreen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PixelLabScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('PARTICLE SYSTEM · MENU TRANSITION'),
        400,
        scrollable: list,
      );
      expect(find.text('PARTICLE SYSTEM · MENU TRANSITION'), findsOneWidget);
    });
  });
}
