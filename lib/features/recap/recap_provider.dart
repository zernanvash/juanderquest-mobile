import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_provider.dart';

/// Plan 62 Juander Recap: `GET /me/recap?period=` (towns only, no coordinates).
class Recap {
  const Recap({
    required this.periodId,
    required this.periodLabel,
    required this.questsCompleted,
    required this.towns,
    required this.townsTotal,
    required this.spotsPosted,
    required this.quizzesPassed,
    required this.stampsEarned,
    required this.bestStreak,
    this.persona,
    this.whereNext,
  });

  final String periodId;
  final String periodLabel;
  final int questsCompleted;
  final List<String> towns;
  final int townsTotal;
  final int spotsPosted;
  final int quizzesPassed;
  final int stampsEarned;
  final int bestStreak;
  final String? persona;
  final String? whereNext;

  bool get isEmpty =>
      questsCompleted == 0 &&
      spotsPosted == 0 &&
      quizzesPassed == 0 &&
      stampsEarned == 0;

  factory Recap.fromJson(Map<String, dynamic> j) {
    final period = (j['period'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return Recap(
      periodId: period['id']?.toString() ?? '',
      periodLabel: period['label']?.toString() ?? '',
      questsCompleted: n(j['quests_completed']),
      towns: (j['towns'] as List? ?? const []).map((t) => t.toString()).toList(),
      townsTotal: n(j['towns_total']),
      spotsPosted: n(j['spots_posted']),
      quizzesPassed: n(j['quizzes_passed']),
      stampsEarned: n(j['stamps_earned']),
      bestStreak: n(j['best_streak']),
      persona: j['persona']?.toString(),
      whereNext: j['where_next']?.toString(),
    );
  }
}

/// `null` = the current season.
final recapProvider =
    FutureProvider.autoDispose.family<Recap, String?>((ref, period) async {
  final response = await ref.read(apiClientProvider).dio.get(
        '/me/recap',
        queryParameters: period == null ? null : {'period': period},
      );
  final data = response.data is Map ? response.data['data'] : null;
  if (data is! Map) throw StateError('Recap response was not understood.');
  return Recap.fromJson(Map<String, dynamic>.from(data));
});
