import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/utils/map_marker_hierarchy.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';

QuestModel _quest(String id, {double lat = 16.025, double lng = 120.231}) =>
    QuestModel(
      id: id,
      title: 'Quest $id',
      description: 'Test quest',
      category: 'cultural',
      locationName: 'Lingayen',
      gpsLat: lat,
      gpsLng: lng,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
    );

SpotModel _spot({SpotLocalPartner? partner}) => SpotModel(
      id: 'spot-1',
      slug: 'kape-pangasinan',
      name: 'Kape Pangasinan',
      description: 'Heritage baywalk coffee shop.',
      category: 'food_dining',
      subcategory: 'cafe',
      municipality: 'Lingayen',
      address: 'Baywalk Rd',
      sourceName: 'Community',
      trustLevel: 'community',
      gpsLat: 16.025,
      gpsLng: 120.231,
      tags: const [],
      reasons: const [],
      localPartner: partner,
    );

void main() {
  group('Plan 122a — 3-tier map marker hierarchy', () {
    test(
      'maps spot, merchant, quest, questDone, and reverted quests accurately',
      () {
        expect(
          resolveSpotMarkerPinKind(
            markerKind: 'spot',
            isLocalPartner: false,
            activeQuestIds: const [],
            completedQuestIds: const {},
            showDoneQuests: true,
          ),
          JdqPinKind.spot,
        );

        expect(
          resolveSpotMarkerPinKind(
            markerKind: 'merchant',
            isLocalPartner: true,
            activeQuestIds: const [],
            completedQuestIds: const {},
            showDoneQuests: true,
          ),
          JdqPinKind.merchant,
        );

        expect(
          resolveSpotMarkerPinKind(
            markerKind: 'quest',
            isLocalPartner: true,
            activeQuestIds: const ['q1'],
            completedQuestIds: const {},
            showDoneQuests: true,
          ),
          JdqPinKind.quest,
        );

        // All active quests done -> stays questDone while active quest exists
        expect(
          resolveSpotMarkerPinKind(
            markerKind: 'quest',
            isLocalPartner: true,
            activeQuestIds: const ['q1'],
            completedQuestIds: const {'q1'},
            showDoneQuests: true,
          ),
          JdqPinKind.questDone,
        );

        // If showDoneQuests is toggled off, falls back to merchant (or spot) so destination stays visible
        expect(
          resolveSpotMarkerPinKind(
            markerKind: 'quest',
            isLocalPartner: true,
            activeQuestIds: const ['q1'],
            completedQuestIds: const {'q1'},
            showDoneQuests: false,
          ),
          JdqPinKind.merchant,
        );

        // Once quest is drafted/inactive, backend sends marker_kind = 'merchant' or 'spot'
        expect(
          resolveSpotMarkerPinKind(
            markerKind: 'merchant',
            isLocalPartner: true,
            activeQuestIds: const [],
            completedQuestIds: const {'q1'},
            showDoneQuests: true,
          ),
          JdqPinKind.merchant,
        );
      },
    );

    test(
      'suppresses duplicate overlapping quest: pin when represented by a visible spot marker',
      () {
        final marker = SpotMapMarker.fromJson(const {
          'id': 'spot-1',
          'slug': 'kape-pangasinan',
          'name': 'Kape Pangasinan',
          'lat': 16.025,
          'lng': 120.231,
          'category': 'food_dining',
          'marker_kind': 'quest',
          'is_local_partner': true,
          'merchant_id': 'm-1',
          'merchant_name': 'Kape Roasters',
          'active_quest_count': 1,
          'active_quest_ids': ['q-bound'],
        });

        final pins = buildUnifiedMapPins(
          clusters: const [],
          viewportMarkers: [marker],
          fallbackSpots: const [],
          hasViewportMapData: true,
          visibleQuests: [_quest('q-bound'), _quest('q-standalone')],
          completedQuestIds: const {},
          showDoneQuests: true,
        );

        expect(pins.where((p) => p.id == 'quest:q-bound'), isEmpty);
        expect(pins.where((p) => p.id == 'quest:q-standalone'), hasLength(1));
        final spotPin = pins.firstWhere((p) => p.id == 'spot:spot-1');
        expect(spotPin.kind, JdqPinKind.quest);
        expect(spotPin.kindWire, 'quest');
      },
    );

    testWidgets(
      'SpotDetailScreen shows LOCAL PARTNER badge only when localPartner != null',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: PixelScope(
                settings: const PixelSettings(),
                child: SpotDetailScreen(
                  key: const ValueKey('spot_without_partner'),
                  spot: _spot(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(
            const ValueKey('spot_detail_local_partner_badge'),
            skipOffstage: false,
          ),
          findsNothing,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: PixelScope(
                settings: const PixelSettings(),
                child: SpotDetailScreen(
                  key: const ValueKey('spot_with_partner'),
                  spot: _spot(
                    partner: const SpotLocalPartner(
                      merchantId: 'm-1',
                      name: 'Kape Roasters',
                      category: 'Cafe',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('spot_detail_local_partner_badge')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.byKey(const ValueKey('spot_detail_local_partner_badge')),
          findsOneWidget,
        );
        expect(find.text('LOCAL PARTNER'), findsOneWidget);
        expect(find.text('Kape Roasters'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });
}
