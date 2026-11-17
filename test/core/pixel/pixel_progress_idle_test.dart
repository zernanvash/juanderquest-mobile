import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_feedback.dart';
import 'package:juanderquest_app/core/pixel/pixel_idle.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';

// Owner 2026-11-17: "have idle animation for the progress bars (maybe
// particle inside the bar)".
void main() {
  tearDown(() => PixelLoop.debugRunInTests = false);

  int step(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(find.descendant(
      of: find.byType(PixelProgressBar),
      matching: find.byType(CustomPaint),
    ));
    return (paint.painter as dynamic).step as int;
  }

  Widget app(double value, {bool idle = true}) => MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: PixelProgressBar(value: value, idle: idle),
          ),
        ),
      );

  testWidgets('a filled bar steps through its idle loop', (tester) async {
    PixelLoop.debugRunInTests = true;
    await tester.pumpWidget(app(0.6));
    expect(step(tester), 0);
    await tester.pump(const Duration(milliseconds: 95));
    await tester.pump(const Duration(milliseconds: 95));
    expect(step(tester), greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty bar or idle: false stays still', (tester) async {
    PixelLoop.debugRunInTests = true;
    for (final w in [app(0), app(0.6, idle: false)]) {
      await tester.pumpWidget(w);
      await tester.pump(const Duration(milliseconds: 400));
      expect(step(tester), 0);
      expect(find.byType(PixelLoop), findsNothing);
    }
  });
}
