import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../quests/providers/quest_provider.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';
import '../theater/theater_coming_soon_section.dart';
import '../theater/theater_about_section.dart';
import '../explore/explore_art.dart';
import '../theater/theater_backdrop.dart';
import '../theater/theater_badges_status_section.dart';
import '../theater/theater_gallery_dialog.dart';
import '../theater/theater_nearby_section.dart';
import '../theater/theater_panel.dart';
import '../theater/theater_quest_picker_sheet.dart';
import '../theater/theater_still_photo.dart';
import '../studio/pixel/studio_icons.dart';
import '../theater/theater_title_block.dart';
import '../theater/theater_venue_section.dart';
import '../widgets/spot_community_section.dart';
import '../widgets/spot_like_heart.dart';

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
  bool _isLiked = false;
  int _likeCount = 0;

  // Plan 75m: scroll state lives in notifiers so scrolling rebuilds only the
  // scroll hint and the backdrop fade, never the whole page.
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);

  /// 0 at the top of the page, 1 once the details cover most of the screen.
  final ValueNotifier<double> _reveal = ValueNotifier(0.0);

  /// Plan 98: the photo the page settled on after skipping broken ones; null
  /// when none loaded (shorter header + "no photo" badge).
  late final ValueNotifier<String?> _photoUrl =
      ValueNotifier(SpotStillPhoto.urlFor(widget.spot));

  @override
  void initState() {
    super.initState();
    _isSaved = widget.spot.saved;
    _isLiked = widget.spot.liked;
    _likeCount = widget.spot.likeCount;
    _scrollController = ScrollController()..addListener(_onScroll);

    Future.microtask(() {
      _loadAlternatives();
      _logInteraction('view');
      if (!mounted) return;
      final qState = ref.read(questProvider);
      if (qState.quests.isEmpty && !qState.isLoading) {
        ref.read(questProvider.notifier).fetchQuests();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrolled.dispose();
    _reveal.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    _scrolled.value = offset >= 10;
    final viewport = _scrollController.position.viewportDimension;
    final span = viewport * 0.6;
    final reveal = span > 0 ? (offset / span).clamp(0.0, 1.0) : 0.0;
    if ((_reveal.value - reveal).abs() > 0.02 || reveal == 0 || reveal == 1) {
      _reveal.value = reveal;
    }
  }

  Future<void> _logInteraction(String type) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/spots/${widget.spot.id}/interactions', data: {'type': type});
    } catch (_) {}
  }

  Future<void> _loadAlternatives() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/spots/${widget.spot.slug}/alternatives');
      if (mounted &&
          response.statusCode == 200 &&
          response.data['data'] is List) {
        setState(() {
          _alternatives = (response.data['data'] as List)
              .map(
                (item) => SpotModel.fromJson(Map<String, dynamic>.from(item)),
              )
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

  /// Plan 93b WP-13: the heart is Like (not Save) and shares state with
  /// Explore and Search through [spotDiscoveryProvider].
  Future<void> _setLiked(bool liked) async {
    if (_isLiked == liked) return;
    final before = widget.spot.copyWith(liked: _isLiked, likeCount: _likeCount);
    final wasCount = _likeCount;
    setState(() {
      _isLiked = liked;
      _likeCount = (_likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
    });
    final notifier = ref.read(spotDiscoveryProvider.notifier);
    final failure = await notifier.setLiked(before, liked: liked);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _isLiked = !liked;
        _likeCount = wasCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: PixelPalette.ink,
          content: Text(
            failure.message,
            style: const TextStyle(color: PixelPalette.paper),
          ),
        ),
      );
      return;
    }
    final live = notifier.current(before);
    if (live.liked == _isLiked && live.likeCount != _likeCount) {
      setState(() => _likeCount = live.likeCount);
    }
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

  void _addPhoto() {
    showPixelToast(
      context,
      'Adding photos to a place is coming soon.',
    );
  }

  void _playQuest(String questId) {
    try {
      context.push('/quests/$questId');
    } catch (_) {}
  }

  void _openQuestPicker(List<SpotQuestMatch> matches) {
    final spot = widget.spot;
    final signedIn = ref.read(authProvider).user != null;
    final canCreateQuest = signedIn && spot.slug.isNotEmpty;
    TheaterQuestPickerSheet.show(
      context,
      spot: spot,
      matches: matches,
      canCreateQuest: canCreateQuest,
      onPlayQuest: _playQuest,
      onCreateQuest: () {
        try {
          context.push('/explore/${spot.slug}/quests/new', extra: spot);
        } catch (_) {}
      },
    );
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
    final hasAlternatives = _alternatives.isNotEmpty;
    final quests = ref.watch(questProvider).quests;
    final showTest = ref.watch(showTestContentProvider);
    final questMatches = matchSpotQuests(spot, quests, showTest: showTest);

    // The app-wide PixelScope applies (it carries the traveler's text size);
    // this page used to override it with defaults.
    return Theme(
      data: AppTheme.pixel,
      child: Scaffold(
        backgroundColor: PixelPalette.ink,
        body: Stack(
          children: [
            // 1. Stationary background photo layer: never scrolls, pans or zooms
            Positioned.fill(
              key: const Key('theater_still_photo'),
              child: RepaintBoundary(
                child: SpotStillPhoto(
                  spot: spot,
                  onPhotoChanged: (url) => _photoUrl.value = url,
                ),
              ),
            ),

            // 1b. Stationary scrims + the Pixel-lab backdrop treatment.
            Positioned.fill(
              child: ValueListenableBuilder<String?>(
                valueListenable: _photoUrl,
                builder: (context, photoUrl, _) => TheaterBackdropLayers(
                  spot: spot,
                  reveal: _reveal,
                  photoUrl: photoUrl,
                ),
              ),
            ),

            // 2. Story content: scrolls over the stationary photo.
            //    Double-tap anywhere pops a heart.
            TheaterDoubleTapHearts(
              onDoubleTapLike: () => _setLiked(true),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // First Viewport: unobstructed photo, top controls, hero block, scroll hint
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<String?>(
                      valueListenable: _photoUrl,
                      builder: (context, photoUrl, _) =>
                          ValueListenableBuilder<bool>(
                        valueListenable: _scrolled,
                        builder: (context, scrolled, _) => TheaterFirstViewport(
                          spot: spot,
                          // Only whether the page has left the top matters here.
                          scrollOffset: scrolled ? 10 : 0,
                          onDirections: _openDirections,
                          onPlayQuest: () => _openQuestPicker(questMatches),
                          onAddPhoto: _addPhoto,
                          hasQuests: questMatches.isNotEmpty,
                          hasPhoto: photoUrl != null,
                        ),
                      ),
                    ),
                  ),

                  // Story content sections with generous spacing revealing photo between panels
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Chapter 1: BADGES & CROWD STATUS
                        TheaterBadgesStatusSection(spot: spot),
                        const SizedBox(height: 28),

                        // Chapter 2: ABOUT
                        TheaterAboutSection(spot: spot),
                        const SizedBox(height: 28),

                        // Chapter 3: NOTES
                        SpotCommunitySection(
                          spotId: spot.id,
                          spotName: spot.name,
                        ),
                        const SizedBox(height: 28),

                        // Chapter 4: VENUE & MAP
                        TheaterVenueSection(
                          spot: spot,
                          onDirections: _openDirections,
                        ),

                        // Chapter 4b: COMING SOON (owner, Plan 101)
                        const SizedBox(height: 28),
                        const TheaterComingSoonSection(),

                        // Chapter 5: NEARBY (only when alternatives exist)
                        if (hasAlternatives) ...[
                          const SizedBox(height: 28),
                          TheaterNearbySection(
                            alternatives: _alternatives,
                            isLoading: _loadingAlternatives,
                          ),
                        ],

                        const SizedBox(height: 28),

                        // End panel: photo credit and safe area (Report is in the top bar)
                        _buildEndPanel(context, spot),

                        SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + 24,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            // Plan 93b WP-11: the top bar is always on screen.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final actions = <Widget>[
                    if (spot.media.isNotEmpty)
                      PixelIconButton(
                        key: const Key('theater_gallery_btn'),
                        icon: StudioIcons.gallery,
                        semanticLabel: 'Open photo gallery',
                        iconHeight: 20,
                        onPressed: () => TheaterGalleryDialog.show(
                          context,
                          media: spot.media,
                        ),
                      ),
                    SpotLikeBarButton(
                      key: const Key('theater_like_btn'),
                      liked: _isLiked,
                      semanticLabel: _isLiked
                          ? 'Unlike spot ($_likeCount likes)'
                          : 'Like spot ($_likeCount likes)',
                      iconHeight: 20,
                      onPressed: () => _setLiked(!_isLiked),
                    ),
                    PixelIconButton(
                      key: const Key('theater_save_btn'),
                      icon: _isSaved
                          ? ExploreArt.bookmarkSaved
                          : ExploreArt.bookmarkUnsaved,
                      semanticLabel:
                          _isSaved ? 'Remove from saved spots' : 'Save spot',
                      iconHeight: 20,
                      style: _isSaved
                          ? PixelBoxStyle.wood
                          : PixelBoxStyle.parchment,
                      onPressed: _toggleSaved,
                    ),
                    PixelIconButton(
                      key: const Key('theater_share_btn'),
                      icon: StudioIcons.share,
                      semanticLabel: 'Share spot link',
                      iconHeight: 20,
                      onPressed: _shareSpot,
                    ),
                    PixelIconButton(
                      key: const Key('theater_report_btn'),
                      icon: ExploreArt.flag,
                      semanticLabel: 'Report a problem',
                      iconHeight: 20,
                      onPressed: _openReportSheet,
                    ),
                  ];
                  // Narrow phones: the hero block already shows the name, so
                  // the bar drops its title before the buttons get squeezed.
                  final roomForTitle =
                      constraints.maxWidth - (actions.length + 1) * 56 >= 96;
                  return KeyedSubtree(
                    key: const Key('theater_pinned_bar'),
                    child: PixelAppBar(
                      title: roomForTitle ? spot.name : '',
                      onBack: () => Navigator.of(context).maybePop(),
                      actions: actions,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndPanel(BuildContext context, SpotModel spot) {
    final grid = PixelGrid.of(context);
    final sourceName = spotCreditName(spot.sourceName);
    final hasSourceLink =
        spot.sourceUrl != null && spot.sourceUrl!.trim().isNotEmpty;

    return TheaterPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JuanDerQuest destination story',
            style: PixelType.small(context, color: PixelPalette.mist),
          ),
          if (sourceName.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            GestureDetector(
              key: const Key('theater_end_source_link'),
              onTap: hasSourceLink
                  ? () => launchUrlString(spot.sourceUrl!.trim())
                  : null,
              child: Text(
                'Photography & curation: $sourceName',
                style: PixelType.small(
                  context,
                  color: hasSourceLink
                      ? PixelPalette.paper
                      : PixelPalette.paperDim,
                ).copyWith(
                  decoration: hasSourceLink ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
