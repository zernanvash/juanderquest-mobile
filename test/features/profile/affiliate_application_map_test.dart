import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map_canvas.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/profile/screens/affiliate_application_screen.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('AffiliateApplicationScreen uses JdqMapCanvas and places pin on tap',
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

    fakeMap.onTapEmpty?.call(const LatLng(16.041, 120.335));
    await tester.pump();

    expect(fakeMap.pins, hasLength(1));
    expect(fakeMap.pins.first.point.latitude, closeTo(16.041, 1e-6));
    expect(find.textContaining('Pin: 16.041000, 120.335000'), findsOneWidget);
  });
}
