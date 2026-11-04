import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/widgets/location_fence_map_picker.dart';

// Phone test 2026-11-01: scrolling the builder page over a task map moved the
// pin. The map is now locked until "Move pin" is tapped.
void main() {
  testWidgets('dragging over the locked map scrolls the page, not the pin',
      (tester) async {
    final changes = <GeoFence>[];
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(children: [
            LocationFenceMapPicker(
              fence:
                  const GeoFence(lat: 16.2044, lng: 120.0406, radiusMeters: 80),
              onChanged: changes.add,
            ),
            const SizedBox(height: 1200),
          ]),
        ),
      ),
    ));
    await tester.pump();

    await tester.drag(
        find.byType(LocationFenceMapPicker), const Offset(0, -200));
    await tester.pump();
    expect(
        changes.where((f) => f.lat != 16.2044 || f.lng != 120.0406), isEmpty);
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(scroll.pixels, greaterThan(100),
        reason: 'the drag should scroll the page');
    scroll.jumpTo(0);
    await tester.pump();

    expect(find.text('Move pin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fence_map_move_pin')));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);
    final ignore = tester.widget<IgnorePointer>(find
        .ancestor(
            of: find.byType(FlutterMap), matching: find.byType(IgnorePointer))
        .first);
    expect(ignore.ignoring, isFalse);
  });
}
