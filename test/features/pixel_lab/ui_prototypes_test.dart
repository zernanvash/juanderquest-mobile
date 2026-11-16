import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/pixel/pixel_text_3d.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/pixel_lab/ui_prototypes_section.dart';

Widget _host() => MaterialApp(
      theme: AppTheme.pixel,
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: UiPrototypesSection(),
        ),
      ),
    );

void main() {
  testWidgets('Plan 101: every menu style renders and a 2.5D button presses', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byType(PixelText3D), findsWidgets);
    for (final key in ['proto_menu_fill', 'proto_menu_compact', 'proto_menu_noBoxes']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('proto_boxless_PLAZA')));
    await tester.tap(find.byKey(const ValueKey('proto_boxless_PLAZA')));
    await tester.pump();
    expect(find.text('TAPPED PLAZA'), findsOneWidget);
  });

  testWidgets('PixelIconFit uses whole device pixels', (tester) async {
    PixelArt art(int n) => PixelArt('t$n', List.filled(n, '.' * n));
    expect(PixelIconFit.fitScale(art(16), 24, 3), 4);
    expect(PixelIconFit.fitScale(art(24), 24, 3), 3);
    expect(PixelIconFit.fitScale(art(64), 24, 1), 1);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('Plan 101 prototypes: no overflow at $size with 2.0x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
        child: _host(),
      ));
      for (final key in ['proto_menu_fill', 'proto_menu_compact', 'proto_menu_noBoxes']) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}

