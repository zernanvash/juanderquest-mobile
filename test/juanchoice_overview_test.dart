import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';

void main() {
  final campaign = ChoiceCampaign(
    id: 'round-1', theme: 'Coast', region: 'Pangasinan', status: 'scheduled',
    opensAt: DateTime.utc(2026, 10, 1), closesAt: DateTime.utc(2026, 10, 8),
  );

  ChoiceOverview overview(DateTime serverTime, {bool enabled = true}) =>
      ChoiceOverview.fromJson({
        'server_time': serverTime.toIso8601String(),
        'availability': {'voting_enabled': enabled},
      });

  test('does not expose the ballot before the server opening instant', () {
    expect(overview(DateTime.utc(2026, 9, 30)).isCampaignOpen(campaign), isFalse);
  });

  test('permits the displayed ballot only within the server window', () {
    expect(overview(DateTime.utc(2026, 10, 2)).isCampaignOpen(campaign), isTrue);
    expect(overview(DateTime.utc(2026, 10, 8)).isCampaignOpen(campaign), isFalse);
  });

  test('server write availability overrides an open date', () {
    expect(overview(DateTime.utc(2026, 10, 2), enabled: false)
        .isCampaignOpen(campaign), isFalse);
  });
}
