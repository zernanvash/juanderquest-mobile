import '../../../core/network/api_client.dart';

bool isVideoMedia(String? url, {String? mimeType, String? mediaType}) {
  if (mediaType == 'video') return true;
  if (mimeType != null && mimeType.toLowerCase().startsWith('video/')) {
    return true;
  }
  if (url == null || url.isEmpty) {
    return false;
  }
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
      other is SpotPhoto &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}

class SpotAuthor {
  final String id;
  final String? handle;
  final String displayName;
  final String avatarUrl;

  const SpotAuthor({
    required this.id,
    this.handle,
    required this.displayName,
    this.avatarUrl = '',
  });

  String get formattedHandle {
    final clean = (handle ?? '').trim().replaceFirst(RegExp(r'^@+'), '');
    return clean.isNotEmpty ? '@$clean' : displayName;
  }

  factory SpotAuthor.fromJson(Map<String, dynamic> j) => SpotAuthor(
        id: j['id']?.toString() ?? '',
        handle: j['handle']?.toString(),
        displayName: j['display_name']?.toString() ?? 'Traveler',
        avatarUrl: j['avatar_url']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (handle != null) 'handle': handle,
        'display_name': displayName,
        'avatar_url': avatarUrl,
      };
}

class SpotSponsor {
  final String name;
  final String? logo;
  final String questId;

  const SpotSponsor({
    required this.name,
    this.logo,
    required this.questId,
  });

  factory SpotSponsor.fromJson(Map<String, dynamic> j) => SpotSponsor(
        name: j['name']?.toString() ?? '',
        logo: j['logo']?.toString(),
        questId: j['quest_id']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (logo != null) 'logo': logo,
        'quest_id': questId,
      };
}

class SpotDuplicateHint {
  final String id;
  final String slug;
  final String name;
  final String municipality;

  const SpotDuplicateHint({
    required this.id,
    required this.slug,
    required this.name,
    required this.municipality,
  });

  factory SpotDuplicateHint.fromJson(Map<String, dynamic> j) =>
      SpotDuplicateHint(
        id: j['id']?.toString() ?? '',
        slug: j['slug']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        municipality: j['municipality']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'municipality': municipality,
      };
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
  final SpotAuthor? author;
  final int? priceLevel;
  final bool saved;

  /// Plan 93b WP-13: the server's like state and real like count.
  final bool liked;
  final int likeCount;
  final List<String> tags, reasons;

  final List<String> goodFor;
  final List<String> bestTime;
  final Map<String, String> hours;
  final List<String> amenities;
  final String? sourceUrl;
  final bool isTest;
  final List<SpotPhoto> media;
  final String status;
  final List<String> moderationReasons;
  final List<String> moderationMessages;
  final SpotDuplicateHint? duplicateSpot;
  final bool appealSubmitted;
  final List<SpotSponsor> sponsors;

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
    this.author,
    this.priceLevel,
    this.saved = false,
    this.liked = false,
    this.likeCount = 0,
    this.goodFor = const [],
    this.bestTime = const [],
    this.hours = const {},
    this.amenities = const [],
    this.sourceUrl,
    this.isTest = false,
    this.media = const [],
    this.status = 'published',
    this.moderationReasons = const [],
    this.moderationMessages = const [],
    this.duplicateSpot,
    this.appealSubmitted = false,
    this.sponsors = const [],
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
      final isVid =
          isVideoMedia(resolved, mimeType: mimeType, mediaType: mediaType);
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
        ? rawGoodFor
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    final rawBestTime = j['best_time'] ?? j['bestTime'];
    final bestTime = rawBestTime is List
        ? rawBestTime
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    final rawHours = j['hours'];
    final Map<String, String> hours = rawHours is Map
        ? rawHours.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        : const <String, String>{};

    final rawAmenities = j['amenities'];
    final amenities = rawAmenities is List
        ? rawAmenities
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    final sourceUrl = j['source_url']?.toString() ?? j['sourceUrl']?.toString();
    final isTest = j['is_test'] == true || j['isTest'] == true;
    final rawModReasons = j['moderation_reasons'];
    final modReasons = rawModReasons is List
        ? rawModReasons
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    final rawModMessages = j['moderation_messages'];
    final modMessages = rawModMessages is List
        ? rawModMessages
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    final rawDup = j['duplicate_spot'];
    final dupHint = rawDup is Map
        ? SpotDuplicateHint.fromJson(Map<String, dynamic>.from(rawDup))
        : null;
    final rawSponsors = j['sponsors'];
    final sponsors = rawSponsors is List
        ? [
            for (final s in rawSponsors)
              if (s is Map && (s['name']?.toString().trim() ?? '').isNotEmpty)
                SpotSponsor.fromJson(Map<String, dynamic>.from(s)),
          ]
        : const <SpotSponsor>[];

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
      liked: j['liked'] == true,
      likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
      imageUrl: primaryImg,
      createdBy: j['created_by']?.toString() ?? j['createdBy']?.toString(),
      author: j['author'] is Map
          ? SpotAuthor.fromJson(Map<String, dynamic>.from(j['author'] as Map))
          : null,
      priceLevel: (j['price_level'] as num?)?.toInt(),
      tags: List<String>.from(j['tags'] ?? []),
      reasons: List<String>.from(j['recommendation_reasons'] ?? []),
      goodFor: goodFor,
      bestTime: bestTime,
      hours: hours,
      amenities: amenities,
      sourceUrl: sourceUrl,
      isTest: isTest,
      media: mediaList,
      status: j['status']?.toString() ?? 'published',
      moderationReasons: modReasons,
      moderationMessages: modMessages,
      duplicateSpot: dupHint,
      appealSubmitted: j['appeal_submitted'] == true,
      sponsors: sponsors,
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
    SpotAuthor? author,
    int? priceLevel,
    bool? saved,
    bool? liked,
    int? likeCount,
    List<String>? tags,
    List<String>? reasons,
    List<String>? goodFor,
    List<String>? bestTime,
    Map<String, String>? hours,
    List<String>? amenities,
    bool? isTest,
    List<SpotPhoto>? media,
    String? status,
    List<String>? moderationReasons,
    List<String>? moderationMessages,
    SpotDuplicateHint? duplicateSpot,
    bool? appealSubmitted,
    List<SpotSponsor>? sponsors,
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
        author: author ?? this.author,
        priceLevel: priceLevel ?? this.priceLevel,
        saved: saved ?? this.saved,
        liked: liked ?? this.liked,
        likeCount: likeCount ?? this.likeCount,
        goodFor: goodFor ?? this.goodFor,
        bestTime: bestTime ?? this.bestTime,
        hours: hours ?? this.hours,
        amenities: amenities ?? this.amenities,
        isTest: isTest ?? this.isTest,
        media: media ?? this.media,
        status: status ?? this.status,
        moderationReasons: moderationReasons ?? this.moderationReasons,
        moderationMessages: moderationMessages ?? this.moderationMessages,
        duplicateSpot: duplicateSpot ?? this.duplicateSpot,
        appealSubmitted: appealSubmitted ?? this.appealSubmitted,
        sponsors: sponsors ?? this.sponsors,
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
        if (author != null) 'author': author!.toJson(),
        if (priceLevel != null) 'price_level': priceLevel,
        'saved': saved,
        'liked': liked,
        'like_count': likeCount,
        'tags': tags,
        'recommendation_reasons': reasons,
        'good_for': goodFor,
        'best_time': bestTime,
        'hours': hours,
        'amenities': amenities,
        'is_test': isTest,
        'media': media.map((m) => m.toJson()).toList(),
        'sponsors': sponsors.map((s) => s.toJson()).toList(),
      };

  static String? _firstPhoto(Map<String, dynamic> json) {
    final photos = json['photos'] ?? json['attached_assets'];
    if (photos is List && photos.isNotEmpty && photos.first is Map) {
      return (photos.first as Map)['url']?.toString();
    }
    return null;
  }
}

/// Lightweight destination search hit returned by `GET /spots/search`.
class SpotSearchHit {
  final String id;
  final String slug;
  final String name;
  final String municipality;
  final String category;
  final String? tier;
  final String? thumb;

  const SpotSearchHit({
    required this.id,
    required this.slug,
    required this.name,
    required this.municipality,
    required this.category,
    this.tier,
    this.thumb,
  });

  factory SpotSearchHit.fromJson(Map<String, dynamic> json) {
    final rawThumb = json['thumb']?.toString();
    return SpotSearchHit(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      tier: json['tier']?.toString(),
      thumb: rawThumb != null && rawThumb.trim().isNotEmpty
          ? SpotModel.resolveImageUrl(rawThumb)
          : null,
    );
  }

  SpotModel toSpotModel() => SpotModel(
        id: id,
        slug: slug,
        name: name,
        description: '',
        category: category,
        subcategory: '',
        municipality: municipality,
        address: '',
        sourceName: 'Verified Catalog',
        trustLevel: 'lgu_verified',
        gpsLat: 0,
        gpsLng: 0,
        imageUrl: thumb,
        tags: const [],
        reasons: const [],
      );
}

/// Lightweight pin returned inside `GET /spots/map` (`data.markers`).
class SpotMapMarker {
  final String id;
  final String slug;
  final String name;
  final double lat;
  final double lng;
  final String category;
  final String? tier;
  final String? thumb;

  const SpotMapMarker({
    required this.id,
    required this.slug,
    required this.name,
    required this.lat,
    required this.lng,
    required this.category,
    this.tier,
    this.thumb,
  });

  factory SpotMapMarker.fromJson(Map<String, dynamic> json) {
    final rawThumb = json['thumb']?.toString();
    return SpotMapMarker(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? '',
      tier: json['tier']?.toString(),
      thumb: rawThumb != null && rawThumb.trim().isNotEmpty
          ? SpotModel.resolveImageUrl(rawThumb)
          : null,
    );
  }

  SpotModel toSpotModel() => SpotModel(
        id: id,
        slug: slug,
        name: name,
        description: '',
        category: category,
        subcategory: '',
        municipality: '',
        address: '',
        sourceName: 'Verified Catalog',
        trustLevel: 'lgu_verified',
        gpsLat: lat,
        gpsLng: lng,
        imageUrl: thumb,
        tags: const [],
        reasons: const [],
      );
}

/// Cluster bubble returned inside `GET /spots/map` (`data.clusters`).
class SpotMapCluster {
  final double lat;
  final double lng;
  final int count;

  /// `[west, south, east, north]` bounds to zoom into on tap.
  final List<double> bbox;

  const SpotMapCluster({
    required this.lat,
    required this.lng,
    required this.count,
    required this.bbox,
  });

  factory SpotMapCluster.fromJson(Map<String, dynamic> json) {
    final rawBbox = json['bbox'];
    final bboxList = rawBbox is List
        ? rawBbox
            .map((e) => (e as num?)?.toDouble() ?? 0.0)
            .toList(growable: false)
        : const <double>[];
    final lat = (json['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (json['lng'] as num?)?.toDouble() ?? 0.0;
    return SpotMapCluster(
      lat: lat,
      lng: lng,
      count: (json['count'] as num?)?.toInt() ?? 0,
      bbox: bboxList.length == 4 ? bboxList : <double>[lng, lat, lng, lat],
    );
  }
}

/// Parsed response for `GET /spots/map`.
class SpotMapViewResponse {
  final List<SpotMapMarker> markers;
  final List<SpotMapCluster> clusters;
  final int total;

  const SpotMapViewResponse({
    required this.markers,
    required this.clusters,
    required this.total,
  });

  factory SpotMapViewResponse.fromEnvelope(Map<String, dynamic> body) {
    final rawData = body['data'];
    if (rawData is! Map) {
      throw const FormatException('Expected map payload from /spots/map');
    }
    final data = Map<String, dynamic>.from(rawData);
    final markers = (data['markers'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => SpotMapMarker.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => m.id.isNotEmpty)
        .toList();
    final clusters = (data['clusters'] as List? ?? const [])
        .whereType<Map>()
        .map((c) => SpotMapCluster.fromJson(Map<String, dynamic>.from(c)))
        .where((c) => c.count > 0)
        .toList();
    final meta = body['meta'];
    final total = meta is Map
        ? ((meta['total'] as num?)?.toInt() ?? markers.length)
        : markers.length;
    return SpotMapViewResponse(
      markers: markers,
      clusters: clusters,
      total: total,
    );
  }
}
