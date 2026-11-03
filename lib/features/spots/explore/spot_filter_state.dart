import '../models/spot_model.dart';

const Map<String, String> _knownCategoryLabels = {
  'eat_drink': 'Food & drink',
  'nature_outdoors': 'Nature',
  'culture_heritage': 'Culture & heritage',
  'activities_wellness': 'Activities',
  'shopping_local': 'Local shops',
  'stay': 'Places to stay',
};

/// Human readable label for a category ID, matching the web implementation.
String categoryLabel(String? category) {
  if (category == null || category.trim().isEmpty) return 'Destination';
  final normalized = category.trim();
  final known = _knownCategoryLabels[normalized];
  if (known != null) return known;

  final words = normalized.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (words.isEmpty) return 'Destination';
  return words[0].toUpperCase() + words.substring(1);
}

/// Filter state and extraction helper for the explore feed.
class SpotFilterState {
  const SpotFilterState({
    this.selectedCategory = 'ALL',
    this.selectedMunicipality = 'ALL',
  });

  final String selectedCategory;
  final String selectedMunicipality;

  bool get isAllSelected =>
      selectedCategory == 'ALL' && selectedMunicipality == 'ALL';

  SpotFilterState toggleCategory(String category) {
    if (selectedCategory == category) {
      return copyWith(selectedCategory: 'ALL');
    }
    return copyWith(selectedCategory: category);
  }

  SpotFilterState toggleMunicipality(String municipality) {
    if (selectedMunicipality == municipality) {
      return copyWith(selectedMunicipality: 'ALL');
    }
    return copyWith(selectedMunicipality: municipality);
  }

  SpotFilterState reset() {
    return const SpotFilterState(
      selectedCategory: 'ALL',
      selectedMunicipality: 'ALL',
    );
  }

  SpotFilterState copyWith({
    String? selectedCategory,
    String? selectedMunicipality,
  }) {
    return SpotFilterState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedMunicipality: selectedMunicipality ?? this.selectedMunicipality,
    );
  }

  /// Evaluates whether a spot passes both category and municipality filters.
  bool matches(SpotModel spot) {
    final matchesCat =
        selectedCategory == 'ALL' || spot.category == selectedCategory;
    final matchesMuni = selectedMunicipality == 'ALL' ||
        spot.municipality == selectedMunicipality;
    return matchesCat && matchesMuni;
  }

  /// Filters a list of spots according to current criteria.
  List<SpotModel> apply(List<SpotModel> spots) {
    return spots.where(matches).toList();
  }

  /// Extracts up to 5 unique non-empty categories from a spots list.
  static List<String> extractCategories(List<SpotModel> spots, {int limit = 5}) {
    final seen = <String>{};
    final result = <String>[];
    for (final s in spots) {
      final cat = s.category.trim();
      if (cat.isNotEmpty && seen.add(cat)) {
        result.add(cat);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  /// Extracts up to 5 unique non-empty municipalities from a spots list.
  static List<String> extractMunicipalities(List<SpotModel> spots, {int limit = 5}) {
    final seen = <String>{};
    final result = <String>[];
    for (final s in spots) {
      final muni = s.municipality.trim();
      if (muni.isNotEmpty && seen.add(muni)) {
        result.add(muni);
        if (result.length >= limit) break;
      }
    }
    return result;
  }
}
