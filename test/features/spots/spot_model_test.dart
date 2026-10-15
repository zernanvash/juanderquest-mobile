import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';

void main() {
  test('resolves API-relative catalog image paths to absolute HTTPS URLs', () {
    final spot = SpotModel.fromJson({
      'slug': 'hundred-islands-national-park',
      'image_url': '/api/v1/uploads/spot-photos/catalog-hundred-islands.jpg',
    });

    expect(
      spot.imageUrl,
      'https://api.juanderquest.app/api/v1/uploads/spot-photos/catalog-hundred-islands.jpg',
    );
  });

  test('preserves an already absolute image URL', () {
    const imageUrl = 'https://images.example.test/destination.jpg';
    final spot = SpotModel.fromJson({
      'slug': 'sample-destination',
      'image_url': imageUrl,
    });

    expect(spot.imageUrl, imageUrl);
  });
}
