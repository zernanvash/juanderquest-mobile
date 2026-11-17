import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_background.dart';
import 'package:juanderquest_app/core/pixel/pixel_texture.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';

void main() {
  tearDown(() => PixelTexture.style.value = PixelTextureStyle.classic);

  for (final style in PixelTextureStyle.values) {
    testWidgets('${style.name} paints without errors', (tester) async {
      PixelTexture.style.value = style;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.pixel,
        home: const Scaffold(
          body: DitherBackground(
            top: PixelPalette.greenMid,
            bottom: PixelPalette.green,
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final painters = tester
          .widgetList<CustomPaint>(find.descendant(
            of: find.byType(DitherBackground),
            matching: find.byType(CustomPaint),
          ))
          .map((c) => c.painter)
          .toList();
      expect(
        painters.any((p) => p is PixelNoisePainter),
        style != PixelTextureStyle.classic,
      );
    });
  }

  test('a fixed style ignores the global pick', () {
    PixelTexture.style.value = PixelTextureStyle.scatter;
    const bg = DitherBackground(
      top: PixelPalette.paper,
      bottom: PixelPalette.parchment,
      style: PixelTextureStyle.classic,
    );
    expect(bg.style, PixelTextureStyle.classic);
  });
}
