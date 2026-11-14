import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/home_calendar_entry.dart';
import '../pixel/home_pixel_art.dart';
import '../providers/home_calendar_provider.dart';

enum CalendarFilter { all, voting, campaign, festival, stampStreak }

/// Concept B Band 4: Pangasinan Chrono-Almanac Calendar.
///
/// Defaults to a compact 7-day Week Strip and expands in-place to a 7-column
/// Month Grid via [ValueKey('home_calendar_mode_toggle')].
class HomeAdventureCalendar extends ConsumerStatefulWidget {
  const HomeAdventureCalendar({
    super.key,
    this.initialDate,
    this.onNavigate,
  });

  final DateTime? initialDate;
  final ValueChanged<String>? onNavigate;

  @override
  ConsumerState<HomeAdventureCalendar> createState() =>
      _HomeAdventureCalendarState();
}

class _HomeAdventureCalendarState extends ConsumerState<HomeAdventureCalendar> {
  late DateTime _selectedDate;
  late DateTime _viewMonth;
  bool _monthExpanded = false;
  bool _agendaExpanded = false;
  CalendarFilter _filter = CalendarFilter.all;

  static const _greenDeepStyle = PixelBoxStyle(
    fill: PixelPalette.greenDeep,
    highlight: PixelPalette.greenMid,
    shade: PixelPalette.ink,
    outline: PixelPalette.ink,
  );

  static const _monthNames = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(base.year, base.month, base.day);
    _viewMonth = DateTime(base.year, base.month, 1);
  }

  void _go(BuildContext context, String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      context.push(route);
    }
  }

  bool _matchesFilter(HomeCalendarEntry e) {
    return switch (_filter) {
      CalendarFilter.all => true,
      CalendarFilter.voting => e.kind == CalendarEntryKind.voting,
      CalendarFilter.campaign => e.kind == CalendarEntryKind.campaign,
      CalendarFilter.festival => e.kind == CalendarEntryKind.festival,
      CalendarFilter.stampStreak => e.kind == CalendarEntryKind.stampStreak,
    };
  }

  List<DateTime> _weekDaysFor(DateTime anchor) {
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  List<DateTime?> _monthCellsFor(DateTime monthStart) {
    final daysInMonth =
        DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final leadingBlanks = monthStart.weekday - 1; // Monday = 1 -> 0 blanks
    final cells = <DateTime?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(monthStart.year, monthStart.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  void _stepPeriod(int delta) {
    setState(() {
      _agendaExpanded = false;
      if (_monthExpanded) {
        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
        _selectedDate = DateTime(_viewMonth.year, _viewMonth.month, 1);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
        _viewMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
      }
    });
  }

  void _jumpToNextEvent(List<HomeCalendarEntry> allEntries) {
    final filtered = allEntries.where(_matchesFilter).toList();
    DateTime? bestDate;

    for (final e in filtered) {
      if (e.monthOnly) {
        final anchor = DateTime(e.startDate.year, e.startDate.month, 1);
        if (anchor.isAfter(_selectedDate)) {
          if (bestDate == null || anchor.isBefore(bestDate)) {
            bestDate = anchor;
          }
        }
        continue;
      }
      final s = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      if (end.isAfter(_selectedDate)) {
        final candidate = s.isAfter(_selectedDate)
            ? s
            : _selectedDate.add(const Duration(days: 1));
        if (!candidate.isAfter(end) &&
            (bestDate == null || candidate.isBefore(bestDate))) {
          bestDate = candidate;
        }
      }
    }

    if (bestDate != null) {
      setState(() {
        _selectedDate = bestDate!;
        _viewMonth = DateTime(bestDate.year, bestDate.month, 1);
        _agendaExpanded = false;
      });
    }
  }

  String _dayKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return 'home_calendar_day_${d.year}_${mm}_$dd';
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final entries = ref.watch(homeCalendarEntriesProvider(_viewMonth.year));
    final filtered = entries.where(_matchesFilter).toList();

    final monthFestivals = filtered
        .where(
          (e) =>
              e.kind == CalendarEntryKind.festival &&
              e.spansMonth(_viewMonth.year, _viewMonth.month),
        )
        .toList();

    final dayEntries = filtered.where((e) => e.spansDay(_selectedDate)).toList();
    final agendaItems = <HomeCalendarEntry>[
      ...dayEntries,
      ...monthFestivals,
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthLabel =
        '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}';

    return PixelPanel(
      key: const ValueKey('home_calendar_panel'),
      style: _greenDeepStyle,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: PixelSprite(HomePixelArt.calendar, scale: 1),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'ALMANAC · $monthLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(context, color: PixelPalette.sun)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniCalButton(
                    key: const ValueKey('home_calendar_prev'),
                    label: '<',
                    onTap: () => _stepPeriod(-1),
                  ),
                  const SizedBox(width: 3),
                  _MiniCalButton(
                    key: const ValueKey('home_calendar_next'),
                    label: '>',
                    onTap: () => _stepPeriod(1),
                  ),
                  const SizedBox(width: 3),
                  _MiniCalButton(
                    key: const ValueKey('home_calendar_mode_toggle'),
                    label: _monthExpanded ? 'WK' : 'MO',
                    active: true,
                    onTap: () =>
                        setState(() => _monthExpanded = !_monthExpanded),
                  ),
                ],
              ),
            ],
          ),
          if (monthFestivals.isNotEmpty) ...[
            const SizedBox(height: 5),
            Container(
              key: const ValueKey('home_calendar_month_fiesta_chip'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: PixelPalette.blueDeep,
                border: Border.all(color: PixelPalette.blueMid, width: 1),
              ),
              child: Text(
                '${_monthNames[_viewMonth.month - 1]} FIESTAS (${monthFestivals.length}) · MONTH ONLY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.blueLight)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          SizedBox(height: grid.px(1)),
          // Filter pills
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _FilterChip(
                label: 'ALL',
                active: _filter == CalendarFilter.all,
                onTap: () => setState(() => _filter = CalendarFilter.all),
              ),
              _FilterChip(
                label: 'VOTE',
                active: _filter == CalendarFilter.voting,
                onTap: () => setState(() => _filter = CalendarFilter.voting),
              ),
              _FilterChip(
                label: 'EVENT',
                active: _filter == CalendarFilter.campaign,
                onTap: () => setState(() => _filter = CalendarFilter.campaign),
              ),
              _FilterChip(
                label: 'FIESTA',
                active: _filter == CalendarFilter.festival,
                onTap: () => setState(() => _filter = CalendarFilter.festival),
              ),
              _FilterChip(
                label: 'STREAK',
                active: _filter == CalendarFilter.stampStreak,
                onTap: () =>
                    setState(() => _filter = CalendarFilter.stampStreak),
              ),
            ],
          ),
          SizedBox(height: grid.px(1)),
          // Day of week header
          const Row(
            children: [
              _DowLabel('M'),
              _DowLabel('T'),
              _DowLabel('W'),
              _DowLabel('T'),
              _DowLabel('F'),
              _DowLabel('S'),
              _DowLabel('S'),
            ],
          ),
          const SizedBox(height: 2),
          // Week strip or full month grid
          if (!_monthExpanded)
            _buildWeekRow(_weekDaysFor(_selectedDate), filtered, today)
          else
            _buildMonthGrid(_monthCellsFor(_viewMonth), filtered, today),
          SizedBox(height: grid.px(1)),
          // Selected day & month agenda
          Container(
            key: const ValueKey('home_calendar_agenda'),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PixelPalette.woodDeep,
              border: Border.all(color: PixelPalette.sun, width: 1),
            ),
            child: agendaItems.isEmpty
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          'No activity on this date',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.greenLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _MiniCalButton(
                        key: const ValueKey('home_calendar_next_event'),
                        label: 'NEXT EVENT >',
                        active: true,
                        onTap: () => _jumpToNextEvent(entries),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in (_agendaExpanded
                          ? agendaItems
                          : agendaItems.take(2))) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                color: _badgeColor(item.kind),
                                child: Text(
                                  item.shortBadge,
                                  style: PixelType.small(
                                    context,
                                    color: PixelPalette.ink,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PixelType.small(
                                    context,
                                    color: PixelPalette.cream,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _MiniCalButton(
                                label: 'GO >',
                                active: true,
                                onTap: () => _go(context, item.route),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (agendaItems.length > 2)
                        GestureDetector(
                          onTap: () => setState(
                            () => _agendaExpanded = !_agendaExpanded,
                          ),
                          child: Text(
                            _agendaExpanded
                                ? 'SHOW LESS'
                                : '+${agendaItems.length - 2} MORE',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.sun,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekRow(
    List<DateTime> days,
    List<HomeCalendarEntry> filtered,
    DateTime today,
  ) {
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: _DayCell(
              key: ValueKey(_dayKey(days[i])),
              day: days[i],
              isToday: days[i] == today,
              isSelected: days[i] == _selectedDate,
              inCurrentMonth: days[i].month == _viewMonth.month,
              kinds: filtered
                  .where((e) => e.spansDay(days[i]))
                  .map((e) => e.kind)
                  .toSet(),
              onTap: () => setState(() {
                _selectedDate = days[i];
                _viewMonth = DateTime(days[i].year, days[i].month, 1);
                _agendaExpanded = false;
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMonthGrid(
    List<DateTime?> cells,
    List<HomeCalendarEntry> filtered,
    DateTime today,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final slice = cells.sublist(i, i + 7);
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 7 < cells.length ? 2 : 0),
          child: Row(
            children: [
              for (var c = 0; c < 7; c++) ...[
                if (c > 0) const SizedBox(width: 2),
                Expanded(
                  child: slice[c] == null
                      ? const SizedBox(height: 48)
                      : _DayCell(
                          key: ValueKey(_dayKey(slice[c]!)),
                          day: slice[c]!,
                          isToday: slice[c] == today,
                          isSelected: slice[c] == _selectedDate,
                          inCurrentMonth: true,
                          kinds: filtered
                              .where((e) => e.spansDay(slice[c]!))
                              .map((e) => e.kind)
                              .toSet(),
                          onTap: () => setState(() {
                            _selectedDate = slice[c]!;
                            _agendaExpanded = false;
                          }),
                        ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Color _badgeColor(CalendarEntryKind kind) {
    return switch (kind) {
      CalendarEntryKind.voting => PixelPalette.sun,
      CalendarEntryKind.campaign => PixelPalette.greenLight,
      CalendarEntryKind.festival => PixelPalette.blueLight,
      CalendarEntryKind.stampStreak => PixelPalette.flame,
    };
  }
}

class _DowLabel extends StatelessWidget {
  const _DowLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(
            maxScaleFactor: 1.3,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: PixelType.small(context, color: PixelPalette.greenLight)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.inCurrentMonth,
    required this.kinds,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool inCurrentMonth;
  final Set<CalendarEntryKind> kinds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? PixelPalette.woodDeep : PixelPalette.greenDark,
          border: Border.all(
            color: isSelected
                ? PixelPalette.sun
                : (isToday ? PixelPalette.cream : PixelPalette.greenMid),
            width: isSelected || isToday ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(context).clamp(
                  maxScaleFactor: 1.3,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${day.day}',
                  maxLines: 1,
                  style: PixelType.small(
                    context,
                    color: isSelected
                        ? PixelPalette.sun
                        : (inCurrentMonth
                            ? PixelPalette.cream
                            : PixelPalette.greenMid),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (kinds.contains(CalendarEntryKind.voting))
                  const _Pip(PixelPalette.sun),
                if (kinds.contains(CalendarEntryKind.campaign))
                  const _Pip(PixelPalette.greenLight),
                if (kinds.contains(CalendarEntryKind.stampStreak))
                  const _Pip(PixelPalette.flame),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      color: color,
    );
  }
}

class _MiniCalButton extends StatelessWidget {
  const _MiniCalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 28, minWidth: 28),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: active ? PixelPalette.sun : PixelPalette.greenDark,
              border: Border.all(
                color: active ? PixelPalette.ink : PixelPalette.greenMid,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: PixelType.small(
                context,
                color: active ? PixelPalette.ink : PixelPalette.cream,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 24),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: active ? PixelPalette.sun : PixelPalette.greenDark,
              border: Border.all(
                color: active ? PixelPalette.ink : PixelPalette.greenMid,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: PixelType.small(
                context,
                color: active ? PixelPalette.ink : PixelPalette.cream,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
