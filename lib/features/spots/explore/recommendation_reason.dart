import '../models/spot_model.dart';

/// Truthful recommendation chip types supported by the explore feed.
enum RecommendationReasonType {
  questAvailable,
  quietNow,
  lguVerified,
}

/// Computes at most one truthful recommendation chip for a destination spot.
///
/// Follows the web `topRecommendationReason` rules:
/// 1. Quest available: if [spot.questId] exists or reasons indicate an active quest.
/// 2. Quiet now: if [spot.crowdStatus] is quiet or reasons indicate low crowd.
/// 3. LGU verified: if [spot.trustLevel] is `lgu_verified` or reasons indicate verification.
///
/// Returns null if no truthful reason applies.
String? getTopRecommendationReason(SpotModel spot) {
  // 1. Quest available has highest action value
  if (spot.questId != null && spot.questId!.trim().isNotEmpty) {
    return 'Quest available';
  }
  for (final reason in spot.reasons) {
    final lower = reason.toLowerCase();
    if (lower.contains('quest') || lower.contains('bounty')) {
      return 'Quest available';
    }
  }

  // 2. Currently quiet (real-time / estimated crowd status)
  if (spot.crowdStatus.toLowerCase() == 'quiet') {
    return 'Quiet now';
  }
  for (final reason in spot.reasons) {
    final lower = reason.toLowerCase();
    if (lower.contains('quiet') || lower.contains('serene')) {
      return 'Quiet now';
    }
  }

  // 3. LGU Verified provenance
  if (spot.trustLevel.toLowerCase() == 'lgu_verified') {
    return 'LGU verified';
  }
  for (final reason in spot.reasons) {
    final lower = reason.toLowerCase();
    if (lower.contains('lgu') || lower.contains('verified')) {
      return 'LGU verified';
    }
  }

  return null;
}
