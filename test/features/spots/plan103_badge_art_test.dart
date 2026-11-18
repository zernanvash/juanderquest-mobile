import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_badges.dart';

// Plan 103 (owner 2026-11-18): the verified and gem medallions ship; the
// other three keep their boxed icons for now.
void main() {
  test('verified and gem use the new 24px medallion art', () {
    expect(ExploreBadge.verified.icon, DesignerArt.badgeVerified);
    expect(ExploreBadge.gem.icon, DesignerArt.badgeGem);
    expect(ExploreBadge.verified.medallion, isTrue);
    expect(ExploreBadge.gem.medallion, isTrue);
    expect(DesignerArt.badgeVerified.width, 24);
    expect(DesignerArt.badgeGem.height, 24);
  });

  test('the other badges are still boxed', () {
    for (final b in [
      ExploreBadge.quest,
      ExploreBadge.quiet,
      ExploreBadge.fiesta
    ]) {
      expect(b.medallion, isFalse, reason: b.id);
    }
  });
}
