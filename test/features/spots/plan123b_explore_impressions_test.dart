import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/providers/explore_impression_batcher.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/repositories/spots_cache_repository.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSpotsCacheRepository extends SpotsCacheRepository {
  _FakeSpotsCacheRepository() : super(memoryFallback: {});
}

void main() {
  group('Plan 123b: ExploreImpressionBatcher', () {
    test('cancels <1s dwell, flushes at 5s debounce and on app pause', () {
      fakeAsync((async) {
        final sent = <List<String>>[];
        final batcher = ExploreImpressionBatcher(
          isAuthenticated: () => true,
          sendBatch: (ids) async => sent.add(ids),
        );

        // Seen for 500ms then scrolled out (<50%) -> cancelled
        batcher.onVisibilityChanged('spot-short', 0.8);
        async.elapse(const Duration(milliseconds: 500));
        batcher.onVisibilityChanged('spot-short', 0.2);
        async.elapse(const Duration(seconds: 6));
        expect(sent, isEmpty);

        // Seen >= 50% for 1s -> queued, flushes after 5s debounce
        batcher.onVisibilityChanged('spot-a', 0.6);
        async.elapse(const Duration(seconds: 1));
        expect(batcher.queuedCount, 1);
        expect(sent, isEmpty);

        async.elapse(const Duration(seconds: 5));
        expect(sent, [
          ['spot-a'],
        ]);

        // Queued then app pauses -> flushes immediately
        batcher.onVisibilityChanged('spot-b', 0.75);
        async.elapse(const Duration(seconds: 1));
        expect(batcher.queuedCount, 1);
        batcher.onAppPaused();
        expect(sent, [
          ['spot-a'],
          ['spot-b'],
        ]);

        batcher.dispose();
      });
    });

    test('flushes immediately at 10 IDs and skips guests', () {
      fakeAsync((async) {
        var authed = false;
        final sent = <List<String>>[];
        final batcher = ExploreImpressionBatcher(
          isAuthenticated: () => authed,
          sendBatch: (ids) async => sent.add(ids),
        );

        // Guest sends nothing
        batcher.onVisibilityChanged('spot-guest', 1.0);
        async.elapse(const Duration(seconds: 7));
        expect(sent, isEmpty);

        authed = true;
        for (var i = 0; i < 10; i++) {
          batcher.onVisibilityChanged('spot-$i', 0.9);
        }
        async.elapse(const Duration(seconds: 1));
        expect(sent.length, 1);
        expect(sent.first.length, 10);
        batcher.dispose();
      });
    });
  });

  group('Plan 123b: SpotDiscoveryNotifier refresh_seed & passive lat/lng', () {
    test('ProviderContainer verifies refresh_seed stability, rotation, and 2-decimal passive lat/lng', () async {
      final recordedParams = <Map<String, dynamic>>[];
      final apiClient = ApiClient(enableRetries: false);
      apiClient.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/spots') {
              recordedParams.add(Map<String, dynamic>.from(options.queryParameters));
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': [
                    {
                      'id': 'sp-${recordedParams.length}',
                      'slug': 'sp-${recordedParams.length}',
                      'name': 'Spot ${recordedParams.length}',
                      'description': 'Desc',
                      'category': 'nature_outdoors',
                      'subcategory': 'beach',
                      'tags': <String>[],
                      'municipality': 'Bolinao',
                      'address': 'Addr',
                      'gps_lat': 16.0,
                      'gps_lng': 120.0,
                      'price_level': 0,
                      'hours': <String, dynamic>{},
                      'amenities': <String>[],
                      'source_type': 'editorial',
                      'source_name': 'JDQ',
                      'trust_level': 'editorial',
                      'status': 'published',
                    },
                  ],
                  'meta': {
                    'count': 1,
                    'total': 2,
                    'next_cursor': 'cursor-2',
                  },
                },
              ),
            );
          },
        ),
      );

      final testProvider =
          StateNotifierProvider<SpotDiscoveryNotifier, SpotDiscoveryState>((ref) {
        return SpotDiscoveryNotifier(
          ref,
          _FakeSpotsCacheRepository(),
          () async => (lat: 16.38491, lng: 119.89421),
        );
      });

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          authProvider.overrideWith(
            (_) => _FakeAuthNotifier(AuthState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(testProvider.notifier);
      await notifier.loadFiltered();
      expect(recordedParams.length, 1);
      final initialSeed = recordedParams[0]['refresh_seed'] as String?;
      expect(initialSeed, isNotNull);
      expect(recordedParams[0]['lat'], 16.38);
      expect(recordedParams[0]['lng'], 119.89);

      // Paging reuses the exact same refresh_seed
      await notifier.loadMore();
      expect(recordedParams.length, 2);
      expect(recordedParams[1]['refresh_seed'], initialSeed);
      expect(recordedParams[1]['cursor'], 'cursor-2');

      // Pull-to-refresh generates a new refresh_seed
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await notifier.loadFiltered(refresh: true);
      expect(recordedParams.length, 3);
      expect(recordedParams[2]['refresh_seed'], isNot(initialSeed));
    });
  });
}
