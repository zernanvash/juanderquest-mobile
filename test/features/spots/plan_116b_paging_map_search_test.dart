import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/search/recent_searches.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/festival_calendar_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_recommended_quest_provider.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/repositories/spots_cache_repository.dart';
import 'package:juanderquest_app/features/spots/screens/spot_explore_screen.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> _spotJson(String id, {bool saved = false, String? crowd}) =>
    <String, dynamic>{
      'id': id,
      'slug': id,
      'name': 'Spot $id',
      'description': 'Description for $id',
      'category': 'nature_outdoors',
      'subcategory': 'beach',
      'municipality': 'Alaminos',
      'address': 'Lucap, Alaminos',
      'source_name': 'Editorial',
      'trust_level': 'lgu_verified',
      'crowd_status': crowd ?? 'quiet',
      'crowd_confidence': 'low',
      'gps_lat': 16.21,
      'gps_lng': 120.01,
      'saved': saved,
      'liked': false,
      'like_count': 0,
      'tags': const <String>[],
      'recommendation_reasons': const <String>[],
    };

class _InertAuth extends AuthNotifier {
  _InertAuth(super.apiClient, super.refreshNotifier) {
    state = AuthState(
      user: UserModel(
        id: 'u-1',
        seedId: 'u-1',
        displayName: 'Explorer',
        email: 'explorer@example.com',
        avatarUrl: '',
        role: 'user',
        demoPoints: 100,
      ),
      token: 'tok',
    );
  }

  @override
  Future<void> refreshProfile() async {}
}

class _InertQuestNotifier extends QuestNotifier {
  _InertQuestNotifier(super.apiClient) {
    state = QuestState(quests: <QuestModel>[], isLoading: false);
  }

  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _InertSubmissionNotifier extends SubmissionNotifier {
  _InertSubmissionNotifier(super.apiClient);

  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 116b Part 2: Cursor Paging, Viewport Map, Typeahead & Bounded Callers',
      () {
    test(
        'SpotDiscoveryNotifier paginates with cursor, deduplicates IDs, stops at null cursor, and caches per filter',
        () async {
      final api = ApiClient();
      final spotRequests = <Map<String, dynamic>>[];
      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/spots') {
              spotRequests.add(Map<String, dynamic>.from(options.queryParameters));
              final cursor = options.queryParameters['cursor'];
              final q = options.queryParameters['q']?.toString() ?? '';
              if (q == 'bolinao') {
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'success': true,
                      'data': [_spotJson('bol-1')],
                      'meta': {'count': 1, 'total': 1, 'next_cursor': null},
                    },
                  ),
                );
              }
              if (cursor == null) {
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'success': true,
                      'data': [_spotJson('s1'), _spotJson('s2')],
                      'meta': {'count': 2, 'total': 3, 'next_cursor': 'cur_2'},
                    },
                  ),
                );
              }
              if (cursor == 'cur_2') {
                // Intentionally repeats s2 to verify client deduplication
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'success': true,
                      'data': [_spotJson('s2'), _spotJson('s3')],
                      'meta': {'count': 2, 'total': 3, 'next_cursor': null},
                    },
                  ),
                );
              }
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': const []},
              ),
            );
          },
        ),
      );

      final memoryCache = <String, String>{};
      final cacheRepo = SpotsCacheRepository(memoryFallback: memoryCache);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          spotsCacheRepositoryProvider.overrideWithValue(cacheRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(spotDiscoveryProvider.notifier);
      await notifier.load();

      expect(spotRequests.first['limit'], 30);
      expect(container.read(spotDiscoveryProvider).spots.map((s) => s.id),
          ['s1', 's2']);
      expect(container.read(spotDiscoveryProvider).nextCursor, 'cur_2');

      await notifier.loadMore();
      expect(spotRequests.last['cursor'], 'cur_2');
      expect(spotRequests.last['limit'], 30);
      expect(container.read(spotDiscoveryProvider).spots.map((s) => s.id),
          ['s1', 's2', 's3']);
      expect(container.read(spotDiscoveryProvider).nextCursor, isNull);

      // No-op once next_cursor is null
      final callsBeforeExtraLoad = spotRequests.length;
      await notifier.loadMore();
      expect(spotRequests.length, callsBeforeExtraLoad);

      // Base cache still keeps only page 1 (2 items), not accumulated page 2
      final baseCached = await cacheRepo.loadSpots(
        partition: SpotsCacheRepository.partitionForFilter(),
      );
      expect(baseCached?.spots.map((s) => s.id), ['s1', 's2']);

      // Search filter resets list & caches under filter-specific partition
      await notifier.load(query: 'bolinao');
      expect(container.read(spotDiscoveryProvider).spots.map((s) => s.id),
          ['bol-1']);
      final queryCached = await cacheRepo.loadSpots(
        partition: SpotsCacheRepository.partitionForFilter(query: 'bolinao'),
      );
      expect(queryCached?.spots.map((s) => s.id), ['bol-1']);

      // Every /spots call included explicit limit=
      for (final req in spotRequests) {
        expect(req['limit'], isNotNull);
      }
    });

    testWidgets(
        'MapViewScreen debounces /spots/map 300ms, cancels in-flight on camera move, and zooms to cluster bbox on tap',
        (tester) async {
      final api = ApiClient();
      final mapRequests = <Map<String, dynamic>>[];
      var cancelledCount = 0;
      Completer<void>? firstGate;

      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/spots/map') {
              mapRequests.add(Map<String, dynamic>.from(options.queryParameters));
              final cancelToken = options.cancelToken;
              if (cancelToken != null) {
                unawaited(
                  cancelToken.whenCancel.then((_) {
                    cancelledCount++;
                  }),
                );
              }
              if (mapRequests.length == 2 && firstGate != null) {
                await firstGate.future;
                if (cancelToken?.isCancelled == true) {
                  return handler.reject(
                    DioException.requestCancelled(
                      requestOptions: options,
                      reason: 'cancelled',
                    ),
                  );
                }
              }
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': {
                      'markers': [
                        {
                          'id': 'm-1',
                          'slug': 'm-1',
                          'name': 'Coastal Pin',
                          'lat': 16.05,
                          'lng': 120.32,
                          'category': 'nature_outdoors',
                          'tier': 'featured',
                          'thumb': null,
                        }
                      ],
                      'clusters': [
                        {
                          'lat': 16.20,
                          'lng': 120.00,
                          'count': 12,
                          'bbox': [119.90, 16.10, 120.15, 16.30],
                        }
                      ],
                    },
                    'meta': {'total': 13},
                  },
                ),
              );
            }
            if (options.path == '/spots') {
              fail('MapViewScreen must never trigger unrequested GET /spots');
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': const []},
              ),
            );
          },
        ),
      );

      final fakeMap = FakeJdqMap()
        ..camera = const JdqCamera(
          center: LatLng(16.035, 120.333),
          zoom: 9.0,
          southWest: LatLng(15.5, 119.5),
          northEast: LatLng(16.6, 121.0),
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            jdqMapFactoryProvider.overrideWithValue(() => fakeMap),
            mapStyleProvider.overrideWith((ref) async => '{}'),
            authProvider.overrideWith(
              (ref) => _InertAuth(
                ref.watch(apiClientProvider),
                ref.watch(authRefreshProvider.notifier),
              ),
            ),
            questProvider.overrideWith(
              (ref) => _InertQuestNotifier(ref.watch(apiClientProvider)),
            ),
            submissionProvider.overrideWith(
              (ref) => _InertSubmissionNotifier(ref.watch(apiClientProvider)),
            ),
            choiceSpotlightProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: MapViewScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Initial /spots/map request landed (markers + clusters independent of Explore)
      expect(mapRequests.length, 1);
      expect(fakeMap.pins.any((p) => p.id == 'cluster:0' && p.clusterCount == 12),
          isTrue);
      expect(fakeMap.pins.any((p) => p.id == 'spot:m-1'), isTrue);

      // Simulate slow 2nd viewport fetch, then camera moves again -> 1st cancelled
      firstGate = Completer<void>();
      fakeMap.onCameraIdle?.call();
      await tester.pump(const Duration(milliseconds: 100));
      // Before 300ms debounce, second request hasn't fired yet
      expect(mapRequests.length, 1);

      await tester.pump(const Duration(milliseconds: 250));
      expect(mapRequests.length, 2);

      // Moving camera again cancels request #2 via CancelToken
      fakeMap.onCameraIdle?.call();
      await tester.pump();
      expect(cancelledCount, 1);

      firstGate.complete();
      await tester.pump(const Duration(milliseconds: 350));
      expect(mapRequests.length, 3);

      // Tap cluster:0 -> fitBounds zooms to cluster bbox [119.90, 16.10, 120.15, 16.30]
      final beforeFit = fakeMap.fitBoundsCallCount;
      fakeMap.onTapPin?.call('cluster:0');
      await tester.pump();
      expect(fakeMap.fitBoundsCallCount, beforeFit + 1);
      expect(fakeMap.camera.southWest.latitude, closeTo(16.10, 0.001));
      expect(fakeMap.camera.southWest.longitude, closeTo(119.90, 0.001));
      expect(fakeMap.camera.northEast.latitude, closeTo(16.30, 0.001));
      expect(fakeMap.camera.northEast.longitude, closeTo(120.15, 0.001));
    });

    testWidgets(
        'Explore Search typeahead uses /spots/search with 250ms debounce & >=2 chars, submits bounded q= reload',
        (tester) async {
      final api = ApiClient();
      final spotCalls = <Map<String, dynamic>>[];
      final searchCalls = <Map<String, dynamic>>[];

      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/spots/search') {
              searchCalls.add(Map<String, dynamic>.from(options.queryParameters));
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': [
                      {
                        'id': 'hit-1',
                        'slug': 'bolinao-falls',
                        'name': 'Bolinao Falls',
                        'municipality': 'Bolinao',
                        'category': 'nature_outdoors',
                        'tier': 'standard',
                        'thumb': null,
                      }
                    ],
                    'meta': {'count': 1},
                  },
                ),
              );
            }
            if (options.path == '/spots') {
              spotCalls.add(Map<String, dynamic>.from(options.queryParameters));
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': [_spotJson('exp-1')],
                    'meta': {'count': 1, 'total': 1, 'next_cursor': null},
                  },
                ),
              );
            }
            if (options.path == '/spot-taxonomy') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': {'categories': const [], 'tags': const []},
                  },
                ),
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': const []},
              ),
            );
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            spotsCacheRepositoryProvider.overrideWithValue(
              SpotsCacheRepository(memoryFallback: <String, String>{}),
            ),
            authProvider.overrideWith(
              (ref) => _InertAuth(
                ref.watch(apiClientProvider),
                ref.watch(authRefreshProvider.notifier),
              ),
            ),
            questProvider.overrideWith(
              (ref) => _InertQuestNotifier(ref.watch(apiClientProvider)),
            ),
            choiceSpotlightProvider.overrideWith((ref) async => null),
            hiddenGemProvider.overrideWith((ref) async => const []),
            festivalCalendarProvider.overrideWith((ref, y) async => const []),
            recentSearchesProvider
                .overrideWith((ref) => RecentSearchesNotifier(load: false)),
          ],
          child: const MaterialApp(home: SpotExploreScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(spotCalls.length, 1);
      expect(spotCalls.first['limit'], 30);

      // Typing 1 char does NOT call /spots/search
      await tester.tap(find.byKey(const ValueKey('explore_search_field')));
      await tester.enterText(
          find.byKey(const ValueKey('explore_search_field')), 'b');
      await tester.pump(const Duration(milliseconds: 300));
      expect(searchCalls, isEmpty);

      // Typing >=2 chars calls /spots/search after 250ms debounce
      await tester.enterText(
          find.byKey(const ValueKey('explore_search_field')), 'bolinao');
      await tester.pump(const Duration(milliseconds: 100));
      expect(searchCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(searchCalls.length, 1);
      expect(searchCalls.first['q'], 'bolinao');
      expect(searchCalls.first['limit'], 15);
      await tester.pump();
      expect(find.text('Bolinao Falls'), findsOneWidget);

      // Submitting runs Explore list with bounded limit=30 and q=bolinao
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(spotCalls.last['q'], 'bolinao');
      expect(spotCalls.last['limit'], 30);
    });

    test('All remaining spot callers send explicit bounded /spots limits',
        () async {
      final api = ApiClient();
      api.setAuthToken('test-token');
      final spotQueries = <Map<String, dynamic>>[];

      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/spots') {
              spotQueries.add(Map<String, dynamic>.from(options.queryParameters));
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': [_spotJson('b1', saved: true, crowd: 'estimated_busy')],
                    'meta': {'count': 1, 'total': 1, 'next_cursor': null},
                  },
                ),
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': const []},
              ),
            );
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          homeLastKnownLocationProvider.overrideWith(
            (ref) async => (lat: 16.03, lng: 120.33),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Resolve homeLastKnownLocationProvider first so homeNearbySpotsProvider uses it
      await container.read(homeLastKnownLocationProvider.future);
      final nearby = await container.read(homeNearbySpotsProvider.future);
      final busy = await container.read(companionBusySpotsProvider.future);
      final saved = await container.read(boundedSavedSpotsProvider.future);
      final sample = await container.read(pixelLabSampleSpotProvider.future);

      expect(nearby.length, 1);
      expect(busy.length, 1);
      expect(saved.length, 1);
      expect(sample?.id, 'b1');

      expect(spotQueries.length, 4);
      expect(spotQueries[0]['limit'], 10);
      expect(spotQueries[0]['lat'], 16.03);
      expect(spotQueries[0]['lng'], 120.33);
      expect(spotQueries[0]['radius_km'], 25);
      expect(spotQueries[1]['limit'], 10);
      expect(spotQueries[2]['limit'], 50);
      expect(spotQueries[3]['limit'], 1);
      for (final q in spotQueries) {
        expect(q['limit'], isNotNull);
      }
    });
  });
}
