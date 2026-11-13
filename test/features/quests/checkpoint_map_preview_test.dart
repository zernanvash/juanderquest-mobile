import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map_canvas.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/pixel/checkpoint_map_preview.dart';

void main() {
  testWidgets('CheckpointMapPreview renders JdqMapCanvas, sets pin, and fires onTap',
      (tester) async {
    final fakeMap = FakeJdqMap();
    var tapped = false;
    final quest = QuestModel(
      id: 'q-1',
      title: 'Tondaligan Beacon',
      description: 'Visit Tondaligan Beach',
      category: 'heritage',
      locationName: 'Dagupan City',
      gpsLat: 16.075,
      gpsLng: 120.345,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
          mapStyleProvider.overrideWith((ref) async => '{}'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CheckpointMapPreview(
              quest: quest,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JdqMapCanvas), findsOneWidget);
    expect(fakeMap.pins, hasLength(1));
    expect(fakeMap.pins.first.id, 'quest:q-1');
    expect(fakeMap.camera.center.latitude, closeTo(16.075, 1e-6));

    await tester.tap(find.byType(CheckpointMapPreview));
    expect(tapped, isTrue);
  });
}
