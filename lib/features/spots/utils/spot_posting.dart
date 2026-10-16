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

const List<String> spotPostingPriceLabels = [
  'Free (₱0)',
  'Budget (₱)',
  'Mid (₱₱)',
  'Premium (₱₱₱)',
  'Luxury (₱₱₱₱)',
];

const List<String> spotPostingSteps = ['basics', 'story', 'place', 'details', 'media', 'review'];

const Map<String, String> spotPostingStepLabels = {
  'basics': 'Basics',
  'story': 'Story',
  'place': 'Place',
  'details': 'Details',
  'media': 'Photo',
  'review': 'Review',
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

class SpotPostingDraft {
  static const Object _unset = Object();

  final String name;
  final String category;
  final String subcategory;
  final String description;
  final String municipality;
  final String address;
  final double? lat;
  final double? lng;
  final String dailyHours;
  final int priceLevel;
  final List<String> tags;
  final List<String> amenities;

  const SpotPostingDraft({
    this.name = '',
    this.category = 'nature_outdoors',
    this.subcategory = 'beach',
    this.description = '',
    this.municipality = '',
    this.address = '',
    this.lat,
    this.lng,
    this.dailyHours = '',
    this.priceLevel = 1,
    this.tags = const [],
    this.amenities = const [],
  });

  SpotPostingDraft copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? description,
    String? municipality,
    String? address,
    Object? lat = _unset,
    Object? lng = _unset,
    String? dailyHours,
    int? priceLevel,
    List<String>? tags,
    List<String>? amenities,
  }) {
    return SpotPostingDraft(
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      municipality: municipality ?? this.municipality,
      address: address ?? this.address,
      lat: identical(lat, _unset) ? this.lat : lat as double?,
      lng: identical(lng, _unset) ? this.lng : lng as double?,
      dailyHours: dailyHours ?? this.dailyHours,
      priceLevel: priceLevel ?? this.priceLevel,
      tags: tags ?? this.tags,
      amenities: amenities ?? this.amenities,
    );
  }
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

String formatPinLabel(double? lat, double? lng) {
  if (lat == null || lng == null) return 'No pin selected';
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

Map<String, String> validatePostingStep(String step, SpotPostingDraft draft) {
  final errors = <String, String>{};

  if (step == 'basics' || step == 'review') {
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
  }

  if (step == 'story' || step == 'review') {
    final description = draft.description.trim();
    if (description.length < 20) {
      errors['description'] = 'Description must be at least 20 characters.';
    } else if (description.length > 2000) {
      errors['description'] = 'Description must be at most 2000 characters.';
    }
  }

  if (step == 'place' || step == 'review') {
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
  }

  if (step == 'details' || step == 'review') {
    if (draft.priceLevel < 0 || draft.priceLevel > 4) {
      errors['priceLevel'] = 'Choose a valid price level.';
    }
    if (draft.amenities.length > 20) {
      errors['amenities'] = 'Choose at most 20 amenities.';
    }
    if (draft.dailyHours.trim().length > 80) {
      errors['dailyHours'] = 'Operating hours must be at most 80 characters.';
    }
  }

  return errors;
}

String? firstInvalidPostingStep(SpotPostingDraft draft) {
  for (final step in ['basics', 'story', 'place', 'details']) {
    if (validatePostingStep(step, draft).isNotEmpty) return step;
  }
  return null;
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
    'price_level': draft.priceLevel,
    'hours': hours,
    'amenities': draft.amenities,
    'image_url': imageUrl ?? '',
    if (assetId != null) 'asset_id': assetId,
    if (assetId != null) 'asset_ids': [assetId],
  };
}
