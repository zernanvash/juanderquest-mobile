import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import '../models/route_model.dart';
import '../providers/navigation_provider.dart';

class RoutePreviewSheet extends StatelessWidget {
  final NavigationState navState;
  final ValueChanged<TravelCosting> onSelectCosting;
  final VoidCallback onChangeOrigin;
  final VoidCallback onSelectDirect;
  final ValueChanged<NearbyTrail> onSelectTrail;
  final ValueChanged<NearbyTrail> onInspectTrail;
  final VoidCallback onOpenSteps;
  final VoidCallback onGo;
  final VoidCallback onRetry;

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
  });

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

  String _etaHeadline(RouteModel? route) {
    if (navState.isLoadingRoute && route == null) {
      return 'FINDING ROUTE…';
    }
    if (route == null) {
      return 'NO ROUTE';
    }
    if (route.isStraightLineFallback) {
      return 'ABOUT ${_formatKm(route.summary.distanceKm)} KM (ESTIMATE)';
    }
    final trail = navState.selectedTrail;
    if (trail != null) {
      return _formatTrailDuration(trail.totalMinutes);
    }
    final mins = (route.summary.durationSeconds / 60).round();
    return '${_formatDuration(mins)} · ${_formatKm(route.summary.distanceKm)} KM';
  }

  String _etaSubtitle(RouteModel? route) {
    final originName = navState.origin.isGps
        ? 'MY LOCATION'
        : navState.origin.name.toUpperCase();
    final trail = navState.selectedTrail;
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
    final route = navState.route;
    final trail = navState.selectedTrail;
    final hasNonServerError = navState.error != null && route == null;

    // Fixed 3-row height for routes list (smaller on compact landscape)
    final listMaxHeight = isShort ? 98.0 : 156.0;
    final rowHeight = isShort ? 42.0 : 48.0;
    final modeHeight = isShort ? 38.0 : 44.0;
    final actionHeight = isShort ? 48.0 : 56.0;

    final goLabel = navState.isFindingGps
        ? 'FINDING YOU…'
        : (trail != null ? 'START TRAIL' : 'GO');

    return Container(
      decoration: const BoxDecoration(
        color: PixelPalette.paper,
        border: Border(
          top: BorderSide(color: Color(0xFF0D1B2A), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, isShort ? 8 : 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasNonServerError) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Couldn't load this. Try again.",
                        style: PixelType.body(
                          context,
                          color: const Color(0xFFBC4749),
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
                      bg: const Color(0xFFFFB703),
                      onTap: onRetry,
                      child: Text(
                        'RETRY',
                        style: PixelType.body(
                          context,
                          color: const Color(0xFF0D1B2A),
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Big ETA
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _etaHeadline(route),
                    key: const ValueKey('nav_eta_big'),
                    style: (isShort
                            ? PixelType.title(context,
                                color: const Color(0xFF0D1B2A))
                            : PixelType.display(context,
                                color: const Color(0xFF0D1B2A)))
                        .copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                  ),
                ),
                SizedBox(height: isShort ? 2 : 4),
                // Sub line + CHANGE
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _etaSubtitle(route),
                        key: const ValueKey('nav_eta_sub'),
                        style: PixelType.small(
                          context,
                          color: const Color(0xFF414844),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: const ValueKey('nav_change_origin'),
                      onTap: onChangeOrigin,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 36),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'CHANGE',
                              style: PixelType.small(
                                context,
                                color: const Color(0xFF0D1B2A),
                              ).copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: isShort ? 4 : 6),

              // 4 Mode buttons
              Row(
                children: [
                  for (var i = 0; i < TravelCosting.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _ModeButton(
                        key: ValueKey('nav_costing_${TravelCosting.values[i].key}'),
                        label: TravelCosting.values[i].label,
                        selected:
                            navState.costing == TravelCosting.values[i],
                        height: modeHeight,
                        onTap: () => onSelectCosting(TravelCosting.values[i]),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isShort ? 4 : 6),

              // Routes list (Direct + nearby trails, bounded height)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(rowHeight, listMaxHeight),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: 1 + navState.nearbyTrails.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final detourCount = navState.selectedDetours.length;
                      final meta = detourCount > 0
                          ? '$detourCount DETOUR${detourCount > 1 ? 'S' : ''}'
                          : 'FASTEST';
                      return _RouteChoiceRow(
                        key: const ValueKey('nav_route_direct'),
                        title: 'DIRECT ROUTE',
                        meta: meta,
                        picked: navState.selectedTrail == null,
                        height: rowHeight,
                        onTap: onSelectDirect,
                      );
                    }
                    final t = navState.nearbyTrails[index - 1];
                    final isPicked = navState.selectedTrail?.id == t.id;
                    final ptsMeta = t.rewardPoints > 0
                        ? ' · +${t.rewardPoints}'
                        : '';
                    return _RouteChoiceRow(
                      key: ValueKey('nav_route_trail_${t.id}'),
                      title: t.title.toUpperCase(),
                      meta: '${t.stopCount} STOPS$ptsMeta',
                      picked: isPicked,
                      height: rowHeight,
                      onTap: () => onSelectTrail(t),
                      onInfo: () => onInspectTrail(t),
                      infoKey: ValueKey('trail_info_${t.id}'),
                    );
                  },
                ),
              ),
              SizedBox(height: isShort ? 6 : 8),

              // Actions row: STEPS + GO / START TRAIL
              Row(
                children: [
                  _PixelRectButton(
                    key: const ValueKey('nav_steps_button'),
                    width: 104,
                    height: actionHeight,
                    bg: const Color(0xFFFAF9F5),
                    onTap: onOpenSteps,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'STEPS',
                        style: PixelType.body(
                          context,
                          color: const Color(0xFF0D1B2A),
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PixelRectButton(
                      key: const ValueKey('nav_start_adventure'),
                      height: actionHeight,
                      bg: const Color(0xFF3F6653),
                      onTap: (route == null || navState.isFindingGps)
                          ? null
                          : onGo,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          goLabel,
                          style: PixelType.title(
                            context,
                            color: const Color(0xFFFAF9F5),
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
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
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFB703)
                : const Color(0xFFFAF9F5),
            border: Border.all(color: const Color(0xFF0D1B2A), width: 2),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: PixelType.body(
                context,
                color: const Color(0xFF0D1B2A),
              ).copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteChoiceRow extends StatelessWidget {
  final String title;
  final String meta;
  final bool picked;
  final double height;
  final VoidCallback onTap;
  final VoidCallback? onInfo;
  final Key? infoKey;

  const _RouteChoiceRow({
    super.key,
    required this.title,
    required this.meta,
    required this.picked,
    required this.height,
    required this.onTap,
    this.onInfo,
    this.infoKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: picked,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: picked
                ? const Color(0xFFFFB703)
                : const Color(0xFFFAF9F5),
            border: Border.all(color: const Color(0xFF0D1B2A), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: picked
                      ? const Color(0xFF0D1B2A)
                      : const Color(0xFFFAF9F5),
                  border: Border.all(color: const Color(0xFF0D1B2A), width: 2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: PixelType.body(
                    context,
                    color: const Color(0xFF0D1B2A),
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                meta,
                style: PixelType.small(
                  context,
                  color: const Color(0xFF0D1B2A),
                ),
                maxLines: 1,
              ),
              if (onInfo != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  key: infoKey,
                  onTap: onInfo,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EBE1),
                      border: Border.all(
                          color: const Color(0xFF0D1B2A), width: 2),
                    ),
                    child: Text(
                      'i',
                      style: PixelType.small(
                        context,
                        color: const Color(0xFF0D1B2A),
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
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
            border: Border.all(color: const Color(0xFF0D1B2A), width: 2),
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
