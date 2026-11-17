import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/open_route.dart';
import '../../../core/dev/test_content.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../cultural_quizzes/providers/cultural_quiz_provider.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/pixel/saved_quests.dart';
import '../../quests/providers/quest_provider.dart';
import '../../submissions/providers/submission_provider.dart';
import '../providers/home_dashboard_providers.dart';
import 'home_command_grid.dart';

/// Quests with at least one verified step and at least one still to do.
List<QuestModel> inProgressQuests(
  List<QuestModel> quests,
  SubmissionState submissions,
) {
  final completedTitles = submissions.submissions
      .where((item) => item.status == 'approved')
      .map((item) => item.questTitle)
      .toSet();
  return quests.where((quest) {
    if (completedTitles.contains(quest.title)) return false;
    if (quest.steps.isEmpty) return false;
    final anyVerified = quest.steps.any((step) => step.isVerified);
    final allVerified = quest.steps.every((step) => step.isVerified);
    return anyVerified && !allVerified;
  }).toList();
}

/// v0.3 main menu (owner 2026-11-16: "create a menu button thats spawns a
/// modal ... should contain all the main menu buttons from the dashboard. i
/// like the 'menu a' main menu layout"). Opened by the MENU button in the
/// bottom bar; [onClose] runs before any navigation.
class MainMenuPanel extends ConsumerWidget {
  const MainMenuPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final quests = withoutTestContent(
      ref.watch(questProvider).quests,
      (quest) => quest.isTest,
      showTest: ref.watch(showTestContentProvider),
    );
    final inProgress = inProgressQuests(quests, ref.watch(submissionProvider));
    final radar =
        ref.watch(quizRadarProvider.select((s) => s.inRangeIncomplete));
    final nearby = ref.watch(homeNearbyQuizProvider).valueOrNull;
    final overview = ref.watch(choiceOverviewProvider).asData?.value;
    final current = overview?.current;
    final voteLive = current != null &&
        (current.status == 'voting' ||
            overview?.isCampaignOpen(current) == true);

    void go(String route) {
      onClose();
      openRoute(context, route);
    }

    return PixelPanel(
      key: const ValueKey('main_menu_panel'),
      style: PixelBoxStyle.parchment,
      padding: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: PixelText3D('Main menu',
                size: 12, depth: 1, textAlign: TextAlign.left),
          ),
          SizedBox(height: grid.px(2)),
          HomeCommandGrid(
            activeQuestsCount: inProgress.length,
            savedCount: ref.watch(savedQuestsProvider).length,
            nearbyQuizCount:
                radar.isNotEmpty ? radar.length : (nearby?.items.length ?? 0),
            voteLive: voteLive,
            onOpenQuizzes: () => go('/cultural-quizzes'),
            onNavigate: go,
          ),
        ],
      ),
    );
  }
}
