import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map_canvas.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/profile/screens/affiliate_application_screen.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
      'AffiliateApplicationScreen uses fixed centre pin (drag camera, tap does not drop pin, confirm returns centre)',
      (tester) async {
    final fakeMap = FakeJdqMap();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
          mapStyleProvider.overrideWith((ref) async => '{}'),
        ],
        child: const MaterialApp(
          home: AffiliateApplicationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JdqMapCanvas), findsOneWidget);

    // Tapping does not drop a pin on the map.
    fakeMap.onTapEmpty?.call(const LatLng(16.041, 120.335));
    await tester.pump();
    expect(fakeMap.pins, isEmpty);

    // Dragging/panning the camera updates the centre pin coordinates.
    await fakeMap.easeTo(const LatLng(16.041, 120.335), 15,
        reducedMotion: true);
    await tester.pump();
    expect(find.textContaining('Pin: 16.041000, 120.335000'), findsOneWidget);

    // Confirm button returns/keeps the current camera centre.
    final confirmBtn = find.byKey(const ValueKey('affiliate_confirm_location'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pump();
    expect(find.textContaining('Pin: 16.041000, 120.335000'), findsOneWidget);
  });
}
