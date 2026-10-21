import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_hunt.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_math.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_task.dart';
import 'package:juanderquest_app/features/ar_experience/engine/shapes_factory.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/screens/qr_scan_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';

const fence = ArFence(lat: 16.0430, lng: 120.3333, radiusMeters: 50);

ArFix fixAt(double lat, double lng, DateTime at, {double accuracy = 5}) =>
    ArFix(lat: lat, lng: lng, accuracy: accuracy, at: at);

/// Upright phone facing [bearing].
CameraPose facing(double bearing) => CameraPose(
      Quat.aboutUp(-bearing * math.pi / 180) *
          Quat.axisAngle(const Vec3(1, 0, 0), math.pi / 2),
    );

class FakeServer {
  final List<String> calls = [];
  ArServerResult<ArChallenge> challenge = ArServerResult.ok(ArChallenge(
      token: 'tok-1', expiresAt: DateTime(2026, 10, 21, 12, 10)));
  List<ArServerResult<void>> submits = [const ArServerResult.ok(null)];
  String? lastToken;

  Future<ArServerResult<ArChallenge>> request(ArFix fix) async {
    calls.add('challenge');
    return challenge;
  }

  Future<ArServerResult<void>> submit(ArFix fix, String token) async {
    calls.add('submit');
    lastToken = token;
    return submits.isEmpty ? const ArServerResult.ok(null) : submits.removeAt(0);
  }
}

void main() {
  group('ArHuntRules', () {
    test('mirrors the server radius rule (accuracy allowance capped at 25 m)', () {
      final now = DateTime(2026);
      // ~67 m north of the centre.
      expect(ArHuntRules.insideFence(fixAt(16.0436, 120.3333, now), fence),
          isFalse);
      expect(
          ArHuntRules.insideFence(
              fixAt(16.0436, 120.3333, now, accuracy: 20), fence),
          isTrue);
      expect(
          ArHuntRules.insideFence(
              fixAt(16.0437, 120.3333, now, accuracy: 200), fence),
          isFalse);
    });

    test('far from the centre the object lies towards the landmark', () {
      final b = ArHuntRules.spawnBearing(
        fix: fixAt(16.0427, 120.3333, DateTime(2026)), // ~33 m south
        fence: fence,
        cameraBearing: 200,
        rng: math.Random(1),
      );
      expect(b, closeTo(0, 0.5));
    });

    test('near the centre the object hides 35–120° to the side', () {
      for (var seed = 0; seed < 50; seed++) {
        final b = ArHuntRules.spawnBearing(
          fix: fixAt(16.0430, 120.3333, DateTime(2026)),
          fence: fence,
          cameraBearing: 100,
          rng: math.Random(seed),
        );
        final off = ArGeo.deltaDegrees(b, 100).abs();
        expect(off, inInclusiveRange(35, 120));
      }
    });

    test('spawn position is 3.5 m away and below eye level', () {
      final p = ArHuntRules.spawnPosition(90);
      expect(p.x, closeTo(3.5, 1e-9));
      expect(p.y.abs(), lessThan(1e-9));
      expect(p.z, ArHuntRules.spawnHeightM);
    });
  });

  group('ArHuntController', () {
    late DateTime now;
    late FakeServer server;
    late ArHuntController hunt;

    setUp(() {
      now = DateTime(2026, 10, 21, 12);
      server = FakeServer();
      hunt = ArHuntController(
        fence: fence,
        requestChallenge: server.request,
        submitEvidence: server.submit,
        rng: math.Random(7),
        now: () => now,
      );
    });

    Future<void> findAndCentre() async {
      await hunt.onFix(fixAt(16.0430, 120.3333, now), cameraBearing: 0);
      expect(hunt.phase, ArHuntPhase.searching);
      final target = ArGeo.bearingOf(hunt.objectPosition!);
      hunt.onCamera(facing(target));
      now = now.add(const Duration(milliseconds: 700));
      hunt.onCamera(facing(target));
    }

    test('outside the fence shows the finder and does not call the server',
        () async {
      await hunt.onFix(fixAt(16.0500, 120.3333, now), cameraBearing: 0);
      expect(hunt.phase, ArHuntPhase.outside);
      expect(hunt.distanceToCentre, greaterThan(700));
      expect(server.calls, isEmpty);
    });

    test('full happy path: unlock, search, centre, collect, verified',
        () async {
      await findAndCentre();
      expect(hunt.phase, ArHuntPhase.aligned);
      await hunt.collect();
      expect(hunt.phase, ArHuntPhase.verified);
      expect(server.calls, ['challenge', 'submit']);
      expect(server.lastToken, 'tok-1');
    });

    test('must stay centred for the hold time', () async {
      await hunt.onFix(fixAt(16.0430, 120.3333, now), cameraBearing: 0);
      final target = ArGeo.bearingOf(hunt.objectPosition!);
      hunt.onCamera(facing(target));
      now = now.add(const Duration(milliseconds: 300));
      hunt.onCamera(facing(target + 30)); // looked away
      now = now.add(const Duration(milliseconds: 400));
      hunt.onCamera(facing(target));
      expect(hunt.phase, ArHuntPhase.searching);
      await hunt.collect();
      expect(server.calls, ['challenge']);
    });

    test('expired token: gets a new one and lets the traveler collect again',
        () async {
      server.submits = [
        const ArServerResult.error('CHALLENGE_TOKEN_EXPIRED', 'expired'),
      ];
      await findAndCentre();
      server.challenge = ArServerResult.ok(ArChallenge(
          token: 'tok-2', expiresAt: DateTime(2026, 10, 21, 12, 20)));
      await hunt.collect();
      expect(hunt.phase, ArHuntPhase.aligned);
      await hunt.collect();
      expect(hunt.phase, ArHuntPhase.verified);
      expect(server.lastToken, 'tok-2');
    });

    test('stale GPS is never sent', () async {
      await findAndCentre();
      now = now.add(const Duration(seconds: 30));
      await hunt.collect();
      expect(hunt.phase, ArHuntPhase.failed);
      expect(hunt.errorCode, 'STALE_GPS');
      expect(server.calls, ['challenge']);
    });

    test('server says too far: recovers when back inside', () async {
      server.challenge = const ArServerResult.error(
          'GPS_RADIUS_EXCEEDED', "Get closer — you're 80 m away.");
      await hunt.onFix(fixAt(16.0430, 120.3333, now), cameraBearing: 0);
      expect(hunt.phase, ArHuntPhase.failed);
      expect(hunt.error, contains('80 m'));
      server.challenge = ArServerResult.ok(ArChallenge(
          token: 'tok-3', expiresAt: DateTime(2026, 10, 21, 12, 30)));
      await hunt.onFix(fixAt(16.0430, 120.3333, now), cameraBearing: 0);
      expect(hunt.phase, ArHuntPhase.searching);
    });

    test('a network failure can be retried', () async {
      server.submits = [const ArServerResult.error('NETWORK', 'offline')];
      await findAndCentre();
      await hunt.collect();
      expect(hunt.phase, ArHuntPhase.failed);
      await hunt.retry(cameraBearing: 0);
      expect(hunt.phase, ArHuntPhase.searching);
    });
  });

  group('ArTaskSpec', () {
    QuestModel quest() => QuestModel.fromJson({
          'id': 'q1',
          'title': 'Hundred Islands Hunt',
          'description': '',
          'category': 'nature',
          'location_name': 'Alaminos',
          'gps_lat': 16.19,
          'gps_lng': 119.98,
          'radius_meters': 100,
          'reward_points': 50,
          'marker_image_url': '',
          'crowd_status': 'low',
          'steps': [],
        });

    test('reads the Plan 43 AR config', () {
      const step = QuestStepModel(
        order: 3,
        title: 'Find the gem',
        description: '',
        checkpointType: 'ar',
        required: true,
        status: 'ready',
        verification: {
          'type': 'ar',
          'fence': {'lat': 16.2, 'lng': 119.99, 'radius_meters': 40},
          'object': 'box',
          'color': '#3B82F6',
        },
      );
      final spec = ArTaskSpec.from(quest(), step);
      expect(spec.stepOrder, 3);
      expect(spec.fence.radiusMeters, 40);
      expect(spec.fence.lat, 16.2);
      expect(spec.shape, ShapeType.crate);
      expect(spec.color.toARGB32(), 0xFF3B82F6);
    });

    test('falls back to the quest location with a 50 m fence', () {
      const step = QuestStepModel(
        order: 1,
        title: '',
        description: '',
        checkpointType: 'ar',
        required: true,
        status: 'ready',
      );
      final spec = ArTaskSpec.from(quest(), step);
      expect(spec.fence.lat, 16.19);
      expect(spec.fence.radiusMeters, 50);
      expect(spec.title, 'Hundred Islands Hunt');
      expect(spec.shape, ShapeType.token);
    });

    test('friendly copy for server error codes', () {
      expect(ArQuestApi.messageFor('NO_ACTIVE_ATTEMPT', null),
          contains('Start this quest'));
      expect(ArQuestApi.messageFor('GPS_RADIUS_EXCEEDED', 'Get closer'),
          'Get closer');
    });
  });

  group('QR and in-app tasks', () {
    test('extracts the marker code from a scan', () {
      expect(extractMarkerCode('  JDQ-QR-7f3a  '), 'JDQ-QR-7f3a');
      expect(
          extractMarkerCode('https://juanderquest.app/q?code=ABC123'), 'ABC123');
      expect(extractMarkerCode('https://example.com/promo'), isNull);
      expect(extractMarkerCode(''), isNull);
      expect(extractMarkerCode('x' * 201), isNull);
    });

    QuestStepModel action(Map<String, dynamic> task) => QuestStepModel(
          order: 2,
          title: 'Quiz',
          description: '',
          checkpointType: 'action',
          required: true,
          status: 'ready',
          verification: {'type': 'action', 'task': task},
        );

    test('in-app task shortcuts', () {
      expect(inAppTaskRoute(action({'kind': 'complete_quiz', 'quiz_id': 'z9'})),
          '/cultural-quizzes/z9');
      expect(inAppTaskRoute(action({'kind': 'vote_juanchoice'})), '/choice');
      expect(inAppTaskRoute(action({'kind': 'like_spot'})), isNull);
    });
  });
}
