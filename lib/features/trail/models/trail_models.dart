import 'package:latlong2/latlong.dart';
import '../../navigation/models/route_model.dart';

/// Postgres NUMERIC columns arrive as strings (e.g. total_km "8.74" on an
/// unlocked trail), so accept a number or a numeric string.
num? _num(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);

enum TrailTier {
  starter('starter', 'Starter'),
  explorer('explorer', 'Explorer'),
  signature('signature', 'Hiyas · Signature'),
  legendary('legendary', 'Hiyas · Legendary'),
  personal('personal', 'Personal');

  final String key;
  final String label;
  const TrailTier(this.key, this.label);

  static TrailTier fromKey(String? key) {
    return TrailTier.values.firstWhere(
      (t) => t.key == key,
      orElse: () => TrailTier.starter,
    );
  }

  bool get isHiyas => this == signature || this == legendary;
}

class UnlockRule {
  final String type;
  final int? pricePoints;
  final int? minLevel;

  const UnlockRule({
    required this.type,
    this.pricePoints,
    this.minLevel,
  });

  factory UnlockRule.fromJson(Map<String, dynamic> json) {
    return UnlockRule(
      type: json['type']?.toString() ?? 'free',
      pricePoints: _num(json['price_points'])?.toInt(),
      minLevel: _num(json['min_level'])?.toInt(),
    );
  }
}

class NearbyTrail {
  final String id;
  final String slug;
  final String title;
  final String tagline;
  final TrailTier tier;
  final String theme;
  final List<String> municipalities;
  final int stopCount;
  final int totalMinutes;
  final double totalKm;
  final UnlockRule unlockRule;
  final DateTime? availableUntil;
  final bool isUnlocked;
  final int rewardPoints;
  final String? coverImageUrl;
  final bool passesHere;
  final double nearestKm;

  const NearbyTrail({
    required this.id,
    required this.slug,
    required this.title,
    required this.tagline,
    required this.tier,
    required this.theme,
    required this.municipalities,
    required this.stopCount,
    required this.totalMinutes,
    required this.totalKm,
    required this.unlockRule,
    this.availableUntil,
    required this.isUnlocked,
    required this.rewardPoints,
    this.coverImageUrl,
    required this.passesHere,
    required this.nearestKm,
  });

  factory NearbyTrail.fromJson(Map<String, dynamic> json) {
    final unlockMap = json['unlock_rule'] is Map<String, dynamic>
        ? json['unlock_rule'] as Map<String, dynamic>
        : <String, dynamic>{};
    return NearbyTrail(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      tier: TrailTier.fromKey(json['tier']?.toString()),
      theme: json['theme']?.toString() ?? '',
      municipalities: (json['municipalities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      stopCount: _num(json['stop_count'])?.toInt() ?? 0,
      totalMinutes: _num(json['total_minutes'])?.toInt() ?? 0,
      totalKm: _num(json['total_km'])?.toDouble() ?? 0.0,
      unlockRule: UnlockRule.fromJson(unlockMap),
      availableUntil: json['available_until'] != null
          ? DateTime.tryParse(json['available_until'].toString())
          : null,
      isUnlocked: json['is_unlocked'] == true,
      rewardPoints: _num(json['reward_points'])?.toInt() ?? 0,
      coverImageUrl: json['cover_image_url']?.toString(),
      passesHere: json['passes_here'] == true,
      nearestKm: _num(json['nearest_km'])?.toDouble() ?? 0.0,
    );
  }
}

class TrailPreviewStop {
  final String name;
  final String municipality;
  final String category;
  final String? imageUrl;
  final String blurb;

  const TrailPreviewStop({
    required this.name,
    required this.municipality,
    required this.category,
    this.imageUrl,
    required this.blurb,
  });

  factory TrailPreviewStop.fromJson(Map<String, dynamic> json) {
    return TrailPreviewStop(
      name: json['name']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      blurb: json['blurb']?.toString() ?? '',
    );
  }
}

class TrailStop {
  final int position;
  final String spotId;
  final String name;
  final String municipality;
  final String category;
  final double lat;
  final double lng;
  final String narration;
  final int arriveOffsetMin;
  final int dwellMin;
  final int legMinutes;
  final double legKm;
  final double checkinRadiusM;
  final bool checkedIn;
  final double? distanceM;
  final double? accuracyM;

  const TrailStop({
    required this.position,
    required this.spotId,
    required this.name,
    required this.municipality,
    required this.category,
    required this.lat,
    required this.lng,
    required this.narration,
    required this.arriveOffsetMin,
    required this.dwellMin,
    required this.legMinutes,
    required this.legKm,
    required this.checkinRadiusM,
    this.checkedIn = false,
    this.distanceM,
    this.accuracyM,
  });

  factory TrailStop.fromJson(Map<String, dynamic> json) {
    return TrailStop(
      position: _num(json['position'])?.toInt() ?? 1,
      spotId: json['spot_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      lat: _num(json['lat'])?.toDouble() ?? 0.0,
      lng: _num(json['lng'])?.toDouble() ?? 0.0,
      narration: json['narration']?.toString() ?? '',
      arriveOffsetMin: _num(json['arrive_offset_min'])?.toInt() ?? 0,
      dwellMin: _num(json['dwell_min'])?.toInt() ?? 30,
      legMinutes: _num(json['leg_minutes'])?.toInt() ?? 0,
      legKm: _num(json['leg_km'])?.toDouble() ?? 0.0,
      checkinRadiusM: _num(json['checkin_radius_m'])?.toDouble() ?? 50.0,
      checkedIn: json['checked_in'] == true,
      distanceM: _num(json['distance_m'])?.toDouble(),
      accuracyM: _num(json['accuracy_m'])?.toDouble(),
    );
  }

  LatLng get point => LatLng(lat, lng);
}

class TrailDetail {
  final String id;
  final String slug;
  final String title;
  final String tagline;
  final TrailTier tier;
  final String theme;
  final List<String> municipalities;
  final int stopCount;
  final int totalMinutes;
  final double totalKm;
  final UnlockRule unlockRule;
  final DateTime? availableUntil;
  final bool isUnlocked;
  final int rewardPoints;
  final String intro;
  final List<TrailStop> stops;
  final List<TrailPreviewStop> preview;

  const TrailDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.tagline,
    required this.tier,
    required this.theme,
    required this.municipalities,
    required this.stopCount,
    required this.totalMinutes,
    required this.totalKm,
    required this.unlockRule,
    this.availableUntil,
    required this.isUnlocked,
    required this.rewardPoints,
    required this.intro,
    this.stops = const [],
    this.preview = const [],
  });

  factory TrailDetail.fromJson(Map<String, dynamic> json) {
    final unlockMap = json['unlock_rule'] is Map<String, dynamic>
        ? json['unlock_rule'] as Map<String, dynamic>
        : <String, dynamic>{};
    return TrailDetail(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      tier: TrailTier.fromKey(json['tier']?.toString()),
      theme: json['theme']?.toString() ?? '',
      municipalities: (json['municipalities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      stopCount: _num(json['stop_count'])?.toInt() ?? 0,
      totalMinutes: _num(json['total_minutes'])?.toInt() ?? 0,
      totalKm: _num(json['total_km'])?.toDouble() ?? 0.0,
      unlockRule: UnlockRule.fromJson(unlockMap),
      availableUntil: json['available_until'] != null
          ? DateTime.tryParse(json['available_until'].toString())
          : null,
      isUnlocked: json['is_unlocked'] == true,
      rewardPoints: _num(json['reward_points'])?.toInt() ?? 0,
      intro: json['intro']?.toString() ??
          (json['story'] is Map ? (json['story']['intro']?.toString() ?? '') : ''),
      stops: (json['stops'] as List<dynamic>?)
              ?.map((s) => TrailStop.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      preview: (json['preview'] as List<dynamic>?)
              ?.map((p) => TrailPreviewStop.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TripOrigin {
  final String name;
  final double lat;
  final double lng;

  const TripOrigin(this.name, this.lat, this.lng);

  LatLng get point => LatLng(lat, lng);
}

/// Exact copy of TRIP_ORIGINS from web_app/src/lib/trip-api.ts (Plan 83 §5.3)
const List<TripOrigin> kTripOrigins = [
  TripOrigin('Manila', 14.5995, 120.9842),
  TripOrigin('Quezon City', 14.676, 121.0437),
  TripOrigin('Makati', 14.5547, 121.0244),
  TripOrigin('Pasay (NAIA)', 14.5086, 121.0194),
  TripOrigin('Clark / Angeles', 15.145, 120.5887),
  TripOrigin('San Fernando, Pampanga', 15.0286, 120.6898),
  TripOrigin('Tarlac City', 15.4755, 120.5963),
  TripOrigin('Cabanatuan', 15.4869, 120.9675),
  TripOrigin('Olongapo', 14.8292, 120.2828),
  TripOrigin('Baguio', 16.4023, 120.596),
  TripOrigin('San Fernando, La Union', 16.6159, 120.3166),
  TripOrigin('Vigan', 17.5747, 120.3869),
  TripOrigin('Laoag', 18.1978, 120.5936),
  TripOrigin('Dagupan City', 16.0433, 120.3333),
  TripOrigin('Lingayen', 16.0218, 120.2319),
  TripOrigin('Urdaneta', 15.9761, 120.5711),
  TripOrigin('Alaminos', 16.1557, 119.9807),
  TripOrigin('San Carlos, Pangasinan', 15.9282, 120.3485),
  TripOrigin('Antipolo', 14.6255, 121.1245),
  TripOrigin('Batangas City', 13.7565, 121.0583),
];

class DetourHighlight {
  final String spotId;
  final String name;
  final String category;

  const DetourHighlight({
    required this.spotId,
    required this.name,
    required this.category,
  });

  factory DetourHighlight.fromJson(Map<String, dynamic> json) {
    return DetourHighlight(
      spotId: json['spot_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
    );
  }
}

class DetourArea {
  final String municipality;
  final double detourKm;
  final int extraMinutes;
  final double score;
  final LatLng center;
  final int spotCount;
  final List<DetourHighlight> highlights;

  const DetourArea({
    required this.municipality,
    required this.detourKm,
    required this.extraMinutes,
    required this.score,
    required this.center,
    required this.spotCount,
    required this.highlights,
  });

  factory DetourArea.fromJson(Map<String, dynamic> json) {
    final c = json['center'] as Map<String, dynamic>? ?? {};
    return DetourArea(
      municipality: json['municipality']?.toString() ?? '',
      detourKm: _num(json['detour_km'])?.toDouble() ?? 0.0,
      extraMinutes: _num(json['extra_minutes'])?.toInt() ?? 0,
      score: _num(json['score'])?.toDouble() ?? 0.0,
      center: LatLng(
        _num(c['lat'])?.toDouble() ?? 0.0,
        _num(c['lng'])?.toDouble() ?? 0.0,
      ),
      spotCount: _num(json['spot_count'])?.toInt() ?? 0,
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((h) => DetourHighlight.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TripPlan {
  final RouteModel baselineRoute;
  final List<DetourArea> detourAreas;

  const TripPlan({
    required this.baselineRoute,
    required this.detourAreas,
  });

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    final baseMap = json['baseline_route'] as Map<String, dynamic>? ?? {};
    return TripPlan(
      baselineRoute: RouteModel.fromJson(baseMap),
      detourAreas: (json['detour_areas'] as List<dynamic>?)
              ?.map((d) => DetourArea.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m > 0 ? '$h hr $m min' : '$h hr';
}
