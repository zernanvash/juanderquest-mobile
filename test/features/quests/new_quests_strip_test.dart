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
  test('new quests: last 24 h only, newest first, boundary on createdAt', () {
    final now = DateTime.utc(2026, 11, 20, 12);
    final list = newQuests([
      _q('old_24h01m', now.subtract(const Duration(hours: 24, minutes: 1))),
      _q('edge_23h59m', now.subtract(const Duration(hours: 23, minutes: 59))),
      _q('hour', now.subtract(const Duration(hours: 1))),
      _q('nodate', null),
    ], now: now);
    expect(list.map((q) => q.id), ['hour', 'edge_23h59m']);
  });

  test('QuestModel reads created_at', () {
    final q = QuestModel.fromJson(
        {'id': 'q', 'created_at': '2026-11-18T03:00:00.000Z'});
    expect(q.createdAt, DateTime.utc(2026, 11, 18, 3));
  });
}
