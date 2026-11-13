import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/app/main_shell.dart';

// Owner 2026-11-04: the nav bar only on the main pages, not on a spot page.
// Plan 85d: tabs are Home · Explore · Map · Quests · Profile; Shop opens from
// Home and Profile as a pushed page without the bar.
void main() {
  test('hotbar shows on the five tab pages', () {
    for (final p in [
      '/',
      '/dashboard',
      '/explore',
      '/map',
      '/quests',
      '/profile',
      '/quests/',
    ]) {
      expect(MainShell.showsHotbar(p), isTrue, reason: p);
    }
  });

  test('hotbar hides on Shop, JuanChoice and detail pages', () {
    for (final p in [
      '/shop',
      '/choice',
      '/explore/spot-1',
      '/quests/q1',
      '/quests/campaigns/c1',
      '/choice/c1',
      '/search',
      '/notifications',
      '/saved',
      '/spots/new',
    ]) {
      expect(MainShell.showsHotbar(p), isFalse, reason: p);
    }
  });
}
