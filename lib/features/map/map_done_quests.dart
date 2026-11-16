import '../quests/models/quest_model.dart';
import '../submissions/models/submission_model.dart';

/// Plan 100 WP-9: which quests the traveler finished, by the Quests list's
/// rule (an approved submission, or every step verified).
bool Function(QuestModel) mapQuestDone(List<SubmissionModel> submissions) {
  final approved = {
    for (final s in submissions)
      if (s.status == 'approved') s.questTitle,
  };
  return (q) =>
      approved.contains(q.title) ||
      (q.steps.isNotEmpty && q.steps.every((s) => s.isVerified));
}

/// Finished quests are hidden unless the traveler turns "Show done quests" on.
List<QuestModel> mapVisibleQuests(
  List<QuestModel> quests,
  bool Function(QuestModel) done, {
  required bool showDone,
}) =>
    showDone ? quests : quests.where((q) => !done(q)).toList();
