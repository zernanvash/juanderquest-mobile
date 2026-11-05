import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/juanchoice/utils/juanchoice_dates.dart';

void main() {
  test('Plan 75n: JuanChoice dates read as "Nov 9, 2026" in Philippine time',
      () {
    // 00:00 PHT on Nov 9 is 16:00 UTC on Nov 8.
    final closes = DateTime.utc(2026, 11, 8, 16);
    expect(choiceDate(closes), 'Nov 9, 2026');
    expect(choiceDate(closes, withYear: false), 'Nov 9');
    expect(choiceDate(DateTime.utc(2026, 12, 31, 15, 59)), 'Dec 31, 2026');
    expect(choiceDate(DateTime.utc(2026, 12, 31, 16)), 'Jan 1, 2027');
  });
}
