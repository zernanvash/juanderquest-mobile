import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:latlong2/latlong.dart';

class _TestQuestNotifier extends QuestNotifier {
  _TestQuestNotifier(super.apiClient, List<QuestModel> quests) {
    state = QuestState(quests: quests, isLoading: false);
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _TestSpotNotifier extends SpotDiscoveryNotifier {
  _TestSpotNotifier(super.ref, List<SpotModel> spots) {
    state = SpotDiscoveryState(
      spots: spots,
      categories: const ['nature', 'beach'],
      isInitialLoading: false,
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {}
}

ApiClient _createTestApiClient() {
  final api = ApiClient();
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/shape')) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [120.30, 16.00],
                    [120.40, 16.00],
                    [120.40, 16.10],
                    [120.30, 16.10],
                    [120.30, 16.00],
                  ]
                ],
              },
            ),
          );
          return;
        }
        if (options.path == '/areas') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': [
                  {
                    'id': 'dagupan',
                    'name': 'Dagupan',
                    'display_name': 'Dagupan City',
                    'level': 'city',
                    'label_lat': 16.0433,
                    'label_lng': 120.3333,
                    'has_boundary': true,
                    'bbox': [120.30, 16.00, 120.40, 16.10],
                    'published_spot_count': 5,
                  }
                ],
              },
            ),
          );
          return;
        }
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <Map<String, dynamic>>[]},
          ),
        );
      },
    ),
  );
  return api;
}

QuestModel _testQuest({String id = 'q1', String title = 'Test Quest'}) =>
    QuestModel(
      id: id,
      title: title,
      description: 'Test Quest Description',
      category: 'eco',
      locationName: 'Hundred Islands',
      gpsLat: 16.2000,
      gpsLng: 120.0000,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
    );

SpotModel _testSpot({String id = 's1', String name = 'Test Spot'}) => SpotModel(
      id: id,
      slug: id,
      name: name,
      description: 'Test Spot Description',
      category: 'nature',
      subcategory: 'beach',
      municipality: 'Alaminos',
      address: 'Lucap, Alaminos',
      sourceName: 'Editorial',
      trustLevel: 'lgu_verified',
      gpsLat: 16.2100,
      gpsLng: 120.0100,
      tags: const [],
      reasons: const [],
    );

Widget _buildTestApp({
  required FakeJdqMap fakeMap,
  String? initialQuestId,
  String? initialSpotId,
  List<QuestModel>? quests,
  List<SpotModel>? spots,
}) {
  final qList = quests ?? [_testQuest()];
  final sList = spots ?? [_testSpot()];
  final testApi = _createTestApiClient();

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApi),
      jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
      mapStyleProvider.overrideWith((ref) async => '{}'),
      questProvider.overrideWith((ref) => _TestQuestNotifier(testApi, qList)),
      spotDiscoveryProvider
          .overrideWith((ref) => _TestSpotNotifier(ref, sList)),
      choiceSpotlightProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      home: MapViewScreen(
        initialQuestId: initialQuestId,
        initialSpotId: initialSpotId,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pixel Map Deep Linking & Marker Selection (Plan 75d §5-6)', () {
    testWidgets(
        'initialQuestId selects quest, focuses camera, and opens inspector card',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final quest = _testQuest(id: 'quest-123', title: 'Deep Quest');

      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        initialQuestId: 'quest-123',
        quests: [quest],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Inspector card displays quest title and details
      expect(find.text('Deep Quest'), findsWidgets);
      expect(find.text('VIEW DETAILS'), findsOneWidget);
    });

    testWidgets(
        'initialSpotId selects spot, focuses camera, and opens inspector card',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final spot = _testSpot(id: 'spot-456', name: 'Deep Spot');

      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        initialSpotId: 'spot-456',
        spots: [spot],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Inspector card displays spot name and details
      expect(find.text('Deep Spot'), findsWidgets);
      expect(find.text('ROUTE HERE'), findsOneWidget);
      expect(find.text('EXPLORE SPOT'), findsOneWidget);
    });

    testWidgets(
        'unknown ID deep link falls back to opening map normally without errors',
        (tester) async {
      final fakeMap = FakeJdqMap();

      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        initialQuestId: 'unknown-id',
        initialSpotId: 'unknown-spot',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      expect(find.text('MAP'), findsOneWidget);
    });

    testWidgets(
        'Map opens completely unobstructed on startup without auto-selected card (Plan 82 WP-1)',
        (tester) async {
      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(fakeMap: fakeMap));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // No inspector card or action button is popped up on initial open
      expect(find.byKey(const ValueKey('marker_inspector_card')), findsNothing);
      expect(find.text('ROUTE HERE'), findsNothing);
      expect(find.text('VIEW DETAILS'), findsNothing);
      expect(find.text('EXPLORE SPOT'), findsNothing);
      expect(find.text('LIST'), findsNothing);
    });

    testWidgets(
        'SIM/TEST prefix is stripped from title and TEST chip is shown (Plan 82 §5.7)',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final quest = _testQuest(id: 'q-test', title: 'SIM · Patar Coastal Trek');
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        initialQuestId: 'q-test',
        quests: [quest],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Patar Coastal Trek'), findsWidgets);
      expect(find.text('TEST'), findsOneWidget);
    });

    testWidgets(
        'Semantic zoom hierarchy: pins hidden at macro zoom < 9.5, quests at 9.5-11, spots at >= 11 (Plan 82 WP-2)',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final quest = _testQuest(id: 'q1', title: 'Quest 1');
      final spot = _testSpot(id: 's1', name: 'Spot 1');

      // Macro overview (zoom 8.0): 0 pins
      fakeMap.camera = fakeMap.camera.copyWith(zoom: 8.0);
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        quests: [quest],
        spots: [spot],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(fakeMap.pins, isEmpty);

      // Regional overview (zoom 10.0): quests only
      fakeMap.camera = fakeMap.camera.copyWith(zoom: 10.0);
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        quests: [quest],
        spots: [spot],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(fakeMap.pins.map((p) => p.id), ['quest:q1']);

      // Local zoom (zoom 12.0): both quests and spots
      fakeMap.camera = fakeMap.camera.copyWith(zoom: 12.0);
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        quests: [quest],
        spots: [spot],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(fakeMap.pins.map((p) => p.id), ['quest:q1', 'spot:s1']);
    });

    testWidgets(
        'Dossier card for spot has ROUTE HERE, EXPLORE SPOT, and no TrailPreviewCard (Plan 82 WP-4)',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final spot =
          _testSpot(id: 'spot-dossier', name: 'Cape Bolinao Lighthouse');
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        initialSpotId: 'spot-dossier',
        spots: [spot],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Cape Bolinao Lighthouse'), findsWidgets);
      expect(find.text('ROUTE HERE'), findsOneWidget);
      expect(find.text('EXPLORE SPOT'), findsOneWidget);
      expect(find.textContaining('IN DEVELOPMENT'), findsNothing);
    });

    testWidgets(
        'Plan 82b WP-2 & WP-3: Empty map tap does not select town, label tap focuses town, tap outside clears',
        (tester) async {
      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(fakeMap: fakeMap));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // 1. onTapEmpty with nothing focused -> nothing focused
      fakeMap.onTapEmpty?.call(const LatLng(16.0433, 120.3333));
      await tester.pump();
      expect(fakeMap.focus, isNull);
      expect(find.text('DAGUPAN'), findsNothing);

      // 2. onTapPlace('dagupan') -> Dagupan focused
      fakeMap.onTapPlace?.call('dagupan');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(fakeMap.focus, isNotNull);
      expect(find.text('DAGUPAN'), findsWidgets);

      // 3. onTapPlace('dagupan') again while focused -> still focused, no flicker
      fakeMap.onTapPlace?.call('dagupan');
      await tester.pump();
      expect(fakeMap.focus, isNotNull);

      // 4. onTapEmpty inside focused town (16.05, 120.35 is inside [120.30, 16.00] - [120.40, 16.10]) -> still focused
      fakeMap.onTapEmpty?.call(const LatLng(16.05, 120.35));
      await tester.pump();
      expect(fakeMap.focus, isNotNull);

      // 5. onTapEmpty outside focused town (15.50, 119.50 is outside) -> focus cleared
      fakeMap.onTapEmpty?.call(const LatLng(15.50, 119.50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fakeMap.focus, isNull);
    });

    testWidgets(
        'Plan 82b WP-4: Standalone POST SPOT FAB and posting banner flow',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(fakeMap: fakeMap));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // FAB is visible on empty map
      final fabFinder = find.byKey(const ValueKey('map_post_spot_fab'));
      expect(fabFinder, findsOneWidget);
      expect(find.text('+ POST SPOT'), findsOneWidget);

      // Tap FAB -> enters pin placement mode
      tester.widget<PixelButton>(fabFinder).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Top banner shows and FAB is hidden while posting
      expect(find.byKey(const ValueKey('map_post_spot_banner')), findsOneWidget);
      expect(find.text('POST A DESTINATION SPOT'), findsOneWidget);
      expect(
        find.text('Move the map so the crosshair is on the place.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('map_post_spot_fab')), findsNothing);

      // Close [X] on the banner cancels pin placement
      final closeFinder = find.descendant(
        of: find.byKey(const ValueKey('map_post_spot_banner')),
        matching: find.byType(PixelIconButton),
      );
      expect(closeFinder, findsOneWidget);
      tester.widget<PixelIconButton>(closeFinder).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Posting ended: banner gone, FAB restored
      expect(find.byKey(const ValueKey('map_post_spot_banner')), findsNothing);
      expect(find.byKey(const ValueKey('map_post_spot_fab')), findsOneWidget);
    });

    testWidgets(
        'Plan 82b WP-4: POST SPOT FAB is hidden when a pin card is open',
        (tester) async {
      final fakeMap = FakeJdqMap();
      final spot = _testSpot(id: 'spot-dossier', name: 'Cape Bolinao');
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        initialSpotId: 'spot-dossier',
        spots: [spot],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Inspector card is open, FAB is hidden
      expect(find.text('Cape Bolinao'), findsWidgets);
      expect(find.byKey(const ValueKey('map_post_spot_fab')), findsNothing);
    });
  });
}
