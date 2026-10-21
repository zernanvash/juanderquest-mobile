import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// A PSA/NAMRIA administrative area from `GET /areas` (Plan 45).
class AdminArea {
  final String id;

  /// `province`, `city`, `municipality` or `barangay`.
  final String level;
  final String name;
  final String displayName;
  final LatLng label;
  final bool hasBoundary;

  /// [minLng, minLat, maxLng, maxLat]; null when unknown.
  final List<double>? bbox;
  final int spotCount;

  const AdminArea({
    required this.id,
    required this.level,
    required this.name,
    required this.displayName,
    required this.label,
    required this.hasBoundary,
    this.bbox,
    this.spotCount = 0,
  });

  factory AdminArea.fromJson(Map<String, dynamic> j) {
    final raw = j['bbox'];
    List<double>? bbox;
    if (raw is List && raw.length == 4) {
      bbox = [for (final v in raw) (v as num).toDouble()];
    }
    return AdminArea(
      id: '${j['id']}',
      level: '${j['level'] ?? 'municipality'}',
      name: '${j['name'] ?? ''}',
      displayName: '${j['display_name'] ?? j['name'] ?? ''}',
      label: LatLng((j['label_lat'] as num?)?.toDouble() ?? 0,
          (j['label_lng'] as num?)?.toDouble() ?? 0),
      hasBoundary: j['has_boundary'] == true,
      bbox: bbox,
      spotCount: (j['published_spot_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// "City", "Town", "Province", "Barangay" — shown under the name.
  String get levelLabel => switch (level) {
        'province' => 'Province',
        'city' => 'City',
        'barangay' => 'Barangay',
        _ => 'Town',
      };
}

/// One polygon: an outer ring plus optional holes.
class AreaPolygon {
  final List<LatLng> outer;
  final List<List<LatLng>> holes;

  const AreaPolygon(this.outer, [this.holes = const []]);
}

/// A boundary from `GET /areas/:id/shape` (GeoJSON Polygon/MultiPolygon).
class AreaShape {
  final List<AreaPolygon> polygons;

  const AreaShape(this.polygons);

  static AreaShape? fromGeoJson(Object? feature) {
    if (feature is! Map) return null;
    final g = feature['type'] == 'Feature' ? feature['geometry'] : feature;
    if (g is! Map) return null;
    List<LatLng> ring(Object? r) => [
          if (r is List)
            for (final p in r)
              if (p is List && p.length >= 2)
                LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
        ];
    AreaPolygon? polygon(Object? rings) {
      if (rings is! List || rings.isEmpty) return null;
      final outer = ring(rings.first);
      if (outer.length < 3) return null;
      return AreaPolygon(outer, [for (final h in rings.skip(1)) ring(h)]);
    }

    final coords = g['coordinates'];
    final out = <AreaPolygon>[];
    if (g['type'] == 'Polygon') {
      final p = polygon(coords);
      if (p != null) out.add(p);
    } else if (g['type'] == 'MultiPolygon' && coords is List) {
      for (final c in coords) {
        final p = polygon(c);
        if (p != null) out.add(p);
      }
    }
    return out.isEmpty ? null : AreaShape(out);
  }

  /// Even-odd ray casting over every ring, so holes and islands work.
  bool contains(double lat, double lng) {
    for (final p in polygons) {
      if (_inRing(p.outer, lat, lng) &&
          !p.holes.any((h) => _inRing(h, lat, lng))) {
        return true;
      }
    }
    return false;
  }

  static bool _inRing(List<LatLng> ring, double lat, double lng) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final yi = ring[i].latitude, xi = ring[i].longitude;
      final yj = ring[j].latitude, xj = ring[j].longitude;
      if ((yi > lat) != (yj > lat) &&
          lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// All outer-ring points, for fitting the camera.
  List<LatLng> get outlinePoints => [for (final p in polygons) ...p.outer];
}

/// True when [bbox] ([minLng, minLat, maxLng, maxLat]) contains the point;
/// unknown boxes are treated as "maybe" so the exact shape decides.
bool areaBboxContains(List<double>? bbox, double lat, double lng) =>
    bbox == null ||
    (lng >= bbox[0] && lat >= bbox[1] && lng <= bbox[2] && lat <= bbox[3]);

/// Box size in square degrees (smaller = more specific area).
double areaBboxSize(List<double>? bbox) => bbox == null
    ? double.infinity
    : (bbox[2] - bbox[0]).abs() * (bbox[3] - bbox[1]).abs();

/// `GET /areas`, `GET /areas/:id/shape`, with a small in-memory shape cache.
class AdminAreaApi {
  final Dio dio;
  final Map<String, AreaShape?> _shapes = {};

  AdminAreaApi(this.dio);

  Future<List<AdminArea>> visible({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required double zoom,
  }) async {
    final res = await dio.get('/areas', queryParameters: {
      'bbox': [minLng, minLat, maxLng, maxLat]
          .map((v) => v.toStringAsFixed(4))
          .join(','),
      'zoom': zoom.floor(),
    });
    final data = res.data is Map ? res.data['data'] : null;
    return [
      if (data is List)
        for (final a in data)
          if (a is Map) AdminArea.fromJson(Map<String, dynamic>.from(a)),
    ];
  }

  Future<AreaShape?> shape(String id) async {
    if (_shapes.containsKey(id)) return _shapes[id];
    final res = await dio.get('/areas/${Uri.encodeComponent(id)}/shape');
    final shape = AreaShape.fromGeoJson(res.data);
    _shapes[id] = shape;
    return shape;
  }
}
