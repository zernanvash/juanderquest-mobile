import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/services/push_routing.dart';

void main() {
  test('app sections pass through, with their query', () {
    expect(appRouteForPushHref('/quests/q1'), '/quests/q1');
    expect(appRouteForPushHref('/plaza?tab=friends'), '/plaza?tab=friends');
    expect(appRouteForPushHref('/choice/c1/candidates/k2'), '/choice/c1/candidates/k2');
  });

  test('web destination links map to the app route', () {
    expect(appRouteForPushHref('/spots/hundred-islands'), '/explore/hundred-islands');
  });

  test('web-only, external and malformed links open the inbox', () {
    for (final href in [
      null,
      '',
      'quests/q1',
      '//evil.example/x',
      'https://evil.example/quests',
      '/merchant/funding',
      '/admin',
      r'/quests\..\x',
    ]) {
      expect(appRouteForPushHref(href), '/notifications', reason: '$href');
    }
    expect(appRouteForPushHref('/'), '/dashboard');
  });
}
