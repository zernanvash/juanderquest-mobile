import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/pixel_lab/v03/pixel_lab_v03_screen.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('v0.3 lab: menu styles, dark page, taps and tabs work', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PixelLabV03Screen()));
    await tester.pump(const Duration(milliseconds: 200));
    for (final k in ['v03_menu_fill', 'v03_menu_compact', 'v03_menu_noBoxes', 'v03_dark', 'v03_light']) {
      await _tapKey(tester, k);
      expect(tester.takeException(), isNull);
    }
    await _tapKey(tester, 'proto_boxless_PLAZA');
    await _tapKey(tester, 'v03_task_1');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('v03_last')), 300);
    expect(find.text('TAPPED PLAZA'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v03_tab_MAP')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('v0.3 lab: no overflow at $size with 2.0x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
        child: const MaterialApp(home: PixelLabV03Screen()),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      for (final k in ['v03_menu_fill', 'v03_menu_compact', 'v03_dark']) {
        await _tapKey(tester, k);
        expect(tester.takeException(), isNull);
      }
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  }
}
