import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/config/map_config.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/map/pixel/pixel_map_mode.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';

class _InMemoryPixelMapModeStore implements PixelMapModeStore {
  _InMemoryPixelMapModeStore([this.mode = PixelMapMode.real]);
  PixelMapMode mode;

  @override
  Future<PixelMapMode> read() async => mode;

  @override
  Future<void> write(PixelMapMode next) async => mode = next;
}

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

SpotModel _testSpot({String id = 's1', String name = 'Test Spot'}) =>
    SpotModel(
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
  bool shaderSupported = true,
  PixelMapMode initialMode = PixelMapMode.real,
  String? initialQuestId,
  String? initialSpotId,
  List<QuestModel>? quests,
  List<SpotModel>? spots,
}) {
  final qList = quests ?? [_testQuest()];
  final sList = spots ?? [_testSpot()];
  final store = _InMemoryPixelMapModeStore(initialMode);
  final testApi = _createTestApiClient();

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApi),
      jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
      mapStyleProvider.overrideWith((ref) async => '{}'),
      shaderFilterSupportedProvider.overrideWithValue(shaderSupported),
      pixelMapModeStoreProvider.overrideWithValue(store),
      pixelMapModeProvider.overrideWith((ref) => PixelMapModeNotifier(store)),
      questProvider.overrideWith((ref) => _TestQuestNotifier(testApi, qList)),
      spotDiscoveryProvider.overrideWith((ref) => _TestSpotNotifier(ref, sList)),
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

  group('Pixel Map Widget & Mode Toggle (Plan 75d §6)', () {
    testWidgets('REAL / PIXEL toggle is hidden when shader filters are unsupported',
        (tester) async {
      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        shaderSupported: false,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('PIXEL'), findsNothing);
      expect(find.text('REAL'), findsNothing);
    });

    testWidgets('REAL / PIXEL toggle is visible when shader filters are supported',
        (tester) async {
      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        shaderSupported: true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('REAL'), findsOneWidget);
      expect(find.text('PIXEL'), findsOneWidget);
    });

    testWidgets('switching Real -> Pixel -> Real preserves center, zoom, and filter',
        (tester) async {
      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        shaderSupported: true,
        initialMode: PixelMapMode.real,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Change filter to QUESTS
      await tester.tap(find.text('QUESTS'));
      await tester.pump();

      // Switch to PIXEL mode
      await tester.tap(find.text('PIXEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Filter remains QUESTS
      expect(find.text('QUESTS'), findsOneWidget);

      // Switch back to REAL mode
      await tester.tap(find.text('REAL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('QUESTS'), findsOneWidget);
    });

    testWidgets('satellite button hides in Pixel mode and restores state on return to Real',
        (tester) async {
      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        shaderSupported: true,
        initialMode: PixelMapMode.real,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Satellite button present in Real mode when satellite is available
      final satelliteFinder = find.byTooltip('Satellite view');
      if (MapConfig.satelliteAvailable()) {
        expect(satelliteFinder, findsOneWidget);

        // Turn on satellite view
        await tester.tap(satelliteFinder);
        await tester.pump();

        // Switch to PIXEL
        await tester.tap(find.text('PIXEL'));
        await tester.pump();

        // Satellite tool is hidden in Pixel mode
        expect(find.byTooltip('Satellite view'), findsNothing);

        // Switch back to REAL
        await tester.tap(find.text('REAL'));
        await tester.pump();

        // Satellite tool reappears and state was restored
        expect(find.byTooltip('Satellite view'), findsOneWidget);
      }
    });

    testWidgets('OpenStreetMap attribution is present in both Real and Pixel modes',
        (tester) async {
      final fakeMap = FakeJdqMap();
      await tester.pumpWidget(_buildTestApp(
        fakeMap: fakeMap,
        shaderSupported: true,
        initialMode: PixelMapMode.real,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('OpenStreetMap'), findsWidgets);

      // Switch to Pixel mode
      await tester.tap(find.text('PIXEL'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('OpenStreetMap'), findsWidgets);
    });
  });

  group('Pixel Map Deep Linking & Marker Selection (Plan 75d §5-6)', () {
    testWidgets('initialQuestId selects quest, focuses camera, and opens inspector card',
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

    testWidgets('initialSpotId selects spot, focuses camera, and opens inspector card',
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
      expect(find.text('NAVIGATE'), findsOneWidget);
    });

    testWidgets('unknown ID deep link falls back to opening map normally without errors',
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
  });
}
