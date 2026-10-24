import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';

void main() {
  test('resolves API-relative catalog image paths against the active API origin', () {
    final spot = SpotModel.fromJson({
      'slug': 'hundred-islands-national-park',
      'image_url': '/api/v1/uploads/spot-photos/catalog-hundred-islands.jpg',
    });

    final origin = Uri.parse(ApiClient.apiBaseUrl).origin;
    expect(
      spot.imageUrl,
      '$origin/api/v1/uploads/spot-photos/catalog-hundred-islands.jpg',
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
