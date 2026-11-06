/// JuanChoice dates as travelers read them (Plan 75n): "Nov 9, 2026" or
/// "Nov 9", always in Philippine time (UTC+8, no daylight saving), never a
/// raw timestamp.
String choiceDate(DateTime value, {bool withYear = true}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final manila = value.toUtc().add(const Duration(hours: 8));
  final day = '${months[manila.month - 1]} ${manila.day}';
  return withYear ? '$day, ${manila.year}' : day;
}

/// The last day travelers can vote, e.g. "Sunday, Nov 8" (owner 2026-11-06).
/// A round that closes at 00:00 Philippine time ends on the day before.
String choiceVotingEnds(DateTime closesAt) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final lastMoment = closesAt.toUtc().subtract(const Duration(seconds: 1));
  final manila = lastMoment.add(const Duration(hours: 8));
  return '${weekdays[manila.weekday - 1]}, '
      '${choiceDate(lastMoment, withYear: false)}';
}
