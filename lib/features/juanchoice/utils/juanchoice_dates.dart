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
