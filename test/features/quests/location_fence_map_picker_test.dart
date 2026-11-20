import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map_canvas.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/widgets/location_fence_map_picker.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
      'fixed centre pin: dragging camera updates point & fence, tap does not drop pin, confirm returns centre',
      (tester) async {
    final fakeMap = FakeJdqMap();
    final changes = <GeoFence>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
        mapStyleProvider.overrideWith((ref) async => '{}'),
      ],
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
    await tester.pumpAndSettle();

    expect(fakeMap.focus, isNotNull);
    // Map is never wrapped in an active IgnorePointer.
    final blockingIgnore = find.ancestor(
      of: find.byType(JdqMapCanvas),
      matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring == true),
    );
    expect(blockingIgnore, findsNothing);

    // Tapping the canvas does not drop a pin on FakeJdqMap.
    await tester.tap(find.byType(JdqMapCanvas));
    await tester.pump();
    expect(changes, isEmpty);

    // Dragging/panning the camera updates the picked point and geofence circle.
    await fakeMap.easeTo(const LatLng(16.2050, 120.0410), 16,
        reducedMotion: true);
    await tester.pump();
    expect(changes.last.lat, closeTo(16.2050, 1e-6));
    expect(changes.last.lng, closeTo(120.0410, 1e-6));
    expect(find.textContaining('16.20500, 120.04100'), findsOneWidget);

    // Confirm button returns the current camera centre.
    changes.clear();
    await tester.tap(find.byKey(const ValueKey('fence_map_use_location')));
    await tester.pump();
    expect(changes.length, 1);
    expect(changes.single.lat, closeTo(16.2050, 1e-6));
    expect(changes.single.lng, closeTo(120.0410, 1e-6));
  });
}
