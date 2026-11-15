import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/home_calendar_entry.dart';

/// Plan 94: festivals staff entered with checked dates (`GET /calendar/festivals`).
/// Any error (offline, older server) yields an empty list so the built-in
/// month-only festivals still show.
final festivalCalendarProvider =
    FutureProvider.family<List<HomeCalendarEntry>, int>((ref, year) async {
  try {
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get('/calendar/festivals', queryParameters: {'year': year});
    final rows = response.data['data'] as List<dynamic>;
    return rows
        .whereType<Map>()
        .map((raw) => _festivalEntry(raw.cast<String, dynamic>()))
        .whereType<HomeCalendarEntry>()
        .toList();
  } catch (_) {
    return const [];
  }
});

HomeCalendarEntry? _festivalEntry(Map<String, dynamic> json) {
  final start = DateTime.tryParse('${json['starts_on']}');
  final end = DateTime.tryParse('${json['ends_on']}');
  final name = '${json['name'] ?? ''}'.trim();
  if (start == null || end == null || name.isEmpty) return null;
  return HomeCalendarEntry(
    id: 'festival-admin-${json['id']}',
    title: name,
    municipality: '${json['municipality'] ?? ''}'.trim(),
    shortBadge: 'FIESTA',
    kind: CalendarEntryKind.festival,
    startDate: DateTime(start.year, start.month, start.day),
    endDate: end.isBefore(start)
        ? DateTime(start.year, start.month, start.day)
        : DateTime(end.year, end.month, end.day),
    route: '/explore',
  );
}
