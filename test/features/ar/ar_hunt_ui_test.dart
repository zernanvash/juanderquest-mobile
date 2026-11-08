import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_quest_screen.dart';

// Owner 2026-11-08: "simplify the AR UI ... add a (i) for info help", then
// "i hate the colder and warmer ... a compass or something? or a radar".
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(backgroundColor: Colors.black, body: Center(child: child)));

  testWidgets('the radar shows how far, and nothing about warmer or colder', (tester) async {
    await tester.pumpWidget(host(const HuntRadar(distance: 13, relativeBearing: 30)));
    expect(find.byKey(const ValueKey('ar_radar')), findsOneWidget);
    expect(find.text('~15 m'), findsOneWidget);
    expect(find.textContaining('WARM'), findsNothing);
    await tester.pumpWidget(host(const HuntRadar(distance: null)));
    expect(find.text('Finding you...'), findsOneWidget);
  });

  test('the blip is to your right when the object is to your right', () {
    expect(HuntRadar.relative(phone: 0, target: 90), 90);
    expect(HuntRadar.relative(phone: 350, target: 10), 20);
    expect(HuntRadar.relative(phone: 90, target: 0), -90);
  });

  test('the blip moves to the middle as you get closer', () {
    expect(HuntRadar.blipRadius(80), 1.0);
    expect(HuntRadar.blipRadius(20), 0.5);
    expect(HuntRadar.blipRadius(0), 0.0);
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
      await tester.pumpWidget(host(const HuntRadar(distance: 4, relativeBearing: -120)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(host(const ArHelpSheet(objectLabel: 'Heritage Pyramid', mode: 'Compass AR')));
      expect(tester.takeException(), isNull);
    });
  }
}
