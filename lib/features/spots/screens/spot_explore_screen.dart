import '../../dashboard/models/home_calendar_entry.dart';
import '../../dashboard/providers/festival_calendar_provider.dart';
import '../../dashboard/providers/home_calendar_provider.dart';
import '../explore/widgets/explore_badges.dart';
import '../explore/widgets/explore_search_bar.dart';
import '../explore/widgets/explore_search_results.dart';
import '../../../core/search/recent_searches.dart';
import '../explore/widgets/explore_spotlight_row.dart';
import '../providers/hidden_gem_provider.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../onboarding/page_tutorials.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../quests/widgets/new_quests_strip.dart';
import '../../../core/dev/test_content.dart';
import '../../../core/theme/app_theme.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../explore/explore_art.dart';
import '../explore/juanchoice_placement.dart';
import '../explore/spot_filter_state.dart';
import '../explore/widgets/explore_juanchoice_card.dart';
import '../explore/widgets/explore_spot_card.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';

class SpotExploreScreen extends ConsumerStatefulWidget {
  const SpotExploreScreen({super.key});

  @override
  ConsumerState<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends ConsumerState<SpotExploreScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};
  final Set<String> _activeCardIds = <String>{};
  SpotFilterState _filterState = const SpotFilterState();
  int _visibleCount = 10;
  int _totalOrdinaryCount = 0;

  // Owner 2026-11-18 (v0.3.3): search lives inside Explore.
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  String _submittedQuery = '';
  Timer? _searchDebounce;
  CancelToken? _searchCancelToken;
  List<SpotSearchHit> _remoteSearchHits = const [];

  bool get _searching =>
      _searchFocus.hasFocus || _query.trim().isNotEmpty || _submittedQuery.isNotEmpty;

  bool get _showTypeahead =>
      _searchFocus.hasFocus ||
      (_query.trim().isNotEmpty && _submittedQuery != _query.trim());

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel('search_closed');
    _searchController.clear();
    _searchFocus.unfocus();
    final hadSubmitted = _submittedQuery.isNotEmpty ||
        ref.read(spotDiscoveryProvider).activeQuery.isNotEmpty;
    setState(() {
      _query = '';
      _submittedQuery = '';
      _remoteSearchHits = const [];
      _visibleCount = 10;
    });
    if (hadSubmitted) {
      unawaited(ref.read(spotDiscoveryProvider.notifier).load(refresh: true));
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel('query_changed');
    setState(() {
      _query = value;
      _submittedQuery = '';
      if (value.trim().length < 2) {
        _remoteSearchHits = const [];
      }
    });
    final trimmed = value.trim();
    if (trimmed.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_runTypeahead(trimmed));
    });
  }

  Future<void> _runTypeahead(String q) async {
    final token = CancelToken();
    _searchCancelToken = token;
    try {
      final hits = await ref
          .read(spotDiscoveryProvider.notifier)
          .searchTypeahead(q, limit: 15, cancelToken: token);
      if (!mounted || token.isCancelled || _query.trim() != q) return;
      setState(() => _remoteSearchHits = hits);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
    } catch (_) {}
  }

  void _submitSearch([String? value]) {
    final submitted = (value ?? _query).trim();
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel('submitted');
    _rememberQuery();
    _searchFocus.unfocus();
    setState(() {
      _submittedQuery = submitted;
      _visibleCount = 10;
    });
    if (submitted.isNotEmpty) {
      unawaited(
        ref.read(spotDiscoveryProvider.notifier).load(
              query: submitted,
              refresh: true,
            ),
      );
    }
  }

  void _setQuery(String q) {
    _searchController.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    _onSearchChanged(q);
  }

  void _rememberQuery() =>
      ref.read(recentSearchesProvider.notifier).add(_query);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(spotDiscoveryProvider.notifier).initialize();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(spotDiscoveryProvider.notifier).flushImpressions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel('disposed');
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyForSpot(String spotId) =>
      _cardKeys.putIfAbsent(spotId, () => GlobalKey());

  void _checkVisibleCards() {
    if (!mounted) return;
    final notifier = ref.read(spotDiscoveryProvider.notifier);
    final mq = MediaQuery.of(context);
    final viewTop = mq.padding.top;
    final viewBottom = mq.size.height - mq.padding.bottom;

    final staleIds =
        _cardKeys.keys.where((id) => !_activeCardIds.contains(id)).toList();
    for (final id in staleIds) {
      notifier.reportCardVisibility(id, 0);
      _cardKeys.remove(id);
    }

    for (final spotId in _activeCardIds) {
      final ctx = _cardKeys[spotId]?.currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize || ro.size.height <= 0) {
        notifier.reportCardVisibility(spotId, 0);
        continue;
      }
      final top = ro.localToGlobal(Offset.zero).dy;
      final bottom = top + ro.size.height;
      final visiblePx = (math.min(bottom, viewBottom) - math.max(top, viewTop))
          .clamp(0.0, ro.size.height);
      notifier.reportCardVisibility(spotId, visiblePx / ro.size.height);
    }
  }

  void _onScroll() {
    _checkVisibleCards();
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final discovery = ref.read(spotDiscoveryProvider);
      if (_visibleCount < _totalOrdinaryCount) {
        setState(() {
          _visibleCount += 10;
        });
        if (_visibleCount + 10 >= _totalOrdinaryCount &&
            discovery.nextCursor != null) {
          unawaited(ref.read(spotDiscoveryProvider.notifier).loadMore());
        }
      } else if (discovery.nextCursor != null) {
        unawaited(ref.read(spotDiscoveryProvider.notifier).loadMore());
      }
    }
  }

  Future<void> _load({bool refresh = false}) async {
    await Future.wait([
      ref
          .read(spotDiscoveryProvider.notifier)
          .load(query: _submittedQuery, refresh: refresh),
      if (refresh) ref.refresh(choiceSpotlightProvider.future),
      if (refresh)
        ref.refresh(hiddenGemProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotDiscoveryProvider);
    final spotlight = ref.watch(choiceSpotlightProvider).valueOrNull;
    final spots = withoutTestContent(
      state.spots,
      (spot) => spot.isTest,
      showTest: ref.watch(showTestContentProvider),
    );

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);

          // 1. Initial extraction of categories & towns from all spots

          // 2. Apply combined category and municipality filtering
          final visibleSpots = _filterState.apply(spots);

          // 3. Featured Destination: first ordinary spot with a photo
          SpotModel? topHeroSpot;
          for (final s in visibleSpots) {
            if (s.imageUrl != null && s.imageUrl!.trim().isNotEmpty) {
              topHeroSpot = s;
              break;
            }
          }

          // 4. JuanChoice In-Feed Placement Planning
          final spotlightPlacement = planJuanChoicePlacement<SpotModel>(
            spots: visibleSpots,
            idOf: (s) => s.id,
            spotlight: spotlight,
          );

          // Plan 75m: the featured spot is not repeated right under itself.
          final ordinarySpots = spotlightPlacement.ordinary
              .where((s) => s.id != topHeroSpot?.id)
              .toList();
          _totalOrdinaryCount = ordinarySpots.length;
          final pagedSpots = ordinarySpots.take(_visibleCount).toList();
          _activeCardIds
            ..clear()
            ..addAll([
              if (topHeroSpot != null) topHeroSpot.id,
              for (final s in pagedSpots) s.id,
            ]);
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibleCards());
          final hasMore = _visibleCount < ordinarySpots.length ||
              state.nextCursor != null ||
              state.isLoadingMore;

          final winnerSpots = spotlight == null
              ? const <SpotModel>[]
              : spots
                  .where((s) => spotlight.winnerSpotIds.contains(s.id))
                  .toList();

          // Badge signals: today's hidden gems and towns with a festival
          // this month.
          final gemIds = <String>{
            for (final g
                in ref.watch(hiddenGemProvider).valueOrNull ?? const [])
              g.id,
          };
          final today = DateTime.now();
          // Festivals only (dated ones from staff, plus the verified
          // month-only list); not the whole Home calendar.
          final fiestaTowns = <String>{
            for (final e in [
              ...ref.watch(festivalCalendarProvider(today.year)).valueOrNull ??
                  const <HomeCalendarEntry>[],
              ...ref.watch(homeFestivalEntriesProvider(today.year)),
            ])
              if (e.municipality.isNotEmpty &&
                  e.spansMonth(today.year, today.month))
                normalizeTown(e.municipality),
          };

          // Back closes the search first.
          return PopScope(
            canPop: !_searching,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _closeSearch();
            },
            child: PageTutorialHost(
              page: TutorialPage.explore,
              stepsBuilder: (ctx) =>
                  buildPageTutorialSteps(ctx, TutorialPage.explore),
              child: Scaffold(
                backgroundColor: PixelPalette.paper,
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(PixelAppBar.heightOf(context)),
                  child: PixelAppBar(
                    title: 'Explore',
                    isTab: true,
                    actions: [
                      const TutorialHelpButton(page: TutorialPage.explore),
                      SizedBox(width: grid.px(2)),
                      // Search is the open box under the bar (owner 2026-11-16).
                      // Owner 2026-11-16: Saved sits right of Search (the Map
                      // moved to the main menu).
                      PixelIconButton(
                        key: const ValueKey('explore_appbar_saved'),
                        icon: ExploreArt.bookmarkSaved,
                        semanticLabel: 'Saved places',
                        style: PixelBoxStyle.parchment,
                        iconHeight: 24,
                        onPressed: () => context.push('/saved'),
                      ),
                    ],
                  ),
                ),
              body: // Owner 2026-11-17: a faint fade on Explore ("too distracting").
                  PixelPanelTexture(
                strength: 0.35,
                child: RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  color: PixelPalette.green,
                  backgroundColor: PixelPalette.paper,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Owner 2026-11-16: more side margin on Explore posts.
                    padding: EdgeInsets.symmetric(
                      horizontal: grid.gutter,
                      vertical: grid.px(2),
                    ),
                    children: [
                      ExploreSearchBar(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        active: _searching,
                        onChanged: _onSearchChanged,
                        onSubmitted: _submitSearch,
                        onClose: _closeSearch,
                      ),
                      SizedBox(height: grid.px(3)),
                      if (_showTypeahead)
                        ExploreSearchResults(
                          query: _query,
                          spots: state.spots,
                          remoteHits: _remoteSearchHits,
                          recent: ref.watch(recentSearchesProvider),
                          onPickRecent: _setQuery,
                          onRemoveRecent: (q) => ref
                              .read(recentSearchesProvider.notifier)
                              .remove(q),
                          onClearRecent: () =>
                              ref.read(recentSearchesProvider.notifier).clear(),
                          onOpenSpot: (spot) {
                            _rememberQuery();
                            _searchFocus.unfocus();
                            context.push('/explore/${spot.slug}', extra: spot);
                          },
                          onMoreFilters: () {
                            _rememberQuery();
                            context.push(
                                '/search?q=${Uri.encodeQueryComponent(_query.trim())}');
                          },
                        )
                      else ...[
                        // App-only blocks preserved in order
                        // Offline Fallback Banner
                        if (state.isOfflineFallback) ...[
                          PixelPanel(
                            style: PixelBoxStyle.gold
                                .copyWith(corner: 2, shadowPx: 0),
                            padding: 2,
                            child: Text(
                              'OFFLINE MODE • VIEWING CACHED DESTINATIONS FROM DEVICE STORAGE. CONNECT TO REFRESH.',
                              style: PixelType.small(context,
                                  color: PixelPalette.ink),
                            ),
                          ),
                          SizedBox(height: grid.px(2)),
                        ],

                        // Owner 2026-11-18: new quests at the very top.
                        const NewQuestsStrip(),

                        // Hidden gem + featured destination, one row, two columns
                        // (owner 2026-11-16).
                        if (topHeroSpot != null)
                          KeyedSubtree(
                            key: _keyForSpot(topHeroSpot.id),
                            child: ExploreSpotlightRow(featured: topHeroSpot),
                          )
                        else
                          const ExploreSpotlightRow(featured: null),

                        // Loading State
                        if (state.isInitialLoading && state.spots.isEmpty)
                          _buildLoadingSkeleton(context, grid)

                        // Error State
                        else if (state.failure != null && state.spots.isEmpty)
                          _buildErrorCard(context, grid, state.failure!.message)

                        // Empty State
                        else if (visibleSpots.isEmpty &&
                            !spotlightPlacement.hasSpotlight)
                          _buildEmptyCard(context, grid)

                        // Feed Stream List
                        else ...[
                          // Feed Cards + JuanChoice Insertion
                          for (var i = 0; i < pagedSpots.length; i++) ...[
                            if (spotlightPlacement.hasSpotlight &&
                                spotlightPlacement.insertionIndex == i) ...[
                              ExploreJuanChoiceCard(
                                spotlight: spotlightPlacement.spotlight!,
                                winnerSpots: winnerSpots,
                                onTapWinner: (winner) => context.push(
                                  '/explore/${winner.slug}',
                                  extra: winner,
                                ),
                                onSeeResults: () => context.push('/choice'),
                              ),
                              SizedBox(height: grid.px(2)),
                            ],
                            ExploreSpotCard(
                              key: _keyForSpot(pagedSpots[i].id),
                              badges: exploreBadgesFor(
                                pagedSpots[i],
                                gemIds: gemIds,
                                fiestaTowns: fiestaTowns,
                              ),
                              spot: pagedSpots[i],
                              likeCount: pagedSpots[i].likeCount,
                              isLiked: pagedSpots[i].liked,
                              isSaved: pagedSpots[i].saved,
                              onTapCard: () => context.push(
                                '/explore/${pagedSpots[i].slug}',
                                extra: pagedSpots[i],
                              ),
                              onToggleLike: () => ref
                                  .read(spotDiscoveryProvider.notifier)
                                  .toggleLiked(pagedSpots[i]),
                              onDoubleTapLike: () => ref
                                  .read(spotDiscoveryProvider.notifier)
                                  .setLiked(pagedSpots[i], liked: true),
                              onToggleSave: () => ref
                                  .read(spotDiscoveryProvider.notifier)
                                  .toggleSaved(pagedSpots[i]),
                              onPlayQuest: pagedSpots[i].questId != null &&
                                      pagedSpots[i].questId!.trim().isNotEmpty
                                  ? () => context
                                      .push('/quests/${pagedSpots[i].questId}')
                                  : null,
                            ),
                            SizedBox(height: grid.px(4)),
                          ],

                          // End-of-feed JuanChoice insertion if insertion index is at or beyond pagedSpots length
                          if (spotlightPlacement.hasSpotlight &&
                              spotlightPlacement.insertionIndex >=
                                  pagedSpots.length) ...[
                            ExploreJuanChoiceCard(
                              spotlight: spotlightPlacement.spotlight!,
                              winnerSpots: winnerSpots,
                              onTapWinner: (winner) => context.push(
                                '/explore/${winner.slug}',
                                extra: winner,
                              ),
                              onSeeResults: () => context.push('/choice'),
                            ),
                            SizedBox(height: grid.px(2)),
                          ],

                          // Paging Controls
                          _buildPagingFooter(
                              context, grid, hasMore, state.failure != null),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagingFooter(
    BuildContext context,
    PixelGrid grid,
    bool hasMore,
    bool hasError,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: grid.px(2)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasError) ...[
            Text(
              'Failed to load posts. Please try again.',
              style: PixelType.small(context, color: PixelPalette.red),
            ),
            SizedBox(height: grid.px(1)),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: PixelButton(
                  label: 'TRY AGAIN',
                  variant: PixelButtonVariant.secondary,
                  style: PixelBoxStyle.parchment,
                  onPressed: () => _load(refresh: true),
                ),
              ),
            ),
          ] else if (hasMore) ...[
            Padding(
              key: const ValueKey('explore_paging_loader'),
              padding: EdgeInsets.symmetric(vertical: grid.px(1)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PixelPalette.gold,
                    ),
                  ),
                  SizedBox(width: grid.px(1)),
                  Text(
                    'Loading more spots…',
                    style: PixelType.small(context, color: PixelPalette.stone),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              "You're caught up. Checking for new posts…",
              style: PixelType.small(context, color: PixelPalette.stone),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context, PixelGrid grid) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(child: PixelLoader()),
        SizedBox(height: grid.px(2)),
        for (var i = 0; i < 2; i++) ...[
          PixelPanel(
            style: PixelBoxStyle.parchment.copyWith(corner: 2, shadowPx: 1),
            padding: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: grid.px(3),
                    width: 120,
                    color: PixelPalette.paperDim),
                SizedBox(height: grid.px(2)),
                Container(
                    height: grid.px(4),
                    width: double.infinity,
                    color: PixelPalette.paperDim),
                SizedBox(height: grid.px(2)),
                Container(
                    height: 120,
                    width: double.infinity,
                    color: PixelPalette.paperDim),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context, PixelGrid grid, String message) {
    return PixelPanel(
      style: PixelBoxStyle.parchment.copyWith(corner: 2, shadowPx: 1),
      padding: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadowText(
            'Failed to load feed',
            style: PixelType.title(context, color: PixelPalette.red),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            message,
            style: PixelType.body(context, color: PixelPalette.slate),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: grid.px(2)),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: PixelButton(
                label: 'TRY AGAIN',
                variant: PixelButtonVariant.primary,
                style: PixelBoxStyle.green,
                onPressed: () => _load(refresh: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.parchment.copyWith(corner: 2, shadowPx: 1),
      padding: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadowText(
            'No destinations found in feed',
            style: PixelType.title(context, color: PixelPalette.ink),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'The community feed could not find active destinations matching your filter.',
            style: PixelType.body(context, color: PixelPalette.slate),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: grid.px(2)),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: PixelButton(
                label: 'RESET & REFRESH FEED',
                variant: PixelButtonVariant.secondary,
                style: PixelBoxStyle.parchment,
                onPressed: () {
                  _searchDebounce?.cancel();
                  _searchCancelToken?.cancel('reset');
                  _searchController.clear();
                  setState(() {
                    _filterState = _filterState.reset();
                    _query = '';
                    _submittedQuery = '';
                    _remoteSearchHits = const [];
                    _visibleCount = 10;
                  });
                  _load(refresh: true);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
