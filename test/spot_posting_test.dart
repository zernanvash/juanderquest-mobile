import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/utils/spot_posting.dart';

void main() {
  group('spot posting pin validation', () {
    test('accepts pins inside the Philippines and rejects outside/NaN', () {
      expect(validatePostingPin(14.5995, 120.9842), isNull);
      expect(validatePostingPin(6.9, 126.2), isNull);
      expect(validatePostingPin(null, 120), contains('Place the destination pin'));
      expect(validatePostingPin(double.nan, 120), contains('valid numbers'));
      expect(validatePostingPin(3.9, 120), contains('inside the Philippines'));
      expect(validatePostingPin(21.6, 120), contains('inside the Philippines'));
      expect(validatePostingPin(14.5, 115.9), contains('inside the Philippines'));
      expect(validatePostingPin(14.5, 127.1), contains('inside the Philippines'));
    });

    test('labels the place without raw coordinates', () {
      expect(formatRecognizedPlaceLabel(const SpotPostingDraft(lat: 15.90834, lng: 119.78923)), 'Selected spot on map');
      expect(formatRecognizedPlaceLabel(const SpotPostingDraft(municipality: 'Bolinao', barangay: 'Brgy. Patar')), 'Brgy. Patar, Bolinao');
      expect(formatRecognizedPlaceLabel(const SpotPostingDraft(municipality: 'Bolinao')), 'Bolinao');
    });
  });

  group('one-page draft validation', () {
    const valid = SpotPostingDraft(
      name: 'Tambobong White Beach',
      description: 'A quiet stretch of white sand with calm water for swimming and picnics.',
      municipality: 'Dasol',
      address: 'Brgy. Tambobong, Dasol',
      lat: 15.9083,
      lng: 119.7892,
    );

    test('requires name, description, locality and a pin', () {
      final errors = validatePostingDraft(const SpotPostingDraft());
      expect(errors.keys, containsAll(['name', 'description', 'municipality', 'address', 'pin']));
      expect(validatePostingDraft(valid), isEmpty);
    });

    test('only accepts the API visitor-fit vocabularies', () {
      expect(validatePostingDraft(valid.copyWith(goodFor: ['families', 'groups'], bestTime: ['sunset'])), isEmpty);
      expect(validatePostingDraft(valid.copyWith(goodFor: ['friends']))['goodFor'], isNotNull);
      expect(validatePostingDraft(valid.copyWith(bestTime: ['morning']))['bestTime'], isNotNull);
    });

    test('gives one clear readiness prompt', () {
      expect(postingReadiness(valid), isNull);
      expect(postingReadiness(valid.copyWith(name: '')), 'Add a name for this place');
      expect(postingReadiness(valid.copyWith(description: '')), 'Tap a story starter or add a short description');
      expect(postingReadiness(valid.copyWith(lat: null)), 'Place the pin on the map');
    });
  });

  group('recognition (Plan 66)', () {
    final rec = SpotRecognitionResult.fromJson({
      'recognized': true,
      'place_name': 'Patar White Beach',
      'name_suggestions': ['Patar White Beach', 'Patar Beach'],
      'formatted_address': 'Patar Road, Brgy. Patar, Bolinao, Pangasinan',
      'municipality': 'Bolinao',
      'barangay': 'Brgy. Patar',
      'outside_pangasinan': false,
      'suggested_category': 'nature_outdoors',
      'suggested_subcategory': 'beach',
      'suggested_details': {
        'good_for': ['families', 'groups', 'friends'],
        'best_time': ['early_morning', 'morning'],
        'amenities': ['parking', 'photo_spots'],
        'daily_hours': '06:00 AM - 06:00 PM',
      },
      'story_starters': ['Patar White Beach in Brgy. Patar, Bolinao with relaxing views and fresh air.'],
      'nearby_duplicates': [
        {'id': 'spot-patar', 'name': 'Patar Rock Formation', 'distance_meters': 42},
      ],
    });

    test('parses the API payload and names unnamed places by area', () {
      expect(rec.title, 'Patar White Beach');
      expect(rec.nearbyDuplicates.single.distanceMeters, 42);
      expect(const SpotRecognitionResult(barangay: 'Brgy. Patar', municipality: 'Bolinao').title, 'New spot in Brgy. Patar, Bolinao');
      expect(const SpotRecognitionResult().title, 'New spot here');
    });

    test('fills an empty draft and drops values the API would reject', () {
      final draft = applyRecognition(const SpotPostingDraft(lat: 16.3, lng: 119.8), rec);
      expect(draft.name, 'Patar White Beach');
      expect(draft.municipality, 'Bolinao');
      expect(draft.barangay, 'Brgy. Patar');
      expect(draft.address, 'Patar Road, Brgy. Patar, Bolinao, Pangasinan');
      expect(draft.category, 'nature_outdoors');
      expect(draft.subcategory, 'beach');
      expect(draft.goodFor, ['families', 'groups']);
      expect(draft.bestTime, ['early_morning']);
      expect(draft.amenities, ['parking']);
      expect(draft.dailyHours, '06:00 AM - 06:00 PM');
    });

    test('never overwrites what the traveler touched', () {
      const typed = SpotPostingDraft(name: 'Hidden Cove', municipality: 'Anda', address: 'Near the school', goodFor: ['couples']);
      final draft = applyRecognition(typed, rec,
          touched: const SpotPostingTouched(name: true, location: true, details: true));
      expect(draft.name, 'Hidden Cove');
      expect(draft.municipality, 'Anda');
      expect(draft.goodFor, ['couples']);
    });

    test('appends story starters once and offline starters are long enough', () {
      const line = 'Patar White Beach in Brgy. Patar, Bolinao with relaxing views and fresh air.';
      expect(appendStoryStarter('', line), line);
      expect(appendStoryStarter('Nice.', line), 'Nice. $line');
      expect(appendStoryStarter(line, line), line);
      for (final starter in SpotRecognitionResult.offline().storyStarters) {
        expect(starter.length, greaterThanOrEqualTo(45));
      }
    });
  });

  group('payload and media helpers', () {
    const draft = SpotPostingDraft(
      name: 'Tambobong White Beach',
      category: 'nature_outdoors',
      subcategory: 'beach',
      description: 'A quiet stretch of white sand with calm water for swimming and picnics.',
      municipality: 'Dasol',
      address: 'Brgy. Tambobong, Dasol',
      lat: 15.9083,
      lng: 119.7892,
      dailyHours: '06:00 AM - 06:00 PM',
      goodFor: ['families'],
      bestTime: ['sunset'],
      tags: ['community'],
      amenities: ['parking'],
    );

    test('maps the draft onto the API contract (good_for/best_time, no price level)', () {
      final payload = buildSpotPayload(draft, assetId: 'asset-1', imageUrl: 'https://cdn.example/photo.jpg');
      expect(payload['name'], 'Tambobong White Beach');
      expect(payload['gps_lat'], 15.9083);
      expect(payload['gps_lng'], 119.7892);
      expect(payload['hours'], {'daily': '06:00 AM - 06:00 PM'});
      expect(payload['good_for'], ['families']);
      expect(payload['best_time'], ['sunset']);
      expect(payload.containsKey('price_level'), isFalse);
      expect(payload['amenities'], ['parking']);
      expect(payload['asset_ids'], ['asset-1']);
    });

    test('omits media keys and empty hours when nothing was provided', () {
      final payload = buildSpotPayload(draft.copyWith(dailyHours: ''));
      expect(payload['hours'], isEmpty);
      expect(payload['image_url'], '');
      expect(payload.containsKey('asset_id'), isFalse);
    });

    test('enforces media size limits per media type', () {
      expect(validatePostingMediaSize(1024, isVideo: false), isNull);
      expect(validatePostingMediaSize(9 * 1024 * 1024, isVideo: false), contains('8 MB'));
      expect(validatePostingMediaSize(20 * 1024 * 1024, isVideo: true), isNull);
      expect(validatePostingMediaSize(31 * 1024 * 1024, isVideo: true), contains('30 MB'));
    });

    test('lists subcategories for known categories only', () {
      expect(subcategoriesForCategory('eat_drink'), contains('cafe'));
      expect(subcategoriesForCategory('unknown'), isEmpty);
    });
  });
}
