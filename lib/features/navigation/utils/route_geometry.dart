import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

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
}
