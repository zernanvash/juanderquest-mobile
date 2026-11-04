import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/onboarding/pixel_tutorial.dart';
import 'package:juanderquest_app/features/pixel_lab/tutorial_preview.dart';

// Owner 2026-11-04: three first-run tutorial styles to choose from in the lab.
void main() {
  Future<void> pumpPreview(WidgetTester tester, TutorialStyle style,
      {Size size = const Size(390, 844), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: TutorialPreviewScreen(style: style),
      ),
    ));
    await tester.pump();
  }

  /// Finishes the typing of the current line.
  Future<void> finishLine(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
  }

  for (final style in TutorialStyle.values) {
    group(style.label, () {
      testWidgets('"Yes" walks through all four lines, then it closes',
          (tester) async {
        await pumpPreview(tester, style);
        await finishLine(tester);
        expect(find.byKey(const ValueKey('tutorial-choice-0')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('tutorial-choice-0')));
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          await finishLine(tester);
          await tester.tapAt(const Offset(195, 300));
          await tester.pump();
        }
        expect(find.byType(PixelTutorialOverlay), findsNothing);
        expect(find.byKey(const ValueKey('tutorial-replay')), findsOneWidget);
      });

      testWidgets('"No, I\'ll explore" skips the rest', (tester) async {
        await pumpPreview(tester, style);
        await finishLine(tester);
        final no = find.byKey(const ValueKey('tutorial-choice-1'));
        await tester.tap(no);
        await tester.pump();
        // The story box moves the heart first; a second tap confirms.
        if (find.byType(PixelTutorialOverlay).evaluate().isNotEmpty) {
          await tester.tap(no);
          await tester.pump();
        }
        expect(find.byType(PixelTutorialOverlay), findsNothing);
      });

      testWidgets('SKIP closes it at any time', (tester) async {
        await pumpPreview(tester, style);
        await tester.tap(find.byKey(const ValueKey('tutorial-skip')));
        await tester.pump();
        expect(find.byType(PixelTutorialOverlay), findsNothing);
      });

      for (final size in const [Size(320, 568), Size(568, 320)]) {
        testWidgets(
            'no overflow at ${size.width.toInt()}x${size.height.toInt()}, 2x text',
            (tester) async {
          await pumpPreview(tester, style, size: size, textScale: 2);
          await finishLine(tester);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('tutorial-choice-0')));
          await tester.pump();
          await finishLine(tester);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
