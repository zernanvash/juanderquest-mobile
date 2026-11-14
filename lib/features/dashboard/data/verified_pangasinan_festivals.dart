import '../models/home_calendar_entry.dart';

/// Real Pangasinan municipal and provincial festivals shown BY MONTH ONLY.
///
/// IMPORTANT: Festival dates move each year (lunisolar/Easter or LGU-scheduled)
/// and need owner confirmation before exact days are shown on the calendar.
/// All entries therefore set `monthOnly: true` and are anchored to the 1st of
/// their month so they appear in the month-header chip and month agenda only.
List<HomeCalendarEntry> verifiedPangasinanFestivalsForYear(int year) {
  HomeCalendarEntry fiesta(
    String id,
    String title,
    String municipality,
    int month, {
    String badge = 'FIESTA',
  }) {
    final anchor = DateTime(year, month, 1);
    return HomeCalendarEntry(
      id: 'festival-$id-$year',
      title: title,
      municipality: municipality,
      shortBadge: badge,
      kind: CalendarEntryKind.festival,
      startDate: anchor,
      endDate: anchor,
      route: '/explore',
      monthOnly: true,
    );
  }

  return [
    fiesta('patupat', 'Patupat Festival (Jan)', 'Pozorrubio', 1),
    fiesta('darayat', 'Darayat Festival (Jan)', 'San Fabian', 1),
    fiesta('binnalon', 'Binnalon Festival (Feb)', 'Binalonan', 2),
    fiesta('bagoong', 'Bagoong Festival (Mar)', 'Lingayen', 3),
    fiesta('panagyaman', 'Panagyaman Festival (Mar)', 'Tayug', 3),
    fiesta('hundred-islands', 'Hundred Islands Festival (Mar)', 'Alaminos City', 3),
    fiesta('agew', 'Agew na Pangasinan (Apr)', 'Lingayen', 4, badge: 'HERITAGE'),
    fiesta('mangunguna', 'Mangunguna Festival (Apr)', 'Bolinao', 4),
    fiesta('bangus', 'Dagupan Bangus Festival (Apr)', 'Dagupan City', 4),
    fiesta('kankanen', 'Kankanen Festival (Apr)', 'Asingan', 4),
    fiesta('mango-bamboo', 'Mango-Bamboo Festival (Apr)', 'San Carlos City', 4),
    fiesta('pistay-dayat', "Pista'y Dayat Sea Festival (Apr–May)", 'Lingayen', 4),
    fiesta('pistay-dayat-may', "Pista'y Dayat Culmination (May)", 'Lingayen', 5),
    fiesta('manaoag-rosario', 'Feast of Our Lady of Manaoag (Oct)', 'Manaoag', 10, badge: 'HERITAGE'),
    fiesta('bugallon', 'Bugallon Town Fiesta (Nov)', 'Bugallon', 11),
    fiesta('galicayo', 'Galicayo Festival (Dec)', 'Manaoag', 12),
    fiesta('puto', 'Calasiao Puto Festival (Dec)', 'Calasiao', 12),
  ];
}
