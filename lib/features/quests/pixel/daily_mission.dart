import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/quest_model.dart';

bool dailyQuestStepActive(Map<String, dynamic>? daily) {
  if (daily == null) return false;
  final missions = daily['missions'];
  if (missions is! List) return false;
  for (final mission in missions.whereType<Map>()) {
    if (mission['kind'] != 'quest_step') continue;
    if (mission['completed'] != true) return true;
  }
  return false;
}

Future<bool> fetchDailyQuestStepActive(ApiClient api) async {
  final response = await api.dio.get('/me/daily');
  final data = response.data is Map ? response.data['data'] : null;
  if (data is! Map) return false;
  return dailyQuestStepActive(Map<String, dynamic>.from(data));
}

final dailyMissionFetcherProvider = Provider<Future<bool> Function()>(
  (ref) => () => fetchDailyQuestStepActive(ref.read(apiClientProvider)),
);

String? dailyMissionQuestId(
  List<QuestModel> quests,
  String Function(QuestModel quest) statusOf,
  bool active,
) {
  if (!active) return null;
  for (final quest in quests) {
    if (statusOf(quest) != 'COMPLETED') return quest.id;
  }
  return null;
}
