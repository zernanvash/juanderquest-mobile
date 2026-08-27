import 'package:latlong2/latlong.dart';

/// Travel costing profile supported by Valhalla engine on Azure VM
enum TravelCosting {
  auto('auto', 'Driving', '🚗'),
  motorcycle('motorcycle', 'Moto', '🏍️'),
  bicycle('bicycle', 'Bicycle', '🚲'),
  pedestrian('pedestrian', 'Eco-Trail', '🚶');

  final String key;
  final String label;
  final String iconEmoji;

  const TravelCosting(this.key, this.label, this.iconEmoji);

  static TravelCosting fromKey(String? key) {
    return TravelCosting.values.firstWhere(
      (c) => c.key == key,
      orElse: () => TravelCosting.auto,
    );
  }
}

/// A step-by-step turn guidance maneuver along the route
class RouteManeuver {
  final String instruction;
  final String? streetName;
  final int distanceMeters;
  final int timeSeconds;

  const RouteManeuver({
    required this.instruction,
    this.streetName,
    required this.distanceMeters,
    required this.timeSeconds,
  });

  factory RouteManeuver.fromJson(Map<String, dynamic> json) {
    return RouteManeuver(
      instruction: json['instruction']?.toString() ?? 'Continue along route',
      streetName: json['streetName']?.toString(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      timeSeconds: (json['timeSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '$distanceMeters m';
  }
}

/// Metadata summary returned by Valhalla or fallback Haversine engine
class RouteSummary {
  final double distanceKm;
  final int durationSeconds;
  final String durationFormatted;
  final TravelCosting costing;
  final bool hasCrowdDiversion;
  final String engine;

  const RouteSummary({
    required this.distanceKm,
    required this.durationSeconds,
    required this.durationFormatted,
    required this.costing,
    required this.hasCrowdDiversion,
    required this.engine,
  });

  factory RouteSummary.fromJson(Map<String, dynamic> json) {
    return RouteSummary(
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      durationFormatted: json['durationFormatted']?.toString() ?? '-- min',
      costing: TravelCosting.fromKey(json['costing']?.toString()),
      hasCrowdDiversion: json['hasCrowdDiversion'] == true,
      engine: json['engine']?.toString() ?? 'valhalla',
    );
  }
}

/// Full turn-by-turn route response model
class RouteModel {
  final RouteSummary summary;
  final List<LatLng> coordinates;
  final List<RouteManeuver> maneuvers;

  const RouteModel({
    required this.summary,
    required this.coordinates,
    required this.maneuvers,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final summaryData = json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawCoords = json['coordinates'] as List<dynamic>? ?? [];
    final coordinates = <LatLng>[];
    for (final item in rawCoords) {
      if (item is List && item.length >= 2) {
        final lat = (item[0] as num).toDouble();
        final lng = (item[1] as num).toDouble();
        coordinates.add(LatLng(lat, lng));
      }
    }

    final rawManeuvers = json['maneuvers'] as List<dynamic>? ?? [];
    final maneuvers = rawManeuvers
        .map((m) => RouteManeuver.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();

    return RouteModel(
      summary: RouteSummary.fromJson(summaryData),
      coordinates: coordinates,
      maneuvers: maneuvers,
    );
  }
}

/// Destination target payload passed to navigation screen
class NavTarget {
  final String name;
  final double lat;
  final double lng;
  final String address;

  const NavTarget({
    required this.name,
    required this.lat,
    required this.lng,
    this.address = 'Pangasinan, Philippines',
  });
}

