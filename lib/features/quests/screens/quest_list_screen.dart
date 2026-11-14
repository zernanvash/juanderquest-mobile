import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/quest_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../submissions/providers/submission_provider.dart';
import '../models/quest_model.dart';
import '../pixel/saved_quests.dart';
import '../providers/quest_provider.dart';

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(questProvider.notifier).fetchQuests();
      ref.read(submissionProvider.notifier).fetchSubmissions();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(questProvider.notifier).fetchQuests(),
      ref.read(submissionProvider.notifier).fetchSubmissions(force: true),
    ]);
  }

  String _getQuestStatus(QuestModel quest) {
    final submissions = ref.read(submissionProvider).submissions;
    final userSub = submissions
        .where((s) => s.questTitle == quest.title || s.id == quest.id)
        .toList();
    if (userSub.any((s) => s.status == 'approved')) return 'COMPLETED';
    if (userSub.any((s) => s.status == 'pending')) return 'PENDING REVIEW';
    if (userSub.any((s) => s.status == 'rejected')) return 'REJECTED';
    return 'AVAILABLE';
  }

  bool _isCompleted(QuestModel quest) {
    if (_getQuestStatus(quest) == 'COMPLETED') return true;
    return quest.steps.isNotEmpty && quest.steps.every((s) => s.isVerified);
  }

  bool _isInProgress(QuestModel quest) {
    if (_isCompleted(quest)) return false;
    if (quest.steps.isEmpty) return false;
    return quest.steps.any((s) => s.isVerified);
  }

  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);
    ref.watch(submissionProvider);
    final user = ref.watch(authProvider).user;
    final savedQuests = ref.watch(savedQuestsProvider);
    final points = user?.points ?? 1250;

    final showTest = ref.watch(showTestContentProvider);
    final visibleQuests = withoutTestContent(
      questState.quests,
      (q) => q.isTest,
      showTest: showTest,
    );

    final completed = visibleQuests.where(_isCompleted).toList();
    final completedIds = completed.map((q) => q.id).toSet();
    final inProgress = visibleQuests
        .where((q) => !completedIds.contains(q.id) && _isInProgress(q))
        .toList();
    final inProgressIds = inProgress.map((q) => q.id).toSet();
    final saved = visibleQuests
        .where(
          (q) =>
              savedQuests.contains(q.id) &&
              !completedIds.contains(q.id) &&
              !inProgressIds.contains(q.id),
        )
        .toList();

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'My quests',
                    onBack: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                    actions: [
                      PixelChip(
                        '$points mJDQ',
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PixelPalette.green,
                      backgroundColor: PixelPalette.parchment,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          grid.px(4),
                          grid.px(3),
                          grid.px(4),
                          grid.px(10) + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: _buildBody(
                          context,
                          grid,
                          questState,
                          inProgress: inProgress,
                          saved: saved,
                          completed: completed,
                          savedIds: savedQuests,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    PixelGrid grid,
    QuestState state, {
    required List<QuestModel> inProgress,
    required List<QuestModel> saved,
    required List<QuestModel> completed,
    required Set<String> savedIds,
  }) {
    if (state.isLoading && state.quests.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: PixelLoader()),
        ),
      ];
    }
    if (state.error != null && state.quests.isEmpty) {
      return [
        _UnavailablePanel(
          message: 'Failed to load quest trails',
          onRetry: () => ref.read(questProvider.notifier).fetchQuests(),
        ),
      ];
    }
    if (inProgress.isEmpty && saved.isEmpty && completed.isEmpty) {
      return [
        _EmptyMyQuestsPanel(
          onExplore: () => context.go('/explore'),
        ),
      ];
    }

    return [
      if (inProgress.isNotEmpty)
        ..._section(
          context,
          grid,
          title: 'In progress',
          quests: inProgress,
          savedIds: savedIds,
        ),
      if (saved.isNotEmpty)
        ..._section(
          context,
          grid,
          title: 'Saved',
          quests: saved,
          savedIds: savedIds,
        ),
      if (completed.isNotEmpty)
        ..._section(
          context,
          grid,
          title: 'Completed',
          quests: completed,
          savedIds: savedIds,
        ),
    ];
  }

  List<Widget> _section(
    BuildContext context,
    PixelGrid grid, {
    required String title,
    required List<QuestModel> quests,
    required Set<String> savedIds,
  }) {
    return [
      Padding(
        padding: EdgeInsets.only(bottom: grid.px(2)),
        child: Text(
          '$title (${quests.length})',
          style: PixelType.title(context, color: PixelPalette.woodDeep),
        ),
      ),
      for (final quest in quests) ...[
        QuestCard(
          quest: quest,
          status: _getQuestStatus(quest),
          isSaved: savedIds.contains(quest.id),
          onToggleSaved: () =>
              ref.read(savedQuestsProvider.notifier).toggle(quest.id),
          onTap: () => context.push('/quests/${quest.id}'),
          onDirections: () => context.push(
            '/navigate?name=${Uri.encodeComponent(quest.title)}&lat=${quest.gpsLat}&lng=${quest.gpsLng}&address=${Uri.encodeComponent(quest.locationName)}',
          ),
        ),
        SizedBox(height: grid.px(3)),
      ],
    ];
  }
}

class _EmptyMyQuestsPanel extends StatelessWidget {
  const _EmptyMyQuestsPanel({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Find a destination to start a quest',
            style: PixelType.body(context),
          ),
          SizedBox(height: grid.px(3)),
          PixelButton(
            key: const ValueKey('my_quests_explore_button'),
            label: 'EXPLORE',
            variant: PixelButtonVariant.primary,
            expand: true,
            onPressed: onExplore,
          ),
        ],
      ),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: PixelType.body(context)),
          SizedBox(height: grid.px(3)),
          PixelButton(
            label: 'RETRY',
            variant: PixelButtonVariant.primary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
