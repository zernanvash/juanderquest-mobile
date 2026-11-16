@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_text_3d.dart';
import 'package:juanderquest_app/core/pixel/pixel_theme.dart';

// Renders the lettering gallery to PNG for a design check (not a golden).
// Run: flutter test --tags preview --dart-define=PREVIEW_OUT=<dir>
void main() {
  testWidgets('lettering preview', (tester) async {
    const out = String.fromEnvironment('PREVIEW_OUT');
    if (out.isEmpty) return;
    for (final f in PixelFonts.families) {
      final file = File('assets/fonts/${{'Silkscreen': 'Silkscreen-Regular', 'PressStart2P': 'PressStart2P-Regular', 'VT323': 'VT323-Regular'}[f] ?? f}.ttf');
      await tester.runAsync(() async {
        final loader = FontLoader(f)..addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
        await loader.load();
      });
    }
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Material(child: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFFF4EBD8),
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            for (final l in PixelTextLook.values)
              Wrap(spacing: 8, children: [
                for (final f in PixelFonts.families)
                  PixelText3D('QUESTS', size: 16, look: l, font: f, colors: PixelText3DColors.gold),
              ]),
          ]),
        ),
      )),
    ));
    await tester.pump();
    await tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('$out/lettering.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
}
