/// Helper to build inverted dimming polygon mask.
/// Outer box covers the world, inner hole is the target area's polygon geometry.
const List<List<double>> kWorldRing = [
  [-180.0, -90.0],
  [180.0, -90.0],
  [180.0, 90.0],
  [-180.0, 90.0],
  [-180.0, -90.0],
];

/// Ported from `web_app/src/lib/map-mask.ts`.
/// Takes GeoJSON geometry [areaGeometry] with coordinates in `[lng, lat]` format.
/// Returns a GeoJSON Polygon whose outer ring is [kWorldRing] and whose inner
/// hole(s) are the exterior ring(s) of [areaGeometry].
Map<String, dynamic>? buildInvertedMask(Map<String, dynamic>? areaGeometry) {
  if (areaGeometry == null) return null;

  final type = areaGeometry['type'];
  final coordinates = areaGeometry['coordinates'];
  if (coordinates is! List || coordinates.isEmpty) return null;

  if (type == 'Polygon') {
    // Polygon: first ring is exterior. We append its exterior ring as a hole in the world polygon.
    return {
      'type': 'Polygon',
      'coordinates': [kWorldRing, coordinates[0]],
    };
  }

  if (type == 'MultiPolygon') {
    // For MultiPolygon, build a Polygon with multiple interior rings (one for each exterior part)
    final rings = <dynamic>[kWorldRing];
    for (final poly in coordinates) {
      if (poly is List && poly.isNotEmpty && poly[0] is List) {
        rings.add(poly[0]);
      }
    }
    return {
      'type': 'Polygon',
      'coordinates': rings,
    };
  }

  return null;
}
