import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_quest_screen.dart';

// Owner 2026-11-08: "make it a UI banner ... just display the cool or warmer ...
// add a (i) for info help ... simplify the AR UI".
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(backgroundColor: Colors.black, body: Center(child: child)));

  testWidgets('the heat banner shows only heat, distance and warmer/colder', (tester) async {
    await tester.pumpWidget(host(const HuntHeatBanner(heat: 'WARM', trend: 'WARMER', distance: 13)));
    expect(find.text('WARM'), findsOneWidget);
    expect(find.text('~15 m'), findsOneWidget);
    expect(find.text('▲ WARMER'), findsOneWidget);
    await tester.pumpWidget(host(const HuntHeatBanner(heat: 'COLD', trend: '', distance: null)));
    expect(find.text('COLD'), findsOneWidget);
    expect(find.textContaining('WARMER'), findsNothing);
  });

  testWidgets('the (i) help explains finding, safety and the mode', (tester) async {
    await tester.pumpWidget(host(const ArHelpSheet(objectLabel: 'Quest Token', mode: 'World AR')));
    expect(find.text('How to find the Quest Token'), findsOneWidget);
    expect(find.text('Stay safe'), findsOneWidget);
    expect(find.text('Mode: World AR'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('banner and help fit at ${size.width.toInt()}x${size.height.toInt()} with 2.0x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(host(const HuntHeatBanner(heat: 'HOT', trend: 'COLDER', distance: 4)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(host(const ArHelpSheet(objectLabel: 'Heritage Pyramid', mode: 'Compass AR')));
      expect(tester.takeException(), isNull);
    });
  }
}
