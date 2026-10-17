import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';

void main() {
  test('parses degraded straight-line route metadata', () {
    final route = RouteModel.fromJson({
      'degraded': true,
      'navigationMode': 'straight_line_estimate',
      'warning': {
        'code': 'OUTSIDE_ROUTING_COVERAGE',
        'message': 'Road routing is only available in Pangasinan.',
        'coverageLabel': 'Pangasinan',
      },
      'summary': {'distanceKm': 12.4, 'durationFormatted': '18 min'},
      'coordinates': [[16.0, 120.0], [16.1, 120.1]],
      'maneuvers': [],
    });
    expect(route.isStraightLineFallback, isTrue);
    expect(route.coverageLabel, 'Pangasinan');
    expect(route.warningMessage, contains('Pangasinan'));
    expect(route.summary.distanceKm, 12.4);
  });
}
