import '../../quests/models/quest_model.dart';
import '../../spots/models/spot_model.dart';

/// One row in the map's accessible list fallback.
class MapListEntry {
  const MapListEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isQuest,
    required this.lat,
    required this.lng,
    this.rewardPoints,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isQuest;
  final double lat;
  final double lng;
  final int? rewardPoints;
}

/// Same semantics as the map pins: 'all', 'quests' or 'spots', sorted A→Z and
/// capped so a large catalog cannot build an unbounded list.
List<MapListEntry> filterMapEntries({
  required List<QuestModel> quests,
  required List<SpotModel> spots,
  required String activeFilter,
  int maxEntries = 200,
}) {
  final entries = <MapListEntry>[];
  if (activeFilter == 'all' || activeFilter == 'quests') {
    for (final quest in quests) {
      entries.add(MapListEntry(
        id: quest.id,
        title: quest.title,
        subtitle: quest.locationName,
        isQuest: true,
        lat: quest.gpsLat,
        lng: quest.gpsLng,
        rewardPoints: quest.rewardPoints,
      ));
    }
  }
  if (activeFilter == 'all' || activeFilter == 'spots') {
    for (final spot in spots) {
      entries.add(MapListEntry(
        id: spot.id,
        title: spot.name,
        subtitle: spot.municipality,
        isQuest: false,
        lat: spot.gpsLat,
        lng: spot.gpsLng,
      ));
    }
  }
  entries.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return entries.length > maxEntries ? entries.sublist(0, maxEntries) : entries;
}
