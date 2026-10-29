// Plan 69: shop banners come alive and the preview looks like the traveler's passport.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/passport_preview.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/profile_banner.dart';
import 'package:juanderquest_app/features/shop/models/cosmetic_item.dart';

CosmeticItem _item(String id, String kind, Map<String, dynamic> asset,
        {int? seed}) =>
    CosmeticItem(
        id: id,
        kind: kind,
        name: id,
        rarity: 'rare',
        asset: asset,
        owned: false,
        equipped: false,
        buyable: true,
        seed: seed);

final _banner = _item('Capiz Heritage', 'banner', {
  'style': 'gradient',
  'colors': ['#ffffff', '#cccccc'],
  'angle': 90
});
final _frame = _item('Bamboo Ring', 'frame', {
  'colors': ['#95d5b2'],
  'width': 3
});

Future<void> _pump(WidgetTester tester, Widget child,
        {bool disableAnimations = false}) =>
    tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: child)))));

/// True when the banner gradient moves over two seconds (the drift is driven by the banner clock).
Future<bool> _moves(WidgetTester tester) async {
  Alignment begin() => ((tester
              .widget<DecoratedBox>(find
                  .descendant(
                      of: find.byType(ProfileBanner),
                      matching: find.byType(DecoratedBox))
                  .first)
              .decoration as BoxDecoration)
          .gradient as LinearGradient)
      .begin as Alignment;
  final before = begin();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 40));
  return begin() != before;
}

void main() {
  test('equippedLoadout resolves loadout ids to items', () {
    final out = equippedLoadout(
        {'frame_id': 'Bamboo Ring', 'banner_id': 'missing'}, [_banner, _frame]);
    expect(out.keys, ['frame']);
    expect(out['frame']!.name, 'Bamboo Ring');
  });

  testWidgets(
      'preview keeps the equipped frame on and labels the previewed banner',
      (tester) async {
    await _pump(
        tester,
        PassportPreview(
            selected: _banner, equipped: {'frame': _frame}, name: 'Juan'));
    expect(find.text('YOUR PASSPORT'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
    expect(find.text('Previewing Banner: Capiz Heritage'), findsOneWidget);
    expect(find.text('Equipped Frame: Bamboo Ring'), findsOneWidget);
    expect(find.text('Animated'), findsOneWidget);
    expect(await _moves(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('passport_motion_toggle')));
    await tester.pump();
    expect(find.text('Still'), findsOneWidget);
    expect(await _moves(tester), isFalse);
  });

  testWidgets(
      'a forced preview animates even when the system removes animations',
      (tester) async {
    await _pump(tester,
        ProfileBanner(asset: _banner.asset, animate: true, forceMotion: true),
        disableAnimations: true);
    expect(await _moves(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unforced banner follows the system setting', (tester) async {
    await _pump(tester, ProfileBanner(asset: _banner.asset, animate: true),
        disableAnimations: true);
    expect(await _moves(tester), isFalse);
    await _pump(tester, ProfileBanner(asset: _banner.asset, animate: true));
    expect(await _moves(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets(
        'preview sheet has no overflow at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true),
              child: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: PassportPreview(
                          selected: _banner,
                          equipped: {
                            'frame': _frame,
                            'title': _item('Island Hopper', 'title',
                                {'text': 'Island Hopper'}),
                          },
                          name: 'Juan dela Cruz Santos',
                          actions: const [Text('Buy for 150 points')]))))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('passport_motion_toggle')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
