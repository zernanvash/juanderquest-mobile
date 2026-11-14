enum CalendarEntryKind { voting, campaign, festival, stampStreak }

/// A single source-agnostic calendar entry shown on [HomeAdventureCalendar].
///
/// When [monthOnly] is true (used for annual Pangasinan festivals whose exact
/// dates move each year), [spansDay] returns false so no exact-day pip is
/// drawn; instead the entry appears in the month-header festival chip and in
/// the agenda when that month is viewed.
class HomeCalendarEntry {
  const HomeCalendarEntry({
    required this.id,
    required this.title,
    required this.shortBadge,
    required this.kind,
    required this.startDate,
    required this.endDate,
    required this.route,
    this.municipality = '',
    this.monthOnly = false,
  });

  final String id;
  final String title;
  final String municipality;
  final String shortBadge;
  final CalendarEntryKind kind;
  final DateTime startDate;
  final DateTime endDate;
  final String route;
  final bool monthOnly;

  bool spansMonth(int year, int month) {
    if (monthOnly) {
      return startDate.year == year && startDate.month == month;
    }
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !e.isBefore(monthStart) && !s.isAfter(monthEnd);
  }

  bool spansDay(DateTime day) {
    if (monthOnly) return false;
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }
}
