import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/profile_banner.dart';

// Owner 2026-11-05: "draw a proper capiz-shell pattern" for Capiz Heritage.
void main() {
  testWidgets('Capiz Heritage draws a pixel capiz window', (tester) async {
    tester.view.physicalSize = const Size(1080, 360);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: ValueKey('capiz'),
            child: ProfileBanner(
              asset: {
                'style': 'gradient',
                'colors': ['#e9d8a6', '#ca9b52'],
                'angle': 120,
                'pattern': 'capiz',
              },
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('capiz')),
      matchesGoldenFile('goldens/capiz_banner.png'),
    );
  });
}
