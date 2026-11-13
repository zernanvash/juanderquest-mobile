import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

class RouteSnapResult {
  final bool snapped;
  final LatLng snappedPoint;
  final int segmentIndex;
  final double distanceToLineMeters;
  final double remainingMeters;
  final List<LatLng> remainingPolyline;

  const RouteSnapResult({
    required this.snapped,
    required this.snappedPoint,
    required this.segmentIndex,
    required this.distanceToLineMeters,
    required this.remainingMeters,
    required this.remainingPolyline,
  });
}

/// Geometry utilities for live route navigation
abstract final class RouteGeometry {
  /// Calculates minimum distance in meters from [point] to any segment in [polyline]
  static double distanceToPolylineMeters(
    LatLng point,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        polyline.first.latitude,
        polyline.first.longitude,
      );
    }

    double minDistance = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final dist = _distanceToSegmentMeters(point, a, b);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  /// Calculates perpendicular distance from [p] to segment [a]-[b] in meters
  static double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final meanLatRad = (a.latitude + b.latitude) * math.pi / 360.0;
    final cosLat = math.cos(meanLatRad);

    // Convert degrees to approximate meters (local flat-earth projection)
    const metersPerDegreeLat = 111132.954;
    final metersPerDegreeLng = 111132.954 * cosLat;

    final ax = a.longitude * metersPerDegreeLng;
    final ay = a.latitude * metersPerDegreeLat;
    final bx = b.longitude * metersPerDegreeLng;
    final by = b.latitude * metersPerDegreeLat;
    final px = p.longitude * metersPerDegreeLng;
    final py = p.latitude * metersPerDegreeLat;

    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0.0) {
      final diffX = px - ax;
      final diffY = py - ay;
      return math.sqrt(diffX * diffX + diffY * diffY);
    }

    // Projection factor t
    var t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    final projX = ax + t * dx;
    final projY = ay + t * dy;

    final diffX = px - projX;
    final diffY = py - projY;
    return math.sqrt(diffX * diffX + diffY * diffY);
  }

  /// Computes target turn locations for each maneuver along [coordinates]
  static List<LatLng> computeManeuverWaypoints(
    List<LatLng> coordinates,
    List<RouteManeuver> maneuvers,
  ) {
    if (coordinates.isEmpty || maneuvers.isEmpty) return const [];
    if (coordinates.length == 1) {
      return List.filled(maneuvers.length, coordinates.first);
    }
    if (maneuvers.length == 1) {
      return [coordinates.last];
    }

    // Cumulative polyline distances
    final cumPoly = <double>[0.0];
    for (var i = 0; i < coordinates.length - 1; i++) {
      final d = Geolocator.distanceBetween(
        coordinates[i].latitude,
        coordinates[i].longitude,
        coordinates[i + 1].latitude,
        coordinates[i + 1].longitude,
      );
      cumPoly.add(cumPoly.last + d);
    }
    final totalPolyDistance = cumPoly.last;

    // Cumulative maneuver distances
    double cumManeuver = 0.0;
    final result = <LatLng>[];

    for (var i = 0; i < maneuvers.length; i++) {
      // The maneuver turn/waypoint is at the end of its leg
      cumManeuver += maneuvers[i].distanceMeters;
      final targetDist = cumManeuver.clamp(0.0, totalPolyDistance);
      result.add(_interpolatePointAtDistance(coordinates, cumPoly, targetDist));
    }

    return result;
  }

  static LatLng _interpolatePointAtDistance(
    List<LatLng> coordinates,
    List<double> cumDist,
    double targetDist,
  ) {
    if (targetDist <= 0.0) return coordinates.first;
    if (targetDist >= cumDist.last) return coordinates.last;

    for (var i = 0; i < cumDist.length - 1; i++) {
      if (cumDist[i] <= targetDist && targetDist <= cumDist[i + 1]) {
        final segLen = cumDist[i + 1] - cumDist[i];
        if (segLen == 0.0) return coordinates[i];
        final t = (targetDist - cumDist[i]) / segLen;
        final lat = coordinates[i].latitude +
            t * (coordinates[i + 1].latitude - coordinates[i].latitude);
        final lng = coordinates[i].longitude +
            t * (coordinates[i + 1].longitude - coordinates[i].longitude);
        return LatLng(lat, lng);
      }
    }
    return coordinates.last;
  }

  /// Snaps [point] onto the nearest segment of [polyline] if within
  /// [maxSnapMeters], and returns remaining distance and trimmed polyline.
  static RouteSnapResult snapToPolyline(
    LatLng point,
    List<LatLng> polyline, {
    double maxSnapMeters = 30.0,
  }) {
    if (polyline.isEmpty) {
      return RouteSnapResult(
        snapped: false,
        snappedPoint: point,
        segmentIndex: 0,
        distanceToLineMeters: double.infinity,
        remainingMeters: 0.0,
        remainingPolyline: const [],
      );
    }
    if (polyline.length == 1) {
      final d = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        polyline.first.latitude,
        polyline.first.longitude,
      );
      return RouteSnapResult(
        snapped: d <= maxSnapMeters,
        snappedPoint: d <= maxSnapMeters ? polyline.first : point,
        segmentIndex: 0,
        distanceToLineMeters: d,
        remainingMeters: d,
        remainingPolyline: polyline,
      );
    }

    double bestDist = double.infinity;
    int bestSeg = 0;
    LatLng bestPoint = polyline.first;

    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final proj = _projectOntoSegment(point, a, b);
      final d = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        proj.latitude,
        proj.longitude,
      );
      if (d < bestDist) {
        bestDist = d;
        bestSeg = i;
        bestPoint = proj;
      }
    }

    final isSnapped = bestDist <= maxSnapMeters;
    final effectiveSeg = bestSeg;
    final anchor = isSnapped ? bestPoint : polyline[effectiveSeg];

    double remaining = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      polyline[effectiveSeg + 1].latitude,
      polyline[effectiveSeg + 1].longitude,
    );
    for (var i = effectiveSeg + 1; i < polyline.length - 1; i++) {
      remaining += Geolocator.distanceBetween(
        polyline[i].latitude,
        polyline[i].longitude,
        polyline[i + 1].latitude,
        polyline[i + 1].longitude,
      );
    }

    final trimmed = <LatLng>[
      anchor,
      ...polyline.sublist(effectiveSeg + 1),
    ];

    return RouteSnapResult(
      snapped: isSnapped,
      snappedPoint: isSnapped ? bestPoint : point,
      segmentIndex: effectiveSeg,
      distanceToLineMeters: bestDist,
      remainingMeters: remaining,
      remainingPolyline: trimmed,
    );
  }

  static LatLng _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    final meanLatRad = (a.latitude + b.latitude) * math.pi / 360.0;
    final cosLat = math.cos(meanLatRad);
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * cosLat;

    final ax = a.longitude * metersPerDegLng;
    final ay = a.latitude * metersPerDegLat;
    final bx = b.longitude * metersPerDegLng;
    final by = b.latitude * metersPerDegLat;
    final px = p.longitude * metersPerDegLng;
    final py = p.latitude * metersPerDegLat;

    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0.0) return a;

    final t = (((px - ax) * dx + (py - ay) * dy) / lenSq).clamp(0.0, 1.0);
    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }

  /// Estimates remaining duration in seconds proportional to remaining distance.
  static int remainingDurationSeconds(
    double remainingMeters,
    double totalMeters,
    int totalDurationSeconds,
  ) {
    if (totalDurationSeconds <= 0) return 0;
    if (totalMeters <= 0) return totalDurationSeconds;
    final ratio = (remainingMeters / totalMeters).clamp(0.0, 1.0);
    return (totalDurationSeconds * ratio).round();
  }
}
