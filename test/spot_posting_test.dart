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

    test('formats pin labels truthfully', () {
      expect(formatPinLabel(null, null), 'No pin selected');
      expect(formatPinLabel(15.90834, 119.78923), '15.90834, 119.78923');
    });
  });

  group('spot posting step validation', () {
    const valid = SpotPostingDraft(
      name: 'Tambobong White Beach',
      description: 'A quiet stretch of white sand with calm water for swimming and picnics.',
      municipality: 'Dasol',
      address: 'Brgy. Tambobong, Dasol',
      lat: 15.9083,
      lng: 119.7892,
    );

    test('requires basics before leaving the first step', () {
      final errors = validatePostingStep('basics', const SpotPostingDraft());
      expect(errors['name'], isNotNull);
      expect(errors.containsKey('subcategory'), isFalse);
    });

    test('requires a meaningful description and locality', () {
      expect(
        validatePostingStep('story', valid.copyWith(description: 'Too short'))['description'],
        contains('at least 20'),
      );
      expect(validatePostingStep('story', valid).isEmpty, isTrue);
      final placeErrors = validatePostingStep('place', valid.copyWith(municipality: '', address: ''));
      expect(placeErrors['municipality'], isNotNull);
      expect(placeErrors['address'], isNotNull);
    });

    test('reports first invalid step in wizard order and accepts the full draft', () {
      expect(firstInvalidPostingStep(const SpotPostingDraft()), 'basics');
      expect(firstInvalidPostingStep(valid.copyWith(description: '')), 'story');
      expect(firstInvalidPostingStep(valid.copyWith(address: '')), 'place');
      expect(firstInvalidPostingStep(valid.copyWith(priceLevel: 9)), 'details');
      expect(firstInvalidPostingStep(valid), isNull);
      expect(validatePostingStep('review', valid).isEmpty, isTrue);
    });
  });

  group('spot posting payload and media helpers', () {
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
      priceLevel: 1,
      tags: ['community'],
      amenities: ['parking'],
    );

    test('maps the draft onto the API contract with server-compatible defaults', () {
      final payload = buildSpotPayload(draft, assetId: 'asset-1', imageUrl: 'https://cdn.example/photo.jpg');
      expect(payload['name'], 'Tambobong White Beach');
      expect(payload['gps_lat'], 15.9083);
      expect(payload['gps_lng'], 119.7892);
      expect(payload['hours'], {'daily': '06:00 AM - 06:00 PM'});
      expect(payload['tags'], ['community']);
      expect(payload['amenities'], ['parking']);
      expect(payload['image_url'], 'https://cdn.example/photo.jpg');
      expect(payload['asset_id'], 'asset-1');
      expect(payload['asset_ids'], ['asset-1']);
    });

    test('omits media keys and empty hours when nothing was provided', () {
      final payload = buildSpotPayload(draft.copyWith(dailyHours: ''));
      expect(payload['hours'], isEmpty);
      expect(payload['image_url'], '');
      expect(payload.containsKey('asset_id'), isFalse);
      expect(payload.containsKey('asset_ids'), isFalse);
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
