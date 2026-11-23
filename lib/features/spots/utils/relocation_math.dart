import 'dart:math' as math;

/// Maximum pin relocation distance (in meters) that saves immediately without admin review.
const int kRelocationInstantMaxMeters = 200;

/// Great-circle haversine distance in meters between two WGS-84 coordinates.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

/// Returns true when a pin move requires admin review (> 200 m).
bool requiresRelocationReview(double distanceMeters) =>
    distanceMeters.round() > kRelocationInstantMaxMeters;

double _toRadians(double deg) => deg * math.pi / 180.0;
