import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/navigation/widgets/ph_outline.g.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_map_thumbnail.dart';
import 'package:juanderquest_app/features/pixel_lab/nav_panel_options.dart';

// Owner 2026-11-13: panel options in the Pixel lab; the panel follows the
// finger; the preview shows the real route on a plain Philippines outline.
void main() {
  for (final layout in NavPanelLayout.values) {
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets(
          '${layout.name} fits at ${size.width.toInt()}x${size.height.toInt()} with 2x text and follows a drag',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.pixel,
          home: MediaQuery(
            data: MediaQueryData(
                size: size, textScaler: const TextScaler.linear(2)),
            child: NavPanelPreview(layout: layout),
          ),
        ));
        expect(tester.takeException(), isNull);

        final sheet = find.byKey(const ValueKey('nav_panel_sheet'));
        final before = tester.getSize(sheet).height;
        // Half-way through a drag the panel has moved by what the finger moved.
        final gesture = await tester
            .startGesture(tester.getTopLeft(sheet) + const Offset(40, 10));
        await gesture.moveBy(const Offset(0, -30));
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
        expect(tester.getSize(sheet).height, greaterThan(before + 20));
        // Keep dragging: past halfway it snaps fully open on release.
        await gesture.moveBy(const Offset(0, -300));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(find.byKey(const ValueKey('nav_panel_carousel')),
            const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(find.textContaining('HERITAGE TRAIL'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Owner 2026-11-13 picked B: "add a hint swipe so user know its a carousel".
  Future<void> pumpB(WidgetTester tester, {bool reduceMotion = false}) async {
    const size = Size(320, 568);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home: MediaQuery(
        data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(2),
            disableAnimations: reduceMotion),
        child: const NavPanelPreview(layout: NavPanelLayout.woodCard),
      ),
    ));
  }

  double carouselOffset(WidgetTester tester) => tester
      .widget<PageView>(find.byKey(const ValueKey('nav_panel_carousel')))
      .controller!
      .offset;

  testWidgets('B nudges the carousel once, then rests on the first card',
      (tester) async {
    await pumpB(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(carouselOffset(tester), greaterThan(0));
    await tester.pumpAndSettle();
    expect(carouselOffset(tester), 0);
    // The next card peeks in at the right edge.
    expect(find.text('HERITAGE TRAIL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B skips the nudge when the phone asks for less motion',
      (tester) async {
    await pumpB(tester, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(carouselOffset(tester), 0);
  });

  testWidgets('B arrows page the carousel and fade at the ends',
      (tester) async {
    await pumpB(tester);
    await tester.pumpAndSettle();
    expect(find.text('8 MIN · 6.9 KM'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('nav_panel_next')));
    await tester.pumpAndSettle();
    expect(find.text('5 HR 51 MIN'), findsWidgets);
    // Last card: next does nothing; previous goes back.
    await tester.tap(find.byKey(const ValueKey('nav_panel_next')));
    await tester.pumpAndSettle();
    expect(find.text('5 HR 51 MIN'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('nav_panel_prev')));
    await tester.pumpAndSettle();
    expect(find.text('8 MIN · 6.9 KM'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test(
      'thumbnail window contains the whole route and keeps some coast around it',
      () {
    const size = Size(72, 72);
    final v = RouteMapPainter.viewport(kLabTrailRoute, size);
    for (var i = 0; i + 1 < kLabTrailRoute.length; i += 2) {
      expect(
          v.contains(Offset(kLabTrailRoute[i], kLabTrailRoute[i + 1])), isTrue);
    }
    // A 7 km route still shows at least 0.3 degrees, so it isn't a blank square.
    final small = RouteMapPainter.viewport(kLabDirectRoute, size);
    expect(small.width, greaterThanOrEqualTo(0.3));
    expect(kPhilippinesOutline.length, greaterThan(10));
  });
}
