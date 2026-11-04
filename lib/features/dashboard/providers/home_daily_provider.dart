import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// One assigned daily mission from `/me/daily`.
class HomeDailyMission {
  const HomeDailyMission({
    required this.id,
    required this.kind,
    required this.title,
    required this.stamps,
    required this.progress,
    required this.target,
    required this.completed,
  });

  final String id;
  final String kind;
  final String title;
  final int stamps;
  final int progress;
  final int target;
  final bool completed;
}

/// The Home slice of the daily rewards state: the stamp balance and today's
/// missions. Home only reads it; claiming and the full calendar live elsewhere.
class HomeDailyState {
  const HomeDailyState({required this.stamps, required this.missions});

  final int stamps;
  final List<HomeDailyMission> missions;

  bool get allComplete =>
      missions.isNotEmpty && missions.every((mission) => mission.completed);

  HomeDailyMission? get nextMission {
    for (final mission in missions) {
      if (!mission.completed) return mission;
    }
    return missions.isEmpty ? null : missions.first;
  }
}

final homeDailyProvider = FutureProvider<HomeDailyState>((ref) async {
  final response = await ref.read(apiClientProvider).dio.get('/me/daily');
  final body = response.data;
  final data = body is Map ? body['data'] : null;
  if (data is! Map) {
    throw StateError('Daily rewards response was not understood.');
  }
  final missions =
      (data['missions'] is List ? data['missions'] as List : const [])
          .whereType<Map>()
          .map(
            (row) => HomeDailyMission(
              id: row['id']?.toString() ?? '',
              kind: row['kind']?.toString() ?? '',
              title: row['title']?.toString() ?? 'Daily mission',
              stamps: (row['stamps'] as num?)?.toInt() ?? 0,
              progress: (row['progress'] as num?)?.toInt() ?? 0,
              target: (row['target'] as num?)?.toInt() ?? 1,
              completed: row['completed'] == true,
            ),
          )
          .toList();
  return HomeDailyState(
    stamps: (data['balance'] as num?)?.toInt() ?? 0,
    missions: missions,
  );
});
