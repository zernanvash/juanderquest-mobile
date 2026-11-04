import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/app/main_shell.dart';

// Owner 2026-11-04: the nav bar only on the main pages, not on a spot page.
void main() {
  test('hotbar shows on the six main pages', () {
    for (final p in [
      '/',
      '/dashboard',
      '/explore',
      '/map',
      '/quests',
      '/choice',
      '/profile',
      '/quests/'
    ]) {
      expect(MainShell.showsHotbar(p), isTrue, reason: p);
    }
  });

  test('hotbar hides on detail pages', () {
    for (final p in [
      '/explore/spot-1',
      '/quests/q1',
      '/quests/campaigns/c1',
      '/choice/c1',
      '/search',
      '/notifications',
      '/saved',
      '/spots/new'
    ]) {
      expect(MainShell.showsHotbar(p), isFalse, reason: p);
    }
  });
}
