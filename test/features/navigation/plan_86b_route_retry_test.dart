import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';

class _RouteRetryAdapter implements HttpClientAdapter {
  int postRoutesCalls = 0;
  final List<String?> idempotencyKeys = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/routes' && options.method == 'POST') {
      postRoutesCalls++;
      idempotencyKeys.add(options.headers['Idempotency-Key']?.toString());
      if (postRoutesCalls == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {
            'degraded': false,
            'navigationMode': 'turn_by_turn',
            'summary': {
              'distanceKm': 42.5,
              'durationSeconds': 2700,
              'durationFormatted': '45 mins',
              'costing': 'auto',
              'hasCrowdDiversion': false,
              'engine': 'valhalla',
            },
            'coordinates': [
              [16.0218, 120.2319],
              [16.0500, 120.4800],
              [16.2000, 119.9000],
            ],
            'maneuvers': [
              {
                'instruction': 'Head north',
                'distanceMeters': 1000,
                'timeSeconds': 60,
              },
            ],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'items': []},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'POST /routes retries once on connection error with the same Idempotency-Key',
    () async {
      final adapter = _RouteRetryAdapter();
      final api = ApiClient(enableRetries: true);
      api.dio.httpClientAdapter = adapter;

      final notifier = NavigationNotifier(
        apiClient: api,
        initialDestination: const NavTarget(
          name: 'Patar Beach',
          lat: 16.2,
          lng: 119.9,
        ),
      );

      // Let constructor's _init() settle before testing toggleDetour -> POST /routes.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isLoadingRoute) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      adapter.postRoutesCalls = 0;
      adapter.idempotencyKeys.clear();

      notifier.toggleDetour(
        const DetourArea(
          municipality: 'Manaoag',
          detourKm: 12.0,
          extraMinutes: 15,
          score: 8.5,
          center: LatLng(16.05, 120.48),
          spotCount: 3,
          highlights: [],
        ),
      );
      while (notifier.state.isLoadingRoute) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(adapter.postRoutesCalls, 2);
      expect(adapter.idempotencyKeys, hasLength(2));
      expect(adapter.idempotencyKeys.first, isNotNull);
      expect(adapter.idempotencyKeys.first, isNotEmpty);
      expect(adapter.idempotencyKeys[1], adapter.idempotencyKeys[0]);
      expect(notifier.state.route, isNotNull);
      expect(notifier.state.route!.degraded, isFalse);
      expect(notifier.state.route!.summary.distanceKm, 42.5);
    },
  );
}
