import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../juanchoice/providers/juanchoice_provider.dart';
import '../../quests/providers/campaign_provider.dart';
import '../data/verified_pangasinan_festivals.dart';
import '../models/home_calendar_entry.dart';
import 'home_daily_provider.dart';

const Set<String> _demoCampaignIds = {
  'bangus-festival-2026',
  'hundred-islands-cleanup-2026',
  'bolinao-reef-guardian-2026',
};

/// Override in tests or provide custom festival entries when needed.
final homeFestivalEntriesProvider =
    Provider.family<List<HomeCalendarEntry>, int>((ref, year) {
  return verifiedPangasinanFestivalsForYear(year);
});

/// Merges real dated app sources into a single source-agnostic calendar list:
/// 1. JuanChoice voting windows (`choiceOverviewProvider`)
/// 2. Live dated campaigns (`campaignProvider`, skipping demo fallbacks)
/// 3. Streak days (`homeDailyProvider` -> last `streak.current` days)
/// 4. Month-only verified Pangasinan festivals
final homeCalendarEntriesProvider =
    Provider.family<List<HomeCalendarEntry>, int>((ref, year) {
  final entries = <HomeCalendarEntry>[];

  // 1. JuanChoice voting windows
  final choice = ref.watch(choiceOverviewProvider).asData?.value;
  if (choice != null) {
    final current = choice.current;
    if (current != null) {
      entries.add(
        HomeCalendarEntry(
          id: 'vote-current-${current.id}',
          title: current.title,
          shortBadge: choice.isCampaignOpen(current) ? 'LIVE VOTE' : 'VOTE',
          kind: CalendarEntryKind.voting,
          startDate: current.opensAt.toLocal(),
          endDate: current.closesAt.toLocal(),
          route: '/choice',
        ),
      );
    }
    if (choice.nextOpensAt != null) {
      final opens = choice.nextOpensAt!.toLocal();
      final closes = (choice.nextClosesAt ?? choice.nextOpensAt!).toLocal();
      entries.add(
        HomeCalendarEntry(
          id: 'vote-next-${opens.toIso8601String()}',
          title: 'Next Round: ${choice.nextTheme ?? 'JuanChoice'}',
          shortBadge: 'NEXT VOTE',
          kind: CalendarEntryKind.voting,
          startDate: opens,
          endDate: closes,
          route: '/choice',
        ),
      );
    }
  }

  // 2. Live dated campaigns (skip demo defaults and un-dated fallbacks)
  final campaigns = ref.watch(campaignProvider).campaigns;
  for (final c in campaigns) {
    if (_demoCampaignIds.contains(c.id)) continue;
    if (c.startDate.isEmpty || c.startDate == c.createdAt) continue;
    final start = DateTime.tryParse(c.startDate)?.toLocal();
    final end = DateTime.tryParse(c.endDate)?.toLocal() ?? start;
    if (start == null || end == null) continue;
    entries.add(
      HomeCalendarEntry(
        id: 'campaign-${c.id}',
        title: c.title,
        municipality: c.municipality,
        shortBadge: c.rewardPerParticipantMjdq > 0
            ? '+${c.rewardPerParticipantMjdq} mJDQ'
            : 'EVENT',
        kind: CalendarEntryKind.campaign,
        startDate: start,
        endDate: end.isBefore(start) ? start : end,
        route: '/quests/campaigns/${c.id}',
      ),
    );
  }

  // 3. Streak view: mark the last `streak.current` days, ending today if
  // today is claimed, otherwise yesterday. The server sends no claim dates
  // and shield days may be included in `streak.current`.
  final daily = ref.watch(homeDailyProvider).asData?.value;
  if (daily != null && daily.streak > 0) {
    final parsedAnchor = DateTime.tryParse(daily.date);
    final now = DateTime.now();
    final today = parsedAnchor != null
        ? DateTime(parsedAnchor.year, parsedAnchor.month, parsedAnchor.day)
        : DateTime(now.year, now.month, now.day);
    final endDay =
        daily.claimToday ? today : today.subtract(const Duration(days: 1));
    final count = daily.streak.clamp(0, 365);
    for (var i = 0; i < count; i++) {
      final d = endDay.subtract(Duration(days: i));
      entries.add(
        HomeCalendarEntry(
          id: 'streak-${d.year}-${d.month}-${d.day}',
          title: 'Daily Stamp Streak Day',
          shortBadge: 'STREAK',
          kind: CalendarEntryKind.stampStreak,
          startDate: d,
          endDate: d,
          route: '/dashboard',
        ),
      );
    }
  }

  // 4. Verified Pangasinan festivals (monthOnly: true)
  entries.addAll(ref.watch(homeFestivalEntriesProvider(year)));

  return entries;
});
