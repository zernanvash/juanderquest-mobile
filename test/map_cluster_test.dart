import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/utils/map_cluster.dart';

void main() {
  final fixtures = (jsonDecode(File('test/fixtures/map-clustering-fixtures.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  group('shared map clustering fixtures', () {
    for (final fixture in fixtures) {
      test(fixture['name'] as String, () {
        final points = (fixture['points'] as List).cast<Map<String, dynamic>>().map((json) {
          return MapClusterPoint(
            id: json['id'] as String,
            kind: json['kind'] == 'quest' ? MapClusterPointKind.quest : MapClusterPointKind.spot,
            lat: (json['lat'] as num).toDouble(),
            lng: (json['lng'] as num).toDouble(),
            pinned: json['pinned'] as bool,
          );
        }).toList();
        final results = clusterPoints(points, (fixture['zoom'] as num).toDouble());
        final expected = (fixture['expected'] as List).cast<Map<String, dynamic>>();
        expect(results.length, expected.length);
        for (var i = 0; i < results.length; i++) {
          final actual = results[i].toJson();
          final want = expected[i];
          if (actual['type'] == 'cluster') {
            final actualCluster = actual;
            final expectedCluster = want;
            expect(actualCluster.keys, containsAll(expectedCluster.keys));
            expect(actualCluster['key'], expectedCluster['key']);
            expect(actualCluster['count'], expectedCluster['count']);
            expect(actualCluster['ids'], expectedCluster['ids']);
            expect(actualCluster['hasQuest'], expectedCluster['hasQuest']);
            expect((actualCluster['lat'] as double), closeTo((expectedCluster['lat'] as num).toDouble(), 1e-9));
            expect((actualCluster['lng'] as double), closeTo((expectedCluster['lng'] as num).toDouble(), 1e-9));
            expect(actualCluster['bounds'], expectedCluster['bounds']);
          } else {
            expect(actual, expected[i]);
          }
        }
      });
    }
  });

  test('cluster counts plus individual points represent every destination', () {
    final points = List.generate(
      30,
      (i) => MapClusterPoint(
        id: 'spot-${i.toString().padLeft(2, '0')}',
        kind: MapClusterPointKind.spot,
        lat: 16 + i * 0.00001,
        lng: 120 + i * 0.00001,
        pinned: false,
      ),
    );
    final groups = clusterPoints(points, 8);
    expect(groups.whereType<MapCluster>(), isNotEmpty);
    expect(groups.fold<int>(0, (sum, item) => sum + (item is MapCluster ? item.count : 1)), 30);
  });
}
