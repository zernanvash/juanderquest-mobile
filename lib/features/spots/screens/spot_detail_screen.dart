import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';
import '../theater/theater_about_section.dart';
import '../theater/theater_chapters.dart';
import '../theater/theater_nearby_section.dart';
import '../theater/theater_overview_section.dart';
import '../theater/theater_panel.dart';
import '../theater/theater_still_photo.dart';
import '../theater/theater_title_block.dart';
import '../theater/theater_venue_section.dart';
import '../widgets/spot_community_section.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  final SpotModel spot;
  const SpotDetailScreen({super.key, required this.spot});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  late final ScrollController _scrollController;
  List<SpotModel> _alternatives = [];
  bool _loadingAlternatives = true;
  bool _isSaved = false;

  SpotTheaterChapter _currentChapter = SpotTheaterChapter.overview;
  double _readingProgress = 0.0;
  double _scrollOffset = 0.0;

  final _overviewKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _notesKey = GlobalKey();
  final _venueKey = GlobalKey();
  final _nearbyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isSaved = widget.spot.saved;
    _scrollController = ScrollController()..addListener(_onScroll);

    Future.microtask(() {
      _loadAlternatives();
      _logInteraction('view');
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final maxScroll = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 1.0;
    final progress = maxScroll > 0 ? (offset / maxScroll).clamp(0.0, 1.0) : 0.0;

    // Scroll-spy to determine the active chapter
    SpotTheaterChapter active = _currentChapter;
    final available =
        SpotTheaterChapter.getAvailable(hasAlternatives: _alternatives.isNotEmpty);

    double getSectionTop(GlobalKey key) {
      final ctx = key.currentContext;
      if (ctx == null) return double.infinity;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return double.infinity;
      return box.localToGlobal(Offset.zero).dy;
    }

    const barThreshold = 180.0;
    if (available.contains(SpotTheaterChapter.nearby) &&
        getSectionTop(_nearbyKey) <= barThreshold) {
      active = SpotTheaterChapter.nearby;
    } else if (getSectionTop(_venueKey) <= barThreshold) {
      active = SpotTheaterChapter.venue;
    } else if (getSectionTop(_notesKey) <= barThreshold) {
      active = SpotTheaterChapter.notes;
    } else if (getSectionTop(_aboutKey) <= barThreshold) {
      active = SpotTheaterChapter.about;
    } else {
      active = SpotTheaterChapter.overview;
    }

    final offsetCrossed10 = (_scrollOffset < 10 && offset >= 10) ||
        (_scrollOffset >= 10 && offset < 10);
    final progressChanged = (_readingProgress - progress).abs() > 0.01;
    final chapterChanged = active != _currentChapter;

    if (offsetCrossed10 || progressChanged || chapterChanged) {
      setState(() {
        _scrollOffset = offset;
        _readingProgress = progress;
        _currentChapter = active;
      });
    }
  }

  void _scrollToChapter(SpotTheaterChapter chapter) {
    GlobalKey? targetKey;
    switch (chapter) {
      case SpotTheaterChapter.overview:
        targetKey = _overviewKey;
        break;
      case SpotTheaterChapter.about:
        targetKey = _aboutKey;
        break;
      case SpotTheaterChapter.notes:
        targetKey = _notesKey;
        break;
      case SpotTheaterChapter.venue:
        targetKey = _venueKey;
        break;
      case SpotTheaterChapter.nearby:
        targetKey = _nearbyKey;
        break;
    }

    final ctx = targetKey.currentContext;
    if (ctx != null) {
      // Stepped jump with zero duration (stepped motion rule)
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: Duration.zero,
      );
    }
  }

  Future<void> _logInteraction(String type) async {
    try {
      await ref.read(apiClientProvider).dio.post(
        '/spots/${widget.spot.id}/interactions',
        data: {'type': type},
      );
    } catch (_) {}
  }

  Future<void> _loadAlternatives() async {
    try {
      final response = await ref.read(apiClientProvider).dio.get(
        '/spots/${widget.spot.slug}/alternatives',
      );
      if (mounted && response.statusCode == 200 && response.data['data'] is List) {
        setState(() {
          _alternatives = (response.data['data'] as List)
              .map((item) => SpotModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingAlternatives = false);
      }
    }
  }

  Future<void> _toggleSaved() async {
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);
    final failure = await ref
        .read(spotDiscoveryProvider.notifier)
        .toggleSaved(widget.spot.copyWith(saved: wasSaved));
    if (!mounted) return;
    if (failure != null) setState(() => _isSaved = wasSaved);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: PixelPalette.ink,
        content: Text(
          failure?.message ??
              (_isSaved
                  ? 'Added "${widget.spot.name}" to saved places.'
                  : 'Removed from saved places.'),
          style: const TextStyle(color: PixelPalette.paper),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareSpot() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: PixelPalette.ink,
        content: Text(
          'Share link copied: https://juanderquest.app/spots/${widget.spot.slug}',
          style: const TextStyle(color: PixelPalette.paper),
        ),
      ),
    );
  }

  Future<void> _openDirections() async {
    await _logInteraction('directions');
    final spot = widget.spot;
    if (!mounted) return;
    try {
      context.push(
        '/navigate?lat=${spot.gpsLat}&lng=${spot.gpsLng}&name=${Uri.encodeComponent(spot.name)}&address=${Uri.encodeComponent(spot.address.isNotEmpty ? spot.address : spot.municipality)}',
      );
    } catch (_) {}
  }

  void _playQuest() {
    if (widget.spot.questId != null) {
      try {
        context.push('/quests/${widget.spot.questId}');
      } catch (_) {}
    }
  }

  bool _isSpotAuthor(WidgetRef ref, SpotModel spot) {
    final user = ref.watch(authProvider).user;
    if (user == null) return false;
    return spot.createdBy != null && spot.createdBy == user.id;
  }

  Future<void> _openReportSheet() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpotReportSheet(
        spotName: widget.spot.name,
        onSubmit: (reason, details) async {
          await ref.read(apiClientProvider).dio.post(
            '/spots/${widget.spot.id}/reports',
            data: {
              'reason': reason,
              if (details.isNotEmpty) 'details': details,
            },
          );
        },
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: PixelPalette.ink,
          content: Text(
            'Thanks. Our moderators will check this destination.',
            style: TextStyle(color: PixelPalette.paper),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final isAuthor = _isSpotAuthor(ref, spot);
    final hasAlternatives = _alternatives.isNotEmpty;

    return PixelScope(
      settings: const PixelSettings(),
      child: Theme(
        data: AppTheme.pixel,
        child: Scaffold(
          backgroundColor: PixelPalette.ink,
          body: Stack(
            children: [
              // 1. Stationary background photo layer: never scrolls, pans or zooms
              Positioned.fill(
                key: const Key('theater_still_photo'),
                child: SpotStillPhoto(spot: spot),
              ),

              // 2. Story content: scrolls over the stationary photo
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // First Viewport: unobstructed photo, top controls, hero block, scroll hint
                  SliverToBoxAdapter(
                    child: TheaterFirstViewport(
                      spot: spot,
                      isSaved: _isSaved,
                      scrollOffset: _scrollOffset,
                      onToggleSave: _toggleSaved,
                      onShare: _shareSpot,
                      onDirections: _openDirections,
                      onPlayQuest: _playQuest,
                    ),
                  ),

                  // Sticky pixel chapter bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TheaterChapterBarDelegate(
                      currentChapter: _currentChapter,
                      hasAlternatives: hasAlternatives,
                      readingProgress: _readingProgress,
                      onSelectChapter: _scrollToChapter,
                    ),
                  ),

                  // Story content sections with generous spacing revealing photo between panels
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Chapter 1: OVERVIEW
                        Container(
                          key: _overviewKey,
                          child: TheaterOverviewSection(
                            spot: spot,
                            isAuthor: isAuthor,
                            onPlayQuest: _playQuest,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Chapter 2: ABOUT
                        Container(
                          key: _aboutKey,
                          child: TheaterAboutSection(spot: spot),
                        ),
                        const SizedBox(height: 28),

                        // Chapter 3: NOTES
                        Container(
                          key: _notesKey,
                          child: SpotCommunitySection(
                            spotId: spot.id,
                            spotName: spot.name,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Chapter 4: VENUE & MAP
                        Container(
                          key: _venueKey,
                          child: TheaterVenueSection(
                            spot: spot,
                            onDirections: _openDirections,
                          ),
                        ),

                        // Chapter 5: NEARBY (only when alternatives exist)
                        if (hasAlternatives) ...[
                          const SizedBox(height: 28),
                          Container(
                            key: _nearbyKey,
                            child: TheaterNearbySection(
                              alternatives: _alternatives,
                              isLoading: _loadingAlternatives,
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // End panel: photo credit, report problem, safe area
                        _buildEndPanel(context, spot),

                        SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + 24,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndPanel(BuildContext context, SpotModel spot) {
    final grid = PixelGrid.of(context);

    return TheaterPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JuanDerQuest destination story',
            style: PixelType.small(context, color: PixelPalette.mist),
          ),
          if (spot.sourceName.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Photography & curation: ${spot.sourceName}',
              style: PixelType.small(context, color: PixelPalette.paperDim),
            ),
          ],
          SizedBox(height: grid.px(2)),
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  key: const Key('theater_end_report_btn'),
                  label: 'Report a problem',
                  variant: PixelButtonVariant.ghost,
                  expand: true,
                  onPressed: _openReportSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TheaterChapterBarDelegate extends SliverPersistentHeaderDelegate {
  _TheaterChapterBarDelegate({
    required this.currentChapter,
    required this.hasAlternatives,
    required this.readingProgress,
    required this.onSelectChapter,
  });

  final SpotTheaterChapter currentChapter;
  final bool hasAlternatives;
  final double readingProgress;
  final ValueChanged<SpotTheaterChapter> onSelectChapter;

  @override
  double get minExtent => 56.0;

  @override
  double get maxExtent => 56.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return TheaterChapterBar(
      currentChapter: currentChapter,
      hasAlternatives: hasAlternatives,
      readingProgress: readingProgress,
      onSelectChapter: onSelectChapter,
    );
  }

  @override
  bool shouldRebuild(_TheaterChapterBarDelegate oldDelegate) =>
      oldDelegate.currentChapter != currentChapter ||
      oldDelegate.hasAlternatives != hasAlternatives ||
      oldDelegate.readingProgress != readingProgress;
}
