import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';

void main() {
  group('QuestModel & QuestStepModel v2 multi-task parsing', () {
    test('parses step with key, verification payload, and step_order_mode', () {
      final json = {
        'id': 'quest_test_1',
        'title': 'Test Multi-Task Quest',
        'description': 'Exploring Pangasinan landmarks',
        'category': 'eco',
        'location_name': 'Lingayen Beach',
        'gps_lat': 16.02,
        'gps_lng': 120.23,
        'radius_meters': 150,
        'reward_points': 100,
        'step_order_mode': 'any',
        'steps': [
          {
            'order': 1,
            'title': 'Arrive on site',
            'description': 'Check in within the geofence',
            'checkpoint_type': 'location',
            'required': true,
            'key': 'task_loc_1',
            'verification': {
              'method': 'location',
              'lat': 16.02,
              'lng': 120.23,
              'radius_meters': 150,
            },
          },
          {
            'order': 2,
            'title': 'Find 3D AR Token',
            'description': 'Scan the area for the spinning token',
            'checkpoint_type': 'ar',
            'required': false,
            'key': 'task_ar_2',
            'verification': {
              'method': 'ar',
              'ar_model': 'token',
              'color': '#FFB703',
            },
          },
        ],
      };

      final quest = QuestModel.fromJson(json);
      expect(quest.id, 'quest_test_1');
      expect(quest.stepOrderMode, 'any');
      expect(quest.steps.length, 2);

      final locStep = quest.steps[0];
      expect(locStep.key, 'task_loc_1');
      expect(locStep.checkpointType, 'location');
      expect(locStep.required, isTrue);
      expect(locStep.verification?['method'], 'location');

      final arStep = quest.steps[1];
      expect(arStep.key, 'task_ar_2');
      expect(arStep.checkpointType, 'ar');
      expect(arStep.required, isFalse);
      expect(arStep.verification?['ar_model'], 'token');
    });

    test('parses QuestAttemptModel with stepOrderMode and verifiedSteps', () {
      final attemptJson = {
        'id': 'attempt_123',
        'quest_id': 'quest_test_1',
        'user_id': 'user_456',
        'version': 2,
        'current_step': 1,
        'total_steps': 2,
        'verified_steps': 1,
        'required_steps': 1,
        'status': 'in_progress',
        'step_order_mode': 'any',
        'steps': [
          {
            'order': 1,
            'title': 'Arrive on site',
            'description': 'Check in within the geofence',
            'checkpoint_type': 'location',
            'required': true,
            'status': 'verified',
          },
          {
            'order': 2,
            'title': 'Find 3D AR Token',
            'description': 'Scan the area for the spinning token',
            'checkpoint_type': 'ar',
            'required': false,
            'status': 'ready',
          },
        ],
      };

      final attempt = QuestAttemptModel.fromJson(attemptJson);
      expect(attempt.id, 'attempt_123');
      expect(attempt.stepOrderMode, 'any');
      expect(attempt.verifiedSteps, 1);
      expect(attempt.requiredSteps, 1);
      expect(attempt.steps[0].isVerified, isTrue);
      expect(attempt.steps[1].isReady, isTrue);
    });
  });
}
