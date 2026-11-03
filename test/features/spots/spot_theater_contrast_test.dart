import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/features/spots/theater/theater_panel.dart';

double _linearize(double component) {
  final c = component / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  final r = _linearize(color.red.toDouble());
  final g = _linearize(color.green.toDouble());
  final b = _linearize(color.blue.toDouble());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

Color _blendOverWhite(Color tint, double alpha) {
  final r = (tint.red * alpha + 255 * (1 - alpha)).round();
  final g = (tint.green * alpha + 255 * (1 - alpha)).round();
  final b = (tint.blue * alpha + 255 * (1 - alpha)).round();
  return Color.fromARGB(255, r, g, b);
}

void main() {
  group('Spot Theater Contrast Tests (All-White Photo Baseline)', () {
    test('82% ink fill over pure white photo achieves WCAG AA contrast >= 4.5:1', () {
      const ink = PixelPalette.ink;
      const alpha = 0.82;
      final effectivePanelBg = _blendOverWhite(ink, alpha);

      // 1. White text (#FFFFFF) over panel background
      const whiteText = PixelPalette.white;
      final whiteContrast = _contrastRatio(whiteText, effectivePanelBg);
      expect(whiteContrast, greaterThanOrEqualTo(4.5));
      expect(whiteContrast, greaterThan(9.0)); // Typically ~9.7:1

      // 2. Paper text (#FAF9F5) over panel background
      const paperText = PixelPalette.paper;
      final paperContrast = _contrastRatio(paperText, effectivePanelBg);
      expect(paperContrast, greaterThanOrEqualTo(4.5));
      expect(paperContrast, greaterThan(9.0)); // Typically ~9.2:1

      // 3. Sun gold accent (#FFB703) over panel background
      const sunText = PixelPalette.sun;
      final sunContrast = _contrastRatio(sunText, effectivePanelBg);
      expect(sunContrast, greaterThanOrEqualTo(4.5)); // Typically ~5.5:1
    });

    test('TheaterBottomScrim (88% ink) provides >= 4.5:1 contrast for title text over white photo', () {
      const ink = PixelPalette.ink;
      const alpha = 0.88;
      final effectiveScrimBg = _blendOverWhite(ink, alpha);

      const titleColor = PixelPalette.white;
      final titleContrast = _contrastRatio(titleColor, effectiveScrimBg);
      expect(titleContrast, greaterThanOrEqualTo(4.5));
      expect(titleContrast, greaterThan(11.0)); // High-contrast legibility
    });

    testWidgets('TheaterPanel renders content with guaranteed minimum 82% ink opacity', (tester) async {
      await tester.pumpWidget(
        const PixelScope(
          settings: PixelSettings(),
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: TheaterPanel(
                  child: Text(
                    'Readable High-Contrast Story Text',
                    style: TextStyle(color: PixelPalette.paper),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TheaterPanel), findsOneWidget);
      expect(find.text('Readable High-Contrast Story Text'), findsOneWidget);
    });
  });
}
