import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map_canvas.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/spots/screens/spot_discovery_studio_screen.dart';
import 'package:juanderquest_app/features/spots/utils/spot_location_handoff.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('SpotDiscoveryStudioScreen uses JdqMapCanvas and eases on tap',
      (tester) async {
    final fakeMap = FakeJdqMap();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
          mapStyleProvider.overrideWith((ref) async => '{}'),
        ],
        child: const MaterialApp(
          home: SpotDiscoveryStudioScreen(
            routePin: StudioPin(16.043, 120.333, 16),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JdqMapCanvas), findsOneWidget);
    expect(fakeMap.camera.center.latitude, closeTo(16.043, 1e-6));

    fakeMap.onTapEmpty?.call(const LatLng(16.050, 120.340));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(fakeMap.camera.center.latitude, closeTo(16.050, 1e-6));
  });
}
