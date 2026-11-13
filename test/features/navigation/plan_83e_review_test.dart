import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';

// Orchestrator review of 83e: every trail starts locked on the server, even
// free ones. After it is unlocked in the offer sheet and chosen, the carousel
// card must count as unlocked, or the main button keeps saying CHOOSE TRAIL
// and reopens the sheet instead of START TRAIL.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('choosing an unlocked trail marks its carousel card unlocked', () async {
    final api = ApiClient(enableRetries: false);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      final data = o.path == '/trails/near'
          ? {
              'items': [
                {'id': 't1', 'title': 'Heritage', 'tier': 'starter', 'is_unlocked': false, 'stop_count': 2},
                {'id': 't2', 'title': 'Coastal', 'tier': 'starter', 'is_unlocked': false, 'stop_count': 3},
              ]
            }
          : <String, dynamic>{};
      h.resolve(Response(requestOptions: o, statusCode: 200, data: {'success': true, 'data': data}));
    }));
    final n = NavigationNotifier(
      apiClient: api,
      initialDestination: const NavTarget(name: 'Capitol', lat: 16.02, lng: 120.23),
    );
    await n.fetchNearbyTrails();
    expect(n.state.nearbyTrails.map((t) => t.isUnlocked), [false, false]);

    n.selectTrail(TrailDetail.fromJson({'id': 't1', 'title': 'Heritage', 'tier': 'starter', 'is_unlocked': true, 'stops': []}));
    expect(n.state.nearbyTrails.firstWhere((t) => t.id == 't1').isUnlocked, isTrue);
    expect(n.state.nearbyTrails.firstWhere((t) => t.id == 't2').isUnlocked, isFalse);

    // Going back to the direct route keeps it unlocked.
    n.selectDirectRoute();
    expect(n.state.nearbyTrails.firstWhere((t) => t.id == 't1').isUnlocked, isTrue);
  });
}
