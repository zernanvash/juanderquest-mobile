import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/task_validation.dart';

void main() {
  group('Plan 73 Quest Builder Models & Validation', () {
    test('Location task round-trip JSON', () {
      const task = BuilderTask(
        key: 'task_loc_1',
        stepOrder: 1,
        title: 'Arrive at destination',
        description: 'Check in within the geofence perimeter.',
        required: true,
        checkpointType: 'location',
        verification: LocationVerification(
          fence: GeoFence(lat: 16.03, lng: 120.33, radiusMeters: 100),
        ),
      );

      final json = task.toJson(isNew: false);
      expect(json['key'], 'task_loc_1');
      expect(json['step_order'], 1);
      expect(json['checkpoint_type'], 'location');
      expect(json['verification']['type'], 'location');
      expect(json['verification']['fence']['radius_meters'], 100);

      final decoded = BuilderTask.fromJson(json);
      expect(decoded.key, 'task_loc_1');
      expect(decoded.checkpointType, 'location');
      expect(decoded.verification, isA<LocationVerification>());
      final ver = decoded.verification as LocationVerification;
      expect(ver.fence.lat, 16.03);
    });

    test('AR task round-trip JSON', () {
      const task = BuilderTask(
        key: 'task_ar_1',
        stepOrder: 2,
        title: 'Find the virtual gem',
        description: 'Locate and collect the floating 3D gem.',
        required: true,
        checkpointType: 'ar',
        verification: ArVerification(
          fence: GeoFence(lat: 16.035, lng: 120.335, radiusMeters: 50),
          object: 'gem',
          color: '#2D6A4F',
        ),
      );

      final json = task.toJson(isNew: false);
      expect(json['checkpoint_type'], 'ar');
      expect(json['verification']['object'], 'gem');
      expect(json['verification']['color'], '#2D6A4F');

      final decoded = BuilderTask.fromJson(json);
      expect(decoded.verification, isA<ArVerification>());
      final ver = decoded.verification as ArVerification;
      expect(ver.object, 'gem');
      expect(ver.color, '#2D6A4F');
    });

    test('AR task keeps its game (Plan 77); old tasks are collect tasks', () {
      const fence = GeoFence(lat: 16.035, lng: 120.335, radiusMeters: 50);
      const ver = ArVerification(fence: fence, game: 'pana');
      expect(ver.toJson()['game'], 'pana');
      expect(ArVerification.fromJson(ver.toJson()).game, 'pana');
      expect(ArVerification.fromJson({'type': 'ar', 'fence': fence.toJson()}).game, 'collect');
      final moved = ver.copyWith(fence: const GeoFence(lat: 16.1, lng: 120.3, radiusMeters: 80));
      expect((moved.game, moved.fence.radiusMeters), ('pana', 80));
    });

    test('QR task (host scans traveler) round-trip JSON', () {
      const task = BuilderTask(
        key: 'task_qr_1',
        stepOrder: 3,
        title: 'Host verification pass',
        description: 'Present your quest pass to the on-site ranger.',
        required: false,
        checkpointType: 'qr',
        verification: QrVerification(
          fence: GeoFence(lat: 16.03, lng: 120.33, radiusMeters: 80),
          scanMode: 'host_scans_traveler',
        ),
      );

      final json = task.toJson(isNew: true);
      expect(json.containsKey('key'), false); // isNew omits key
      expect(json['verification']['scan_mode'], 'host_scans_traveler');

      final decoded = BuilderTask.fromJson({
        ...json,
        'key': 'task_qr_1',
      });
      expect(decoded.verification, isA<QrVerification>());
      final ver = decoded.verification as QrVerification;
      expect(ver.scanMode, 'host_scans_traveler');
    });

    test('Photo task round-trip JSON', () {
      const task = BuilderTask(
        key: 'task_photo_1',
        stepOrder: 4,
        title: 'Heritage plaque photo',
        description: 'Take a clear photo of the founding marker.',
        required: true,
        checkpointType: 'photo',
        verification: PhotoVerification(
          prompt: 'Capture the historic marker in daylight.',
          requireGps: true,
          fence: GeoFence(lat: 16.03, lng: 120.33, radiusMeters: 100),
        ),
      );

      final json = task.toJson();
      expect(json['verification']['prompt'], 'Capture the historic marker in daylight.');
      expect(json['verification']['require_gps'], true);
      expect(json['verification']['fence']['radius_meters'], 100);
    });

    test('Validation enforces web parity messages', () {
      // 1. Empty title and short description
      var state = const QuestBuilderState(
        title: '',
        description: 'Short',
        category: 'eco',
        rewardPoints: 75,
        stepOrderMode: 'sequential',
        status: 'draft',
        tasks: [],
        version: 1,
      );
      var errors = validateQuestBuilder(state);
      expect(errors.any((e) => e.message == 'Title must be at least 3 characters.'), isTrue);
      expect(errors.any((e) => e.message == 'Description must be at least 10 characters.'), isTrue);

      // 2. Published requires tasks and at least one required task
      state = state.copyWith(
        title: 'Valid Quest Title',
        description: 'This is a long enough description for travelers.',
        status: 'published',
      );
      errors = validateQuestBuilder(state);
      expect(errors.any((e) => e.message == 'At least one task is required to publish.'), isTrue);

      // Add a non-required task
      state = state.copyWith(
        tasks: [
          const BuilderTask(
            key: 'task_1',
            stepOrder: 1,
            title: 'Valid Title',
            description: 'Valid Description',
            required: false,
            checkpointType: 'location',
            verification: LocationVerification(
              fence: GeoFence(lat: 16, lng: 120, radiusMeters: 100),
            ),
          ),
        ],
      );
      errors = validateQuestBuilder(state);
      expect(errors.any((e) => e.message == 'At least one task must be marked as required to publish.'), isTrue);

      // Photo task without prompt
      state = state.copyWith(
        tasks: [
          const BuilderTask(
            key: 'task_1',
            stepOrder: 1,
            title: 'Photo Task',
            description: 'Take a picture',
            required: true,
            checkpointType: 'photo',
            verification: PhotoVerification(prompt: 'tiny'),
          ),
        ],
      );
      errors = validateQuestBuilder(state);
      expect(errors.any((e) => e.message == 'Photo prompt must be at least 5 characters.'), isTrue);
    });
  });
}
