import 'package:latlong2/latlong.dart';

import '../../quests/models/quest_model.dart';
import '../../spots/models/spot_model.dart';
import '../engine/jdq_map.dart';

/// Plan 122a: Resolves the unified 3-tier pin kind for a destination marker.
///
/// Priority:
/// 1. Active published quest(s) -> `quest` (or `questDone` when every active quest
///    at this destination has been completed by the traveler; if `showDoneQuests`
///    is false, drops back to `merchant` or `spot` so the destination remains visible).
/// 2. Local Partner (`markerKind == 'merchant'` or `isLocalPartner == true`) -> `merchant`.
/// 3. Base destination -> `spot`.
JdqPinKind resolveSpotMarkerPinKind({
  required String markerKind,
  required bool isLocalPartner,
  required List<String> activeQuestIds,
  required Set<String> completedQuestIds,
  required bool showDoneQuests,
}) {
  if (markerKind == 'quest') {
    if (activeQuestIds.isNotEmpty &&
        activeQuestIds.every(completedQuestIds.contains)) {
      if (showDoneQuests) return JdqPinKind.questDone;
      return isLocalPartner ? JdqPinKind.merchant : JdqPinKind.spot;
    }
    return JdqPinKind.quest;
  }
  if (markerKind == 'merchant' || isLocalPartner) {
    return JdqPinKind.merchant;
  }
  return JdqPinKind.spot;
}

/// Plan 122a: Builds the unified pin list for `MapViewScreen` with zero duplicate
/// overlapping `quest:` pins whenever a quest is already represented by a visible
/// destination marker.
List<JdqPin> buildUnifiedMapPins({
  required List<SpotMapCluster> clusters,
  required List<SpotMapMarker> viewportMarkers,
  required List<SpotModel> fallbackSpots,
  required bool hasViewportMapData,
  required List<QuestModel> visibleQuests,
  required Set<String> completedQuestIds,
  required bool showDoneQuests,
}) {
  final boundQuestIds = <String>{};
  if (hasViewportMapData) {
    for (final m in viewportMarkers) {
      boundQuestIds.addAll(m.activeQuestIds);
    }
  } else {
    for (final s in fallbackSpots) {
      boundQuestIds.addAll(s.activeQuestIds);
      if (s.questId != null && s.questId!.isNotEmpty) {
        boundQuestIds.add(s.questId!);
      }
    }
  }

  final pins = <JdqPin>[
    for (var i = 0; i < clusters.length; i++)
      JdqPin(
        'cluster:$i',
        LatLng(clusters[i].lat, clusters[i].lng),
        '${clusters[i].count}',
        clusterCount: clusters[i].count,
      ),
    // Only emit standalone quest pins when not already represented by a spot marker.
    for (final q in visibleQuests)
      if (!boundQuestIds.contains(q.id))
        JdqPin(
          'quest:${q.id}',
          LatLng(q.gpsLat, q.gpsLng),
          q.title,
          quest: true,
          done: completedQuestIds.contains(q.id),
          kind: completedQuestIds.contains(q.id)
              ? JdqPinKind.questDone
              : JdqPinKind.quest,
        ),
  ];

  if (hasViewportMapData) {
    for (final m in viewportMarkers) {
      final kind = resolveSpotMarkerPinKind(
        markerKind: m.markerKind,
        isLocalPartner: m.isLocalPartner,
        activeQuestIds: m.activeQuestIds,
        completedQuestIds: completedQuestIds,
        showDoneQuests: showDoneQuests,
      );
      pins.add(
        JdqPin(
          'spot:${m.id}',
          LatLng(m.lat, m.lng),
          m.name,
          quest: kind == JdqPinKind.quest || kind == JdqPinKind.questDone,
          done: kind == JdqPinKind.questDone,
          kind: kind,
        ),
      );
    }
  } else {
    for (final s in fallbackSpots) {
      final activeIds = s.activeQuestIds.isNotEmpty
          ? s.activeQuestIds
          : (s.questId != null && s.questId!.isNotEmpty
              ? <String>[s.questId!]
              : const <String>[]);
      final kind = resolveSpotMarkerPinKind(
        markerKind: s.markerKind,
        isLocalPartner: s.localPartner != null,
        activeQuestIds: activeIds,
        completedQuestIds: completedQuestIds,
        showDoneQuests: showDoneQuests,
      );
      pins.add(
        JdqPin(
          'spot:${s.id}',
          LatLng(s.gpsLat, s.gpsLng),
          s.name,
          quest: kind == JdqPinKind.quest || kind == JdqPinKind.questDone,
          done: kind == JdqPinKind.questDone,
          kind: kind,
        ),
      );
    }
  }

  return pins;
}
