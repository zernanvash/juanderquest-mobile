import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/widgets/trail_route_thumbnail.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';

// Owner 2026-11-10: "the valhalla aint working rn". The server was fine; the
// app sent origin/destination strings, the API answered INVALID_QUERY and the
// app fell back to a straight line. These pin the request to the API's shape.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '/routes uses start/end params (GET) and start/end objects (POST)',
    () async {
      final sent = <RequestOptions>[];
      final api = ApiClient(enableRetries: false);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            sent.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {'items': []},
                },
              ),
            );
          },
        ),
      );
      final n = NavigationNotifier(
        apiClient: api,
        initialDestination: const NavTarget(
          name: 'Patar Beach',
          lat: 16.2,
          lng: 119.9,
        ),
      );
      await n.fetchRoute();

      final get = sent.lastWhere(
        (o) => o.path == '/routes' && o.method == 'GET',
      );
      expect(
        get.queryParameters.keys,
        containsAll(['start_lat', 'start_lng', 'end_lat', 'end_lng']),
      );
      expect(get.queryParameters, isNot(contains('origin')));
      expect(
        (get.queryParameters['end_lat'], get.queryParameters['end_lng']),
        (16.2, 119.9),
      );

      n.toggleDetour(
        const DetourArea(
          municipality: 'Binmaley',
          center: LatLng(16.03, 120.26),
          detourKm: 1,
          extraMinutes: 5,
          score: 1,
          spotCount: 1,
          highlights: [],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await n.fetchRoute();

      final post = sent.lastWhere(
        (o) => o.path == '/routes' && o.method == 'POST',
      );
      final body = post.data as Map<String, dynamic>;
      expect(body['start'], isA<Map>());
      expect(body['end'], {'lat': 16.2, 'lng': 119.9});
      expect(body['via'], [
        {'lat': 16.03, 'lng': 120.26},
      ]);
      expect(body.containsKey('origin'), isFalse);
    },
  );

  test('route thumbnail fits every stop inside the box, keeping order', () {
    const size = Size(300, 112);
    final pts = TrailShapePainter.project(const [
      (16.0, 120.0),
      (16.1, 120.3),
      (16.4, 119.9),
    ], size);
    expect(pts, hasLength(3));
    for (final p in pts) {
      expect(p.dx, inInclusiveRange(14, 286));
      expect(p.dy, inInclusiveRange(14, 98));
    }
    // North is up: the most northern stop has the smallest y.
    expect(pts[2].dy, lessThan(pts[0].dy));
    // One point, or identical points, still land in the box.
    expect(
      TrailShapePainter.project(const [(16.0, 120.0)], size).single.dx,
      inInclusiveRange(0, 300),
    );
  });

  testWidgets('route thumbnail paints without errors at 320 wide', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: TrailRouteThumbnail(points: [(16.0, 120.0), (16.1, 120.3)]),
          ),
        ),
      ),
    );
    expect(find.byType(TrailRouteThumbnail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
