import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';

const _spot = SpotModel(
  id: 'spot-1',
  slug: 'spot-1',
  name: 'Patar Beach',
  description: 'White sand.',
  category: 'nature_outdoors',
  subcategory: 'beach',
  municipality: 'Bolinao',
  address: 'Patar, Bolinao',
  sourceName: 'LGU',
  trustLevel: 'lgu_verified',
  gpsLat: 16.3,
  gpsLng: 119.8,
  tags: [],
  reasons: [],
  likeCount: 4,
);

class _Seeded extends SpotDiscoveryNotifier {
  _Seeded(super.ref) {
    state = const SpotDiscoveryState(
      spots: [_spot],
      trending: [_spot],
      isInitialLoading: false,
    );
  }
}

/// Plan 93b WP-13: likes go to the server and stay in one place.
void main() {
  late List<String> calls;
  late bool fail;

  ProviderContainer container() {
    final client = ApiClient(enableRetries: false);
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(onRequest: (options, handler) {
        calls.add('${options.method} ${options.path}');
        if (fail) {
          return handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ));
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'liked': options.method == 'PUT',
              'like_count': options.method == 'PUT' ? 9 : 8,
            },
          },
        ));
      }),
    );
    final c = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      spotDiscoveryProvider.overrideWith((ref) => _Seeded(ref)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    calls = [];
    fail = false;
  });

  test('like sends PUT, takes the server count, updates spots and trending',
      () async {
    final c = container();
    final notifier = c.read(spotDiscoveryProvider.notifier);
    expect(await notifier.toggleLiked(_spot), isNull);
    expect(calls, ['PUT /spots/spot-1/like']);
    final state = c.read(spotDiscoveryProvider);
    expect(state.spots.single.liked, isTrue);
    expect(state.spots.single.likeCount, 9);
    expect(state.trending.single.liked, isTrue);

    // A stale copy (liked: false) still toggles from the live state: unlike.
    await notifier.toggleLiked(_spot);
    expect(calls.last, 'DELETE /spots/spot-1/like');
    expect(c.read(spotDiscoveryProvider).spots.single.likeCount, 8);
  });

  test('double-tap like is idempotent', () async {
    final c = container();
    final notifier = c.read(spotDiscoveryProvider.notifier);
    await notifier.setLiked(_spot, liked: true);
    await notifier.setLiked(_spot, liked: true);
    expect(calls, ['PUT /spots/spot-1/like']);
  });

  test('a failed like rolls back', () async {
    fail = true;
    final c = container();
    final failure = await c
        .read(spotDiscoveryProvider.notifier)
        .setLiked(_spot, liked: true);
    expect(failure, isNotNull);
    final spot = c.read(spotDiscoveryProvider).spots.single;
    expect(spot.liked, isFalse);
    expect(spot.likeCount, 4);
  });

  test('SpotModel reads liked and like_count, defaulting to 0', () {
    final json = _spot.toJson();
    expect(
        SpotModel.fromJson({...json, 'liked': true, 'like_count': 3}).likeCount,
        3);
    expect(SpotModel.fromJson({...json, 'liked': true}).liked, isTrue);
    final noCount = Map<String, dynamic>.from(json)..remove('like_count');
    expect(SpotModel.fromJson(noCount).likeCount, 0);
  });
}
