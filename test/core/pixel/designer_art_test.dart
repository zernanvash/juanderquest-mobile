import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/features/pixel_lab/pixel_lab_screen.dart';

Iterable<PixelArt> _allArt() sync* {
  for (final v in DesignerArt.all.values) {
    if (v is PixelArt) yield v;
    if (v is PixelFrames) yield* v.frames;
  }
}

void main() {
  test('every pixel uses a brand palette key (or "." for transparent)', () {
    for (final art in _allArt()) {
      for (final row in art.rows) {
        expect(row.length, art.width, reason: '${art.name} has a ragged row');
        for (final ch in row.split('')) {
          expect(ch == '.' || PixelPalette.byKey.containsKey(ch), isTrue, reason: '${art.name}: unknown key "$ch"');
        }
      }
    }
  });

  test('animations have same-size frames and the expected frame counts', () {
    expect(DesignerArt.heartLikeAnim.frames, hasLength(12));
    expect(DesignerArt.heartUnlikeAnim.frames, hasLength(13));
    expect(DesignerArt.juanIdle.frames, hasLength(8));
    for (final v in DesignerArt.all.values.whereType<PixelFrames>()) {
      final first = v.frames.first;
      for (final f in v.frames) {
        expect((f.width, f.height), (first.width, first.height), reason: v.name);
      }
    }
  });

  testWidgets('a sprite covers exactly scale device pixels per art pixel', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Center(child: PixelSprite(DesignerArt.heartLiked, scale: 3))));
    final size = tester.getSize(find.byType(CustomPaint).last);
    expect(size.width * 2.75, closeTo(36 * 3, 0.001));
  });

  testWidgets('pixel lab renders and the like button plays', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PixelLabScreen()));
    await tester.tap(find.byKey(const ValueKey('pixel_lab_like')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Pixel lab'), findsOneWidget);
  });
}
