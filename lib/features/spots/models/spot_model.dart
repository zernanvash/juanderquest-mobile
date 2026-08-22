class SpotPhoto {
  final String url;
  const SpotPhoto({required this.url});
}

class SpotModel {
  final String id,
      slug,
      name,
      description,
      category,
      subcategory,
      municipality,
      address,
      sourceName,
      trustLevel,
      crowdStatus,
      crowdConfidence;
  final double gpsLat, gpsLng;
  final double? distanceKm;
  final String? questId;
  final String? imageUrl;
  final bool saved;
  final List<String> tags, reasons;

  const SpotModel(
      {required this.id,
      required this.slug,
      required this.name,
      required this.description,
      required this.category,
      required this.subcategory,
      required this.municipality,
      required this.address,
      required this.sourceName,
      required this.trustLevel,
      required this.gpsLat,
      required this.gpsLng,
      required this.tags,
      required this.reasons,
      this.crowdStatus = 'unknown',
      this.crowdConfidence = 'none',
      this.distanceKm,
      this.questId,
      this.imageUrl,
      this.saved = false});

  List<SpotPhoto> get photos => imageUrl != null && imageUrl!.isNotEmpty
      ? [SpotPhoto(url: imageUrl!)]
      : const [];

  factory SpotModel.fromJson(Map<String, dynamic> j) => SpotModel(
        id: j['id'] ?? '',
        slug: j['slug'] ?? '',
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        category: j['category'] ?? '',
        subcategory: j['subcategory'] ?? '',
        municipality: j['municipality'] ?? '',
        address: j['address'] ?? '',
        sourceName: j['source_name'] ?? '',
        trustLevel: j['trust_level'] ?? '',
        crowdStatus: j['crowd_status'] ?? 'unknown',
        crowdConfidence: j['crowd_confidence'] ?? 'none',
        gpsLat: (j['gps_lat'] as num?)?.toDouble() ?? 0,
        gpsLng: (j['gps_lng'] as num?)?.toDouble() ?? 0,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        questId: j['quest_id'],
        saved: j['saved'] == true,
        imageUrl: j['image_url'] ?? j['photo_url'] ?? _firstPhoto(j),
        tags: List<String>.from(j['tags'] ?? []),
        reasons: List<String>.from(j['recommendation_reasons'] ?? []),
      );

  SpotModel copyWith({bool? saved}) => SpotModel(
      id: id,
      slug: slug,
      name: name,
      description: description,
      category: category,
      subcategory: subcategory,
      municipality: municipality,
      address: address,
      sourceName: sourceName,
      trustLevel: trustLevel,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      tags: tags,
      reasons: reasons,
      crowdStatus: crowdStatus,
      crowdConfidence: crowdConfidence,
      distanceKm: distanceKm,
      questId: questId,
      imageUrl: imageUrl,
      saved: saved ?? this.saved);

  static String? _firstPhoto(Map<String, dynamic> json) {
    final photos = json['photos'] ?? json['attached_assets'];
    if (photos is List && photos.isNotEmpty && photos.first is Map) {
      return (photos.first as Map)['url']?.toString();
    }
    return null;
  }
}
