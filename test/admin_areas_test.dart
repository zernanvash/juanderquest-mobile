import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/utils/admin_areas.dart';

void main() {
  // A 1°×1° square around (16.5, 120.5) with a 0.2° hole in the middle.
  final polygonWithHole = {
    'type': 'Feature',
    'properties': {'id': 'x'},
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        [
          [120, 16],
          [121, 16],
          [121, 17],
          [120, 17],
          [120, 16]
        ],
        [
          [120.4, 16.4],
          [120.6, 16.4],
          [120.6, 16.6],
          [120.4, 16.6],
          [120.4, 16.4]
        ],
      ],
    },
  };

  test('parses a GeoJSON Feature polygon with a hole (lng,lat order)', () {
    final shape = AreaShape.fromGeoJson(polygonWithHole)!;
    expect(shape.polygons, hasLength(1));
    expect(shape.polygons.first.outer.first.latitude, 16);
    expect(shape.polygons.first.outer.first.longitude, 120);
    expect(shape.polygons.first.holes, hasLength(1));
  });

  test('contains respects holes', () {
    final shape = AreaShape.fromGeoJson(polygonWithHole)!;
    expect(shape.contains(16.2, 120.2), isTrue);
    expect(shape.contains(16.5, 120.5), isFalse); // in the hole
    expect(shape.contains(17.5, 120.5), isFalse); // outside
  });

  test('MultiPolygon: islands count', () {
    final shape = AreaShape.fromGeoJson({
      'type': 'MultiPolygon',
      'coordinates': [
        [
          [
            [120, 16],
            [120.1, 16],
            [120.1, 16.1],
            [120, 16]
          ]
        ],
        [
          [
            [119.9, 16.2],
            [120.0, 16.2],
            [120.0, 16.3],
            [119.9, 16.2]
          ]
        ],
      ],
    })!;
    expect(shape.polygons, hasLength(2));
    expect(shape.contains(16.25, 119.97), isTrue);
    expect(shape.outlinePoints, hasLength(8));
  });

  test('rejects broken geometry', () {
    expect(AreaShape.fromGeoJson(null), isNull);
    expect(
        AreaShape.fromGeoJson({
          'type': 'Point',
          'coordinates': [1, 2]
        }),
        isNull);
  });

  test('reads an /areas item', () {
    final a = AdminArea.fromJson({
      'id': 'ph-01-55-dagupan',
      'level': 'city',
      'name': 'Dagupan',
      'display_name': 'Dagupan City',
      'label_lat': 16.04,
      'label_lng': 120.34,
      'has_boundary': true,
      'bbox': [120.3, 16.0, 120.4, 16.1],
      'published_spot_count': 12,
    });
    expect(a.levelLabel, 'City');
    expect(a.bbox, [120.3, 16.0, 120.4, 16.1]);
    expect(a.spotCount, 12);
  });

  test('declutter keeps the more important of two overlapping labels', () {
    final kept = declutterAreaLabels(const [
      AreaLabelBox('small', Offset(100, 100), Size(60, 20), 1),
      AreaLabelBox('big', Offset(110, 104), Size(80, 20), 50),
      AreaLabelBox('far', Offset(300, 300), Size(60, 20), 0),
    ]);
    expect(kept, {'big', 'far'});
  });
}
