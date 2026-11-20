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

  test('Plan 116: web paths for plaza, merchants, economy/funding, recap', () {
    expect(appRouteForPushHref('/plaza/act-9'), '/plaza?activity=act-9');
    expect(appRouteForPushHref('/plaza/act-9?comments=1'),
        '/plaza?comments=1&activity=act-9');
    expect(appRouteForPushHref('/merchants/m-42'), '/merchants/m-42');
    expect(appRouteForPushHref('/economy/funding/q-12'), '/quests/q-12/funding');
    expect(appRouteForPushHref('/recap'), '/recap');
    expect(appRouteForPushHref('/leaderboard'), '/leaderboard');
  });

  test('Plan 116: table-driven notification kind/href -> expected route', () {
    final cases = <({
      String name,
      String? href,
      String? kind,
      Map<String, dynamic>? data,
      String expected,
    })>[
      (
        name: 'quest_funding via href',
        href: '/economy/funding/q1',
        kind: 'quest_funding',
        data: null,
        expected: '/quests/q1/funding',
      ),
      (
        name: 'quest_funding via kind+id',
        href: null,
        kind: 'quest_funding',
        data: {'quest_id': 'q2'},
        expected: '/quests/q2/funding',
      ),
      (
        name: 'sponsorship via kind+id',
        href: null,
        kind: 'sponsorship',
        data: {'questId': 'q3'},
        expected: '/quests/q3/funding',
      ),
      (
        name: 'quest_reward via kind+id',
        href: null,
        kind: 'quest_reward',
        data: {'quest_id': 'q4'},
        expected: '/quests/q4',
      ),
      (
        name: 'follow via kind+handle',
        href: null,
        kind: 'follow',
        data: {'actor_handle': '@juan'},
        expected: '/profile/%40juan',
      ),
      (
        name: 'cheer via kind+activity_id',
        href: null,
        kind: 'cheer',
        data: {'activity_id': 'a1'},
        expected: '/plaza?activity=a1',
      ),
      (
        name: 'comment via kind+activity_id',
        href: null,
        kind: 'comment',
        data: {'activity_id': 'a2'},
        expected: '/plaza?activity=a2&comments=1',
      ),
      (
        name: 'overtaken via kind+quest_id',
        href: null,
        kind: 'overtaken',
        data: {'quest_id': 'q5'},
        expected: '/quests/q5',
      ),
      (
        name: 'overtaken fallback to leaderboard',
        href: null,
        kind: 'overtaken',
        data: null,
        expected: '/leaderboard',
      ),
      (
        name: 'weekly_recap',
        href: null,
        kind: 'weekly_recap',
        data: null,
        expected: '/recap',
      ),
      (
        name: 'weekly_champion',
        href: null,
        kind: 'weekly_champion',
        data: null,
        expected: '/leaderboard',
      ),
      (
        name: 'chain_alert via kind+quest_id',
        href: null,
        kind: 'chain_alert',
        data: {'quest_id': 'q6'},
        expected: '/quests/q6',
      ),
      (
        name: 'spot_photo_approved via kind+slug',
        href: null,
        kind: 'spot_photo_approved',
        data: {'spot_slug': 'bolinao-lighthouse'},
        expected: '/explore/bolinao-lighthouse',
      ),
      (
        name: 'spot_moderation via kind+slug',
        href: null,
        kind: 'spot_moderation',
        data: {'slug': 'hundred-islands'},
        expected: '/explore/hundred-islands',
      ),
      (
        name: 'suki_reward via kind+program_id',
        href: null,
        kind: 'suki_reward',
        data: {'program_id': 'suki_1'},
        expected: '/suki/suki_1',
      ),
      (
        name: 'nearby_quest via kind+quest_id',
        href: null,
        kind: 'nearby_quest',
        data: {'quest_id': 'q7'},
        expected: '/quests/q7',
      ),
      (
        name: 'unknown kind -> notifications list (never Home)',
        href: null,
        kind: 'something_new',
        data: null,
        expected: '/notifications',
      ),
    ];

    for (final c in cases) {
      expect(
        appRouteForNotification(href: c.href, kind: c.kind, data: c.data),
        c.expected,
        reason: c.name,
      );
    }
  });
}
