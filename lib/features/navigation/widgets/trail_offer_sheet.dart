import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trail/models/trail_models.dart';
import '../../trail/services/trails_api.dart';
import 'trail_route_thumbnail.dart';

class TrailOfferSheet extends ConsumerStatefulWidget {
  final NearbyTrail trail;
  final ValueChanged<TrailDetail> onChoose;

  const TrailOfferSheet({
    super.key,
    required this.trail,
    required this.onChoose,
  });

  static Future<void> show(
    BuildContext context, {
    required NearbyTrail trail,
    required ValueChanged<TrailDetail> onChoose,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TrailOfferSheet(
        trail: trail,
        onChoose: onChoose,
      ),
    );
  }

  @override
  ConsumerState<TrailOfferSheet> createState() => _TrailOfferSheetState();
}

class _TrailOfferSheetState extends ConsumerState<TrailOfferSheet> {
  TrailDetail? _detail;
  bool _isLoading = true;
  bool _isUnlocking = false;
  bool _isConfirmingUnlock = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail =
          await ref.read(trailsApiProvider).fetchTrail(widget.trail.id);
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = TrailsApi.extractErrorMessage(e);
        });
      }
    }
  }

  Future<void> _handleUnlockAndChoose() async {
    final detail = _detail;
    if (detail == null) return;

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.user == null) {
      setState(() => _error = 'Log in to start a trail');
      return;
    }

    final isFree = (widget.trail.unlockRule.type == 'free') ||
        (detail.unlockRule.type == 'free');
    final price = detail.unlockRule.pricePoints ?? 0;
    if (!isFree && !detail.isUnlocked && price > 0 && !_isConfirmingUnlock) {
      setState(() => _isConfirmingUnlock = true);
      return;
    }

    setState(() {
      _isUnlocking = true;
      _error = null;
    });

    try {
      if (!detail.isUnlocked) {
        await ref.read(trailsApiProvider).unlockTrail(detail.id);
        ref.read(authRefreshProvider).notify();
      }
      final fresh = await ref.read(trailsApiProvider).fetchTrail(detail.id);
      if (mounted) {
        setState(() {
          _detail = fresh;
          _isUnlocking = false;
          _isConfirmingUnlock = false;
        });
        widget.onChoose(fresh);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUnlocking = false;
          _error = TrailsApi.extractErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final media = MediaQuery.of(context);
    final user = ref.watch(authProvider).user;

    final isHiyas = widget.trail.tier.isHiyas;
    final isUnlocked = _detail?.isUnlocked ?? widget.trail.isUnlocked;
    final isFree = (widget.trail.unlockRule.type == 'free') ||
        (_detail?.unlockRule.type == 'free');
    final price = _detail?.unlockRule.pricePoints ?? (isHiyas ? 150 : 0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: PixelPalette.paper,
        border: Border(
          top: BorderSide(color: PixelPalette.woodDeep, width: 3),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Cover Strip
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: PixelPalette.woodNight,
                border: Border(
                  bottom: BorderSide(color: PixelPalette.woodDeep, width: 2),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: grid.px(2),
                    top: grid.px(1),
                    child: Row(
                      children: [
                        PixelChip(
                          isHiyas ? 'HIYAS TRAIL' : 'STARTER TRAIL',
                          style:
                              isHiyas ? PixelBoxStyle.gold : PixelBoxStyle.wood,
                        ),
                        if (widget.trail.passesHere) ...[
                          SizedBox(width: grid.px(1)),
                          const PixelChip(
                            'PASSES HERE',
                            style: PixelBoxStyle.parchment,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: grid.px(1),
                    right: grid.px(2),
                    child: PixelButton(
                      key: const ValueKey('trail_offer_close'),
                      label: 'X',
                      variant: PixelButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.all(grid.px(3)),
                children: [
                  Text(
                    widget.trail.title.toUpperCase(),
                    style:
                        PixelType.title(context, color: PixelPalette.woodDeep),
                  ),
                  if (widget.trail.tagline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.trail.tagline,
                      style:
                          PixelType.body(context, color: PixelPalette.woodMid),
                    ),
                  ],
                  SizedBox(height: grid.px(2)),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: PixelPanel(
                          style: PixelBoxStyle.parchment,
                          child: Column(
                            children: [
                              Text(
                                '${widget.trail.stopCount}',
                                style: PixelType.title(context,
                                    color: PixelPalette.woodDeep),
                              ),
                              Text('STOPS', style: PixelType.small(context)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: grid.px(1)),
                      Expanded(
                        child: PixelPanel(
                          style: PixelBoxStyle.parchment,
                          child: Column(
                            children: [
                              Text(
                                formatMinutes(widget.trail.totalMinutes),
                                style: PixelType.title(context,
                                    color: PixelPalette.woodDeep),
                              ),
                              Text('DURATION', style: PixelType.small(context)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: grid.px(1)),
                      Expanded(
                        child: PixelPanel(
                          style: PixelBoxStyle.gold,
                          child: Column(
                            children: [
                              Text(
                                '+${widget.trail.rewardPoints}',
                                style: PixelType.title(context,
                                    color: PixelPalette.woodDeep),
                              ),
                              Text('POINTS', style: PixelType.small(context)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: grid.px(2)),

                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.all(grid.px(4)),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: PixelPalette.woodDeep),
                      ),
                    )
                  else if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: grid.px(2)),
                      child: Text(
                        _error!,
                        style: PixelType.body(context,
                            color: PixelPalette.redDeep),
                      ),
                    )
                  else if (_detail != null) ...[
                    if (_detail!.intro.isNotEmpty) ...[
                      Text(
                        _detail!.intro,
                        style: PixelType.body(context, color: PixelPalette.ink),
                      ),
                      SizedBox(height: grid.px(2)),
                    ],

                    // Route shape (only when the stop coordinates are known)
                    if (isUnlocked && _detail!.stops.length >= 2) ...[
                      TrailRouteThumbnail(
                        key: const ValueKey('trail_offer_route_shape'),
                        points: [
                          for (final s in _detail!.stops) (s.lat, s.lng)
                        ],
                      ),
                      SizedBox(height: grid.px(2)),
                    ],

                    // Stops List (Unlocked)
                    if (isUnlocked && _detail!.stops.isNotEmpty) ...[
                      Text(
                        'STOPS IN ORDER',
                        style: PixelType.title(context,
                            color: PixelPalette.woodDeep),
                      ),
                      SizedBox(height: grid.px(1)),
                      for (final stop in _detail!.stops) ...[
                        PixelPanel(
                          style: stop.checkedIn
                              ? PixelBoxStyle.wood
                              : PixelBoxStyle.parchment,
                          child: Row(
                            children: [
                              PixelChip(
                                '${stop.position}',
                                style: stop.checkedIn
                                    ? PixelBoxStyle.gold
                                    : PixelBoxStyle.wood,
                              ),
                              SizedBox(width: grid.px(2)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stop.name.toUpperCase(),
                                      style: PixelType.body(
                                        context,
                                        color: stop.checkedIn
                                            ? PixelPalette.paper
                                            : PixelPalette.woodDeep,
                                      ),
                                    ),
                                    Text(
                                      '${stop.municipality} · Stay ${formatMinutes(stop.dwellMin)}',
                                      style: PixelType.small(
                                        context,
                                        color: stop.checkedIn
                                            ? PixelPalette.parchment
                                            : PixelPalette.woodMid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (stop.checkedIn)
                                const PixelChip('CHECKED IN',
                                    style: PixelBoxStyle.gold),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(1)),
                      ],
                    ]
                    // Preview Grid (Locked)
                    else if (!isUnlocked && _detail!.preview.isNotEmpty) ...[
                      Text(
                        isFree ? 'TRAIL PREVIEW' : "WHAT YOU'LL DISCOVER",
                        style: PixelType.title(context,
                            color: PixelPalette.woodDeep),
                      ),
                      SizedBox(height: grid.px(1)),
                      for (final p in _detail!.preview) ...[
                        PixelPanel(
                          style: PixelBoxStyle.parchment,
                          child: Row(
                            children: [
                              PixelChip(isFree ? '•' : '?',
                                  style: PixelBoxStyle.wood),
                              SizedBox(width: grid.px(2)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name.toUpperCase(),
                                      style: PixelType.body(context,
                                          color: PixelPalette.woodDeep),
                                    ),
                                    Text(
                                      p.blurb.isNotEmpty
                                          ? p.blurb
                                          : p.municipality,
                                      style: PixelType.small(context,
                                          color: PixelPalette.woodMid),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(1)),
                      ],
                      if (!isFree)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: grid.px(1)),
                          child: Text(
                            'Route order, coordinates, and turn-by-turn guidance unlock when choosing this trail.',
                            style: PixelType.small(context,
                                color: PixelPalette.woodMid),
                          ),
                        ),
                    ],
                  ],

                  // Confirmation Note
                  if (_isConfirmingUnlock) ...[
                    SizedBox(height: grid.px(2)),
                    PixelPanel(
                      style: PixelBoxStyle.gold,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNLOCK HIYAS TRAIL',
                            style: PixelType.title(context,
                                color: PixelPalette.woodDeep),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Spend $price points to unlock this curated trail? Your balance: ${user?.points ?? 0} pts. Points are in-app only.',
                            style: PixelType.body(context,
                                color: PixelPalette.woodDeep),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Pinned Bottom Actions
            Padding(
              padding: EdgeInsets.all(grid.px(2)),
              child: Row(
                children: [
                  if (_isConfirmingUnlock) ...[
                    Expanded(
                      child: PixelButton(
                        key: const ValueKey('trail_offer_cancel'),
                        label: 'Cancel',
                        variant: PixelButtonVariant.secondary,
                        onPressed: _isUnlocking
                            ? null
                            : () => setState(() => _isConfirmingUnlock = false),
                      ),
                    ),
                    SizedBox(width: grid.px(1)),
                  ],
                  Expanded(
                    flex: 2,
                    child: PixelButton(
                      key: const ValueKey('trail_offer_primary_cta'),
                      label: isUnlocked
                          ? 'LOAD TRAIL ON MAP'
                          : isFree
                              ? 'CHOOSE TRAIL'
                              : _isConfirmingUnlock
                                  ? 'CONFIRM · $price PTS'
                                  : 'UNLOCK & CHOOSE · $price PTS',
                      variant: (isUnlocked || isFree || _isConfirmingUnlock)
                          ? PixelButtonVariant.primary
                          : PixelButtonVariant.secondary,
                      onPressed: (_isLoading || _isUnlocking)
                          ? null
                          : isUnlocked
                              ? () {
                                  if (_detail != null) {
                                    widget.onChoose(_detail!);
                                    Navigator.of(context).pop();
                                  }
                                }
                              : _handleUnlockAndChoose,
                    ),
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
