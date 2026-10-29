const List<Map<String, dynamic>> spotPostingCategories = [
  {
    'id': 'eat_drink',
    'label': '🍜 Food & Culinary',
    'subcategories': ['restaurant', 'carinderia', 'cafe', 'bakery', 'street_food', 'bar'],
  },
  {
    'id': 'nature_outdoors',
    'label': '🏖️ Nature & Beaches',
    'subcategories': ['beach', 'waterfall', 'cave', 'park', 'trailhead', 'viewpoint'],
  },
  {
    'id': 'culture_heritage',
    'label': '🏛️ Heritage & Shrines',
    'subcategories': ['church', 'museum', 'heritage_site', 'arts_crafts'],
  },
  {
    'id': 'activities_wellness',
    'label': '🧗 Outdoor & Eco',
    'subcategories': ['sports_venue', 'running_spot', 'gym', 'recreation', 'water_activity'],
  },
  {
    'id': 'shopping_local',
    'label': '🛍️ Local MSME Crafts',
    'subcategories': ['market', 'souvenir', 'local_products'],
  },
  {
    'id': 'stay',
    'label': '🛏️ Stay & Lodging',
    'subcategories': ['hotel', 'resort', 'homestay', 'campsite'],
  },
];

const List<String> spotPostingAmenities = [
  'parking',
  'restrooms',
  'food_nearby',
  'guide_available',
  'cottage_rentals',
  'boat_service',
  'wifi_signal',
  'pwd_accessible',
];

/// Visitor fit values accepted by `POST /spots` (`good_for`), same as the web composer.
const Map<String, String> spotGoodForOptions = {
  'families': 'Families & kids',
  'solo': 'Solo travelers',
  'couples': 'Couples',
  'groups': 'Groups & barkada',
  'seniors_access': 'Seniors / limited mobility',
};

/// Best-time values accepted by `POST /spots` (`best_time`).
const Map<String, String> spotBestTimeOptions = {
  'early_morning': 'Early morning',
  'daytime': 'Daytime',
  'sunset': 'Sunset',
  'night': 'Night',
  'weekdays': 'Weekdays',
  'dry_season': 'Dry season',
  'rainy_season': 'Rainy season too',
};

const double philippineMinLat = 4.5;
const double philippineMaxLat = 21.5;
const double philippineMinLng = 116;
const double philippineMaxLng = 127;

const int spotPostingMaxImageBytes = 8 * 1024 * 1024;
const int spotPostingMaxVideoBytes = 30 * 1024 * 1024;

List<String> subcategoriesForCategory(String categoryId) {
  final match = spotPostingCategories.firstWhere(
    (category) => category['id'] == categoryId,
    orElse: () => const {'subcategories': <String>[]},
  );
  return List<String>.from(match['subcategories'] as List);
}

String categoryLabel(String categoryId) {
  final match = spotPostingCategories.firstWhere(
    (category) => category['id'] == categoryId,
    orElse: () => {'label': categoryId.replaceAll('_', ' ')},
  );
  return match['label'] as String;
}

class SpotPostingDraft {
  static const Object _unset = Object();

  final String name;
  final String category;
  final String subcategory;
  final String description;
  final String municipality;
  final String barangay;
  final String address;
  final double? lat;
  final double? lng;
  final String dailyHours;
  final List<String> goodFor;
  final List<String> bestTime;
  final List<String> tags;
  final List<String> amenities;

  const SpotPostingDraft({
    this.name = '',
    this.category = 'nature_outdoors',
    this.subcategory = 'beach',
    this.description = '',
    this.municipality = '',
    this.barangay = '',
    this.address = '',
    this.lat,
    this.lng,
    this.dailyHours = '',
    this.goodFor = const [],
    this.bestTime = const [],
    this.tags = const [],
    this.amenities = const [],
  });

  SpotPostingDraft copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? description,
    String? municipality,
    String? barangay,
    String? address,
    Object? lat = _unset,
    Object? lng = _unset,
    String? dailyHours,
    List<String>? goodFor,
    List<String>? bestTime,
    List<String>? tags,
    List<String>? amenities,
  }) {
    return SpotPostingDraft(
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      municipality: municipality ?? this.municipality,
      barangay: barangay ?? this.barangay,
      address: address ?? this.address,
      lat: identical(lat, _unset) ? this.lat : lat as double?,
      lng: identical(lng, _unset) ? this.lng : lng as double?,
      dailyHours: dailyHours ?? this.dailyHours,
      goodFor: goodFor ?? this.goodFor,
      bestTime: bestTime ?? this.bestTime,
      tags: tags ?? this.tags,
      amenities: amenities ?? this.amenities,
    );
  }
}

/// A nearby published spot (within 80 m) returned by `GET /spots/recognize`.
class NearbyDuplicate {
  final String id;
  final String name;
  final int distanceMeters;

  const NearbyDuplicate({required this.id, required this.name, required this.distanceMeters});
}

/// Plan 66: `GET /api/v1/spots/recognize` result.
class SpotRecognitionResult {
  final bool recognized;
  final String? placeName;
  final List<String> nameSuggestions;
  final String formattedAddress;
  final String? municipality;
  final String? barangay;
  final bool outsidePangasinan;
  final String suggestedCategory;
  final String suggestedSubcategory;
  final List<String> goodFor;
  final List<String> bestTime;
  final List<String> amenities;
  final String dailyHours;
  final List<String> storyStarters;
  final List<NearbyDuplicate> nearbyDuplicates;

  const SpotRecognitionResult({
    this.recognized = false,
    this.placeName,
    this.nameSuggestions = const [],
    this.formattedAddress = '',
    this.municipality,
    this.barangay,
    this.outsidePangasinan = false,
    this.suggestedCategory = 'nature_outdoors',
    this.suggestedSubcategory = 'viewpoint',
    this.goodFor = const [],
    this.bestTime = const [],
    this.amenities = const [],
    this.dailyHours = '',
    this.storyStarters = const [],
    this.nearbyDuplicates = const [],
  });

  factory SpotRecognitionResult.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List ? value.whereType<String>().toList() : const [];
    final details = json['suggested_details'] is Map ? Map<String, dynamic>.from(json['suggested_details'] as Map) : const <String, dynamic>{};
    return SpotRecognitionResult(
      recognized: json['recognized'] == true,
      placeName: json['place_name'] as String?,
      nameSuggestions: strings(json['name_suggestions']),
      formattedAddress: (json['formatted_address'] as String?) ?? '',
      municipality: json['municipality'] as String?,
      barangay: json['barangay'] as String?,
      outsidePangasinan: json['outside_pangasinan'] == true,
      suggestedCategory: (json['suggested_category'] as String?) ?? 'nature_outdoors',
      suggestedSubcategory: (json['suggested_subcategory'] as String?) ?? 'viewpoint',
      goodFor: strings(details['good_for']),
      bestTime: strings(details['best_time']),
      amenities: strings(details['amenities']),
      dailyHours: (details['daily_hours'] as String?) ?? '',
      storyStarters: strings(json['story_starters']),
      nearbyDuplicates: [
        for (final item in (json['nearby_duplicates'] as List?) ?? const [])
          if (item is Map)
            NearbyDuplicate(
              id: '${item['id']}',
              name: '${item['name']}',
              distanceMeters: (item['distance_meters'] as num?)?.round() ?? 0,
            ),
      ],
    );
  }

  /// Offline fallback so posting never blocks on a weak signal: generic starters, no address.
  factory SpotRecognitionResult.offline() => const SpotRecognitionResult(
        goodFor: ['groups', 'solo', 'couples'],
        bestTime: ['early_morning', 'sunset'],
        amenities: ['parking'],
        dailyHours: '06:00 AM - 06:00 PM',
        storyStarters: [
          'A scenic spot with relaxing views and fresh air, worth a stop on any trip.',
          'Best visited in the early morning or late afternoon; bring water and sun protection.',
        ],
      );

  /// "Patar White Beach" or "New spot in Brgy. Patar, Bolinao".
  String get title {
    if (placeName != null && placeName!.trim().isNotEmpty) return placeName!;
    final where = [barangay, municipality].whereType<String>().where((part) => part.isNotEmpty).join(', ');
    return where.isEmpty ? 'New spot here' : 'New spot in $where';
  }
}

/// Which draft fields the traveler edited by hand; recognition never overwrites them.
class SpotPostingTouched {
  final bool name;
  final bool category;
  final bool location;
  final bool details;

  const SpotPostingTouched({this.name = false, this.category = false, this.location = false, this.details = false});

  SpotPostingTouched copyWith({bool? name, bool? category, bool? location, bool? details}) => SpotPostingTouched(
        name: name ?? this.name,
        category: category ?? this.category,
        location: location ?? this.location,
        details: details ?? this.details,
      );
}

/// Fills untouched fields from recognition, keeping only values `POST /spots` accepts.
SpotPostingDraft applyRecognition(
  SpotPostingDraft draft,
  SpotRecognitionResult rec, {
  SpotPostingTouched touched = const SpotPostingTouched(),
}) {
  var next = draft;
  if (!touched.location) {
    next = next.copyWith(
      municipality: rec.municipality ?? next.municipality,
      barangay: rec.barangay ?? '',
      address: rec.formattedAddress.isNotEmpty ? rec.formattedAddress : next.address,
    );
  }
  if (!touched.name && rec.placeName != null && rec.placeName!.trim().isNotEmpty) {
    next = next.copyWith(name: rec.placeName);
  }
  if (!touched.category && spotPostingCategories.any((c) => c['id'] == rec.suggestedCategory)) {
    final subs = subcategoriesForCategory(rec.suggestedCategory);
    next = next.copyWith(
      category: rec.suggestedCategory,
      subcategory: subs.contains(rec.suggestedSubcategory) ? rec.suggestedSubcategory : subs.first,
    );
  }
  if (!touched.details) {
    next = next.copyWith(
      goodFor: rec.goodFor.where(spotGoodForOptions.containsKey).take(5).toList(),
      bestTime: rec.bestTime.where(spotBestTimeOptions.containsKey).take(4).toList(),
      amenities: rec.amenities.where(spotPostingAmenities.contains).toList(),
      dailyHours: rec.dailyHours,
    );
  }
  return next;
}

/// Traveler-facing place label; never raw coordinates.
String formatRecognizedPlaceLabel(SpotPostingDraft draft) {
  final where = [draft.barangay, draft.municipality].where((part) => part.trim().isNotEmpty).join(', ');
  return where.isEmpty ? 'Selected spot on map' : where;
}

/// Appends a story starter once.
String appendStoryStarter(String description, String starter) {
  final current = description.trim();
  if (current.contains(starter)) return description;
  return current.isEmpty ? starter : '$current $starter';
}

String? validatePostingPin(double? lat, double? lng) {
  if (lat == null || lng == null) return 'Place the destination pin on the map first.';
  if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) {
    return 'The pin coordinates must be valid numbers.';
  }
  if (lat < philippineMinLat ||
      lat > philippineMaxLat ||
      lng < philippineMinLng ||
      lng > philippineMaxLng) {
    return 'The pin must be inside the Philippines. Move the pin and try again.';
  }
  return null;
}

/// Validates the whole one-page draft before publishing.
Map<String, String> validatePostingDraft(SpotPostingDraft draft) {
  final errors = <String, String>{};
  final name = draft.name.trim();
  if (name.length < 3) {
    errors['name'] = 'Destination name must be at least 3 characters.';
  } else if (name.length > 200) {
    errors['name'] = 'Destination name must be at most 200 characters.';
  }
  if (!spotPostingCategories.any((category) => category['id'] == draft.category)) {
    errors['category'] = 'Choose a valid category.';
  }
  final subcategory = draft.subcategory.trim();
  if (subcategory.length < 2 || subcategory.length > 50) {
    errors['subcategory'] = 'Choose a subcategory for this destination.';
  }
  final description = draft.description.trim();
  if (description.length < 20) {
    errors['description'] = 'Description must be at least 20 characters.';
  } else if (description.length > 2000) {
    errors['description'] = 'Description must be at most 2000 characters.';
  }
  final municipality = draft.municipality.trim();
  if (municipality.length < 2 || municipality.length > 100) {
    errors['municipality'] = 'Municipality or city is required.';
  }
  final address = draft.address.trim();
  if (address.length < 3 || address.length > 300) {
    errors['address'] = 'Address or landmark description is required.';
  }
  final pinError = validatePostingPin(draft.lat, draft.lng);
  if (pinError != null) errors['pin'] = pinError;
  if (draft.goodFor.length > 5 || draft.goodFor.any((id) => !spotGoodForOptions.containsKey(id))) {
    errors['goodFor'] = 'Choose at most 5 visitor fit tags.';
  }
  if (draft.bestTime.length > 4 || draft.bestTime.any((id) => !spotBestTimeOptions.containsKey(id))) {
    errors['bestTime'] = 'Choose at most 4 best time tags.';
  }
  if (draft.amenities.length > 20) errors['amenities'] = 'Choose at most 20 amenities.';
  if (draft.dailyHours.trim().length > 80) {
    errors['dailyHours'] = 'Operating hours must be at most 80 characters.';
  }
  return errors;
}

/// One clear prompt for the sticky publish bar, or null when the draft is ready.
String? postingReadiness(SpotPostingDraft draft) {
  final errors = validatePostingDraft(draft);
  if (errors.containsKey('pin')) return 'Place the pin on the map';
  if (errors.containsKey('name')) return 'Add a name for this place';
  if (errors.containsKey('description')) return 'Tap a story starter or add a short description';
  if (errors.containsKey('municipality') || errors.containsKey('address')) return 'Add the town and a landmark';
  return errors.isEmpty ? null : errors.values.first;
}

String? validatePostingMediaSize(int bytes, {required bool isVideo}) {
  final maxBytes = isVideo ? spotPostingMaxVideoBytes : spotPostingMaxImageBytes;
  if (bytes > maxBytes) {
    return isVideo ? 'Video file size exceeds 30 MB limit.' : 'File size exceeds 8 MB limit.';
  }
  return null;
}

Map<String, dynamic> buildSpotPayload(
  SpotPostingDraft draft, {
  String? assetId,
  String? imageUrl,
}) {
  final hours = draft.dailyHours.trim().isEmpty ? <String, dynamic>{} : {'daily': draft.dailyHours.trim()};
  return {
    'name': draft.name.trim(),
    'description': draft.description.trim(),
    'category': draft.category,
    'subcategory': draft.subcategory.trim(),
    'tags': draft.tags,
    'municipality': draft.municipality.trim(),
    'address': draft.address.trim(),
    'gps_lat': draft.lat,
    'gps_lng': draft.lng,
    'good_for': draft.goodFor,
    'best_time': draft.bestTime,
    'hours': hours,
    'amenities': draft.amenities,
    'image_url': imageUrl ?? '',
    if (assetId != null) 'asset_id': assetId,
    if (assetId != null) 'asset_ids': [assetId],
  };
}
