import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';

// Orchestrator review of 83b: check-in sends the real GPS accuracy (the server
// rejects fixes worse than 100 m), and the completion reward comes from the
// server's `completion` object, not the trail's list price.
const _stop = TrailStop(
  position: 1,
  spotId: 's1',
  name: 'Capitol',
  municipality: 'Lingayen',
  category: 'history',
  lat: 16.021,
  lng: 120.235,
  narration: '',
  arriveOffsetMin: 0,
  dwellMin: 15,
  legMinutes: 0,
  legKm: 0,
  checkinRadiusM: 50,
  checkedIn: false,
);

const _trail = TrailDetail(
  id: 't1',
  slug: 't1',
  title: 'T',
  tagline: '',
  tier: TrailTier.starter,
  theme: 'history',
  municipalities: ['Lingayen'],
  stopCount: 1,
  totalMinutes: 15,
  totalKm: 1,
  unlockRule: UnlockRule(type: 'free'),
  isUnlocked: true,
  rewardPoints: 50,
  intro: '',
  stops: [_stop],
  preview: [],
);

Position _at(double accuracy) => Position(
      latitude: 16.021,
      longitude: 120.235,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  unlockedDetailParses();

  Future<(NavigationNotifier, List<RequestOptions>)> setup(
      Map<String, dynamic> checkinData) async {
    final sent = <RequestOptions>[];
    final api = ApiClient(enableRetries: false);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent.add(o);
      final data = o.path.endsWith('/checkin') ? checkinData : {'items': []};
      h.resolve(Response(
          requestOptions: o,
          statusCode: 200,
          data: {'success': true, 'data': data}));
    }));
    final n = NavigationNotifier(
      apiClient: api,
      trailsApi: TrailsApi(api),
      initialDestination:
          const NavTarget(name: 'Capitol', lat: 16.021, lng: 120.235),
    );
    n.selectTrail(_trail);
    await Future<void>.delayed(Duration.zero);
    return (n, sent);
  }

  test('check-in sends the real accuracy, even above 100 m', () async {
    final (n, sent) = await setup({'completion': null});
    n.updatePosition(_at(150));
    await n.checkInCurrentStop();
    final body = sent.lastWhere((o) => o.path.endsWith('/checkin')).data as Map;
    expect(body['accuracy_m'], 150);
  });

  test('completion reward comes from the server completion object', () async {
    final (n, _) = await setup({
      'completion': {'reward_points': 65},
    });
    n.updatePosition(_at(10));
    await n.checkInCurrentStop();
    expect(n.state.isTrailCompleted, isTrue);
    expect(n.state.trailCompletionReward, 65);
  });

  test('a trail completed before gets no reward points', () async {
    final (n, _) = await setup({'completion': null});
    n.updatePosition(_at(10));
    await n.checkInCurrentStop();
    expect(n.state.isTrailCompleted, isTrue);
    expect(n.state.trailCompletionReward, isNull);
  });
}

// Owner phone 2026-11-13: an unlocked trail showed "type 'String' is not a
// subtype of type 'num?' in type cast". The unlocked detail spreads the raw
// trails row, so Postgres NUMERIC values (total_km, check-in distance and
// accuracy) arrive as strings.
void unlockedDetailParses() {
  test('unlocked trail detail with numeric strings parses', () {
    final d = TrailDetail.fromJson({
      'id': 'coastal_wonders_trail',
      'title': 'Coastal Wonders Trail',
      'tier': 'starter',
      'stop_count': 6,
      'total_minutes': 435,
      'total_km': '61.20',
      'is_unlocked': true,
      'story': {'intro': 'Sea and sand.'},
      'stops': [
        {
          'position': 1,
          'spot_id': 's1',
          'name': 'Tondaligan Beach',
          'lat': 16.07,
          'lng': 120.33,
          'leg_km': 0,
          'checkin_radius_m': 80,
          'checked_in': true,
          'verified_at': '2026-11-13T02:00:00Z',
          'distance_m': '12.40',
          'accuracy_m': '8.00',
        },
      ],
    });
    expect(d.totalKm, 61.2);
    expect(d.stops.single.distanceM, 12.4);
    expect(d.stops.single.accuracyM, 8.0);
  });
}
