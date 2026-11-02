import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/theater/theater_chapters.dart';

void main() {
  group('SpotModel theater extensions', () {
    test('defaults all new fields to empty, false, or null when omitted', () {
      final spot = SpotModel.fromJson({
        'id': 'spot-1',
        'slug': 'test-spot',
        'name': 'Test Spot',
        'description': 'A beautiful test destination.',
        'category': 'nature',
        'subcategory': 'beach',
        'municipality': 'Bolinao',
        'address': 'Patar',
        'source_name': 'JuanDerQuest',
        'trust_level': 'verified',
        'gps_lat': 16.3,
        'gps_lng': 119.8,
      });

      expect(spot.goodFor, isEmpty);
      expect(spot.bestTime, isEmpty);
      expect(spot.hours, isEmpty);
      expect(spot.amenities, isEmpty);
      expect(spot.sourceUrl, isNull);
      expect(spot.isTest, isFalse);
      expect(spot.media, isEmpty);
      expect(spot.leadStillPhoto, isNull);
    });

    test('parses new fields when present', () {
      final spot = SpotModel.fromJson({
        'id': 'spot-2',
        'slug': 'patar-beach',
        'name': 'Patar Beach',
        'description': 'Golden white sands of Bolinao. Watch the stunning sunset over the West Philippine Sea.',
        'category': 'nature',
        'subcategory': 'beach',
        'municipality': 'Bolinao',
        'address': 'Brgy. Patar',
        'source_name': 'LGU Bolinao',
        'source_url': 'https://bolinao.gov.ph',
        'trust_level': 'lgu_verified',
        'gps_lat': 16.3,
        'gps_lng': 119.8,
        'good_for': ['Swimming', 'Sunset viewing', 'Photography'],
        'best_time': ['4:00 PM - 6:00 PM', 'Summer'],
        'hours': {'monday': 'Open 24 hours', 'sunday': 'Open 24 hours'},
        'amenities': ['Parking', 'Restrooms', 'Cottages'],
        'is_test': true,
        'image_url': 'https://example.com/patar.jpg',
      });

      expect(spot.goodFor, ['Swimming', 'Sunset viewing', 'Photography']);
      expect(spot.bestTime, ['4:00 PM - 6:00 PM', 'Summer']);
      expect(spot.hours, {'monday': 'Open 24 hours', 'sunday': 'Open 24 hours'});
      expect(spot.amenities, ['Parking', 'Restrooms', 'Cottages']);
      expect(spot.sourceUrl, 'https://bolinao.gov.ph');
      expect(spot.isTest, isTrue);
      expect(spot.media.length, 1);
      expect(spot.media.first.url, 'https://example.com/patar.jpg');
      expect(spot.media.first.isVideo, isFalse);
    });

    test('JSON round-trip preserves all fields', () {
      const original = SpotModel(
        id: 'spot-roundtrip',
        slug: 'round-trip-spot',
        name: 'Round Trip Place',
        description: 'First sentence here. Second sentence continues.',
        category: 'culture',
        subcategory: 'church',
        municipality: 'Manaoag',
        address: 'Milo St.',
        sourceName: 'Tourism Board',
        sourceUrl: 'https://tourism.ph',
        trustLevel: 'lgu_verified',
        gpsLat: 16.04,
        gpsLng: 120.48,
        tags: ['heritage', 'pilgrimage'],
        reasons: ['Popular shrine'],
        crowdStatus: 'estimated_quiet',
        crowdConfidence: 'high',
        distanceKm: 12.5,
        questId: 'quest-77',
        imageUrl: 'https://example.com/manaoag.jpg',
        createdBy: 'user-42',
        saved: true,
        goodFor: ['Prayer', 'History'],
        bestTime: ['Morning'],
        hours: {'daily': '6:00 AM - 7:00 PM'},
        amenities: ['Wheelchair accessible', 'Gift shop'],
        isTest: true,
        media: [
          SpotPhoto(
            url: 'https://example.com/manaoag.jpg',
            isVideo: false,
            sourceName: 'Tourism Board',
            sourceUrl: 'https://tourism.ph',
          ),
          SpotPhoto(
            url: 'https://example.com/manaoag-bell.mp4',
            isVideo: true,
            sourceName: 'Pilgrim Vid',
          ),
        ],
      );

      final json = original.toJson();
      final restored = SpotModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.slug, original.slug);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.category, original.category);
      expect(restored.subcategory, original.subcategory);
      expect(restored.municipality, original.municipality);
      expect(restored.address, original.address);
      expect(restored.sourceName, original.sourceName);
      expect(restored.sourceUrl, original.sourceUrl);
      expect(restored.trustLevel, original.trustLevel);
      expect(restored.gpsLat, original.gpsLat);
      expect(restored.gpsLng, original.gpsLng);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.questId, original.questId);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.createdBy, original.createdBy);
      expect(restored.saved, original.saved);
      expect(restored.tags, original.tags);
      expect(restored.reasons, original.reasons);
      expect(restored.goodFor, original.goodFor);
      expect(restored.bestTime, original.bestTime);
      expect(restored.hours, original.hours);
      expect(restored.amenities, original.amenities);
      expect(restored.isTest, original.isTest);
      expect(restored.media.length, original.media.length);
      expect(restored.media[0].url, original.media[0].url);
      expect(restored.media[0].isVideo, original.media[0].isVideo);
      expect(restored.media[1].url, original.media[1].url);
      expect(restored.media[1].isVideo, original.media[1].isVideo);
    });

    test('media order: image_url -> attached_assets -> photos, with de-duplication', () {
      final json = {
        'id': 'spot-media-order',
        'slug': 'media-order-spot',
        'name': 'Media Order Spot',
        'description': 'Testing media order.',
        'category': 'nature',
        'subcategory': 'park',
        'municipality': 'Alaminos',
        'address': 'Lucap',
        'source_name': 'Spot Source',
        'trust_level': 'community',
        'gps_lat': 16.2,
        'gps_lng': 120.0,
        'image_url': 'https://example.com/1-primary.jpg',
        'attached_assets': [
          {'url': 'https://example.com/2-attached.jpg'},
          {'url': 'https://example.com/1-primary.jpg'}, // Duplicate of primary
          {'url': 'https://example.com/3-video.mp4', 'media_type': 'video'},
        ],
        'photos': [
          'https://example.com/2-attached.jpg', // Duplicate of attached
          'https://example.com/4-photo.jpg',
        ],
      };

      final spot = SpotModel.fromJson(json);

      expect(spot.media.length, 4);
      expect(spot.media[0].url, 'https://example.com/1-primary.jpg');
      expect(spot.media[0].isVideo, isFalse);

      expect(spot.media[1].url, 'https://example.com/2-attached.jpg');
      expect(spot.media[1].isVideo, isFalse);

      expect(spot.media[2].url, 'https://example.com/3-video.mp4');
      expect(spot.media[2].isVideo, isTrue);

      expect(spot.media[3].url, 'https://example.com/4-photo.jpg');
      expect(spot.media[3].isVideo, isFalse);
    });

    test('leadStillPhoto skips video items and selects first still photo', () {
      final json = {
        'id': 'spot-video-lead',
        'slug': 'video-lead-spot',
        'name': 'Video Lead Spot',
        'description': 'First video destination.',
        'category': 'nature',
        'subcategory': 'beach',
        'municipality': 'Bolinao',
        'address': 'Patar',
        'source_name': 'Drone Explorer',
        'trust_level': 'community',
        'gps_lat': 16.3,
        'gps_lng': 119.8,
        'image_url': 'https://example.com/drone-flyover.mp4',
        'photos': [
          'https://example.com/still-photo-1.jpg',
          'https://example.com/still-photo-2.jpg',
        ],
      };

      final spot = SpotModel.fromJson(json);
      expect(spot.media.first.isVideo, isTrue);
      expect(spot.leadStillPhoto, isNotNull);
      expect(spot.leadStillPhoto!.url, 'https://example.com/still-photo-1.jpg');
      expect(spot.leadStillPhoto!.isVideo, isFalse);
    });

    test('teaser extracts the first sentence of description', () {
      final spotWithPeriod = SpotModel.fromJson({
        'id': 's1',
        'slug': 's1',
        'name': 'Spot 1',
        'description': 'Hundred Islands is a cluster of 124 islands. It offers island hopping and snorkeling.',
        'category': 'nature',
        'subcategory': 'park',
        'municipality': 'Alaminos',
        'address': '',
        'source_name': '',
        'trust_level': '',
        'gps_lat': 0,
        'gps_lng': 0,
      });
      expect(spotWithPeriod.teaser, 'Hundred Islands is a cluster of 124 islands.');

      final spotWithExclamation = spotWithPeriod.copyWith(
        description: 'Experience the magic of Pangasinan! Plan your visit now.',
      );
      expect(spotWithExclamation.teaser, 'Experience the magic of Pangasinan!');

      final spotWithQuestion = spotWithPeriod.copyWith(
        description: 'Looking for a tranquil beach? Patar white beach awaits.',
      );
      expect(spotWithQuestion.teaser, 'Looking for a tranquil beach?');

      final spotNoPunctuation = spotWithPeriod.copyWith(
        description: 'Single unpunctuated sentence',
      );
      expect(spotNoPunctuation.teaser, 'Single unpunctuated sentence');

      final spotEmpty = spotWithPeriod.copyWith(description: '   ');
      expect(spotEmpty.teaser, '');
    });

    test('chapters helper returns 4 chapters without alternatives, 5 with alternatives', () {
      final base = SpotTheaterChapter.getAvailable(hasAlternatives: false);
      expect(base.length, 4);
      expect(base.map((c) => c.id).toList(), ['overview', 'about', 'notes', 'venue']);

      final withAlts = SpotTheaterChapter.getAvailable(hasAlternatives: true);
      expect(withAlts.length, 5);
      expect(withAlts.map((c) => c.id).toList(), ['overview', 'about', 'notes', 'venue', 'nearby']);
    });
  });
}
