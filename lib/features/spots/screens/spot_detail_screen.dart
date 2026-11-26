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
import '../../merchant/models/merchant_models.dart';
import '../../merchant/providers/merchant_hub_provider.dart';
import '../../quests/providers/quest_provider.dart';
import '../../suki/widgets/spot_suki_row.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';
import '../theater/theater_coming_soon_section.dart';
import '../theater/theater_about_section.dart';
import '../explore/explore_art.dart';
import '../theater/theater_backdrop.dart';
import '../theater/theater_badges_status_section.dart';
import '../theater/theater_photos_section.dart';
import '../theater/theater_nearby_section.dart';
import '../theater/theater_panel.dart';
import '../theater/theater_quest_picker_sheet.dart';
import '../theater/theater_still_photo.dart';
import '../studio/pixel/studio_icons.dart';
import '../theater/theater_title_block.dart';
import '../theater/theater_venue_section.dart';
import '../widgets/spot_add_photo_sheet.dart';
import '../widgets/spot_cover_picker_sheet.dart';
import '../widgets/spot_community_section.dart';
import '../widgets/spot_like_heart.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  final SpotModel spot;
  const SpotDetailScreen({super.key, required this.spot});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  late SpotModel _spot;
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
  late final ValueNotifier<String?> _photoUrl = ValueNotifier(
    SpotStillPhoto.urlFor(widget.spot),
  );

  @override
  void initState() {
    super.initState();
    _spot = widget.spot;
    _isSaved = _spot.saved;
    _isLiked = _spot.liked;
    _likeCount = _spot.likeCount;
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
  void didUpdateWidget(covariant SpotDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spot != widget.spot) {
      _spot = widget.spot;
      _isSaved = _spot.saved;
      _isLiked = _spot.liked;
      _likeCount = _spot.likeCount;
      _photoUrl.value = SpotStillPhoto.urlFor(_spot);
    }
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

  Future<void> _addPhoto() async {
    if (ref.read(authProvider).user == null) {
      // Review 2026-11-17: /login does not exist; sign in, then come back.
      context.go(
        '/?redirect=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
      );
      return;
    }
    final sent = await SpotAddPhotoSheet.show(context, spot: widget.spot);
    if (sent == true && mounted) {
      showPixelToast(context, 'Sent for review');
    }
  }

  /// Plan 124b: the author (or a platform admin) has an approved photo that
  /// isn't the cover yet.
  bool _canChooseCover(SpotModel spot, String? myId, String? myRole) {
    if (myId == null) return false;
    if (spot.createdBy != myId && myRole != 'admin') return false;
    return spot.coverCandidates.any((c) => c.url != spot.imageUrl);
  }

  Future<void> _chooseCover() async {
    final spot = _spot;
    final url = await SpotCoverPickerSheet.show(
      context,
      candidates: spot.coverCandidates,
      currentUrl: spot.imageUrl,
      onPick: (assetId) async {
        final res = await ref
            .read(apiClientProvider)
            .dio
            .patch('/spots/${spot.id}/cover', data: {'asset_id': assetId});
        final data = res.data is Map ? res.data['data'] : null;
        final raw = data is Map ? data['image_url']?.toString() : null;
        if (raw == null || raw.isEmpty) {
          throw Exception('No cover url returned.');
        }
        return SpotModel.resolveImageUrl(raw);
      },
    );
    if (url == null || !mounted) return;
    // The new cover leads the photos, like the server orders them.
    final media = [
      ...spot.media.where((p) => p.url == url),
      ...spot.media.where((p) => p.url != url),
    ];
    setState(() => _spot = spot.copyWith(imageUrl: url, media: media));
    ref.read(spotDiscoveryProvider.notifier).applyCover(spot.id, url);
    showPixelToast(context, 'Cover photo updated');
  }

  void _playQuest(String questId) {
    try {
      context.push('/quests/$questId');
    } catch (_) {}
  }

  void _openQuestPicker(List<SpotQuestMatch> matches) {
    final spot = _spot;
    final user = ref.read(authProvider).user;
    final isPoster =
        user != null && spot.createdBy != null && spot.createdBy == user.id;
    final isAdmin =
        user != null && (user.role == 'admin' || user.role == 'area_admin');
    final isPosterless = spot.createdBy == null || spot.createdBy!.isEmpty;
    final canCreateQuest =
        spot.slug.isNotEmpty && (isPoster || (isAdmin && isPosterless));
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

  Future<void> _openEditSpot() async {
    try {
      final updated = await context.push<SpotModel>(
        '/explore/${_spot.slug}/edit',
        extra: _spot,
      );
      if (updated != null && mounted) {
        setState(() => _spot = updated);
      }
    } catch (_) {}
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
    final spot = _spot;
    final me = ref.watch(authProvider).user;
    final isAuthor =
        me != null && spot.createdBy != null && spot.createdBy == me.id;
    final merchantStatus =
        isAuthor ? ref.watch(merchantHubStatusProvider).valueOrNull : null;
    final canLinkAsMerchant = isAuthor &&
        spot.localPartner == null &&
        merchantStatus?.state == MerchantHubState.approvedMerchant;
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
                // Owner 2026-11-20: bouncing past the bottom glitched (content springs
                // while the photo stays put). Bounce at the top only; stop at the end.
                physics: const TopBounceScrollPhysics(),
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

                        // Chapter 2b: PHOTOS (owner 2026-11-18): the place to
                        // see this destination's photos; tap for full screen.
                        TheaterPhotosSection(
                          media: spot.media,
                          onAddPhoto: _addPhoto,
                          onChooseCover: _canChooseCover(spot, me?.id, me?.role)
                              ? _chooseCover
                              : null,
                        ),
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

                        // Plan 122a: Local Partner storefront badge & link card
                        if (spot.localPartner != null) ...[
                          const SizedBox(height: 20),
                          _buildLocalPartnerCard(context, spot.localPartner!),
                        ] else if (canLinkAsMerchant) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PixelButton(
                              key: const ValueKey(
                                'spot_detail_link_merchant_btn',
                              ),
                              label: 'Link as my Merchant Hub location',
                              variant: PixelButtonVariant.secondary,
                              onPressed: () {
                                try {
                                  context.push('/merchant/location');
                                } catch (_) {}
                              },
                            ),
                          ),
                        ],

                        // Plan 107: Suki shops at this destination.
                        SpotSukiRow(lat: spot.gpsLat, lng: spot.gpsLng),

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
                    if (isAuthor)
                      PixelButton(
                        key: const Key('theater_edit_btn'),
                        label: '✎ EDIT',
                        variant: PixelButtonVariant.secondary,
                        onPressed: _openEditSpot,
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

  Widget _buildLocalPartnerCard(
    BuildContext context,
    SpotLocalPartner partner,
  ) {
    return PixelPanel(
      key: const ValueKey('spot_detail_local_partner_card'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelPanel(
                key: const ValueKey('spot_detail_local_partner_badge'),
                style: PixelBoxStyle.gold,
                padding: 1,
                child: Text(
                  'LOCAL PARTNER',
                  style: PixelType.small(
                    context,
                    color: PixelPalette.ink,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                partner.category,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            partner.name,
            style: PixelType.title(context, color: PixelPalette.ink),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: PixelButton(
              key: const ValueKey('spot_detail_view_partner_btn'),
              label: 'VIEW PARTNER',
              variant: PixelButtonVariant.primary,
              onPressed: () {
                try {
                  context.push('/merchants/${partner.merchantId}');
                } catch (_) {}
              },
            ),
          ),
        ],
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

/// Bounces when pulled past the top (the backdrop is built for that) but stops
/// dead at the bottom, like Android's clamping physics.
class TopBounceScrollPhysics extends BouncingScrollPhysics {
  const TopBounceScrollPhysics({super.parent});

  @override
  TopBounceScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      TopBounceScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final max = position.maxScrollExtent;
    // Already at/after the end and moving further down: refuse the overscroll.
    if (value > position.pixels && position.pixels >= max) {
      return value - position.pixels;
    }
    // Crossing the end in one step: stop exactly at it.
    if (position.pixels < max && value > max) return value - max;
    return super.applyBoundaryConditions(position, value);
  }
}
