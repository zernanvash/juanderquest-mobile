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

  bool get isVideo {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    final url = imageUrl!.toLowerCase().split('?').first;
    return url.endsWith('.mp4') ||
        url.endsWith('.webm') ||
        url.endsWith('.mov') ||
        url.endsWith('.m4v') ||
        url.contains('spot_video');
  }


  static const Map<String, String> _defaultCuratedPhotos = {
    'hundred-islands-national-park':
        'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?auto=format&fit=crop&w=1200&q=80',
    'patar-white-beach':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    'bolinao-falls-1':
        'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=1200&q=80',
    'third-wave-cafe-dagupan':
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=80',
    'minor-basilica-of-manaoag':
        'https://images.unsplash.com/photo-1548625361-16a9a087192a?auto=format&fit=crop&w=1200&q=80',
  };

  factory SpotModel.fromJson(Map<String, dynamic> j) {
    final slug = (j['slug'] ?? '').toString();
    final rawImg = j['image_url'] ?? j['photo_url'] ?? _firstPhoto(j);
    final fallbackImg = _defaultCuratedPhotos[slug];
    final finalImg = (rawImg != null && rawImg.toString().isNotEmpty)
        ? rawImg.toString()
        : fallbackImg;

    return SpotModel(
      id: j['id'] ?? '',
      slug: slug,
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
      imageUrl: finalImg,
      tags: List<String>.from(j['tags'] ?? []),
      reasons: List<String>.from(j['recommendation_reasons'] ?? []),
    );
  }

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
