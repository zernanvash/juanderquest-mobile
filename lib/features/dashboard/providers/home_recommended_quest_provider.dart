import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../ar_experience/core/ar_math.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/pixel/daily_mission.dart';
import '../../quests/providers/quest_provider.dart';
import '../../settings/home_town.dart';
import '../../submissions/providers/submission_provider.dart';
import '../../trail/models/trail_models.dart';
import 'home_daily_provider.dart';

class HomeRecommendedQuest {
  const HomeRecommendedQuest({
    required this.quest,
    required this.reason,
  });

  final QuestModel quest;
  final String reason;
}

/// Reads the phone's last known position ONLY if location permission is
/// already granted. Never prompts the user for permission on Home.
final homeLastKnownLocationProvider =
    FutureProvider<({double lat, double lng})?>((ref) async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    final pos = await Geolocator.getLastKnownPosition();
    if (pos == null) return null;
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return null;
  }
});

String _normTown(String raw) {
  return raw
      .toLowerCase()
      .replaceAll(' city', '')
      .replaceAll(' municipality', '')
      .trim();
}

/// Computes the single recommended quest for Home once per quest-list /
/// submission / daily / location / home-town state change (never in build).
final homeRecommendedQuestProvider = Provider<HomeRecommendedQuest?>((ref) {
  final quests = ref.watch(questProvider.select((s) => s.quests));
  final submissions = ref.watch(submissionProvider.select((s) => s.submissions));
  final daily = ref.watch(homeDailyProvider).valueOrNull;
  final lastLoc = ref.watch(homeLastKnownLocationProvider).valueOrNull;
  final homeTown = ref.watch(homeTownProvider).valueOrNull?.town;

  final completedTitles = submissions
      .where((s) => s.status == 'approved')
      .map((s) => s.questTitle)
      .toSet();

  final eligible = quests.where((q) {
    if (q.isTest) return false;
    if (q.remainingSlots != null && q.remainingSlots! <= 0) return false;
    if (completedTitles.contains(q.title)) return false;
    if (q.steps.isNotEmpty && q.steps.every((s) => s.isVerified)) return false;
    return true;
  }).toList();

  if (eligible.isEmpty) return null;

  // 1. Today's daily mission quest
  final dailyMissionActive = daily?.missions.any(
        (m) => m.kind == 'quest_step' && !m.completed,
      ) ==
      true;
  if (dailyMissionActive) {
    final missionId = dailyMissionQuestId(
      eligible,
      (q) => completedTitles.contains(q.title) ? 'COMPLETED' : 'AVAILABLE',
      true,
    );
    if (missionId != null) {
      final match = eligible.firstWhere((q) => q.id == missionId);
      return HomeRecommendedQuest(quest: match, reason: "Today's mission");
    }
  }

  // 2. Closest to last known location (only if permission already granted)
  if (lastLoc != null) {
    QuestModel? closest;
    double? bestMeters;
    for (final q in eligible) {
      if (q.gpsLat == 0 && q.gpsLng == 0) continue;
      final d = ArGeo.distanceMeters(
        lastLoc.lat,
        lastLoc.lng,
        q.gpsLat,
        q.gpsLng,
      );
      if (bestMeters == null || d < bestMeters) {
        bestMeters = d;
        closest = q;
      }
    }
    if (closest != null && bestMeters != null) {
      final km = (bestMeters / 1000).toStringAsFixed(1);
      return HomeRecommendedQuest(quest: closest, reason: '$km km away');
    }
  }

  // 3. Closest to user's home town
  if (homeTown != null && homeTown.trim().isNotEmpty) {
    final norm = _normTown(homeTown);
    for (final q in eligible) {
      if (q.locationName.toLowerCase().contains(norm)) {
        return HomeRecommendedQuest(quest: q, reason: 'In your town');
      }
    }
    TripOrigin? townOrigin;
    for (final origin in kTripOrigins) {
      if (_normTown(origin.name) == norm) {
        townOrigin = origin;
        break;
      }
    }
    if (townOrigin != null) {
      QuestModel? closest;
      double? bestMeters;
      for (final q in eligible) {
        if (q.gpsLat == 0 && q.gpsLng == 0) continue;
        final d = ArGeo.distanceMeters(
          townOrigin.lat,
          townOrigin.lng,
          q.gpsLat,
          q.gpsLng,
        );
        if (bestMeters == null || d < bestMeters) {
          bestMeters = d;
          closest = q;
        }
      }
      if (closest != null) {
        return HomeRecommendedQuest(quest: closest, reason: 'In your town');
      }
    }
  }

  // 4. Highest reward
  var best = eligible.first;
  for (final q in eligible.skip(1)) {
    if (q.rewardPoints > best.rewardPoints) {
      best = q;
    }
  }
  return HomeRecommendedQuest(quest: best, reason: 'Top reward');
});
