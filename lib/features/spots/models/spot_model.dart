import '../../../core/network/api_client.dart';

bool isVideoMedia(String? url, {String? mimeType, String? mediaType}) {
  if (mediaType == 'video') return true;
  if (mimeType != null && mimeType.toLowerCase().startsWith('video/')) return true;
  if (url == null || url.isEmpty) return false;
  final cleanUrl = url.toLowerCase().split('?').first;
  return cleanUrl.endsWith('.mp4') ||
      cleanUrl.endsWith('.webm') ||
      cleanUrl.endsWith('.mov') ||
      cleanUrl.endsWith('.m4v') ||
      cleanUrl.contains('spot_video');
}

class SpotPhoto {
  final String url;
  final bool isVideo;
  final String? sourceName;
  final String? sourceUrl;

  const SpotPhoto({
    required this.url,
    this.isVideo = false,
    this.sourceName,
    this.sourceUrl,
  });

  factory SpotPhoto.fromJson(Map<String, dynamic> j) {
    final rawUrl = j['url']?.toString() ?? '';
    final mime = j['mime_type']?.toString();
    final mediaType = j['media_type']?.toString();
    final isVid = j['is_video'] == true ||
        isVideoMedia(rawUrl, mimeType: mime, mediaType: mediaType);
    return SpotPhoto(
      url: SpotModel.resolveImageUrl(rawUrl),
      isVideo: isVid,
      sourceName: j['source_name']?.toString(),
      sourceUrl: j['source_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'is_video': isVideo,
        if (sourceName != null) 'source_name': sourceName,
        if (sourceUrl != null) 'source_url': sourceUrl,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotPhoto && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
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
  final String? createdBy;
  final bool saved;
  final List<String> tags, reasons;

  final List<String> goodFor;
  final List<String> bestTime;
  final Map<String, String> hours;
  final List<String> amenities;
  final String? sourceUrl;
  final bool isTest;
  final List<SpotPhoto> media;

  const SpotModel({
    required this.id,
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
    this.createdBy,
    this.saved = false,
    this.goodFor = const [],
    this.bestTime = const [],
    this.hours = const {},
    this.amenities = const [],
    this.sourceUrl,
    this.isTest = false,
    this.media = const [],
  });

  List<SpotPhoto> get photos => media.isNotEmpty
      ? media
      : (imageUrl != null && imageUrl!.isNotEmpty
          ? [SpotPhoto(url: imageUrl!)]
          : const []);

  bool get isVideo {
    if (media.isNotEmpty) {
      return media.first.isVideo;
    }
    return isVideoMedia(imageUrl);
  }

  SpotPhoto? get leadStillPhoto {
    for (final p in media) {
      if (!p.isVideo) return p;
    }
    if (imageUrl != null && imageUrl!.isNotEmpty && !isVideoMedia(imageUrl)) {
      return SpotPhoto(
        url: imageUrl!,
        sourceName: sourceName,
        sourceUrl: sourceUrl,
      );
    }
    return null;
  }

  String get teaser {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'^(.*?[.!?])(?:\s|$)').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return trimmed.split('\n').first.trim();
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
    final primaryImg = (rawImg != null && rawImg.toString().trim().isNotEmpty)
        ? resolveImageUrl(rawImg.toString())
        : fallbackImg;

    final mediaList = <SpotPhoto>[];
    final seenUrls = <String>{};

    void addCandidate(
      String? rawUrl, {
      String? mimeType,
      String? mediaType,
      String? srcName,
      String? srcUrl,
    }) {
      if (rawUrl == null) return;
      final trimmed = rawUrl.trim();
      if (trimmed.isEmpty) return;
      final resolved = resolveImageUrl(trimmed);
      if (seenUrls.contains(resolved)) return;
      seenUrls.add(resolved);
      final isVid = isVideoMedia(resolved, mimeType: mimeType, mediaType: mediaType);
      mediaList.add(SpotPhoto(
        url: resolved,
        isVideo: isVid,
        sourceName: srcName ?? j['source_name']?.toString(),
        sourceUrl: srcUrl ?? j['source_url']?.toString(),
      ));
    }

    if (primaryImg != null && primaryImg.trim().isNotEmpty) {
      addCandidate(primaryImg);
    }

    final rawAttached = j['attached_assets'];
    if (rawAttached is List) {
      for (final a in rawAttached) {
        if (a is Map) {
          addCandidate(
            a['url']?.toString(),
            mimeType: a['mime_type']?.toString(),
            mediaType: a['media_type']?.toString(),
            srcName: a['source_name']?.toString(),
            srcUrl: a['source_url']?.toString(),
          );
        } else if (a is String) {
          addCandidate(a);
        }
      }
    }

    final rawPhotos = j['photos'];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is String) {
          addCandidate(p);
        } else if (p is Map) {
          addCandidate(
            p['url']?.toString(),
            mimeType: p['mime_type']?.toString(),
            mediaType: p['media_type']?.toString(),
            srcName: p['source_name']?.toString(),
            srcUrl: p['source_url']?.toString(),
          );
        }
      }
    }

    final rawMedia = j['media'];
    if (rawMedia is List) {
      for (final m in rawMedia) {
        if (m is Map) {
          addCandidate(
            m['url']?.toString(),
            mimeType: m['mime_type']?.toString(),
            mediaType: m['media_type']?.toString(),
            srcName: m['source_name']?.toString(),
            srcUrl: m['source_url']?.toString(),
          );
        } else if (m is String) {
          addCandidate(m);
        }
      }
    }

    final rawGoodFor = j['good_for'] ?? j['goodFor'];
    final goodFor = rawGoodFor is List
        ? rawGoodFor.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final rawBestTime = j['best_time'] ?? j['bestTime'];
    final bestTime = rawBestTime is List
        ? rawBestTime.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final rawHours = j['hours'];
    final Map<String, String> hours = rawHours is Map
        ? rawHours.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        : const <String, String>{};

    final rawAmenities = j['amenities'];
    final amenities = rawAmenities is List
        ? rawAmenities.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final sourceUrl = j['source_url']?.toString() ?? j['sourceUrl']?.toString();
    final isTest = j['is_test'] == true || j['isTest'] == true;

    return SpotModel(
      id: j['id']?.toString() ?? '',
      slug: slug,
      name: j['name']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      category: j['category']?.toString() ?? '',
      subcategory: j['subcategory']?.toString() ?? '',
      municipality: j['municipality']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      sourceName: j['source_name']?.toString() ?? '',
      trustLevel: j['trust_level']?.toString() ?? '',
      crowdStatus: j['crowd_status']?.toString() ?? 'unknown',
      crowdConfidence: j['crowd_confidence']?.toString() ?? 'none',
      gpsLat: (j['gps_lat'] as num?)?.toDouble() ?? 0,
      gpsLng: (j['gps_lng'] as num?)?.toDouble() ?? 0,
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
      questId: j['quest_id']?.toString(),
      saved: j['saved'] == true,
      imageUrl: primaryImg,
      createdBy: j['created_by']?.toString() ?? j['createdBy']?.toString(),
      tags: List<String>.from(j['tags'] ?? []),
      reasons: List<String>.from(j['recommendation_reasons'] ?? []),
      goodFor: goodFor,
      bestTime: bestTime,
      hours: hours,
      amenities: amenities,
      sourceUrl: sourceUrl,
      isTest: isTest,
      media: mediaList,
    );
  }

  static String resolveImageUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return uri.toString();
    }
    final apiUri = Uri.parse(ApiClient.apiBaseUrl);
    final apiOrigin = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );
    final path =
        value.trim().startsWith('/') ? value.trim() : '/${value.trim()}';
    return apiOrigin.resolve(path).toString();
  }

  SpotModel copyWith({
    String? id,
    String? slug,
    String? name,
    String? description,
    String? category,
    String? subcategory,
    String? municipality,
    String? address,
    String? sourceName,
    String? sourceUrl,
    String? trustLevel,
    String? crowdStatus,
    String? crowdConfidence,
    double? gpsLat,
    double? gpsLng,
    double? distanceKm,
    String? questId,
    String? imageUrl,
    String? createdBy,
    bool? saved,
    List<String>? tags,
    List<String>? reasons,
    List<String>? goodFor,
    List<String>? bestTime,
    Map<String, String>? hours,
    List<String>? amenities,
    bool? isTest,
    List<SpotPhoto>? media,
  }) =>
      SpotModel(
        id: id ?? this.id,
        slug: slug ?? this.slug,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        subcategory: subcategory ?? this.subcategory,
        municipality: municipality ?? this.municipality,
        address: address ?? this.address,
        sourceName: sourceName ?? this.sourceName,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        trustLevel: trustLevel ?? this.trustLevel,
        gpsLat: gpsLat ?? this.gpsLat,
        gpsLng: gpsLng ?? this.gpsLng,
        tags: tags ?? this.tags,
        reasons: reasons ?? this.reasons,
        crowdStatus: crowdStatus ?? this.crowdStatus,
        crowdConfidence: crowdConfidence ?? this.crowdConfidence,
        distanceKm: distanceKm ?? this.distanceKm,
        questId: questId ?? this.questId,
        imageUrl: imageUrl ?? this.imageUrl,
        createdBy: createdBy ?? this.createdBy,
        saved: saved ?? this.saved,
        goodFor: goodFor ?? this.goodFor,
        bestTime: bestTime ?? this.bestTime,
        hours: hours ?? this.hours,
        amenities: amenities ?? this.amenities,
        isTest: isTest ?? this.isTest,
        media: media ?? this.media,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'description': description,
        'category': category,
        'subcategory': subcategory,
        'municipality': municipality,
        'address': address,
        'source_name': sourceName,
        if (sourceUrl != null) 'source_url': sourceUrl,
        'trust_level': trustLevel,
        'crowd_status': crowdStatus,
        'crowd_confidence': crowdConfidence,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (questId != null) 'quest_id': questId,
        if (imageUrl != null) 'image_url': imageUrl,
        if (createdBy != null) 'created_by': createdBy,
        'saved': saved,
        'tags': tags,
        'recommendation_reasons': reasons,
        'good_for': goodFor,
        'best_time': bestTime,
        'hours': hours,
        'amenities': amenities,
        'is_test': isTest,
        'media': media.map((m) => m.toJson()).toList(),
      };

  static String? _firstPhoto(Map<String, dynamic> json) {
    final photos = json['photos'] ?? json['attached_assets'];
    if (photos is List && photos.isNotEmpty && photos.first is Map) {
      return (photos.first as Map)['url']?.toString();
    }
    return null;
  }
}
