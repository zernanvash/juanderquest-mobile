import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/map_done_quests.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';

QuestModel _quest(String id, String title, List<String> stepStatuses) =>
    QuestModel(
      id: id,
      title: title,
      description: '',
      category: 'eco',
      locationName: 'Alaminos City',
      gpsLat: 16.2,
      gpsLng: 120.0,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
      steps: [
        for (var i = 0; i < stepStatuses.length; i++)
          QuestStepModel(
            order: i + 1,
            title: 'Step $i',
            description: '',
            checkpointType: 'location',
            required: true,
            status: stepStatuses[i],
          ),
      ],
    );

void main() {
  final approved = _quest('q1', 'Approved Trek', ['pending']);
  final allSteps = _quest('q2', 'All Steps', ['verified', 'verified']);
  final open = _quest('q3', 'Open Trek', ['verified', 'pending']);
  final pendingReview = _quest('q4', 'Under Review', ['pending']);
  final quests = [approved, allSteps, open, pendingReview];
  final done = mapQuestDone([
    SubmissionModel(
      id: 's1',
      questTitle: 'Approved Trek',
      category: 'eco',
      status: 'approved',
      rewardPoints: 50,
      createdAt: '2026-11-16',
    ),
    SubmissionModel(
      id: 's2',
      questTitle: 'Under Review',
      category: 'eco',
      status: 'pending',
      rewardPoints: 50,
      createdAt: '2026-11-16',
    ),
  ]);

  test('DONE off: done quests are hidden from the map', () {
    expect(
      mapVisibleQuests(quests, done, showDone: false).map((q) => q.id),
      ['q3', 'q4'],
    );
  });

  test('Done quests show (greyed) by default; owner 2026-11-18', () {
    expect(mapVisibleQuests(quests, done, showDone: true), quests);
    expect(quests.where(done).map((q) => q.id), ['q1', 'q2']);
  });
}
