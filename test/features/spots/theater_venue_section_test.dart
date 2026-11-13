import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map_canvas.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/theater/theater_venue_section.dart';

void main() {
  testWidgets('TheaterVenueSection renders JdqMapCanvas with spot pin',
      (tester) async {
    final fakeMap = FakeJdqMap();
    const spot = SpotModel(
      id: 'spot-1',
      name: 'Hundred Islands',
      slug: 'hundred-islands',
      description: 'Marine reserve',
      category: 'nature',
      subcategory: 'islands',
      municipality: 'Alaminos',
      address: 'Lucap Wharf, Alaminos',
      sourceName: 'lgu',
      trustLevel: 'verified',
      gpsLat: 16.201,
      gpsLng: 120.038,
      tags: [],
      reasons: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
          mapStyleProvider.overrideWith((ref) async => '{}'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TheaterVenueSection(
                spot: spot,
                onDirections: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JdqMapCanvas), findsOneWidget);
    expect(fakeMap.pins, hasLength(1));
    expect(fakeMap.pins.first.id, 'spot:spot-1');
    expect(fakeMap.camera.center.latitude, closeTo(16.201, 1e-6));
  });
}
