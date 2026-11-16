import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/dev/test_content.dart';
import '../../../core/theme/app_theme.dart';
import '../../juanchoice/providers/juanchoice_provider.dart';
import '../explore/explore_art.dart';
import '../explore/juanchoice_placement.dart';
import '../explore/spot_filter_state.dart';
import '../explore/widgets/explore_featured_card.dart';
import '../explore/widgets/explore_juanchoice_card.dart';
import '../explore/widgets/explore_spot_card.dart';
import '../models/spot_model.dart';
import '../providers/hidden_gem_provider.dart';
import '../providers/spot_discovery_provider.dart';
import '../widgets/hidden_gem_card.dart';

class SpotExploreScreen extends ConsumerStatefulWidget {
  const SpotExploreScreen({super.key});

  @override
  ConsumerState<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends ConsumerState<SpotExploreScreen> {
  final ScrollController _scrollController = ScrollController();
  SpotFilterState _filterState = const SpotFilterState();
  int _visibleCount = 10;
  int _totalOrdinaryCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(spotDiscoveryProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        _visibleCount < _totalOrdinaryCount) {
      setState(() {
        _visibleCount += 10;
      });
    }
  }

  Future<void> _load({bool refresh = false}) async {
    await Future.wait([
      ref.read(spotDiscoveryProvider.notifier).load(refresh: refresh),
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
          final hasMore = _visibleCount < ordinarySpots.length;

          final winnerSpots = spotlight == null
              ? const <SpotModel>[]
              : spots
                  .where((s) => spotlight.winnerSpotIds.contains(s.id))
                  .toList();

          return Scaffold(
            backgroundColor: PixelPalette.paper,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: PixelAppBar(
                title: 'Explore',
                isTab: true,
                actions: [
                  PixelIconButton(
                    icon: DesignerArt.search,
                    semanticLabel: 'Search & Filters',
                    style: PixelBoxStyle.parchment,
                    iconHeight: 24,
                    onPressed: () => context.push('/search'),
                  ),
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
            body: RefreshIndicator(
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
                  // App-only blocks preserved in order
                  // Offline Fallback Banner
                  if (state.isOfflineFallback) ...[
                    PixelPanel(
                      style:
                          PixelBoxStyle.gold.copyWith(corner: 2, shadowPx: 0),
                      padding: 2,
                      child: Text(
                        'OFFLINE MODE • VIEWING CACHED DESTINATIONS FROM DEVICE STORAGE. CONNECT TO REFRESH.',
                        style:
                            PixelType.small(context, color: PixelPalette.ink),
                      ),
                    ),
                    SizedBox(height: grid.px(2)),
                  ],

                  // Personalized Hidden Gem (hero #1 at the top of feed)
                  const HiddenGemCard(),
                  SizedBox(height: grid.px(2)),

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
                    // Featured Destination (Hero card with real photo)
                    if (topHeroSpot != null) ...[
                      ExploreFeaturedCard(
                        spot: topHeroSpot,
                        onTap: () => context.push(
                          '/explore/${topHeroSpot!.slug}',
                          extra: topHeroSpot,
                        ),
                      ),
                      SizedBox(height: grid.px(2)),
                    ],

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
                          onSeeResults: () => context.push('/juanchoice'),
                        ),
                        SizedBox(height: grid.px(2)),
                      ],
                      ExploreSpotCard(
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
                            ? () =>
                                context.push('/quests/${pagedSpots[i].questId}')
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
                        onSeeResults: () => context.push('/juanchoice'),
                      ),
                      SizedBox(height: grid.px(2)),
                    ],

                    // Paging Controls
                    _buildPagingFooter(
                        context, grid, hasMore, state.failure != null),
                  ],
                ],
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
            style: PixelType.title(context, color: PixelPalette.wood),
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
                  setState(() {
                    _filterState = _filterState.reset();
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
