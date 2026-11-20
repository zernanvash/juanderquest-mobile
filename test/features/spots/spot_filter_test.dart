import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/explore/spot_filter_state.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';

SpotModel _spot(String id, String category, String municipality) {
  return SpotModel(
    id: id,
    slug: id,
    name: 'Spot $id',
    description: 'Description for $id',
    category: category,
    subcategory: '',
    municipality: municipality,
    address: '$municipality, Pangasinan',
    sourceName: 'Tourism Board',
    trustLevel: 'open_data',
    gpsLat: 16.0,
    gpsLng: 120.0,
    tags: const [],
    reasons: const [],
  );
}

void main() {
  group('categoryLabel', () {
    test('formats known categories', () {
      expect(categoryLabel('eat_drink'), 'Food & drink');
      expect(categoryLabel('nature_outdoors'), 'Nature');
      expect(categoryLabel('culture_heritage'), 'Culture & heritage');
      expect(categoryLabel('activities_wellness'), 'Activities');
      expect(categoryLabel('shopping_local'), 'Local shops');
      expect(categoryLabel('stay'), 'Places to stay');
    });

    test('formats fallback unknown categories with capitalization and spacing', () {
      expect(categoryLabel('eco_tourism'), 'Eco tourism');
      expect(categoryLabel('farm_tours'), 'Farm tours');
      expect(categoryLabel('diving-snorkeling'), 'Diving snorkeling');
    });

    test('handles null or empty category safely', () {
      expect(categoryLabel(null), 'Destination');
      expect(categoryLabel(''), 'Destination');
      expect(categoryLabel('   '), 'Destination');
    });
  });

  group('SpotFilterState', () {
    final spots = [
      _spot('s1', 'nature_outdoors', 'Bolinao'),
      _spot('s2', 'eat_drink', 'Dagupan'),
      _spot('s3', 'nature_outdoors', 'Dagupan'),
      _spot('s4', 'culture_heritage', 'Manaoag'),
      _spot('s5', 'nature_outdoors', 'Alaminos'),
      _spot('s6', 'stay', 'Bolinao'),
      _spot('s7', 'activities_wellness', 'San Fabian'),
    ];

    test('extracts up to 5 unique categories and municipalities', () {
      final cats = SpotFilterState.extractCategories(spots);
      expect(cats.length, 5);
      expect(cats, [
        'nature_outdoors',
        'eat_drink',
        'culture_heritage',
        'stay',
        'activities_wellness',
      ]);

      final munis = SpotFilterState.extractMunicipalities(spots);
      expect(munis.length, 5);
      expect(munis, [
        'Bolinao',
        'Dagupan',
        'Manaoag',
        'Alaminos',
        'San Fabian',
      ]);
    });

    test('filters by category alone', () {
      const state = SpotFilterState(selectedCategory: 'eat_drink');
      final filtered = state.apply(spots);
      expect(filtered.length, 1);
      expect(filtered.first.id, 's2');
    });

    test('filters by municipality alone', () {
      const state = SpotFilterState(selectedMunicipality: 'Dagupan');
      final filtered = state.apply(spots);
      expect(filtered.length, 2);
      expect(filtered.map((s) => s.id).toList(), ['s2', 's3']);
    });

    test('combines category and municipality filters', () {
      const state = SpotFilterState(
        selectedCategory: 'nature_outdoors',
        selectedMunicipality: 'Dagupan',
      );
      final filtered = state.apply(spots);
      expect(filtered.length, 1);
      expect(filtered.first.id, 's3');
    });

    test('toggling category switches between category and ALL', () {
      var state = const SpotFilterState();
      expect(state.selectedCategory, 'ALL');

      state = state.toggleCategory('nature_outdoors');
      expect(state.selectedCategory, 'nature_outdoors');

      // Tapping same category toggles back to ALL
      state = state.toggleCategory('nature_outdoors');
      expect(state.selectedCategory, 'ALL');
    });

    test('toggling municipality switches between municipality and ALL', () {
      var state = const SpotFilterState();
      expect(state.selectedMunicipality, 'ALL');

      state = state.toggleMunicipality('Bolinao');
      expect(state.selectedMunicipality, 'Bolinao');

      // Tapping same municipality toggles back to ALL
      state = state.toggleMunicipality('Bolinao');
      expect(state.selectedMunicipality, 'ALL');
    });

    test('reset clears both category and municipality to ALL', () {
      var state = const SpotFilterState(
        selectedCategory: 'nature_outdoors',
        selectedMunicipality: 'Bolinao',
      );
      expect(state.isAllSelected, isFalse);

      state = state.reset();
      expect(state.selectedCategory, 'ALL');
      expect(state.selectedMunicipality, 'ALL');
      expect(state.isAllSelected, isTrue);
    });
  });
}
