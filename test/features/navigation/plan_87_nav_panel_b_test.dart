import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_map_thumbnail.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_preview_sheet.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> secureStore = {};

  setUp(() {
    secureStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : secureStore[key];
        case 'write':
          if (key != null) {
            secureStore[key] = args['value']?.toString() ?? '';
          }
          return null;
        case 'delete':
          if (key != null) secureStore.remove(key);
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  const target = NavTarget(
    name: 'Tondaligan Beach',
    lat: 16.06,
    lng: 120.34,
    address: 'Dagupan',
  );

  final sampleRoute = RouteModel(
    summary: const RouteSummary(
      distanceKm: 6.9,
      durationSeconds: 480,
      durationFormatted: '8 min',
      costing: TravelCosting.auto,
      hasCrowdDiversion: false,
      engine: 'valhalla',
    ),
    coordinates: [
      for (var i = 0; i < 250; i++)
        LatLng(16.02 + i * 0.0002, 120.23 + i * 0.0004),
    ],
    maneuvers: const [
      RouteManeuver(
        instruction: 'Head north',
        distanceMeters: 200,
        timeSeconds: 30,
      ),
    ],
  );

  NearbyTrail makeTrail(String id, {bool unlocked = true}) => NearbyTrail(
        id: id,
        slug: id,
        title: 'Trail $id',
        tagline: '',
        tier: TrailTier.starter,
        theme: 'heritage',
        municipalities: const ['Dagupan'],
        stopCount: 3,
        totalMinutes: 45,
        totalKm: 5.0,
        nearestKm: 1.0,
        unlockRule: const UnlockRule(type: 'free'),
        isUnlocked: unlocked,
        rewardPoints: 50,
        passesHere: true,
      );

  Widget wrapSheet({
    required NavigationState navState,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RoutePreviewSheet(
                  navState: navState,
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
            ],
          ),
        ),
      ),
    );
  }

  group('Plan 87: Navigation Panel Option B', () {
    testWidgets('drag moves panel height mid-point and snaps on release <= 60%',
        (tester) async {
      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1')],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      final sheetFinder = find.byType(RoutePreviewSheet);
      final closedHeight = tester.getSize(sheetFinder).height;

      // Tap handle to open and check 60% cap (<= 800 * 0.6 = 480)
      await tester.tap(find.byKey(const ValueKey('nav_sheet_handle')));
      await tester.pumpAndSettle();
      final openHeight = tester.getSize(sheetFinder).height;
      expect(openHeight, greaterThan(closedHeight));
      expect(openHeight, lessThanOrEqualTo(480.0));

      // Tap handle to close again
      await tester.tap(find.byKey(const ValueKey('nav_sheet_handle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(sheetFinder).height, closeTo(closedHeight, 0.5));

      // Drag up partially (less than half) -> mid-point height moves 1:1
      final gesture =
          await tester.startGesture(tester.getCenter(sheetFinder));
      await gesture.moveBy(const Offset(0, -24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      final midHeight = tester.getSize(sheetFinder).height;
      expect(midHeight, greaterThan(closedHeight));
      expect(midHeight, lessThan(openHeight));

      // Release -> snaps back down to closed
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getSize(sheetFinder).height, closeTo(closedHeight, 0.5));

      // Drag up past halfway -> snaps open
      final gesture2 =
          await tester.startGesture(tester.getCenter(sheetFinder));
      await gesture2.moveBy(const Offset(0, -24));
      await tester.pump();
      await gesture2.moveBy(Offset(0, -(openHeight - closedHeight) * 0.8));
      await tester.pump();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(tester.getSize(sheetFinder).height, closeTo(openHeight, 0.5));
    });

    testWidgets('swipe arrows move between cards and fade at ends',
        (tester) async {
      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1'), makeTrail('t2')],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      final prevFinder = find.byKey(const ValueKey('nav_route_prev'));
      final nextFinder = find.byKey(const ValueKey('nav_route_next'));

      double opacityOf(Finder f) {
        final op = tester.widget<Opacity>(
          find.descendant(of: f, matching: find.byType(Opacity)),
        );
        return op.opacity;
      }

      // At card 0: prev faded to 0.25, next at 1.0
      expect(opacityOf(prevFinder), closeTo(0.25, 0.01));
      expect(opacityOf(nextFinder), closeTo(1.0, 0.01));

      // Tapping prev at card 0 is a no-op
      await tester.tap(prevFinder);
      await tester.pumpAndSettle();
      expect(opacityOf(prevFinder), closeTo(0.25, 0.01));

      // Tap next twice -> moves to card 1 then card 2 (last card)
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(opacityOf(prevFinder), closeTo(1.0, 0.01));
      expect(opacityOf(nextFinder), closeTo(1.0, 0.01));

      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(opacityOf(prevFinder), closeTo(1.0, 0.01));
      expect(opacityOf(nextFinder), closeTo(0.25, 0.01));

      // Tapping next at last card is a no-op
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(opacityOf(nextFinder), closeTo(0.25, 0.01));
    });

    testWidgets(
        'one-time nudge plays once, persists seen flag, and skips when seen or reduced motion',
        (tester) async {
      // 1. First show: plays nudge and persists flag
      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1')],
          ),
          disableAnimations: false,
        ),
      );
      await tester.pump(); // start async seen() read
      await tester.pump(const Duration(milliseconds: 50));
      expect(secureStore[NavCarouselHintPrefs.key], 'true');

      // Pump past 0.7s delay into stepped nudge
      await tester.pump(const Duration(milliseconds: 900));
      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('nav_route_carousel')),
      );
      expect(pageView.controller?.offset ?? 0, greaterThan(0));

      // Finish nudge back to 0
      await tester.pumpAndSettle();
      expect(pageView.controller?.offset ?? 0, closeTo(0, 0.5));

      // 2. Second show with flag already set: skips nudge
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1')],
          ),
          disableAnimations: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 950));
      final pv2 = tester.widget<PageView>(
        find.byKey(const ValueKey('nav_route_carousel')),
      );
      expect(pv2.controller?.offset ?? 0, closeTo(0, 0.1));

      // 3. Reduced motion: skips nudge even if flag cleared
      secureStore.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1')],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 950));
      expect(secureStore[NavCarouselHintPrefs.key], isNull);
    });

    testWidgets(
        'direct and trail cards render RouteMapThumbnail with thinned route and stops',
        (tester) async {
      const selectedTrail = TrailDetail(
        id: 't1',
        slug: 't1',
        title: 'Heritage Trail',
        tagline: '',
        intro: '',
        tier: TrailTier.starter,
        theme: 'heritage',
        municipalities: ['Dagupan'],
        stopCount: 2,
        totalMinutes: 45,
        totalKm: 5.0,
        unlockRule: UnlockRule(type: 'free'),
        isUnlocked: true,
        rewardPoints: 50,
        stops: [
          TrailStop(
            position: 1,
            spotId: 's1',
            name: 'Stop 1',
            municipality: 'Dagupan',
            category: 'heritage',
            lat: 16.04,
            lng: 120.33,
            narration: '',
            arriveOffsetMin: 10,
            dwellMin: 15,
            legMinutes: 10,
            legKm: 2.5,
            checkinRadiusM: 80,
          ),
          TrailStop(
            position: 2,
            spotId: 's2',
            name: 'Stop 2',
            municipality: 'Dagupan',
            category: 'heritage',
            lat: 16.06,
            lng: 120.34,
            narration: '',
            arriveOffsetMin: 25,
            dwellMin: 15,
            legMinutes: 10,
            legKm: 2.5,
            checkinRadiusM: 80,
          ),
        ],
      );

      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1')],
            selectedTrail: selectedTrail,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      // Direct card thumbnail (thinned <= 200 points = <= 400 doubles)
      final directThumb = tester.widget<RouteMapThumbnail>(
        find.descendant(
          of: find.byKey(const ValueKey('nav_route_direct')),
          matching: find.byType(RouteMapThumbnail),
        ),
      );
      expect(directThumb.route, isNotEmpty);

      // Selected trail card thumbnail has route coordinates + stops
      final trailThumb = tester.widget<RouteMapThumbnail>(
        find.descendant(
          of: find.byKey(const ValueKey('nav_route_trail_t1')),
          matching: find.byType(RouteMapThumbnail),
        ),
      );
      expect(trailThumb.route.length, lessThanOrEqualTo(400));
      expect(trailThumb.route, isNotEmpty);
      expect(trailThumb.stops, [120.33, 16.04, 120.34, 16.06]);

      // Orchestrator review: picking a trail keeps the old direct route in
      // navState until the trail route loads; the trail card must not draw it.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1')],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpWidget(
        wrapSheet(
          navState: NavigationState(
            destination: target,
            route: sampleRoute,
            nearbyTrails: [makeTrail('t1')],
            selectedTrail: selectedTrail,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      final pendingThumb = tester.widget<RouteMapThumbnail>(
        find.descendant(
          of: find.byKey(const ValueKey('nav_route_trail_t1')),
          matching: find.byType(RouteMapThumbnail),
        ),
      );
      expect(pendingThumb.route, [120.33, 16.04, 120.34, 16.06]);
    });
  });
}
