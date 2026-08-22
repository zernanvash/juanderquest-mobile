import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../submissions/providers/submission_provider.dart';

enum BadgeState { earned, inProgress, locked }

class ProfileStatsModel {
  final int completedQuestsCount;
  final int pendingSubmissionsCount;
  final int totalPointsEarned;
  final BadgeState ecoPioneerState;
  final BadgeState heritageKeeperState;
  final BadgeState foodExplorerState;

  ProfileStatsModel({
    required this.completedQuestsCount,
    required this.pendingSubmissionsCount,
    required this.totalPointsEarned,
    required this.ecoPioneerState,
    required this.heritageKeeperState,
    required this.foodExplorerState,
  });

  int get pointsBalance => totalPointsEarned;
  int get completedQuests => completedQuestsCount;
  int get totalSubmissions => completedQuestsCount + pendingSubmissionsCount;
}

final profileStatsProvider = Provider<ProfileStatsModel>((ref) {
  final subState = ref.watch(submissionProvider);

  if (subState.submissions.isEmpty && !subState.isLoading) {
    Future.microtask(() {
      ref.read(submissionProvider.notifier).fetchSubmissions();
    });
  }

  final approvedSubs = subState.submissions.where((s) => s.status == 'approved').toList();
  final pendingSubs = subState.submissions.where((s) => s.status == 'pending').toList();

  final hasApprovedEco = approvedSubs.any((s) => s.category.toLowerCase().contains('eco'));
  final hasPendingEco = pendingSubs.any((s) => s.category.toLowerCase().contains('eco'));

  final hasApprovedCultural = approvedSubs.any((s) => s.category.toLowerCase().contains('cultural') || s.category.toLowerCase().contains('heritage'));
  final hasPendingCultural = pendingSubs.any((s) => s.category.toLowerCase().contains('cultural') || s.category.toLowerCase().contains('heritage'));

  final hasApprovedFood = approvedSubs.any((s) => s.category.toLowerCase().contains('food') || s.category.toLowerCase().contains('trade'));
  final hasPendingFood = pendingSubs.any((s) => s.category.toLowerCase().contains('food') || s.category.toLowerCase().contains('trade'));

  final totalPoints = approvedSubs.fold<int>(0, (sum, s) => sum + s.rewardPoints);

  return ProfileStatsModel(
    completedQuestsCount: approvedSubs.length,
    pendingSubmissionsCount: pendingSubs.length,
    totalPointsEarned: totalPoints,
    ecoPioneerState: hasApprovedEco
        ? BadgeState.earned
        : (hasPendingEco ? BadgeState.inProgress : BadgeState.locked),
    heritageKeeperState: hasApprovedCultural
        ? BadgeState.earned
        : (hasPendingCultural ? BadgeState.inProgress : BadgeState.locked),
    foodExplorerState: hasApprovedFood
        ? BadgeState.earned
        : (hasPendingFood ? BadgeState.inProgress : BadgeState.locked),
  );
});
