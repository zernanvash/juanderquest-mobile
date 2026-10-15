import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Camera target for a selected pin so it appears above the floating inspector
/// card instead of underneath it.
///
/// Pure Web-Mercator approximation (156543.03392 m/px at zoom 0, 111 320 m per
/// degree of latitude) so the offset math is unit-testable without a map.
/// The returned center sits south of the pin by [cardOffsetRatio] of the map
/// height, which lifts the pin into the visible area above the card.
LatLng focusTargetAboveCard({
  required double lat,
  required double lng,
  required double zoom,
  required double mapHeightPx,
  double cardOffsetRatio = 0.16,
}) {
  final clampedZoom = zoom.clamp(0.0, 22.0);
  final metersPerPixel =
      156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, clampedZoom);
  final deltaDegrees = (mapHeightPx * cardOffsetRatio * metersPerPixel) / 111320.0;
  return LatLng(lat - deltaDegrees, lng);
}
