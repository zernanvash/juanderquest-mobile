import 'dart:math' as math;

import '../../juanchoice/models/juanchoice_models.dart';

/// Result of planning the placement of the JuanChoice spotlight inside the feed.
class JuanChoicePlacementResult<T> {
  const JuanChoicePlacementResult({
    required this.spotlight,
    required this.ordinary,
    required this.insertionIndex,
  });

  /// The active spotlight, or null if expired, missing, or without winners.
  final ChoiceSpotlight? spotlight;

  /// Spots excluding any winners promoted in the spotlight.
  final List<T> ordinary;

  /// 0-based insertion index in [ordinary] (at most 3), or -1 if no spotlight.
  final int insertionIndex;

  bool get hasSpotlight => spotlight != null && insertionIndex >= 0;
}

/// Port of the web's `planJuanChoicePlacement` rule.
///
/// If a valid spotlight is active (unexpired and has winners), any matching
/// winner spots are excluded from [spots] to form the ordinary list, and the
/// spotlight card is scheduled to be inserted at `min(3, ordinary.length)`.
///
/// Otherwise, returns a null spotlight, the unchanged spots list, and an
/// insertion index of -1.
JuanChoicePlacementResult<T> planJuanChoicePlacement<T>({
  required List<T> spots,
  required String Function(T) idOf,
  required ChoiceSpotlight? spotlight,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();

  if (spotlight == null ||
      !currentTime.isBefore(spotlight.expiresAt) ||
      spotlight.winnerSpotIds.isEmpty) {
    return JuanChoicePlacementResult<T>(
      spotlight: null,
      ordinary: List<T>.of(spots),
      insertionIndex: -1,
    );
  }

  final ordinary = spots
      .where((spot) => !spotlight.winnerSpotIds.contains(idOf(spot)))
      .toList();
  final insertionIndex = math.min(3, ordinary.length);

  return JuanChoicePlacementResult<T>(
    spotlight: spotlight,
    ordinary: ordinary,
    insertionIndex: insertionIndex,
  );
}
