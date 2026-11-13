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
