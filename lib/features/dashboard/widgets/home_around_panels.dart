import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/open_route.dart';
import '../../../core/dev/test_content.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_idle.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../ar_experience/core/ar_math.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../models/home_calendar_entry.dart';
import '../pixel/home_pixel_art.dart';
import '../providers/home_calendar_provider.dart';
import '../providers/home_recommended_quest_provider.dart';

// QA 2026-11-17: "0 m" read as broken when standing at the place.
String _distance(double meters) => meters < 15
    ? 'HERE'
    : meters < 950
        ? '${(meters / 10).round() * 10} m'
        : '${(meters / 1000).toStringAsFixed(meters < 9950 ? 1 : 0)} km';

/// Owner 2026-11-17: the three closest places, from the spots Home already
/// loads and the phone's last known position (Home never asks for location).
class HomeNearbyPanel extends ConsumerWidget {
  const HomeNearbyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final loc = ref.watch(homeLastKnownLocationProvider).valueOrNull;
    final spots = withoutTestContent<SpotModel>(
      ref.watch(homeNearbySpotsProvider).valueOrNull ?? const <SpotModel>[],
      (s) => s.isTest,
      showTest: ref.watch(showTestContentProvider),
    );

    final near = <({SpotModel spot, double meters})>[];
    if (loc != null) {
      for (final s in spots) {
        if (s.gpsLat == 0 && s.gpsLng == 0) continue;
        near.add((
          spot: s,
          meters: ArGeo.distanceMeters(loc.lat, loc.lng, s.gpsLat, s.gpsLng),
        ));
      }
      near.sort((a, b) => a.meters.compareTo(b.meters));
    }
    final top = near.take(3).toList();

    return PixelPanel(
      key: const ValueKey('home_nearby'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelSectionTitle(
            'NEARBY',
            icon: DesignerArt.spotMarker,
            iconWrap: (icon) => PixelPulse(child: icon),
            colors: PixelText3DColors.green,
            value: top.isEmpty ? null : _distance(top.first.meters),
            valueColor: PixelPalette.greenDark,
          ),
          if (top.isEmpty) ...[
            SizedBox(height: grid.px(2)),
            Text(
              loc == null
                  ? 'Open the Map once with location on, and the places '
                      'closest to you show here.'
                  : 'No places loaded yet. Pull down to refresh.',
              key: const ValueKey('home_nearby_empty'),
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('home_nearby_map'),
              label: 'OPEN MAP',
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: () => openRoute(context, '/map'),
            ),
          ],
          for (final n in top) ...[
            SizedBox(height: grid.px(2)),
            GestureDetector(
              key: ValueKey('home_nearby_${n.spot.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                pixelTick(context);
                context.push('/explore/${n.spot.slug}', extra: n.spot);
              },
              child: ConstrainedBox(
                // Design system: tap targets are at least 48 tall.
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            n.spot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.body(context)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            n.spot.municipality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: grid.px(2)),
                    Flexible(
                      // QA 2026-11-17: distances line up on the right.
                      fit: FlexFit.tight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _distance(n.meters),
                          style: PixelType.numbers(
                            context,
                            color: PixelPalette.greenDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Owner 2026-11-17: the next thing on the Almanac (festival, campaign or
/// vote), with how soon it is. Opens the Almanac.
class HomeNextEventPanel extends ConsumerWidget {
  const HomeNextEventPanel({super.key, this.now});

  /// For tests.
  final DateTime? now;

  static HomeCalendarEntry? pick(List<HomeCalendarEntry> all, DateTime today) {
    HomeCalendarEntry? best;
    for (final e in all) {
      if (e.kind == CalendarEntryKind.stampStreak) continue;
      final end = e.monthOnly
          ? DateTime(e.startDate.year, e.startDate.month + 1, 0)
          : DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      if (end.isBefore(today)) continue;
      if (best == null || e.startDate.isBefore(best.startDate)) best = e;
    }
    return best;
  }

  static const _months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  static String when(HomeCalendarEntry e, DateTime today) {
    if (e.monthOnly) {
      return e.startDate.year == today.year && e.startDate.month == today.month
          ? 'THIS MONTH'
          : _months[e.startDate.month - 1];
    }
    final start =
        DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
    final days = start.difference(today).inDays;
    if (days <= 0) return 'NOW';
    if (days == 1) return 'TOMORROW';
    return 'IN $days DAYS';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final entries = [
      ...ref.watch(homeCalendarEntriesProvider(today.year)),
      // Late in the year, look into January too.
      if (today.month >= 11)
        ...ref.watch(homeCalendarEntriesProvider(today.year + 1)),
    ];
    final next = pick(entries, today);

    return PixelPanel(
      key: const ValueKey('home_next_event'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelSectionTitle(
            'NEXT EVENT',
            icon: HomePixelArt.calendar,
            colors: PixelText3DColors.green,
            value: next == null ? null : when(next, today),
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(2)),
          if (next == null)
            Text(
              'Nothing coming up yet. The Almanac lists festivals by month.',
              key: const ValueKey('home_next_event_empty'),
              style: PixelType.body(context, color: PixelPalette.slate),
            )
          else ...[
            Text(
              next.title,
              key: const ValueKey('home_next_event_title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
            ),
            if (next.municipality.isNotEmpty)
              Text(
                next.municipality,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
          ],
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('home_next_event_open'),
            label: 'OPEN ALMANAC',
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () => context.push('/almanac'),
          ),
        ],
      ),
    );
  }
}
