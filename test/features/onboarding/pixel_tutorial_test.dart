import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/features/onboarding/pixel_tutorial.dart';
import 'package:juanderquest_app/features/pixel_lab/tutorial_preview.dart';

// Owner 2026-11-04: B's dark spotlight with C's Juan at the bottom left.
void main() {
  Future<void> pumpPreview(WidgetTester tester,
      {Size size = const Size(390, 844),
      double textScale = 1,
      double dpr = 1}) async {
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TutorialPreviewScreen(),
      ),
    ));
    await tester.pump();
  }

  /// Finishes the typing of the current line.
  Future<void> finishLine(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
  }

  group('first-run tutorial', () {
    testWidgets('"Yes" walks through all four lines, then it closes',
        (tester) async {
      await pumpPreview(tester);
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
      await pumpPreview(tester);
      await finishLine(tester);
      final no = find.byKey(const ValueKey('tutorial-choice-1'));
      await tester.tap(no);
      await tester.pump();
      expect(find.byType(PixelTutorialOverlay), findsNothing);
    });

    testWidgets('SKIP closes it at any time', (tester) async {
      await pumpPreview(tester);
      await tester.tap(find.byKey(const ValueKey('tutorial-skip')));
      await tester.pump();
      expect(find.byType(PixelTutorialOverlay), findsNothing);
    });

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets(
          'no overflow at ${size.width.toInt()}x${size.height.toInt()}, 2x text',
          (tester) async {
        await pumpPreview(tester, size: size, textScale: 2);
        await finishLine(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('tutorial-choice-0')));
        await tester.pump();
        await finishLine(tester);
        expect(tester.takeException(), isNull);
      });
    }

    // Owner 2026-11-06 (phone screenshot): Juan's legs covered "HEY, I'M JUAN".
    // He is drawn in device pixels, so he is taller on low-density screens.
    for (final dpr in const [1.0, 2.25, 3.0]) {
      testWidgets('Juan stands on the box, clear of the text (dpr $dpr)',
          (tester) async {
        await pumpPreview(tester, dpr: dpr);
        await finishLine(tester);
        final juan = tester.getRect(find.byWidgetPredicate(
            (w) => w is PixelAnimation && w.frames == DesignerArt.juanIdle));
        final box = tester.getRect(find.descendant(
            of: find.byType(PixelTutorialOverlay),
            matching: find.byWidgetPredicate(
                (w) => w is PixelPanel && w.style == PixelBoxStyle.wood)));
        final text = tester.getRect(find.textContaining('First time'));
        expect(juan.bottom, lessThanOrEqualTo(box.top + 8),
            reason: 'feet on the top edge of the box');
        expect(juan.bottom, greaterThan(box.top - 8));
        expect(juan.bottom, lessThan(text.top));
      });
    }
  });
}
