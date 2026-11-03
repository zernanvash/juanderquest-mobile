import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_hunt.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_task.dart';
import 'package:juanderquest_app/features/ar_experience/core/geo_anchor.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_placement_screen.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/widgets/task_settings_panel.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';

// Plan 76: creators place the AR object live; the map pin is approximate.
void main() {
  group('geoPointOf', () {
    test('is the inverse of GeoAnchor.localPoint', () {
      const lat = 16.0430, lng = 120.3333;
      for (final (bearing, distance, offset) in [
        (0.0, 3.0, 0.0),
        (75.0, 6.5, 213.0),
        (190.0, 1.2, 359.0),
        (300.0, 12.0, 47.5),
      ]) {
        final p = GeoAnchor.localPoint(
            camX: 2,
            camZ: -1,
            bearing: bearing,
            distance: distance,
            headingOffset: offset);
        final g = geoPointOf(
            lat: lat,
            lng: lng,
            camX: 2,
            camZ: -1,
            anchorX: p.x,
            anchorZ: p.z,
            headingOffset: offset);
        expect(g.distance, closeTo(distance, 1e-9));
        expect(g.bearing, closeTo(bearing, 1e-6));
        // And the lat/lng lands where enuOffset says it is.
        final back = GeoAnchor.enuOffset(lat, lng, g.lat, g.lng);
        final polar = GeoAnchor.polar(back.east, back.north);
        expect(polar.distance, closeTo(distance, 0.01));
        expect(polar.bearing, closeTo(bearing, 0.1));
      }
    });
  });

  group('PlacementGps', () {
    final t = DateTime(2026, 11, 3, 10);

    test('needs three fixes and 8 m or better', () {
      final g = PlacementGps();
      g.add(16.0, 120.0, 4, t);
      g.add(16.0, 120.0, 4, t);
      expect(g.accuracy, isNull);
      expect(g.objectPoint(anchorX: 0, anchorZ: -3, headingOffset: 0), isNull);
      g.add(16.0, 120.0, 40, t);
      expect(g.accuracy, 4);
      expect(g.good, isTrue);
    });

    test('walking around before saving does not move the object', () {
      // Heading offset 0: ARCore -Z is north. The anchor sits at z = -3.
      // The creator walks 3 m east between fixes and GPS follows exactly.
      final still = PlacementGps();
      final walking = PlacementGps();
      for (var i = 0; i < 4; i++) {
        still.add(16.0, 120.0, 4, t);
        final eastM = i.toDouble();
        final dLng = eastM / (111320 * math.cos(16 * math.pi / 180));
        walking.add(16.0, 120.0 + dLng, 4, t, camX: eastM);
      }
      final a = still.objectPoint(anchorX: 0, anchorZ: -3, headingOffset: 0)!;
      final b = walking.objectPoint(anchorX: 0, anchorZ: -3, headingOffset: 0)!;
      final off = GeoAnchor.enuOffset(a.lat, a.lng, b.lat, b.lng);
      expect(off.east.abs() + off.north.abs(), lessThan(0.01));
      // And it is 3 m north of where the creator stood.
      final from = GeoAnchor.enuOffset(16.0, 120.0, a.lat, a.lng);
      expect(from.north, closeTo(3, 0.01));
    });

    test('drops fixes older than the window, and resets', () {
      final g = PlacementGps();
      for (var i = 0; i < 3; i++) {
        g.add(16, 120, 3, t);
      }
      expect(g.accuracy, 3);
      g.reset();
      expect(g.accuracy, isNull);
      for (var i = 0; i < 3; i++) {
        g.add(16, 120, 3, t);
      }
      g.add(16, 120, 15, t.add(const Duration(seconds: 30)));
      expect(g.accuracy, isNull);
    });
  });

  group('live spawn wait', () {
    test('GPS error counts for the traveler', () {
      // 12 m away at ±5 m: close enough.
      expect(
          ArHuntRules.liveTooFar(
              distance: 12, accuracy: 5, unlockedFor: Duration.zero),
          isFalse);
      // 20 m away at ±5 m: walk closer.
      expect(
          ArHuntRules.liveTooFar(
              distance: 20, accuracy: 5, unlockedFor: Duration.zero),
          isTrue);
      // The allowance is capped at 10 m.
      expect(
          ArHuntRules.liveTooFar(
              distance: 20, accuracy: 60, unlockedFor: Duration.zero),
          isTrue);
    });

    test('nobody waits forever: after the limit it spawns near them', () {
      expect(
          ArHuntRules.liveTooFar(
              distance: 40,
              accuracy: 5,
              unlockedFor: ArHuntRules.liveWaitLimit),
          isFalse);
    });
  });

  group('ArVerification placement', () {
    const fence = GeoFence(lat: 16.035, lng: 120.335, radiusMeters: 50);

    test('a live placement round-trips through JSON', () {
      const v = ArVerification(
          fence: fence,
          object: 'gem',
          placedLive: true,
          placementAccuracyM: 4.24);
      final json = v.toJson();
      expect(json['placement'], {'mode': 'ar_live', 'gps_accuracy_m': 4.2});
      final back = ArVerification.fromJson(json);
      expect(back.placedLive, isTrue);
      expect(back.placementAccuracyM, 4.2);
      expect(back.object, 'gem');
    });

    test('no placement in JSON means map (approximate)', () {
      final v =
          ArVerification.fromJson({'type': 'ar', 'fence': fence.toJson()});
      expect(v.placedLive, isFalse);
      expect(v.toJson()['placement'], {'mode': 'map'});
    });

    test('changing object or colour keeps it live; a new pin does not', () {
      const v =
          ArVerification(fence: fence, placedLive: true, placementAccuracyM: 3);
      expect(v.copyWith(object: 'box').placedLive, isTrue);
      expect(v.copyWith(color: '#E11D48').placedLive, isTrue);
      final moved = v.copyWith(fence: fence.copyWith(lat: 16.04));
      expect(moved.placedLive, isFalse);
      expect(moved.placementAccuracyM, isNull);
    });
  });

  group('player', () {
    const fence = ArFence(lat: 16.0430, lng: 120.3333, radiusMeters: 50);

    test('a live object lies in its true direction even near the centre', () {
      // About 5 m south of the point: a map task would hide it to the side.
      final fix =
          ArFix(lat: 16.04295, lng: 120.3333, accuracy: 4, at: DateTime(2026));
      for (var seed = 0; seed < 20; seed++) {
        final b = ArHuntRules.spawnBearing(
            fix: fix,
            fence: fence,
            cameraBearing: 100,
            rng: math.Random(seed),
            exactPoint: true);
        expect(b, closeTo(0, 0.5));
      }
    });

    test('ArTaskSpec reads placement from the step', () {
      QuestModel questWith(Map<String, dynamic> ver) => QuestModel.fromJson({
            'id': 'q1',
            'title': 'Gem hunt',
            'gps_lat': 16.043,
            'gps_lng': 120.3333,
            'steps': [
              {
                'step_order': 1,
                'title': 'Find it',
                'checkpoint_type': 'ar',
                'verification': ver,
              },
            ],
          });
      const f = {'lat': 16.043, 'lng': 120.3333, 'radius_meters': 50};
      final live = questWith({
        'type': 'ar',
        'fence': f,
        'placement': {'mode': 'ar_live'},
      });
      final map = questWith({'type': 'ar', 'fence': f});
      expect(ArTaskSpec.from(live, live.steps.first).placedLive, isTrue);
      expect(ArTaskSpec.from(map, map.steps.first).placedLive, isFalse);
    });
  });

  group('builder section', () {
    const fence = GeoFence(lat: 16.035, lng: 120.335, radiusMeters: 60);

    Future<ArVerification?> pump(WidgetTester tester, ArVerification start,
        {ArPlacementResult? result}) async {
      ArVerification? last;
      var current = start;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ArPlacementSection(
                verification: current,
                placeLive: (_, __) async => result,
                onChanged: (v) => setState(() {
                  current = v;
                  last = v;
                }),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('ar-place-live')));
      await tester.pumpAndSettle();
      return last;
    }

    testWidgets('PLACE IN AR is primary; a map task is marked APPROXIMATE',
        (tester) async {
      await pump(tester, const ArVerification(fence: fence));
      expect(find.textContaining('APPROXIMATE'), findsOneWidget);
      expect(find.byKey(const ValueKey('ar-place-map-link')), findsOneWidget);
    });

    testWidgets(
        'a live placement moves the point, keeps the radius and drops the warning',
        (tester) async {
      final v = await pump(
          tester, const ArVerification(fence: fence, object: 'gem'),
          result: const ArPlacementResult(
              lat: 16.0351, lng: 120.3352, accuracyM: 4));
      expect(v!.placedLive, isTrue);
      expect(v.fence.lat, 16.0351);
      expect(v.fence.radiusMeters, 60);
      expect(v.object, 'gem');
      expect(find.textContaining('APPROXIMATE'), findsNothing);
      expect(find.textContaining('Placed live'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      final v = await pump(tester, const ArVerification(fence: fence));
      expect(v, isNull);
    });
  });
}
