import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/filter_chip_row.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_search_field.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/quest_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../submissions/providers/submission_provider.dart';
import '../models/quest_model.dart';
import '../providers/quest_provider.dart';

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  String _selectedCategory = '';
  final TextEditingController _searchController = TextEditingController();

  final List<FilterChipOption> _categoryOptions = const [
    FilterChipOption(key: '', label: 'All Quests', icon: Icons.explore_rounded),
    FilterChipOption(key: 'eco', label: '🌿 Eco', icon: null),
    FilterChipOption(key: 'cultural', label: '🏛️ Cultural', icon: null),
    FilterChipOption(key: 'food', label: '🍱 Culinary', icon: null),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(questProvider.notifier).fetchQuests();
      ref.read(submissionProvider.notifier).fetchSubmissions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getQuestStatus(QuestModel quest) {
    final submissions = ref.read(submissionProvider).submissions;
    final userSub = submissions.where((s) => s.questTitle == quest.title || s.id == quest.id).toList();

    if (userSub.any((s) => s.status == 'approved')) return 'COMPLETED';
    if (userSub.any((s) => s.status == 'pending')) return 'PENDING REVIEW';
    if (userSub.any((s) => s.status == 'rejected')) return 'REJECTED';
    return 'AVAILABLE';
  }

  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);
    final user = ref.watch(authProvider).user;
    final points = user?.points ?? 1250;

    final filteredQuests = questState.quests.where((q) {
      final query = _searchController.text.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          q.title.toLowerCase().contains(query) ||
          q.locationName.toLowerCase().contains(query) ||
          q.categoryDisplay.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory.isEmpty ||
          q.categoryDisplay.toLowerCase().contains(_selectedCategory.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();

    return JdqScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.sunGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.woodBrown, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Discover Quests',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.woodBrown,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.gutter),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.crowdModerateBg,
              borderRadius: AppSpacing.roundedPill,
              border: Border.all(color: AppColors.sunGold.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.sunGold, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$points pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.woodBrown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(questProvider.notifier).fetchQuests();
          await ref.read(submissionProvider.notifier).fetchSubmissions();
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.md,
          ),
          children: [
            JdqSectionHeader(
              title: 'Play & Earn Rewards',
              subtitle: 'Participate in location-verified quests and earn points.',
            ),

            JdqSearchField(
              controller: _searchController,
              hintText: 'Search quests, hiking, food trails...',
              onSubmitted: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),

            const SizedBox(height: AppSpacing.md),

            FilterChipRow(
              options: _categoryOptions,
              selectedKey: _selectedCategory,
              onSelected: (key) => setState(() => _selectedCategory = key),
            ),

            const SizedBox(height: AppSpacing.lg),

            AsyncStateView(
              isLoading: questState.isLoading,
              errorMessage: questState.error,
              isEmpty: filteredQuests.isEmpty,
              emptyMessage: 'No quests matching criteria',
              emptySubtitle: 'Try expanding your category filter or search terms.',
              emptyIcon: Icons.emoji_events_outlined,
              onRetry: () {
                ref.read(questProvider.notifier).fetchQuests();
              },
              content: Column(
                children: [
                  if (filteredQuests.isNotEmpty) ...[
                    QuestCard(
                      quest: filteredQuests.first,
                      status: _getQuestStatus(filteredQuests.first),
                      isFeatured: true,
                      onTap: () => context.push('/quests/${filteredQuests.first.id}'),
                    ),

                    ...filteredQuests.skip(1).map((quest) {
                      return QuestCard(
                        quest: quest,
                        status: _getQuestStatus(quest),
                        onTap: () => context.push('/quests/${quest.id}'),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
