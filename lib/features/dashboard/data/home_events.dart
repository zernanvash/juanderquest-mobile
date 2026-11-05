import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The web dashboard's static Pangasinan events list (DashboardCalendar.tsx),
/// with each action mapped to an existing mobile route.
class HomeEvent {
  const HomeEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.municipality,
    required this.category,
    required this.description,
    required this.route,
    this.endDate,
    this.badge,
  });

  final String id;
  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String municipality;
  final String category;
  final String description;
  final String route;
  final String? badge;

  HomeEvent shifted(int years) => HomeEvent(
        id: id,
        title: title,
        date: DateTime(date.year + years, date.month, date.day),
        endDate: endDate == null
            ? null
            : DateTime(endDate!.year + years, endDate!.month, endDate!.day),
        municipality: municipality,
        category: category,
        description: description,
        route: route,
        badge: badge,
      );
}

final _events = <HomeEvent>[
  HomeEvent(
    id: 'ev-bangus-fest',
    title: 'Dagupan Bangus Festival & Gilon-Gilon',
    date: DateTime(2026, 10, 18),
    endDate: DateTime(2026, 10, 24),
    municipality: 'Dagupan City',
    category: 'festival',
    badge: 'Major provincial festival',
    description:
        'Street dancing, culinary expositions and grill promenades in the milkfish capital.',
    route: '/explore',
  ),
  HomeEvent(
    id: 'ev-pista-dayat',
    title: 'Pista Dayat (Sea & Coastal Festival)',
    date: DateTime(2026, 10, 26),
    endDate: DateTime(2026, 10, 28),
    municipality: 'Lingayen & coastal LGUs',
    category: 'festival',
    badge: 'Coastal celebration',
    description:
        'Sand-sculpting, coastal walks and regatta races along Lingayen Gulf.',
    route: '/explore',
  ),
  HomeEvent(
    id: 'ev-hundred-islands-cleanup',
    title: 'Hundred Islands Marine Sanctuary Eco-Quest',
    date: DateTime(2026, 10, 14),
    municipality: 'Alaminos City',
    category: 'eco_quest',
    badge: '+100 XP bounty',
    description:
        'Low-tide reef monitoring and Lucap gateway verification for eco-scouts.',
    route: '/quests',
  ),
  HomeEvent(
    id: 'ev-juanchoice-round',
    title: 'JuanChoice Community Spotlight: Round 2',
    date: DateTime(2026, 10, 20),
    endDate: DateTime(2026, 10, 25),
    municipality: 'Pangasinan-wide',
    category: 'dao_voting',
    badge: 'Civic governance',
    description:
        'Vote for emerging hidden gems to receive a provincial spotlight.',
    route: '/choice',
  ),
  HomeEvent(
    id: 'ev-puto-calasiao',
    title: 'Calasiao Puto & Culinary Weekend Expo',
    date: DateTime(2026, 10, 17),
    municipality: 'Calasiao',
    category: 'market',
    badge: 'Gastronomy fair',
    description: 'Bite-sized rice delicacies and northern Luzon trade stalls.',
    route: '/explore',
  ),
  HomeEvent(
    id: 'ev-bolinao-lighthouse',
    title: 'Cape Bolinao Historical Sunset Trail',
    date: DateTime(2026, 10, 24),
    municipality: 'Bolinao',
    category: 'cultural',
    badge: 'Heritage walk',
    description:
        'Guided heritage walk from Punta Piedra Point to Cape Bolinao Lighthouse.',
    route: '/explore',
  ),
  HomeEvent(
    id: 'ev-manaoag-pilgrim',
    title: 'Minor Basilica of Manaoag Rosary Assembly',
    date: DateTime(2026, 10, 11),
    municipality: 'Manaoag',
    category: 'cultural',
    badge: 'Pilgrimage heritage',
    description:
        'Annual veneration and historic bell-tower heritage exposition.',
    route: '/explore',
  ),
  HomeEvent(
    id: 'ev-antong-falls',
    title: 'Antong Falls Protected Watershed Eco-Trek',
    date: DateTime(2026, 10, 31),
    municipality: 'Sison',
    category: 'eco_quest',
    badge: '+120 XP bounty',
    description:
        'Forest reserve trail cleanup and geotagged spring documentation.',
    route: '/quests',
  ),
  HomeEvent(
    id: 'ev-tayug-sunflower',
    title: 'Tayug Agri-Park Sunflower Maze Opening',
    date: DateTime(2026, 10, 28),
    municipality: 'Tayug',
    category: 'market',
    badge: 'Agri-tourism',
    description:
        'Seasonal opening of eastern Pangasinan\'s sunflower landscape.',
    route: '/explore',
  ),
];

const _annualCategories = {'festival', 'cultural', 'market'};

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _shifted(DateTime value, int years) =>
    DateTime(value.year + years, value.month, value.day);

/// Annual events move to their current or next occurrence so the list never
/// goes stale; one-off eco-quests and voting rounds drop after they end.
List<HomeEvent> projectHomeEvents(DateTime now) {
  final today = _day(now);
  final projected = <HomeEvent>[];
  for (final event in _events) {
    final end = event.endDate ?? event.date;
    if (!_annualCategories.contains(event.category)) {
      if (!end.isBefore(today)) projected.add(event);
      continue;
    }
    var years = today.year - event.date.year;
    if (_shifted(end, years).isBefore(today)) years += 1;
    projected.add(event.shifted(years));
  }
  projected.sort((a, b) => a.date.compareTo(b.date));
  return projected;
}

String homeEventCountdown(HomeEvent event, DateTime now) {
  final today = _day(now);
  final end = event.endDate ?? event.date;
  if (!event.date.isAfter(today) && !end.isBefore(today)) {
    return event.date == today && event.endDate == null
        ? 'Today'
        : 'Happening now';
  }
  final days = _day(event.date).difference(today).inDays;
  if (days == 1) return 'Tomorrow';
  if (days < 14) return 'In $days days';
  if (days < 60) return 'In ${(days / 7).round()} weeks';
  return 'In ${(days / 30).round()} months';
}

final homeEventsProvider = Provider<List<HomeEvent>>(
  (ref) => projectHomeEvents(DateTime.now()),
);
