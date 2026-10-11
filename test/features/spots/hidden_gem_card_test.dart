import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/features/spots/models/hidden_gem_model.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/widgets/hidden_gem_card.dart';

const _gem = HiddenGemModel(
  id: 'spot-antong-falls',
  name: 'Antong Falls & Mountain Brook',
  municipality: 'Sison',
  reason: 'Matches your travel interests',
  crowdStatus: 'quiet',
);

Widget _harness(Future<List<HiddenGemModel>> Function() load) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(body: SingleChildScrollView(child: HiddenGemCard())),
    ),
    GoRoute(
      path: '/explore/:slug',
      builder: (_, state) => Scaffold(body: Text('detail:${state.pathParameters['slug']}')),
    ),
  ]);
  return ProviderScope(
    overrides: [hiddenGemProvider.overrideWith((ref) => load())],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('parses the bounded API payload and labels crowd honestly', () {
    final gem = HiddenGemModel.fromJson({
      'id': 'spot-agno-umbrella-rocks',
      'name': 'Agno Umbrella Rocks',
      'municipality': 'Agno',
      'image_url': '',
      'crowd_status': 'unknown',
      'reason': 'Discover somewhere different',
    });
    expect(gem.imageUrl, isNull);
    expect(gem.crowdLabel, 'Crowd level not yet reported');
    expect(_gem.crowdLabel, 'Usually quiet');
  });

  testWidgets('renders the ad-style card with Not sponsored disclosure', (tester) async {
    await tester.pumpWidget(_harness(() async => const [_gem]));
    await tester.pumpAndSettle();

    expect(find.text('HIDDEN GEM'), findsOneWidget);
    expect(find.text('Not sponsored'), findsOneWidget);
    expect(find.text('Antong Falls & Mountain Brook'), findsOneWidget);
    expect(find.text('Matches your travel interests'), findsOneWidget);
    expect(find.text('Usually quiet'), findsOneWidget);
  });

  testWidgets('tapping the CTA opens the destination by id', (tester) async {
    await tester.pumpWidget(_harness(() async => const [_gem]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View this gem'));
    await tester.pumpAndSettle();

    expect(find.text('detail:spot-antong-falls'), findsOneWidget);
  });

  testWidgets('collapses when there are no gems', (tester) async {
    await tester.pumpWidget(_harness(() async => const []));
    await tester.pumpAndSettle();
    expect(find.text('HIDDEN GEM'), findsNothing);
  });

  testWidgets('collapses on network error instead of blocking the feed', (tester) async {
    await tester.pumpWidget(_harness(() async => throw Exception('offline')));
    await tester.pumpAndSettle();
    expect(find.text('HIDDEN GEM'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
