import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../cultural_quizzes/models/cultural_quiz_model.dart';
import '../../profile/providers/profile_stats_provider.dart';
import '../../quests/models/quest_model.dart';
import '../../quests/providers/quest_provider.dart';
import '../../submissions/providers/submission_provider.dart';
import '../data/home_events.dart';
import '../providers/home_dashboard_providers.dart';
import 'home_widgets.dart';

class HomeQuestsTab extends StatelessWidget {
  const HomeQuestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _QuestProgressSection(),
        SizedBox(height: grid.px(2)),
        const _NearbyQuizSection(),
        SizedBox(height: grid.px(2)),
        const _EventsSection(),
      ],
    );
  }
}

class _QuestProgressSection extends ConsumerWidget {
  const _QuestProgressSection();

  static List<QuestModel> _inProgress(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final quests = ref.watch(questProvider);
    final submissions = ref.watch(submissionProvider);
    final stats = ref.watch(profileStatsProvider);
    final inProgress = _inProgress(
      withoutTestContent(
        quests.quests,
        (quest) => quest.isTest,
        showTest: ref.watch(showTestContentProvider),
      ),
      submissions,
    );
    return HomePanel(
      key: const ValueKey('home_quest_progress_panel'),
      title: 'Quest progress',
      subtitle: 'Ongoing trails and steps verified',
      // No header "See all": the full-width button below already does it.
      child: quests.isLoading && quests.quests.isEmpty
          ? const HomeInlineLoading(label: 'Loading quests')
          : quests.error != null && quests.quests.isEmpty
              ? HomeErrorPanel(
                  message: 'Quests are unavailable.',
                  retryKey: const ValueKey('home_quests_retry'),
                  onRetry: () => ref.read(questProvider.notifier).fetchQuests(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inProgress.isEmpty)
                      const HomeEmptyText('No quests in progress yet.')
                    else
                      for (var i = 0; i < inProgress.length; i++) ...[
                        if (i > 0) SizedBox(height: grid.px(1)),
                        _QuestProgressCard(quest: inProgress[i]),
                      ],
                    SizedBox(height: grid.px(2)),
                    HomeStatSlot(
                      key: const ValueKey('home_completed_quests'),
                      label: 'Completed quests',
                      value: '${stats.completedQuests}',
                      onTap: () => context.push('/quests'),
                    ),
                    SizedBox(height: grid.px(2)),
                    PixelButton(
                      key: const ValueKey('home_see_all_quests'),
                      label: 'See all quests',
                      expand: true,
                      onPressed: () => context.push('/quests'),
                    ),
                  ],
                ),
    );
  }
}

class _QuestProgressCard extends StatelessWidget {
  const _QuestProgressCard({required this.quest});

  final QuestModel quest;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final total = quest.steps.length;
    final done = quest.steps.where((step) => step.isVerified).length;
    final step = (done + 1).clamp(1, total == 0 ? 1 : total);
    return Semantics(
      container: true,
      label: '${quest.title}, step $step of $total',
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              quest.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.body(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: grid.px(0.5)),
            Text(
              'Step $step of $total · ${quest.categoryDisplay}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            PixelProgressBar(
              value: total == 0 ? 0 : done / total,
              segments: total == 0 ? 1 : total.clamp(1, 20).toInt(),
              color: PixelPalette.sun,
            ),
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: ValueKey('home_quest_continue_${quest.id}'),
              label: 'Continue',
              expand: true,
              onPressed: () => context.push('/quests/${quest.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyQuizSection extends ConsumerWidget {
  const _NearbyQuizSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final quizzes = ref.watch(homeNearbyQuizProvider);
    return HomePanel(
      key: const ValueKey('home_quiz_panel'),
      title: 'Cultural quizzes',
      subtitle: 'Nearby destination quizzes',
      child: quizzes.when(
        loading: () => const HomeInlineLoading(label: 'Looking for quizzes'),
        error: (_, __) => HomeErrorPanel(
          message: 'Nearby quizzes are unavailable.',
          retryKey: const ValueKey('home_quiz_retry'),
          onRetry: () => ref.invalidate(homeNearbyQuizProvider),
        ),
        data: (result) => result.items.isEmpty
            ? HomeEmptyText(
                'No quizzes ${result.originLabel.toLowerCase()} yet.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    result.originLabel,
                    style: PixelType.small(
                      context,
                      color: PixelPalette.greenDark,
                    ),
                  ),
                  SizedBox(height: grid.px(1)),
                  for (var i = 0; i < result.items.take(3).length; i++) ...[
                    if (i > 0) SizedBox(height: grid.px(1)),
                    _QuizRow(quiz: result.items[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  const _QuizRow({required this.quiz});

  final NearbyQuizInvitationModel quiz;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final distance = quiz.distanceMeters > 0
        ? '${quiz.distanceMeters} m away'
        : quiz.municipality;
    return Semantics(
      button: true,
      label: 'Open quiz ${quiz.title}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_quiz_${quiz.quizId}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/cultural-quizzes/${quiz.quizId}'),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          quiz.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PixelType.body(
                            context,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: grid.px(1)),
                      PixelChip(
                        quiz.isCompleted
                            ? 'Play again'
                            : '+${quiz.xpReward} XP',
                        style: quiz.isCompleted
                            ? PixelBoxStyle.slot
                            : PixelBoxStyle.gold,
                        textColor: quiz.isCompleted
                            ? PixelPalette.slate
                            : PixelPalette.ink,
                      ),
                    ],
                  ),
                  SizedBox(height: grid.px(0.5)),
                  Text(
                    '${quiz.destinationName} · $distance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventsSection extends ConsumerWidget {
  const _EventsSection();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _date(DateTime value) =>
      '${_months[value.month - 1]} ${value.day}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = ref
        .watch(homeEventsProvider)
        .where((event) => !(event.endDate ?? event.date).isBefore(today))
        .take(3)
        .toList();
    return HomePanel(
      key: const ValueKey('home_events_panel'),
      title: 'Events calendar',
      subtitle: 'Upcoming festivals & fiestas',
      child: events.isEmpty
          ? const HomeEmptyText('No upcoming events listed.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < events.length; i++) ...[
                  if (i > 0) SizedBox(height: grid.px(1)),
                  _EventRow(event: events[i], now: now),
                ],
              ],
            ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.now});

  final HomeEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final range = event.endDate == null
        ? _EventsSection._date(event.date)
        : '${_EventsSection._date(event.date)} · ${_EventsSection._date(event.endDate!)}';
    return Semantics(
      button: true,
      label: 'Open event ${event.title}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('home_event_${event.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(event.route),
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            padding: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full width so long festival names get their two lines;
                // the countdown sits with the badge underneath.
                Text(
                  event.title,
                  key: ValueKey('home_event_title_${event.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: grid.px(0.5)),
                Text(
                  '$range · ${event.municipality}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(1)),
                Wrap(
                  spacing: grid.px(1),
                  runSpacing: grid.px(1),
                  children: [
                    PixelChip(
                      homeEventCountdown(event, now),
                      style: PixelBoxStyle.slot,
                      textColor: PixelPalette.greenDark,
                    ),
                    if (event.badge != null)
                      PixelChip(
                        event.badge!,
                        style: PixelBoxStyle.gold,
                        textColor: PixelPalette.ink,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
