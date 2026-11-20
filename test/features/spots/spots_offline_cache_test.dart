import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/repositories/spots_cache_repository.dart';

void main() {
  group('Phase 6: Mobile Offline-First Spots Cache Tests', () {
    late Map<String, String> memoryStore;
    late SpotsCacheRepository repository;

    const testSpot1 = SpotModel(
      id: 'spot-hundred-islands',
      slug: 'hundred-islands-national-park',
      name: 'Hundred Islands National Park',
      description: 'Iconic protected national park with 124 islands.',
      category: 'nature_outdoors',
      subcategory: 'island',
      municipality: 'Alaminos City',
      address: 'Lucap, Alaminos City, Pangasinan',
      sourceName: 'Pangasinan Tourism',
      trustLevel: 'verified',
      gpsLat: 16.2063,
      gpsLng: 119.9706,
      tags: ['beach', 'islands', 'ecotourism'],
      reasons: ['TOP_DESTINATION', 'NATURAL_WONDER'],
      imageUrl: 'https://images.unsplash.com/hundred-islands',
      saved: false,
    );

    const testSpot2 = SpotModel(
      id: 'spot-patar-beach',
      slug: 'patar-white-beach',
      name: 'Patar White Beach',
      description: 'Golden-white sands and clear waters along the Bolinao coastline.',
      category: 'nature_outdoors',
      subcategory: 'beach',
      municipality: 'Bolinao',
      address: 'Patar, Bolinao, Pangasinan',
      sourceName: 'Bolinao Tourism',
      trustLevel: 'verified',
      gpsLat: 16.3025,
      gpsLng: 119.7824,
      tags: ['beach', 'sunset', 'swimming'],
      reasons: ['POPULAR_BEACH'],
      imageUrl: 'https://images.unsplash.com/patar',
      saved: true,
    );

    setUp(() {
      memoryStore = <String, String>{};
      repository = SpotsCacheRepository(memoryFallback: memoryStore);
    });

    test('1. Saves and retrieves public spots with metadata and freshness flags', () async {
      // Initially empty
      final initial = await repository.loadSpots();
      expect(initial, isNull);

      // Save spots
      await repository.saveSpots([testSpot1, testSpot2]);

      // Load back
      final result = await repository.loadSpots();
      expect(result, isNotNull);
      expect(result!.spots.length, equals(2));
      expect(result.spots.first.name, equals('Hundred Islands National Park'));
      expect(result.spots.first.gpsLat, equals(16.2063));
      expect(result.spots.last.saved, isTrue);
      expect(result.isStale, isFalse);
      expect(result.partition, equals(SpotsCacheRepository.publicPartition));
    });

    test('2. Correctly flags stale cache when age exceeds staleThreshold', () async {
      await repository.saveSpots([testSpot1]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Using zero threshold simulates immediate staleness
      final result = await repository.loadSpots(
        staleThreshold: Duration.zero,
      );
      expect(result, isNotNull);
      expect(result!.isStale, isTrue);
    });

    test('3. Saves and loads taxonomy categories and tags', () async {
      final initial = await repository.loadTaxonomy();
      expect(initial, isNull);

      final categories = ['nature_outdoors', 'culture_heritage', 'eat_drink'];
      final tags = ['beach', 'church', 'seafood'];

      await repository.saveTaxonomy(categories, tags);

      final loaded = await repository.loadTaxonomy();
      expect(loaded, isNotNull);
      expect(loaded!.categories, equals(categories));
      expect(loaded.tags, equals(tags));
    });

    test('4. Partition isolation and purge user partition upon logout', () async {
      const userA = 'user-scout-123';
      const userPartition = 'user_$userA';

      // Save user bookmarks partition
      await repository.saveSpots([testSpot2], partition: userPartition);

      // Public spots remain intact
      await repository.saveSpots([testSpot1], partition: SpotsCacheRepository.publicPartition);

      // Both exist
      final userCache = await repository.loadSpots(partition: userPartition);
      final publicCache = await repository.loadSpots(partition: SpotsCacheRepository.publicPartition);

      expect(userCache, isNotNull);
      expect(userCache!.spots.first.id, equals(testSpot2.id));
      expect(publicCache, isNotNull);
      expect(publicCache!.spots.first.id, equals(testSpot1.id));

      // Purge User A partition (simulating logout)
      await repository.purgeUserPartition(userA);

      // User A partition is now gone, while public spots remain
      final purgedUserCache = await repository.loadSpots(partition: userPartition);
      final remainingPublicCache = await repository.loadSpots(partition: SpotsCacheRepository.publicPartition);

      expect(purgedUserCache, isNull);
      expect(remainingPublicCache, isNotNull);
      expect(remainingPublicCache!.spots.length, equals(1));
    });

    test('5. Purge all resets entire local database/file cache', () async {
      await repository.saveSpots([testSpot1]);
      await repository.saveTaxonomy(['nature'], ['beach']);

      expect(await repository.loadSpots(), isNotNull);
      expect(await repository.loadTaxonomy(), isNotNull);

      await repository.purgeAll();

      expect(await repository.loadSpots(), isNull);
      expect(await repository.loadTaxonomy(), isNull);
    });
  });
}
