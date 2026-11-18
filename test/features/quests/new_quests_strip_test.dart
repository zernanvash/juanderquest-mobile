import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/widgets/new_quests_strip.dart';

QuestModel _q(String id, DateTime? created) => QuestModel(
      id: id,
      title: id,
      description: '',
      category: 'eco',
      locationName: 'Bolinao',
      gpsLat: 16,
      gpsLng: 120,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
      createdAt: created,
    );

void main() {
  test('new quests: last 72 h only, newest first (owner 2026-11-18)', () {
    final now = DateTime.utc(2026, 11, 18, 12);
    final list = newQuests([
      _q('old', now.subtract(const Duration(days: 4))),
      _q('day', now.subtract(const Duration(hours: 20))),
      _q('hour', now.subtract(const Duration(hours: 1))),
      _q('nodate', null),
    ], now: now);
    expect(list.map((q) => q.id), ['hour', 'day']);
  });

  test('QuestModel reads created_at', () {
    final q = QuestModel.fromJson(
        {'id': 'q', 'created_at': '2026-11-18T03:00:00.000Z'});
    expect(q.createdAt, DateTime.utc(2026, 11, 18, 3));
  });
}
