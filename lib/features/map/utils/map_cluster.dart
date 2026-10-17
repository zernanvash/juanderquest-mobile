import 'dart:math' as math;

enum MapClusterPointKind { spot, quest }

class MapClusterPoint {
  const MapClusterPoint({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.pinned,
  });

  final String id;
  final MapClusterPointKind kind;
  final double lat;
  final double lng;
  final bool pinned;
}

sealed class MapClusterResult {
  const MapClusterResult();
  String get sortKey;
  Map<String, Object?> toJson();
}

class MapPointResult extends MapClusterResult {
  const MapPointResult(this.id);
  final String id;

  @override
  String get sortKey => 'point:$id';

  @override
  Map<String, Object?> toJson() => {'type': 'point', 'id': id};
}

class MapCluster extends MapClusterResult {
  const MapCluster({
    required this.key,
    required this.count,
    required this.lat,
    required this.lng,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.ids,
    required this.hasQuest,
  });

  final String key;
  final int count;
  final double lat;
  final double lng;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final List<String> ids;
  final bool hasQuest;

  bool get hasNonZeroSpan => minLat != maxLat || minLng != maxLng;

  @override
  String get sortKey => 'cluster:$key';

  @override
  Map<String, Object?> toJson() => {
        'type': 'cluster',
        'key': key,
        'count': count,
        'lat': lat,
        'lng': lng,
        'bounds': {
          'minLat': minLat,
          'maxLat': maxLat,
          'minLng': minLng,
          'maxLng': maxLng,
        },
        'ids': ids,
        'hasQuest': hasQuest,
      };
}

/// Keep this projection, cell size, pinned rule, and output ordering in sync
/// with web_app/src/lib/map-cluster.ts and the shared fixture JSON.
List<MapClusterResult> clusterPoints(
  List<MapClusterPoint> points,
  double zoom, {
  double cellPx = 64,
}) {
  if (cellPx <= 0 || !cellPx.isFinite) {
    throw ArgumentError.value(cellPx, 'cellPx', 'must be positive and finite');
  }
  if (points.isEmpty) return const [];

  final sortedPoints = [...points]..sort((a, b) => a.id.compareTo(b.id));
  if (zoom >= 16) return sortedPoints.map((point) => MapPointResult(point.id)).toList();

  final output = <MapClusterResult>[];
  final groups = <String, List<MapClusterPoint>>{};
  for (final point in sortedPoints) {
    if (point.pinned) {
      output.add(MapPointResult(point.id));
      continue;
    }
    final projected = _projectToWorldPixels(point.lat, point.lng, zoom);
    final cellKey = '${(projected.x / cellPx).floor()}:${(projected.y / cellPx).floor()}';
    groups.putIfAbsent(cellKey, () => []).add(point);
  }

  for (final entry in groups.entries) {
    final group = entry.value;
    if (group.length == 1) {
      output.add(MapPointResult(group.single.id));
      continue;
    }
    final ids = group.map((point) => point.id).toList()..sort();
    final latTotal = group.fold<double>(0, (total, point) => total + point.lat);
    final lngTotal = group.fold<double>(0, (total, point) => total + point.lng);
    output.add(MapCluster(
      key: 'z${zoom.floor()}:${entry.key}',
      count: group.length,
      lat: latTotal / group.length,
      lng: lngTotal / group.length,
      minLat: group.map((point) => point.lat).reduce(math.min),
      maxLat: group.map((point) => point.lat).reduce(math.max),
      minLng: group.map((point) => point.lng).reduce(math.min),
      maxLng: group.map((point) => point.lng).reduce(math.max),
      ids: ids,
      hasQuest: group.any((point) => point.kind == MapClusterPointKind.quest),
    ));
  }

  output.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  return output;
}

({double x, double y}) _projectToWorldPixels(double lat, double lng, double zoom) {
  final latRad = lat * math.pi / 180;
  final scale = 256 * math.pow(2, zoom).toDouble();
  return (
    x: ((lng + 180) / 360) * scale,
    y: ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2) * scale,
  );
}
