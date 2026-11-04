import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/quest_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../submissions/providers/submission_provider.dart';
import '../models/campaign_model.dart';
import '../models/quest_model.dart';
import '../pixel/daily_mission.dart';
import '../pixel/pixel_tag.dart';
import '../pixel/quest_paging.dart';
import '../pixel/saved_quests.dart';
import '../providers/campaign_provider.dart';
import '../providers/quest_provider.dart';

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  static const _questCategories = <(String, String)>[
    ('', 'All'),
    ('eco', 'Eco-Tourism'),
    ('cultural', 'Cultural Heritage'),
    ('food', 'Culinary'),
  ];

  static const _campaignCategories = <(String, String)>[
    ('', 'All campaigns'),
    ('eco', 'Eco-cleanups'),
    ('cultural', 'Cultural festivals'),
    ('sports_adventure', 'Sports & adventure'),
    ('food_trade', 'Food & agri-trade'),
  ];

  int _activeTabIndex = 0;
  String _selectedCategory = '';
  String _selectedCampaignCategory = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _visibleCount = 10;
  int _filteredCount = 0;
  bool _showTop = false;
  bool _dailyMissionActive = false;
  bool _dailyMissionRequested = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(questProvider.notifier).fetchQuests();
      ref.read(campaignProvider.notifier).fetchCampaigns();
      ref.read(submissionProvider.notifier).fetchSubmissions();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final showTop = position.pixels > MediaQuery.sizeOf(context).height * 0.8;
    if (showTop != _showTop) {
      setState(() => _showTop = showTop);
    }
    if (position.pixels >= position.maxScrollExtent - 300 &&
        _visibleCount < _filteredCount) {
      setState(() {
        _visibleCount = nextPageCount(_visibleCount, _filteredCount);
      });
    }
  }

  Future<void> _loadDailyMission() async {
    if (!mounted) return;
    if (!ref.read(authProvider).isAuthenticated) {
      if (mounted) setState(() => _dailyMissionActive = false);
      return;
    }
    try {
      final active = await ref.read(dailyMissionFetcherProvider)();
      if (mounted) setState(() => _dailyMissionActive = active);
    } catch (_) {
      if (mounted) setState(() => _dailyMissionActive = false);
    }
  }

  Future<void> _refresh() async {
    _visibleCount = 10;
    await Future.wait([
      ref.read(questProvider.notifier).fetchQuests(),
      ref.read(campaignProvider.notifier).fetchCampaigns(forceRefresh: true),
      ref.read(submissionProvider.notifier).fetchSubmissions(force: true),
      _loadDailyMission(),
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

  bool _questMatches(QuestModel quest) {
    final query = _searchController.text.toLowerCase().trim();
    final matchesSearch = query.isEmpty ||
        quest.title.toLowerCase().contains(query) ||
        quest.locationName.toLowerCase().contains(query) ||
        quest.categoryDisplay.toLowerCase().contains(query) ||
        quest.tags.any((tag) => tag.toLowerCase().contains(query));
    if (!matchesSearch) return false;
    if (_selectedCategory.isEmpty) return true;
    final category = quest.category.toLowerCase();
    final display = quest.categoryDisplay.toLowerCase();
    if (_selectedCategory == 'food') {
      return category == 'food' ||
          category == 'food_trade' ||
          display.contains('food') ||
          display.contains('culinary');
    }
    return category == _selectedCategory || display.contains(_selectedCategory);
  }

  bool _campaignMatches(CampaignModel campaign) {
    final query = _searchController.text.toLowerCase().trim();
    final matchesSearch = query.isEmpty ||
        campaign.title.toLowerCase().contains(query) ||
        campaign.locationName.toLowerCase().contains(query) ||
        campaign.municipality.toLowerCase().contains(query) ||
        campaign.description.toLowerCase().contains(query);
    if (!matchesSearch) return false;
    if (_selectedCampaignCategory.isEmpty) return true;
    final category = campaign.category.toLowerCase();
    if (_selectedCampaignCategory == 'food_trade') {
      return category == 'food' ||
          category == 'food_trade' ||
          category.contains('food');
    }
    if (_selectedCampaignCategory == 'sports_adventure') {
      return category == 'sports_adventure' || category.contains('sport');
    }
    return category == _selectedCampaignCategory ||
        category.contains(_selectedCampaignCategory);
  }

  void _selectTab(int index) {
    setState(() {
      _activeTabIndex = index;
      _visibleCount = 10;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _selectQuestCategory(String key) {
    setState(() {
      _selectedCategory = key;
      _visibleCount = 10;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _selectCampaignCategory(String key) {
    setState(() {
      _selectedCampaignCategory = key;
      _visibleCount = 10;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);
    final campaignState = ref.watch(campaignProvider);
    final user = ref.watch(authProvider).user;
    final savedQuests = ref.watch(savedQuestsProvider);
    final points = user?.points ?? 1250;
    final signedIn = user != null;

    if (signedIn && !_dailyMissionRequested) {
      _dailyMissionRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDailyMission();
      });
    }

    final filteredQuests = questState.quests.where(_questMatches).toList();
    final filteredCampaigns =
        campaignState.campaigns.where(_campaignMatches).toList();
    _filteredCount =
        _activeTabIndex == 0 ? filteredQuests.length : filteredCampaigns.length;
    // Never shrink the page below its size: quests arrive after the first
    // build (0 while loading), and a 0 here would hide them for good.
    if (_visibleCount > _filteredCount && _filteredCount >= 10) {
      _visibleCount = _filteredCount;
    }

    final missionQuestId = dailyMissionQuestId(
      filteredQuests,
      _getQuestStatus,
      signedIn && _dailyMissionActive,
    );

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
                    title: 'Quests',
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
                    child: Stack(
                      children: [
                        RefreshIndicator(
                          color: PixelPalette.green,
                          backgroundColor: PixelPalette.parchment,
                          onRefresh: _refresh,
                          child: ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              grid.px(4),
                              grid.px(3),
                              grid.px(4),
                              grid.px(10) +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            children: [
                              _intro(context, grid, questState, campaignState),
                              SizedBox(height: grid.px(3)),
                              _categoryChips(context, grid),
                              SizedBox(height: grid.px(2)),
                              _search(context, grid),
                              SizedBox(height: grid.px(3)),
                              if (_activeTabIndex == 0)
                                ..._quests(
                                  context,
                                  grid,
                                  questState,
                                  filteredQuests,
                                  savedQuests,
                                  missionQuestId,
                                )
                              else
                                ..._campaigns(
                                  context,
                                  grid,
                                  campaignState,
                                  filteredCampaigns,
                                ),
                            ],
                          ),
                        ),
                        if (_showTop)
                          Positioned(
                            right: grid.px(4),
                            bottom: grid.px(4),
                            child: PixelButton(
                              key: const ValueKey('quests_top_btn'),
                              label: 'Top',
                              style: PixelBoxStyle.wood,
                              textColor: PixelPalette.white,
                              onPressed: () => _scrollController.jumpTo(0),
                            ),
                          ),
                      ],
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

  Widget _intro(
    BuildContext context,
    PixelGrid grid,
    QuestState questState,
    CampaignState campaignState,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelTag(
            'Location challenges & bounties',
            style: PixelBoxStyle.gold,
            textColor: PixelPalette.ink,
            maxWidth: grid.px(150),
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'Eco-Quests',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Visit a place, verify it on site, earn points and badges.',
            style: PixelType.body(context, color: PixelPalette.paperDim),
          ),
          SizedBox(height: grid.px(3)),
          PixelSegmented(
            items: [
              'Quests · ${questState.quests.length}',
              'Events · ${campaignState.campaigns.length}',
            ],
            selectedIndex: _activeTabIndex,
            onChanged: _selectTab,
          ),
        ],
      ),
    );
  }

  Widget _categoryChips(BuildContext context, PixelGrid grid) {
    final options =
        _activeTabIndex == 0 ? _questCategories : _campaignCategories;
    final selected =
        _activeTabIndex == 0 ? _selectedCategory : _selectedCampaignCategory;
    return Wrap(
      spacing: grid.px(2),
      runSpacing: grid.px(1),
      children: [
        for (final option in options)
          _CategoryChip(
            key: ValueKey('quests_category_${option.$1}'),
            label: option.$2,
            selected: selected == option.$1,
            onTap: () => _activeTabIndex == 0
                ? _selectQuestCategory(option.$1)
                : _selectCampaignCategory(option.$1),
          ),
      ],
    );
  }

  Widget _search(BuildContext context, PixelGrid grid) {
    return Row(
      children: [
        const PixelSprite(DesignerArt.search, scale: 2),
        SizedBox(width: grid.px(2)),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: PixelTextField(
              controller: _searchController,
              hint: _activeTabIndex == 0
                  ? 'Quests, town, tag'
                  : 'Events & festivals',
              onChanged: (_) => setState(() {
                _visibleCount = 10;
              }),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _quests(
    BuildContext context,
    PixelGrid grid,
    QuestState state,
    List<QuestModel> filtered,
    Set<String> saved,
    String? missionQuestId,
  ) {
    if (state.isLoading && state.quests.isEmpty) {
      return [
        const Padding(
            padding: EdgeInsets.all(32), child: Center(child: PixelLoader()))
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
    if (filtered.isEmpty) {
      return [
        const _EmptyPanel(
          title: 'No quest trails found',
          message: 'Try changing your search terms or category filter.',
        ),
      ];
    }
    final visible = filtered.take(_visibleCount).toList();
    return [
      for (final quest in visible) ...[
        QuestCard(
          quest: quest,
          status: _getQuestStatus(quest),
          isSaved: saved.contains(quest.id),
          dailyMission: quest.id == missionQuestId,
          onToggleSaved: () =>
              ref.read(savedQuestsProvider.notifier).toggle(quest.id),
          onTap: () => context.push('/quests/${quest.id}'),
          onDirections: () => context.push(
            '/navigate?name=${Uri.encodeComponent(quest.title)}&lat=${quest.gpsLat}&lng=${quest.gpsLng}&address=${Uri.encodeComponent(quest.locationName)}',
          ),
        ),
        SizedBox(height: grid.px(3)),
      ],
      if (_visibleCount < filtered.length)
        Padding(
          padding: EdgeInsets.only(bottom: grid.px(3)),
          child: Text(
            'Loading more as you scroll...',
            textAlign: TextAlign.center,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ),
    ];
  }

  List<Widget> _campaigns(
    BuildContext context,
    PixelGrid grid,
    CampaignState state,
    List<CampaignModel> filtered,
  ) {
    if (state.isLoading && state.campaigns.isEmpty) {
      return [
        const Padding(
            padding: EdgeInsets.all(32), child: Center(child: PixelLoader()))
      ];
    }
    if (state.failure != null && state.campaigns.isEmpty) {
      return [
        _UnavailablePanel(
          message: 'Event campaigns are unavailable.',
          onRetry: () => ref
              .read(campaignProvider.notifier)
              .fetchCampaigns(forceRefresh: true),
        ),
      ];
    }
    if (filtered.isEmpty) {
      return [
        const _EmptyPanel(
          title: 'No event campaigns found',
          message:
              'Check back soon for upcoming municipal festivals and eco-rallies.',
        ),
      ];
    }
    final visible = filtered.take(_visibleCount).toList();
    return [
      for (final campaign in visible) ...[
        _CampaignCard(campaign: campaign),
        SizedBox(height: grid.px(3)),
      ],
      if (_visibleCount < filtered.length)
        Padding(
          padding: EdgeInsets.only(bottom: grid.px(3)),
          child: Text(
            'Loading more as you scroll...',
            textAlign: TextAlign.center,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ),
    ];
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            pixelTick(context);
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              widthFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: grid.px(110)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PixelChip(
                    label,
                    style: selected ? PixelBoxStyle.green : PixelBoxStyle.slot,
                    textColor:
                        selected ? PixelPalette.white : PixelPalette.slate,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: PixelType.body(context)),
          SizedBox(height: grid.px(2)),
          PixelButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      child: PixelEmptyState(
        title: title,
        message: message,
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final CampaignModel campaign;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final start = campaign.startDate.split('T').first;
    final end = campaign.endDate.split('T').first;
    return Semantics(
      button: true,
      label: '${campaign.title}. ${campaign.hostName}. ${campaign.status}.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(
          '/quests/campaigns/${campaign.id}',
          extra: campaign,
        ),
        child: PixelPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PixelPanel(
                style: PixelBoxStyle.slot,
                sunken: true,
                padding: 1,
                child: ClipRect(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      campaign.bannerImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _CampaignFallback(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(1),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PixelTag(
                    campaign.municipality,
                    style: PixelBoxStyle.green,
                    textColor: PixelPalette.white,
                    maxWidth: grid.px(70),
                  ),
                  PixelTag(
                    campaign.status,
                    style: PixelBoxStyle.gold,
                    textColor: PixelPalette.ink,
                    maxWidth: grid.px(45),
                  ),
                ],
              ),
              SizedBox(height: grid.px(2)),
              Text(
                campaign.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.body(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                '${campaign.hostName} · $start to $end',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                campaign.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              SizedBox(height: grid.px(2)),
              PixelButton(
                label: 'View event >',
                expand: true,
                onPressed: () => context.push(
                  '/quests/campaigns/${campaign.id}',
                  extra: campaign,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignFallback extends StatelessWidget {
  const _CampaignFallback();

  @override
  Widget build(BuildContext context) => const DitherBackground(
        top: PixelPalette.paperDim,
        bottom: PixelPalette.paper,
      );
}
