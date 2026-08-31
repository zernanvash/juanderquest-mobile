import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_chip_row.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_search_field.dart';
import '../../../core/widgets/quest_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ar_experience/controllers/calibration_controller.dart';
import '../../submissions/providers/submission_provider.dart';
import '../models/campaign_model.dart';
import '../models/quest_model.dart';
import '../providers/campaign_provider.dart';
import '../providers/quest_provider.dart';

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  int _activeTabIndex = 0; // 0 = Ongoing Trails, 1 = Event Campaigns
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
      ref.read(campaignProvider.notifier).fetchCampaigns();
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
    final userSub = submissions
        .where((s) => s.questTitle == quest.title || s.id == quest.id)
        .toList();

    if (userSub.any((s) => s.status == 'approved')) return 'COMPLETED';
    if (userSub.any((s) => s.status == 'pending')) return 'PENDING REVIEW';
    if (userSub.any((s) => s.status == 'rejected')) return 'REJECTED';
    return 'AVAILABLE';
  }

  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);
    final campaignState = ref.watch(campaignProvider);
    final user = ref.watch(authProvider).user;
    final points = user?.points ?? 1250;

    final filteredQuests = questState.quests.where((q) {
      final query = _searchController.text.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          q.title.toLowerCase().contains(query) ||
          q.locationName.toLowerCase().contains(query) ||
          q.categoryDisplay.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory.isEmpty ||
          q.categoryDisplay
              .toLowerCase()
              .contains(_selectedCategory.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();

    final filteredCampaigns = campaignState.campaigns.where((c) {
      final query = _searchController.text.toLowerCase().trim();
      return query.isEmpty ||
          c.title.toLowerCase().contains(query) ||
          c.locationName.toLowerCase().contains(query) ||
          c.municipality.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }).toList();

    return JdqScaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: AppColors.sunGold, size: 22),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Quests & Campaigns Hub',
                style: TextStyle(
                  color: AppColors.woodBrown,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sunGold.withOpacity(0.2),
              borderRadius: AppSpacing.roundedPill,
              border: Border.all(color: AppColors.sunGold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded,
                    size: 14, color: AppColors.woodBrown),
                const SizedBox(width: 4),
                Text(
                  '$points mJDQ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
          await Future.wait([
            ref.read(questProvider.notifier).fetchQuests(),
            ref
                .read(campaignProvider.notifier)
                .fetchCampaigns(forceRefresh: true),
            ref.read(submissionProvider.notifier).fetchSubmissions(),
          ]);
        },
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // AR Calibration Prompt Banner if uncalibrated
            if (!ref.watch(calibrationProvider).isCalibrated) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.sunGold.withOpacity(0.14),
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.sunGold.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.explore_rounded,
                          color: AppColors.woodBrown, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calibrate AR Sensors',
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.woodBrown,
                            ),
                          ),
                          Text(
                            'Align the compass for stable AR tracking.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sunGold,
                        foregroundColor: AppColors.woodBrown,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () =>
                          context.push('/ar-calibration?returnTo=/quests'),
                      child: const Text('Setup',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Segmented Tab Switcher (Ongoing Trails vs Event Campaigns)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedXl,
                border: Border.all(color: AppColors.borderLowContrast),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 0
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: AppSpacing.roundedLg,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 15,
                                color: _activeTabIndex == 0
                                    ? AppColors.sunGold
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ongoing Trails',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTabIndex == 0
                                      ? Colors.white
                                      : AppColors.woodBrown,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _activeTabIndex == 0
                                      ? Colors.white.withOpacity(0.2)
                                      : AppColors.surfaceContainerLow,
                                  borderRadius: AppSpacing.roundedPill,
                                ),
                                child: Text(
                                  '${questState.quests.length}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeTabIndex == 0
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 1
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: AppSpacing.roundedLg,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.festival_rounded,
                                size: 15,
                                color: _activeTabIndex == 1
                                    ? AppColors.sunGold
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Event Campaigns',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTabIndex == 1
                                      ? Colors.white
                                      : AppColors.woodBrown,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _activeTabIndex == 1
                                      ? Colors.white.withOpacity(0.2)
                                      : AppColors.surfaceContainerLow,
                                  borderRadius: AppSpacing.roundedPill,
                                ),
                                child: Text(
                                  '${campaignState.campaigns.length}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _activeTabIndex == 1
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search Field
            JdqSearchField(
              controller: _searchController,
              hintText: _activeTabIndex == 0
                  ? 'Search quest trails...'
                  : 'Search event campaigns & festivals...',
              onChanged: (_) => setState(() {}),
              onClear: () {
                _searchController.clear();
                setState(() {});
              },
            ),

            const SizedBox(height: 10),

            // Sub-category filters (For Ongoing Trails)
            if (_activeTabIndex == 0) ...[
              FilterChipRow(
                options: _categoryOptions,
                selectedKey: _selectedCategory,
                onSelected: (key) => setState(() => _selectedCategory = key),
              ),
              const SizedBox(height: 12),
            ],

            // Active Tab Content
            if (_activeTabIndex == 0)
              _buildTrailsView(questState, filteredQuests)
            else
              _buildCampaignsView(campaignState, filteredCampaigns),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailsView(
      QuestState questState, List<QuestModel> filteredQuests) {
    if (questState.isLoading && questState.quests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (questState.error != null && questState.quests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.danger),
            const SizedBox(height: 8),
            Text('Failed to load quest trails',
                style: AppTypography.labelLarge
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(questProvider.notifier).fetchQuests(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (filteredQuests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(color: AppColors.borderLowContrast),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 44, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text('No quest trails found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            Text('Try changing your search terms or category filter.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: filteredQuests.map<Widget>((quest) {
        final status = _getQuestStatus(quest);
        return QuestCard(
          quest: quest,
          status: status,
          onTap: () => context.push('/quests/${quest.id}'),
        );
      }).toList(),
    );
  }

  Widget _buildCampaignsView(
      CampaignState campaignState, List<CampaignModel> filteredCampaigns) {
    if (campaignState.isLoading && campaignState.campaigns.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (filteredCampaigns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.roundedLg,
          border: Border.all(color: AppColors.borderLowContrast),
        ),
        child: const Column(
          children: [
            Icon(Icons.festival_outlined, size: 44, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text('No event campaigns found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            Text(
                'Check back soon for upcoming municipal festivals and eco-rallies.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: filteredCampaigns
          .map((campaign) => _buildCampaignCard(campaign))
          .toList(),
    );
  }

  Widget _buildCampaignCard(CampaignModel campaign) {
    final quotaPercent = campaign.maxParticipants > 0
        ? (campaign.reservedParticipants / campaign.maxParticipants)
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push('/quests/campaigns/${campaign.id}', extra: campaign),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Facebook-Style Full-Bleed Banner Photo
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    campaign.bannerImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerLow,
                      child: const Center(
                        child: Icon(Icons.festival_rounded,
                            color: AppColors.textMuted, size: 40),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3.5),
                    decoration: const BoxDecoration(
                      color: AppColors.sunGold,
                      borderRadius: AppSpacing.roundedPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            size: 13, color: AppColors.woodBrown),
                        const SizedBox(width: 3),
                        Text(
                          '+${campaign.rewardPerParticipantMjdq} mJDQ',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.woodBrown),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Municipality Tag & Category
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        campaign.municipality,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 6),
                      const Text('•',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(
                        campaign.hostName,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Title
                  Text(
                    campaign.title,
                    style: AppTypography.headlineSmall.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.woodBrown),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    campaign.description,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  // Quota Progress Bar
                  ClipRRect(
                    borderRadius: AppSpacing.roundedPill,
                    child: LinearProgressIndicator(
                      value: quotaPercent,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceContainerLow,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Footer: Quota & Action Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${campaign.reservedParticipants} / ${campaign.maxParticipants} Registered',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary),
                      ),
                      const Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward_rounded,
                              size: 12, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
