import 'package:flutter_test/flutter_test.dart';

import 'package:juanderquest_app/features/map/utils/map_list.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';

QuestModel _quest(String id, String title) => QuestModel(
      id: id,
      title: title,
      description: 'desc',
      category: 'eco',
      locationName: 'Bolinao',
      gpsLat: 16.3,
      gpsLng: 119.8,
      radiusMeters: 200,
      rewardPoints: 50,
      markerImageUrl: '',
    );

SpotModel _spot(String id, String name) => SpotModel(
      id: id,
      slug: id,
      name: name,
      description: 'desc',
      category: 'nature',
      subcategory: 'beach',
      municipality: 'Alaminos',
      address: 'Alaminos',
      sourceName: 'Editorial',
      trustLevel: 'lgu_verified',
      gpsLat: 16.1,
      gpsLng: 119.9,
      tags: const [],
      reasons: const [],
    );

void main() {
  final quests = [_quest('q2', 'Zipline Loop'), _quest('q1', 'Heritage Walk')];
  final spots = [_spot('s2', 'Patar Beach'), _spot('s1', 'Cape Bolinao')];

  test('all filter includes quests and spots sorted by title', () {
    final entries = filterMapEntries(quests: quests, spots: spots, activeFilter: 'all');
    expect(entries.map((e) => e.title).toList(),
        ['Cape Bolinao', 'Heritage Walk', 'Patar Beach', 'Zipline Loop']);
    expect(entries.first.isQuest, isFalse);
    expect(entries.first.subtitle, 'Alaminos');
    expect(entries.last.rewardPoints, 50);
  });

  test('quests filter excludes spots and spots filter excludes quests', () {
    final questEntries = filterMapEntries(quests: quests, spots: spots, activeFilter: 'quests');
    expect(questEntries.every((e) => e.isQuest), isTrue);
    expect(questEntries.length, 2);

    final spotEntries = filterMapEntries(quests: quests, spots: spots, activeFilter: 'spots');
    expect(spotEntries.every((e) => !e.isQuest), isTrue);
    expect(spotEntries.length, 2);
  });

  test('entries are capped so a large catalog cannot build an unbounded list', () {
    final many = List.generate(300, (i) => _spot('s$i', 'Spot ${i.toString().padLeft(3, '0')}'));
    final entries = filterMapEntries(quests: const [], spots: many, activeFilter: 'spots');
    expect(entries.length, 200);
    expect(entries.first.title, 'Spot 000');
  });

  test('empty filter result stays empty and honest', () {
    final entries = filterMapEntries(quests: const [], spots: const [], activeFilter: 'all');
    expect(entries, isEmpty);
  });
}
