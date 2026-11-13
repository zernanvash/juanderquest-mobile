import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import '../models/route_model.dart';
import '../providers/navigation_provider.dart';
import 'nav_pixel_art.dart';
import 'route_map_thumbnail.dart';

class RoutePreviewSheet extends StatefulWidget {
  final NavigationState navState;
  final ValueChanged<TravelCosting> onSelectCosting;
  final VoidCallback onChangeOrigin;
  final VoidCallback onSelectDirect;
  final ValueChanged<NearbyTrail> onSelectTrail;
  final ValueChanged<NearbyTrail> onInspectTrail;
  final VoidCallback onOpenSteps;
  final VoidCallback onGo;
  final VoidCallback onRetry;
  final VoidCallback? onRetryTrails;

  const RoutePreviewSheet({
    super.key,
    required this.navState,
    required this.onSelectCosting,
    required this.onChangeOrigin,
    required this.onSelectDirect,
    required this.onSelectTrail,
    required this.onInspectTrail,
    required this.onOpenSteps,
    required this.onGo,
    required this.onRetry,
    this.onRetryTrails,
  });

  @override
  State<RoutePreviewSheet> createState() => _RoutePreviewSheetState();
}

class _RoutePreviewSheetState extends State<RoutePreviewSheet>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _snapController;
  int _centredPage = 0;
  Timer? _debounceTimer;
  bool _isOpen = false;
  bool _isDragging = false;
  double _height = 0;
  double _snapFrom = 0;
  double _snapTo = 0;
  List<LatLng>? _lastRouteCoordsRef;
  List<double> _thinnedRoute = const [];
  List<double> _cachedDirectRoute = const [];

  static List<double> _thinCoords(List<LatLng> coords,
      {int maxPoints = 200}) {
    if (coords.isEmpty) return const [];
    final n = coords.length;
    if (n <= maxPoints) {
      final out = <double>[];
      for (final c in coords) {
        out.add(c.lng);
        out.add(c.lat);
      }
      return out;
    }
    final out = <double>[];
    final step = (n - 1) / (maxPoints - 1);
    for (var i = 0; i < maxPoints - 1; i++) {
      final c = coords[(i * step).round()];
      out.add(c.lng);
      out.add(c.lat);
    }
    out.add(coords.last.lng);
    out.add(coords.last.lat);
    return out;
  }

  @override
  void initState() {
    super.initState();
    final initial = _indexForSelected(widget.navState);
    _centredPage = initial;
    _pageController = PageController(
      viewportFraction: 0.86,
      initialPage: initial,
    );
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(() {
        final t = const _Stepped(4).transform(_snapController.value);
        setState(() {
          _height = _snapFrom + (_snapTo - _snapFrom) * t;
        });
      });
  }

  @override
  void didUpdateWidget(RoutePreviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.navState.selectedTrail?.id;
    final newId = widget.navState.selectedTrail?.id;
    if (newId != oldId && newId != null) {
      final target = _indexForSelected(widget.navState);
      if (target != _centredPage) {
        setState(() => _centredPage = target);
        if (_pageController.hasClients) {
          if (MediaQuery.disableAnimationsOf(context)) {
            _pageController.jumpToPage(target);
          } else {
            _pageController.animateToPage(
              target,
              duration: const Duration(milliseconds: 180),
              curve: Curves.linear,
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _snapController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _animateTo(double target,
      {required bool open, required bool disableAnimations}) {
    _isOpen = open;
    if (disableAnimations) {
      _snapController.stop();
      setState(() => _height = target);
      return;
    }
    _snapFrom = _height;
    _snapTo = target;
    _snapController.forward(from: 0);
  }

  void _drag(DragUpdateDetails d, double minH, double maxH) {
    _snapController.stop();
    _isDragging = true;
    setState(() {
      _height = (_height - d.delta.dy).clamp(minH, maxH);
      _isOpen = _height > (minH + maxH) / 2;
    });
  }

  void _dragEnd(
      DragEndDetails d, double minH, double maxH, bool disableAnimations) {
    _isDragging = false;
    final v = d.primaryVelocity ?? 0;
    final up = v.abs() > 300 ? v < 0 : _height > (minH + maxH) / 2;
    _animateTo(up ? maxH : minH,
        open: up, disableAnimations: disableAnimations);
  }

  List<NearbyTrail> _sortedTrails(NavigationState state) {
    final copy = [...state.nearbyTrails];
    copy.sort((a, b) {
      if (a.passesHere != b.passesHere) return a.passesHere ? -1 : 1;
      return a.nearestKm.compareTo(b.nearestKm);
    });
    return copy;
  }

  int _indexForSelected(NavigationState state) {
    final selectedId = state.selectedTrail?.id;
    if (selectedId == null) return 0;
    final trails = _sortedTrails(state);
    final idx = trails.indexWhere((t) => t.id == selectedId);
    return idx >= 0 ? idx + 1 : 0;
  }

  void _onPageChanged(int page, List<NearbyTrail> trails) {
    if (_centredPage != page) {
      setState(() => _centredPage = page);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      if (page == 0) {
        if (widget.navState.selectedTrail != null) {
          widget.onSelectDirect();
        }
        return;
      }
      final trailIdx = page - 1;
      if (trailIdx < 0 || trailIdx >= trails.length) return;
      final t = trails[trailIdx];
      if (t.isUnlocked && widget.navState.selectedTrail?.id != t.id) {
        widget.onSelectTrail(t);
      }
    });
  }

  void _jumpToCard(int index) {
    if (!_pageController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 160),
        curve: Curves.linear,
      );
    }
  }

  NearbyTrail? _centredLockedTrail(List<NearbyTrail> trails) {
    if (_centredPage <= 0) return null;
    final idx = _centredPage - 1;
    if (idx < 0 || idx >= trails.length) return null;
    final t = trails[idx];
    return t.isUnlocked ? null : t;
  }

  String _formatKm(double km) {
    final rounded = (km * 10).round() / 10.0;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.round()}';
    }
    return rounded.toStringAsFixed(1);
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes MIN';
    }
    final hr = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return '$hr HR';
    return '$hr HR $rem';
  }

  String _formatTrailDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes MIN';
    }
    final hr = minutes ~/ 60;
    final rem = minutes % 60;
    return '$hr HR $rem MIN';
  }

  String _formatArriveClock(int durationSeconds) {
    final arrive = DateTime.now().add(Duration(seconds: durationSeconds));
    final hour12 = arrive.hour % 12 == 0 ? 12 : arrive.hour % 12;
    final min = arrive.minute.toString().padLeft(2, '0');
    final ampm = arrive.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$min $ampm';
  }

  String _etaHeadline(RouteModel? route, NearbyTrail? lockedTrail) {
    if (lockedTrail != null) {
      return _formatTrailDuration(lockedTrail.totalMinutes);
    }
    if (widget.navState.isLoadingRoute) {
      return 'FINDING ROUTE…';
    }
    if (route == null) {
      return 'NO ROUTE';
    }
    if (route.isStraightLineFallback) {
      return 'ABOUT ${_formatKm(route.summary.distanceKm)} KM (ESTIMATE)';
    }
    final trail = widget.navState.selectedTrail;
    if (trail != null) {
      return _formatTrailDuration(trail.totalMinutes);
    }
    final mins = (route.summary.durationSeconds / 60).round();
    return '${_formatDuration(mins)} · ${_formatKm(route.summary.distanceKm)} KM';
  }

  Widget _buildEtaHeadlineWidget(
    BuildContext context,
    RouteModel? route,
    NearbyTrail? lockedTrail,
    bool isShort,
  ) {
    final baseStyle = (isShort
            ? PixelType.body(context, color: PixelPalette.paper)
            : PixelType.title(context, color: PixelPalette.paper))
        .copyWith(fontWeight: FontWeight.bold);

    final showSplitDirect = lockedTrail == null &&
        !widget.navState.isLoadingRoute &&
        route != null &&
        !route.isStraightLineFallback &&
        widget.navState.selectedTrail == null;

    if (showSplitDirect) {
      final mins = (route.summary.durationSeconds / 60).round();
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: _formatDuration(mins), style: baseStyle),
            TextSpan(
              text: ' · ${_formatKm(route.summary.distanceKm)} KM',
              style: baseStyle.copyWith(
                fontWeight: FontWeight.normal,
                color: PixelPalette.parchment,
              ),
            ),
          ],
        ),
        key: const ValueKey('nav_eta_big'),
        maxLines: 1,
      );
    }

    return Text(
      _etaHeadline(route, lockedTrail),
      key: const ValueKey('nav_eta_big'),
      style: baseStyle,
      maxLines: 1,
    );
  }

  String _etaSubtitle(RouteModel? route, NearbyTrail? lockedTrail) {
    if (lockedTrail != null) {
      final price = lockedTrail.unlockRule.pricePoints ?? 0;
      return price == 0 ? 'FREE TO START' : 'UNLOCK FOR $price PTS';
    }
    final originName = widget.navState.origin.isGps
        ? 'MY LOCATION'
        : widget.navState.origin.name.toUpperCase();
    final trail = widget.navState.selectedTrail;
    if (trail != null) {
      final pts = trail.rewardPoints > 0 ? ' · +${trail.rewardPoints} PTS' : '';
      return 'FROM $originName$pts';
    }
    final secs = route?.summary.durationSeconds ?? 0;
    return 'ARRIVE ${_formatArriveClock(secs)} · FROM $originName';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isShort = media.size.height < 420;
    final textScale = media.textScaler.scale(1.0);
    final navState = widget.navState;
    final route = navState.route;
    final trail = navState.selectedTrail;
    if (!identical(route?.coordinates, _lastRouteCoordsRef)) {
      _lastRouteCoordsRef = route?.coordinates;
      _thinnedRoute =
          route != null ? _thinCoords(route.coordinates) : const [];
      if (trail == null && _thinnedRoute.isNotEmpty) {
        _cachedDirectRoute = _thinnedRoute;
      }
    }
    final directRoutePoints = _cachedDirectRoute.isNotEmpty
        ? _cachedDirectRoute
        : <double>[
            if (navState.origin.lat != null && navState.origin.lng != null) ...[
              navState.origin.lng!,
              navState.origin.lat!,
            ],
            navState.destination.lng,
            navState.destination.lat,
          ];
    final sortedTrails = _sortedTrails(navState);
    final lockedTrail = _centredLockedTrail(sortedTrails);
    final hasNonServerError =
        navState.error != null && route == null && lockedTrail == null;

    final hasGhostCard = navState.isLoadingTrails ||
        navState.trailsError != null ||
        sortedTrails.isEmpty;
    final cardCount = 1 + sortedTrails.length + (hasGhostCard ? 1 : 0);

    final baseCardHeight = isShort ? 64.0 : 88.0;
    final cardHeight = isShort
        ? 64.0
        : (baseCardHeight * textScale.clamp(1.0, 1.42))
            .clamp(baseCardHeight, 124.0);
    final woodBarHeight = isShort ? 34.0 : 40.0;
    const swipeHeight = 32.0;
    final modeHeight = isShort ? 44.0 : 52.0;
    final actionHeight = isShort ? 44.0 : 52.0;
    final topPad = isShort ? 4.0 : 6.0;
    const bottomPad = 6.0;
    final gap = isShort ? 4.0 : 6.0;
    final screenHeight = media.size.height;
    final bottomInset = media.padding.bottom;
    final errorExtra = hasNonServerError ? 48.0 : 0.0;
    final minHeight = 2.0 +
        topPad +
        woodBarHeight +
        gap +
        errorExtra +
        cardHeight +
        swipeHeight +
        actionHeight +
        bottomPad +
        bottomInset;
    final openExtrasHeight = gap +
        modeHeight +
        gap +
        40.0 +
        gap +
        (isShort ? 40.0 : 44.0) +
        (textScale > 1.3 ? 12.0 : 0.0);
    final rawMaxHeight = minHeight + openExtrasHeight;
    final maxHeight = math.max(
      minHeight,
      math.min(rawMaxHeight, screenHeight * 0.6),
    );
    if (!_isDragging && !_snapController.isAnimating) {
      _height = _isOpen ? maxHeight : minHeight;
    }
    final currentHeight = _height.clamp(minHeight, maxHeight);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final showOpenBody = currentHeight > minHeight + 12;

    final String goLabel;
    final VoidCallback? goTap;
    if (lockedTrail != null) {
      final price = lockedTrail.unlockRule.pricePoints ?? 0;
      goLabel = price == 0 ? 'CHOOSE TRAIL' : 'UNLOCK · $price PTS';
      goTap = navState.isFindingGps
          ? null
          : () => widget.onInspectTrail(lockedTrail);
    } else {
      goLabel = navState.isFindingGps
          ? 'FINDING YOU…'
          : (trail != null ? 'START TRAIL' : 'GO');
      goTap = (route == null || navState.isFindingGps) ? null : widget.onGo;
    }

    return SizedBox(
      height: currentHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => _drag(d, minHeight, maxHeight),
        onVerticalDragEnd: (d) =>
            _dragEnd(d, minHeight, maxHeight, disableAnimations),
        child: Container(
          decoration: const BoxDecoration(
            color: PixelPalette.paper,
            border: Border(
              top: BorderSide(color: PixelPalette.ink, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: PixelPalette.white,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, topPad, 12, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Slim wood title bar: clock + nav_eta_big + handle
                  SizedBox(
                    height: woodBarHeight,
                    child: PixelPanel(
                      style: PixelBoxStyle.wood,
                      padding: 2,
                      child: Row(
                        children: [
                          const NavPixelIcon(NavPixelArt.clock, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _buildEtaHeadlineWidget(
                                context,
                                route,
                                lockedTrail,
                                isShort,
                              ),
                            ),
                          ),
                          GestureDetector(
                            key: const ValueKey('nav_sheet_handle'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _animateTo(
                              _isOpen ? minHeight : maxHeight,
                              open: !_isOpen,
                              disableAnimations: disableAnimations,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Container(
                                width: 28,
                                height: 4,
                                color: PixelPalette.woodLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  if (hasNonServerError) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Couldn't load this. Try again.",
                            style: PixelType.body(
                              context,
                              color: PixelPalette.red,
                            ).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PixelRectButton(
                          key: const ValueKey('nav_retry'),
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          bg: PixelPalette.sun,
                          onTap: widget.onRetry,
                          child: Text(
                            'RETRY',
                            style: PixelType.body(
                              context,
                              color: PixelPalette.ink,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap),
                  ],

                  // Swipeable Route Carousel (always visible in Option B)
                  SizedBox(
                    height: cardHeight,
                    child: PageView.builder(
                      key: const ValueKey('nav_route_carousel'),
                      controller: _pageController,
                      itemCount: cardCount,
                      onPageChanged: (p) => _onPageChanged(p, sortedTrails),
                      itemBuilder: (context, index) {
                        final thumbSize = isShort ? 48.0 : 68.0;
                        if (index == 0) {
                          final detourCount = navState.selectedDetours.length;
                          final meta = detourCount > 0
                              ? '$detourCount DETOUR${detourCount > 1 ? 'S' : ''}'
                              : 'FASTEST';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _DirectCarouselCard(
                              key: const ValueKey('nav_route_direct'),
                              meta: meta,
                              picked: navState.selectedTrail == null,
                              thumbSize: thumbSize,
                              routePoints: directRoutePoints,
                              onTap: () {
                                if (_centredPage != 0) {
                                  _jumpToCard(0);
                                } else if (navState.selectedTrail != null) {
                                  widget.onSelectDirect();
                                }
                              },
                            ),
                          );
                        }

                        final trailIdx = index - 1;
                        if (trailIdx < sortedTrails.length) {
                          final t = sortedTrails[trailIdx];
                          final isPicked = navState.selectedTrail?.id == t.id;
                          final isCentredLocked =
                              !t.isUnlocked && _centredPage == index;
                          final flatStops = isPicked &&
                                  navState.selectedTrail != null &&
                                  navState.selectedTrail!.stops.isNotEmpty
                              ? <double>[
                                  for (final s in navState.selectedTrail!.stops)
                                    ...[s.lng, s.lat],
                                ]
                              : const <double>[];
                          final trailRoutePoints =
                              isPicked && _thinnedRoute.isNotEmpty
                                  ? _thinnedRoute
                                  : flatStops;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _TrailCarouselCard(
                              key: ValueKey('nav_route_trail_${t.id}'),
                              trail: t,
                              picked: isPicked,
                              centredLocked: isCentredLocked,
                              thumbSize: thumbSize,
                              durationLabel:
                                  _formatTrailDuration(t.totalMinutes),
                              kmLabel: '${_formatKm(t.totalKm)} KM',
                              routePoints: trailRoutePoints,
                              stopPoints: flatStops,
                              onTap: () {
                                if (_centredPage != index) {
                                  _jumpToCard(index);
                                } else {
                                  widget.onInspectTrail(t);
                                }
                              },
                            ),
                          );
                        }

                        // Ghost card (loading / error / empty)
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _GhostCarouselCard(
                            isLoading: navState.isLoadingTrails,
                            error: navState.trailsError,
                            onRetry: widget.onRetryTrails ?? widget.onRetry,
                          ),
                        );
                      },
                    ),
                  ),

                  // Swipe row (page squares; arrows added in Step 4)
                  SizedBox(
                    height: swipeHeight,
                    child: Center(
                      child: _PageSquares(
                        key: const ValueKey('nav_route_dots'),
                        count: cardCount,
                        current:
                            _centredPage.clamp(0, math.max(0, cardCount - 1)),
                      ),
                    ),
                  ),

                  // Pinned full-width GO / START TRAIL / CHOOSE TRAIL / UNLOCK
                  _PixelRectButton(
                    key: const ValueKey('nav_start_adventure'),
                    height: actionHeight,
                    bg: PixelPalette.green,
                    onTap: goTap,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        goLabel,
                        style: PixelType.title(
                          context,
                          color: PixelPalette.paper,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  if (showOpenBody)
                    Expanded(
                      child: ClipRect(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: gap),
                              // 4 Mode buttons
                              Row(
                                children: [
                                  for (var i = 0;
                                      i < TravelCosting.values.length;
                                      i++) ...[
                                    if (i > 0) const SizedBox(width: 6),
                                    Expanded(
                                      child: _ModeButton(
                                        key: ValueKey(
                                            'nav_costing_${TravelCosting.values[i].key}'),
                                        costing: TravelCosting.values[i],
                                        selected: navState.costing ==
                                            TravelCosting.values[i],
                                        height: modeHeight,
                                        onTap: () => widget.onSelectCosting(
                                            TravelCosting.values[i]),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: gap),
                              // Origin line + CHANGE
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _etaSubtitle(route, lockedTrail),
                                      key: const ValueKey('nav_eta_sub'),
                                      style: PixelType.small(
                                        context,
                                        color: PixelPalette.slate,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    key: const ValueKey('nav_change_origin'),
                                    onTap: widget.onChangeOrigin,
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 36),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            'CHANGE',
                                            style: PixelType.small(
                                              context,
                                              color: PixelPalette.ink,
                                            ).copyWith(
                                              fontWeight: FontWeight.bold,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: gap),
                              _PixelRectButton(
                                key: const ValueKey('nav_steps_button'),
                                height: isShort ? 40 : 44,
                                bg: PixelPalette.paper,
                                onTap: widget.onOpenSteps,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'STEPS',
                                    style: PixelType.body(
                                      context,
                                      color: PixelPalette.ink,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectCarouselCard extends StatelessWidget {
  final String meta;
  final bool picked;
  final double thumbSize;
  final List<double> routePoints;
  final VoidCallback onTap;

  const _DirectCarouselCard({
    super.key,
    required this.meta,
    required this.picked,
    required this.thumbSize,
    required this.routePoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: picked,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: picked ? PixelPalette.sun : PixelPalette.parchment,
            border: Border.all(color: PixelPalette.ink, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x400D1B2A),
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: RouteMapThumbnail(
                  route: routePoints,
                  lineColor: PixelPalette.blueBright,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIRECT ROUTE',
                        style: PixelType.body(context, color: PixelPalette.ink)
                            .copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ).copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailCarouselCard extends StatelessWidget {
  final NearbyTrail trail;
  final bool picked;
  final bool centredLocked;
  final double thumbSize;
  final String durationLabel;
  final String kmLabel;
  final List<double> routePoints;
  final List<double> stopPoints;
  final VoidCallback onTap;

  const _TrailCarouselCard({
    super.key,
    required this.trail,
    required this.picked,
    required this.centredLocked,
    required this.thumbSize,
    required this.durationLabel,
    required this.kmLabel,
    required this.routePoints,
    required this.stopPoints,
    required this.onTap,
  });

  Widget _buildLeftTile() {
    return SizedBox(
      width: thumbSize,
      height: thumbSize,
      child: RouteMapThumbnail(
        route: routePoints,
        stops: stopPoints,
        lineColor: PixelPalette.greenBright,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        centredLocked ? PixelPalette.sun : PixelPalette.ink;
    final price = trail.unlockRule.pricePoints ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: picked,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: picked ? PixelPalette.sun : PixelPalette.parchment,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x400D1B2A),
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildLeftTile(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      trail.title.toUpperCase(),
                      style: PixelType.body(context, color: PixelPalette.ink)
                          .copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CardChip(
                            label: trail.tier.isHiyas ? 'HIYAS' : 'STARTER',
                            bg: trail.tier.isHiyas
                                ? PixelPalette.sunLight
                                : PixelPalette.wood,
                            fg: trail.tier.isHiyas
                                ? PixelPalette.ink
                                : PixelPalette.paper,
                          ),
                          if (trail.passesHere) ...[
                            const SizedBox(width: 4),
                            const _CardChip(
                              label: 'PASSES HERE',
                              bg: PixelPalette.paper,
                              fg: PixelPalette.ink,
                            ),
                          ],
                          const SizedBox(width: 4),
                          if (trail.isUnlocked)
                            const _CardChip(
                              label: 'UNLOCKED',
                              bg: PixelPalette.green,
                              fg: PixelPalette.paper,
                            )
                          else
                            _CardChip(
                              label: price == 0 ? 'FREE' : '$price',
                              bg: PixelPalette.paper,
                              fg: PixelPalette.ink,
                              leading: const NavPixelIcon(
                                NavPixelArt.lock,
                                size: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${trail.stopCount} STOPS · $durationLabel',
                                  style: PixelType.small(
                                    context,
                                    color: PixelPalette.ink,
                                  ),
                                  maxLines: 1,
                                ),
                                Text(
                                  kmLabel,
                                  style: PixelType.small(
                                    context,
                                    color: PixelPalette.slate,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (trail.rewardPoints > 0) ...[
                          const SizedBox(width: 4),
                          _CardChip(
                            label: '+${trail.rewardPoints} PTS',
                            bg: PixelPalette.sunLight,
                            fg: PixelPalette.ink,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Widget? leading;

  const _CardChip({
    required this.label,
    required this.bg,
    required this.fg,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: PixelPalette.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: PixelType.small(context, color: fg)
                .copyWith(fontWeight: FontWeight.bold, fontSize: 10),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _GhostCarouselCard extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const _GhostCarouselCard({
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  @override
  State<_GhostCarouselCard> createState() => _GhostCarouselCardState();
}

class _GhostCarouselCardState extends State<_GhostCarouselCard> {
  Timer? _timer;
  int _dots = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(_GhostCarouselCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.isLoading && !reduce) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (!mounted) return;
        setState(() => _dots = (_dots % 3) + 1);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final ellipsis = reduce ? '…' : '.' * _dots;
    final label = widget.isLoading
        ? 'FINDING TRAILS$ellipsis'
        : (widget.error != null
            ? "COULDN'T LOAD TRAILS"
            : 'NO TRAILS NEAR HERE YET');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PixelPalette.parchment,
        border: Border.all(color: PixelPalette.ink, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: PixelType.body(context, color: PixelPalette.slate)
                    .copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
              ),
            ),
          ),
          if (!widget.isLoading && widget.error != null) ...[
            const SizedBox(width: 8),
            _PixelRectButton(
              key: const ValueKey('nav_trails_retry'),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              bg: PixelPalette.sun,
              onTap: widget.onRetry,
              child: Text(
                'RETRY',
                style: PixelType.small(context, color: PixelPalette.ink)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageSquares extends StatelessWidget {
  final int count;
  final int current;

  const _PageSquares({
    super.key,
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    if (count > 8) {
      return Center(
        child: Text(
          '${current + 1} / $count',
          style: PixelType.small(context, color: PixelPalette.ink)
              .copyWith(fontWeight: FontWeight.bold),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? PixelPalette.ink : PixelPalette.paper,
              border: Border.all(color: PixelPalette.ink, width: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final TravelCosting costing;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  const _ModeButton({
    super.key,
    required this.costing,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  PixelArt get _icon => switch (costing) {
        TravelCosting.auto => NavPixelArt.modeCar,
        TravelCosting.motorcycle => NavPixelArt.modeMoto,
        TravelCosting.bicycle => NavPixelArt.modeBike,
        TravelCosting.pedestrian => NavPixelArt.modeWalk,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: costing.label,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? PixelPalette.sun : PixelPalette.paper,
            border: selected
                ? const Border(
                    top: BorderSide(color: PixelPalette.ink, width: 3),
                    left: BorderSide(color: PixelPalette.ink, width: 3),
                    right: BorderSide(color: PixelPalette.sunLight, width: 2),
                    bottom: BorderSide(color: PixelPalette.sunLight, width: 2),
                  )
                : Border.all(color: PixelPalette.ink, width: 2),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NavPixelIcon(_icon, size: 16),
                const SizedBox(height: 2),
                Text(
                  costing.label,
                  style: PixelType.small(
                    context,
                    color: PixelPalette.ink,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelRectButton extends StatelessWidget {
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;
  final Color bg;
  final VoidCallback? onTap;
  final Widget child;

  const _PixelRectButton({
    super.key,
    this.width,
    required this.height,
    this.padding,
    required this.bg,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          width: width,
          height: height,
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: PixelPalette.ink, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x660D1B2A),
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Stepped extends Curve {
  const _Stepped(this.steps);
  final int steps;

  @override
  double transformInternal(double t) => (t * steps).ceil() / steps;
}
