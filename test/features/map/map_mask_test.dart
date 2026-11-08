import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/map_mask.dart';

void main() {
  group('buildInvertedMask', () {
    test('returns null when areaGeometry is missing', () {
      expect(buildInvertedMask(null), isNull);
    });

    test(
        'builds an inverted polygon with world outer ring and area inner ring for Polygon',
        () {
      final polygon = {
        'type': 'Polygon',
        'coordinates': [
          [
            [120.3, 16.0],
            [120.4, 16.0],
            [120.4, 16.1],
            [120.3, 16.1],
            [120.3, 16.0],
          ],
        ],
      };

      final mask = buildInvertedMask(polygon);
      expect(mask, isNotNull);
      expect(mask!['type'], 'Polygon');
      final coordinates = mask['coordinates'] as List;
      expect(coordinates.length, 2);
      expect(coordinates[0], [
        [-180.0, -90.0],
        [180.0, -90.0],
        [180.0, 90.0],
        [-180.0, 90.0],
        [-180.0, -90.0],
      ]);
      expect(coordinates[1], (polygon['coordinates'] as List)[0]);
    });

    test('handles MultiPolygon by creating multiple interior hole rings', () {
      final multiPolygon = {
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [120.1, 16.0],
              [120.2, 16.0],
              [120.2, 16.1],
              [120.1, 16.1],
              [120.1, 16.0],
            ],
          ],
          [
            [
              [120.5, 16.0],
              [120.6, 16.0],
              [120.6, 16.1],
              [120.5, 16.1],
              [120.5, 16.0],
            ],
          ],
        ],
      };

      final mask = buildInvertedMask(multiPolygon);
      expect(mask, isNotNull);
      expect(mask!['type'], 'Polygon');
      final coordinates = mask['coordinates'] as List;
      expect(coordinates.length, 3); // 1 world + 2 holes
    });
  });
}
