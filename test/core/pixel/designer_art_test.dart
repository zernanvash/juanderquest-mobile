import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
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
    expect(DesignerArt.chestOpenAnim.frames, hasLength(6));
    expect((DesignerArt.chestOpenAnim.frames.first.width, DesignerArt.chestOpenAnim.frames.first.height), (32, 32));
    expect((DesignerArt.navHome.width, DesignerArt.navHome.height), (24, 24));
    expect((DesignerArt.navProfile.width, DesignerArt.navProfile.height), (24, 24));
    expect((DesignerArt.navMap.width, DesignerArt.navMap.height), (32, 32));
    expect((DesignerArt.questionMark.width, DesignerArt.questionMark.height), (32, 32));
    expect((DesignerArt.gem.width, DesignerArt.gem.height), (32, 32));
    expect((DesignerArt.spotMarker.width, DesignerArt.spotMarker.height), (64, 64));
    expect((DesignerArt.salakot.width, DesignerArt.salakot.height), (23, 23));
    expect((DesignerArt.handshake.width, DesignerArt.handshake.height), (32, 32));
    expect(DesignerArt.coinAnim.frames, hasLength(7));
    expect((DesignerArt.coinAnim.frames.first.width, DesignerArt.coinAnim.frames.first.height), (13, 13));
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
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: const PixelLabScreen(),
        ),
      ),
    );
    expect(find.text('Pixel lab'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pixel_lab_like')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('pixel_lab_like')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('pixel_lab_like')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pixel_lab_chest')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PixelAnimation), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('pixel_lab_chest')), findsOneWidget);
  });

  testWidgets('MjdqAmount renders number + coin and exposes "<amount> mJDQ" to screen readers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.pixel,
        home: const Scaffold(
          body: Center(child: MjdqAmount(1250)),
        ),
      ),
    );
    expect(find.text('1250'), findsOneWidget);
    expect(find.byType(PixelSprite), findsOneWidget);
    expect(find.bySemanticsLabel('1250 mJDQ'), findsOneWidget);
  });

  testWidgets('MjdqAmount rests facing front, turns once when points increase, and settles facing front', (tester) async {
    // Owner 2026-11-16: start from the coin facing the front; eased turn.
    final front = DesignerArt.coinAnim.frames[3];
    Widget buildFor(int points) => MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Center(child: MjdqAmount(points, animateOnIncrease: true)),
          ),
        );
    PixelArt shown() => tester.widget<PixelSprite>(find.byType(PixelSprite)).art;

    await tester.pumpWidget(buildFor(100));
    expect(shown(), same(front));

    await tester.pumpWidget(buildFor(150));
    await tester.pump();
    expect(shown(), same(front), reason: 'the turn starts facing front');
    await tester.pump(const Duration(milliseconds: 450));
    expect(shown(), isNot(same(front)), reason: 'mid-turn shows another frame');

    await tester.pump(const Duration(seconds: 1));
    expect(shown(), same(front));
  });
}
