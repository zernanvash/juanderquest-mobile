import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/services/push_routing.dart';

void main() {
  test('app sections pass through, with their query', () {
    expect(appRouteForPushHref('/quests/q1'), '/quests/q1');
    // Owner 2026-11-18: nearby-quest pushes open the quest.
    expect(appRouteForPushHref('/quests/quest-tondaligan-mi3x9'),
        '/quests/quest-tondaligan-mi3x9');
    expect(appRouteForPushHref('/plaza?tab=friends'), '/plaza?tab=friends');
    expect(appRouteForPushHref('/choice/c1/candidates/k2'),
        '/choice/c1/candidates/k2');
  });

  test('web destination links map to the app route', () {
    expect(appRouteForPushHref('/spots/hundred-islands'),
        '/explore/hundred-islands');
    // QA 2026-11-17: funding and follower links open their pages.
    expect(appRouteForPushHref('/funding?quest_id=q7'), '/quests/q7/funding');
    expect(appRouteForPushHref('/funding'), '/notifications');
    expect(appRouteForPushHref('/users/@kzo'), '/profile/%40kzo');
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

  test('Plan 107: a Suki reward notification opens its card', () {
    expect(appRouteForPushHref('/suki/suki_abc123'), '/suki/suki_abc123');
  });
}
