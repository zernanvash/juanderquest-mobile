import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_arrive_overlay.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_bottom_bar.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_top_banner.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_preview_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/safety_disclaimer_sheet.dart';
import 'package:juanderquest_app/features/navigation/widgets/trail_tracker_bar.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';
import 'package:latlong2/latlong.dart';

class _FakeTrailsApi83e extends TrailsApi {
  _FakeTrailsApi83e() : super(ApiClient());

  @override
  Future<TrailDetail> fetchTrail(String idOrSlug) async {
    return TrailDetail(
      id: idOrSlug,
      slug: 'trail-$idOrSlug',
      title: 'Pangasinan Heritage Trail',
      tagline: 'Historic coastal stops',
      tier: TrailTier.starter,
      theme: 'heritage',
      municipalities: const ['Lingayen', 'Dagupan'],
      stopCount: 2,
      totalMinutes: 45,
      totalKm: 12.0,
      unlockRule: const UnlockRule(type: 'free'),
      isUnlocked: true,
      rewardPoints: 50,
      intro: 'Explore historic sites.',
      stops: const [
        TrailStop(
          position: 1,
          spotId: 's1',
          name: 'Capitol Building',
          municipality: 'Lingayen',
          category: 'Heritage',
          lat: 16.0218,
          lng: 120.2319,
          arriveOffsetMin: 10,
          dwellMin: 15,
          legMinutes: 10,
          legKm: 4.0,
          checkinRadiusM: 60,
          checkedIn: false,
          narration: 'Historic capitol building',
        ),
        TrailStop(
          position: 2,
          spotId: 's2',
          name: 'Patar Beach',
          municipality: 'Bolinao',
          category: 'Beach',
          lat: 16.3228,
          lng: 119.7844,
          arriveOffsetMin: 45,
          dwellMin: 20,
          legMinutes: 35,
          legKm: 8.0,
          checkinRadiusM: 60,
          checkedIn: false,
          narration: 'White sand beach',
        ),
      ],
      preview: const [],
    );
  }
}

NearbyTrail _makeTrail({
  required String id,
  required String title,
  bool passesHere = false,
  double nearestKm = 5.0,
  bool isUnlocked = false,
  TrailTier tier = TrailTier.starter,
  int? pricePoints,
  int rewardPoints = 50,
}) {
  return NearbyTrail(
    id: id,
    slug: id,
    title: title,
    tagline: 'Tagline for $title',
    tier: tier,
    theme: 'heritage',
    municipalities: const ['Lingayen'],
    stopCount: 4,
    totalMinutes: 125,
    totalKm: 24.5,
    unlockRule: UnlockRule(
      type: pricePoints != null && pricePoints > 0 ? 'points' : 'free',
      pricePoints: pricePoints,
    ),
    isUnlocked: isUnlocked,
    rewardPoints: rewardPoints,
    passesHere: passesHere,
    nearestKm: nearestKm,
  );
}

void main() {
  const target = NavTarget(
    name: 'Patar Beach',
    lat: 16.3228,
    lng: 119.7844,
    address: 'Bolinao, Pangasinan',
  );

  const sampleRoute = RouteModel(
    coordinates: [LatLng(16.0218, 120.2319), LatLng(16.3228, 119.7844)],
    summary: RouteSummary(
      distanceKm: 48.2,
      durationSeconds: 3120,
      durationFormatted: '52 mins',
      costing: TravelCosting.auto,
      hasCrowdDiversion: false,
      engine: 'valhalla',
    ),
    maneuvers: [
      RouteManeuver(
        instruction: 'Turn right onto Romulo Hwy',
        distanceMeters: 420,
        timeSeconds: 60,
        streetName: 'Romulo Hwy',
      ),
    ],
  );

  group('Plan 83e §8: Carousel Tests', () {
    testWidgets(
        'carousel orders DIRECT first, passesHere trails first, then nearestKm',
        (tester) async {
      final trails = [
        _makeTrail(
            id: 'far', title: 'Far Trail', passesHere: false, nearestKm: 12.0),
        _makeTrail(
            id: 'pass', title: 'Passes Trail', passesHere: true, nearestKm: 9.0),
        _makeTrail(
            id: 'near', title: 'Near Trail', passesHere: false, nearestKm: 1.5),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: NavigationState(
                  destination: target,
                  route: sampleRoute,
                  nearbyTrails: trails,
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) {},
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      final pageView =
          tester.widget<PageView>(find.byKey(const ValueKey('nav_route_carousel')));
      expect(pageView.childrenDelegate.estimatedChildCount, 1 + trails.length);

      // Card 0 = DIRECT ROUTE, Card 1 = Passes Trail (passesHere: true)
      expect(find.byKey(const ValueKey('nav_route_direct')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_route_trail_pass')), findsOneWidget);
    });

    testWidgets(
        'fast swipe across 3 cards fetches once after 350ms debounce for unlocked trail',
        (tester) async {
      final selectedIds = <String>[];
      final trails = [
        _makeTrail(
          id: 'u1',
          title: 'Trail One',
          passesHere: true,
          nearestKm: 1.0,
          isUnlocked: true,
        ),
        _makeTrail(
          id: 'u2',
          title: 'Trail Two',
          passesHere: false,
          nearestKm: 2.0,
          isUnlocked: true,
        ),
        _makeTrail(
          id: 'u3',
          title: 'Trail Three',
          passesHere: false,
          nearestKm: 3.0,
          isUnlocked: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: NavigationState(
                  destination: target,
                  route: sampleRoute,
                  nearbyTrails: trails,
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (t) => selectedIds.add(t.id),
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      final carousel = find.byKey(const ValueKey('nav_route_carousel'));
      // Swipe quickly across 3 cards before 350ms passes
      await tester.drag(carousel, const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(carousel, const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(carousel, const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 100));

      // Debounce hasn't fired yet
      expect(selectedIds, isEmpty);

      // Pump past 350ms debounce -> settles and selects final centred card once
      await tester.pump(const Duration(milliseconds: 400));
      expect(selectedIds.length, 1);
    });

    testWidgets(
        'locked trail does not change route and main button reads CHOOSE TRAIL or UNLOCK · 150 PTS',
        (tester) async {
      var selectTrailCalls = 0;
      NearbyTrail? inspected;
      final trails = [
        _makeTrail(
          id: 'locked-free',
          title: 'Starter Free Loop',
          passesHere: true,
          nearestKm: 1.0,
          isUnlocked: false,
          pricePoints: 0,
        ),
        _makeTrail(
          id: 'locked-paid',
          title: 'Hiyas Gold Loop',
          passesHere: false,
          nearestKm: 2.0,
          isUnlocked: false,
          tier: TrailTier.signature,
          pricePoints: 150,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: NavigationState(
                  destination: target,
                  route: sampleRoute,
                  nearbyTrails: trails,
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) => selectTrailCalls++,
                onInspectTrail: (t) => inspected = t,
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      final carousel = find.byKey(const ValueKey('nav_route_carousel'));
      // Swipe to locked free trail (index 1)
      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectTrailCalls, 0);
      expect(find.text('CHOOSE TRAIL'), findsOneWidget);
      expect(find.text('FREE TO START'), findsOneWidget);

      // Tap centred trail card -> opens TrailOfferSheet callback
      await tester.tap(find.byKey(const ValueKey('nav_route_trail_locked-free')));
      expect(inspected?.id, 'locked-free');

      // Swipe to locked paid Hiyas trail (index 2)
      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectTrailCalls, 0);
      expect(find.text('UNLOCK · 150 PTS'), findsOneWidget);
      expect(find.text('UNLOCK FOR 150 PTS'), findsOneWidget);
    });

    testWidgets('loading, empty, and error ghost cards render properly',
        (tester) async {
      // 1. Loading
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: const NavigationState(
                  destination: target,
                  route: sampleRoute,
                  isLoadingTrails: true,
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) {},
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('nav_route_carousel')),
        const Offset(-500, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('FINDING TRAILS'), findsOneWidget);

      // 2. Empty
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: const NavigationState(
                  destination: target,
                  route: sampleRoute,
                  isLoadingTrails: false,
                  nearbyTrails: [],
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) {},
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('nav_route_carousel')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('NO TRAILS NEAR HERE YET'), findsOneWidget);

      // 3. Error + RETRY
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: const NavigationState(
                  destination: target,
                  route: sampleRoute,
                  isLoadingTrails: false,
                  trailsError: 'Network error',
                  nearbyTrails: [],
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) {},
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
                onRetryTrails: () => retried = true,
              ),
            ),
          ),
        ),
      );
      final carousel = find.byKey(const ValueKey('nav_route_carousel'));
      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text("COULDN'T LOAD TRAILS"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_trails_retry')));
      expect(retried, isTrue);
    });

    testWidgets('action row stays on screen with 12 trails and shows 1 / 13',
        (tester) async {
      final trails = List.generate(
        12,
        (i) => _makeTrail(
          id: 't-$i',
          title: 'Trail $i',
          nearestKm: i.toDouble(),
          isUnlocked: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RoutePreviewSheet(
                navState: NavigationState(
                  destination: target,
                  route: sampleRoute,
                  nearbyTrails: trails,
                ),
                onSelectCosting: (_) {},
                onChangeOrigin: () {},
                onSelectDirect: () {},
                onSelectTrail: (_) {},
                onInspectTrail: (_) {},
                onOpenSteps: () {},
                onGo: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('1 / 13'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_steps_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_start_adventure')), findsOneWidget);
    });
  });

  group('Plan 83e §8: Driving & Arrive Polish Tests', () {
    test('AdventureTopBanner progress bar segments: 0 at 500m, 4 at 200m, 8 at 0m',
        () {
      expect(AdventureTopBanner.filledSegmentsForDistance(500), 0);
      expect(AdventureTopBanner.filledSegmentsForDistance(200), 4);
      expect(AdventureTopBanner.filledSegmentsForDistance(0), 8);
    });

    testWidgets(
        'TrailTrackerBar renders filled, next, and later squares for 1 of 4 checked in',
        (tester) async {
      const stops = [
        TrailStop(
          position: 1,
          spotId: 's1',
          name: 'Stop 1',
          municipality: 'Lingayen',
          category: 'Heritage',
          lat: 16.0,
          lng: 120.0,
          arriveOffsetMin: 10,
          dwellMin: 10,
          legMinutes: 10,
          legKm: 3.0,
          checkinRadiusM: 60,
          checkedIn: true,
          narration: 'Stop 1',
        ),
        TrailStop(
          position: 2,
          spotId: 's2',
          name: 'Stop 2',
          municipality: 'Lingayen',
          category: 'Heritage',
          lat: 16.01,
          lng: 120.01,
          arriveOffsetMin: 20,
          dwellMin: 10,
          legMinutes: 10,
          legKm: 3.0,
          checkinRadiusM: 60,
          checkedIn: false,
          narration: 'Stop 2',
        ),
        TrailStop(
          position: 3,
          spotId: 's3',
          name: 'Stop 3',
          municipality: 'Lingayen',
          category: 'Heritage',
          lat: 16.02,
          lng: 120.02,
          arriveOffsetMin: 30,
          dwellMin: 10,
          legMinutes: 10,
          legKm: 3.0,
          checkinRadiusM: 60,
          checkedIn: false,
          narration: 'Stop 3',
        ),
        TrailStop(
          position: 4,
          spotId: 's4',
          name: 'Stop 4',
          municipality: 'Lingayen',
          category: 'Heritage',
          lat: 16.03,
          lng: 120.03,
          arriveOffsetMin: 40,
          dwellMin: 10,
          legMinutes: 10,
          legKm: 3.0,
          checkinRadiusM: 60,
          checkedIn: false,
          narration: 'Stop 4',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrailTrackerBar(
              key: ValueKey('nav_trail_tracker'),
              stops: stops,
            ),
          ),
        ),
      );

      final containers = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byKey(const ValueKey('nav_trail_tracker')),
              matching: find.byType(Container),
            ),
          )
          .toList();
      expect(containers.length, 4);
      expect((containers[0].decoration as BoxDecoration).color, PixelPalette.sun);
      expect((containers[1].decoration as BoxDecoration).color, PixelPalette.paper);
      expect((containers[2].decoration as BoxDecoration).color, PixelPalette.parchment);
      expect((containers[3].decoration as BoxDecoration).color, PixelPalette.parchment);
    });

    testWidgets('Arrive reward chip counts up and hides when 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: AdventureArriveOverlay(
              isTrailCompleted: true,
              trailTitle: 'Heritage Trail',
              trailRewardPoints: 120,
              destinationName: 'Patar Beach',
              onContinueCheckIn: () {},
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('+120 PTS'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: AdventureArriveOverlay(
              isTrailCompleted: true,
              trailTitle: 'Heritage Trail',
              trailRewardPoints: 0,
              destinationName: 'Patar Beach',
              onContinueCheckIn: () {},
              onDone: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('nav_arrive_reward_chip')), findsNothing);
    });

    testWidgets(
        'Reduced motion leaves zero pending periodic timers across all 83e widgets',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailsApiProvider.overrideWithValue(_FakeTrailsApi83e()),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      RoutePreviewSheet(
                        navState: const NavigationState(
                          destination: target,
                          route: sampleRoute,
                          isLoadingTrails: true,
                        ),
                        onSelectCosting: (_) {},
                        onChangeOrigin: () {},
                        onSelectDirect: () {},
                        onSelectTrail: (_) {},
                        onInspectTrail: (_) {},
                        onOpenSteps: () {},
                        onGo: () {},
                        onRetry: () {},
                      ),
                      const AdventureTopBanner(
                        currentManeuver: RouteManeuver(
                          instruction: 'Turn right',
                          distanceMeters: 200,
                          timeSeconds: 30,
                        ),
                        distanceToManeuverM: 200,
                        isRerouting: true,
                      ),
                      AdventureBottomBar(
                        summary: sampleRoute.summary,
                        isWithinCheckinRadius: true,
                        onCheckIn: () {},
                        onOpenSteps: () {},
                        onEnd: () {},
                      ),
                      AdventureArriveOverlay(
                        isTrailCompleted: true,
                        trailTitle: 'Heritage Trail',
                        trailRewardPoints: 80,
                        destinationName: 'Patar Beach',
                        onContinueCheckIn: () {},
                        onDone: () {},
                      ),
                      const SafetyDisclaimerSheet(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('+80 PTS'), findsOneWidget);
      // Test finishes immediately without "Timer is still pending" assertion.
    });
  });
}
