import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/core/pixel/pixel_rpg.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';

// Plan 75k (owner 2026-11-05, argon's audit): the RPG-feel kit.
Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.pixel,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: Center(child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('lore panel renders its title and content', (tester) async {
    await tester.pumpWidget(_app(const SizedBox(
      width: 300,
      child: PixelLorePanel(title: 'Capiz Heritage', child: Text('Rare')),
    )));
    expect(find.text('Capiz Heritage'), findsOneWidget);
    expect(find.text('Rare'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tappable slot presses on touch and fires on release',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(PixelTappableSlot(
      onTap: () => taps++,
      child: const Text('Slot'),
    )));
    PixelPanel panel() => tester.widget<PixelPanel>(find.byType(PixelPanel));
    expect(panel().pressed, isFalse);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Slot')));
    await tester.pump();
    expect(panel().pressed, isTrue);
    await gesture.up();
    await tester.pump();
    expect(panel().pressed, isFalse);
    expect(taps, 1);
  });

  testWidgets('micro sprites have their frames', (tester) async {
    expect(PixelMicroArt.sparkle.frames, hasLength(4));
    expect(PixelMicroArt.coin.frames, hasLength(4));
    for (final f in [
      ...PixelMicroArt.sparkle.frames,
      ...PixelMicroArt.coin.frames
    ]) {
      expect(f.rows.every((r) => r.length == f.width), isTrue, reason: f.name);
    }
  });

  testWidgets('idle bob steps 1 art px and stops with reduced motion',
      (tester) async {
    await tester.pumpWidget(_app(const PixelIdleBob(child: Text('Icon'))));
    double dy() => tester
        .widget<Transform>(find
            .ancestor(of: find.text('Icon'), matching: find.byType(Transform))
            .first)
        .transform
        .getTranslation()
        .y;
    expect(dy(), 0);
    await tester.pump(const Duration(milliseconds: 520));
    expect(dy(), lessThan(0));
    await tester.pumpWidget(
        _app(const PixelIdleBob(child: Text('Icon')), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 600));
    expect(dy(), 0);
    await tester.pumpAndSettle();
  });

  testWidgets('rolling number steps to the new value; reduced motion jumps',
      (tester) async {
    Widget n(int v, {bool reduce = false}) => _app(
          PixelRollingNumber(value: v, style: const TextStyle()),
          reduceMotion: reduce,
        );
    await tester.pumpWidget(n(150));
    expect(find.text('150'), findsOneWidget);
    await tester.pumpWidget(n(175));
    await tester.pump(const Duration(milliseconds: 130));
    final mid = int.parse((tester.widget<Text>(find.byType(Text)).data)!);
    expect(mid, inExclusiveRange(150, 175));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('175'), findsOneWidget);
    await tester.pumpWidget(n(200, reduce: true));
    await tester.pump();
    expect(find.text('200'), findsOneWidget);
  });
}
