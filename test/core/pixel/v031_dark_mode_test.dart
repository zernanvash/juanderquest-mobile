import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_background.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/pixel/pixel_surface.dart';
import 'package:juanderquest_app/core/pixel/pixel_text_3d.dart';

Widget _page(bool dark) => MaterialApp(
      home: PixelScope(
        settings: PixelSettings(darkMode: dark),
        child: const DitherBackground(
          top: PixelPalette.paper,
          bottom: PixelPalette.parchment,
          child: Column(
            children: [
              PixelText3D('PAGE TITLE'),
              PixelPanel(
                style: PixelBoxStyle.parchment,
                child: PixelText3D('PANEL TITLE'),
              ),
            ],
          ),
        ),
      ),
    );

Color _band(WidgetTester tester, String text) {
  final rich = tester.widgetList<RichText>(find.descendant(
    of: find.widgetWithText(PixelText3D, text),
    matching: find.byType(RichText),
  ));
  return rich.last.text.style!.color!;
}

void main() {
  test('dark mode is saved and read back', () {
    const on = PixelSettings(darkMode: true);
    expect(PixelSettings.fromJson(jsonOf(on))!.darkMode, isTrue);
    expect(PixelSettings.fromJson('{}')!.darkMode, isFalse);
    expect(on == const PixelSettings(), isFalse);
  });

  testWidgets('light mode keeps the light page and gold lettering',
      (tester) async {
    await tester.pumpWidget(_page(false));
    expect(find.byKey(const ValueKey('pixel_dark_page')), findsNothing);
    expect(_band(tester, 'PAGE TITLE'), PixelText3DColors.gold.band);
  });

  testWidgets(
      'dark mode: plain dark-brown page, cream page lettering, '
      'panels keep gold', (tester) async {
    await tester.pumpWidget(_page(true));
    final page = tester
        .widget<ColoredBox>(find.byKey(const ValueKey('pixel_dark_page')));
    expect(page.color, PixelSurface.darkPage);
    expect(_band(tester, 'PAGE TITLE'), PixelText3DColors.cream.band);
    expect(_band(tester, 'PANEL TITLE'), PixelText3DColors.gold.band);
  });
}

String jsonOf(PixelSettings s) => jsonEncode(s.toJson());
