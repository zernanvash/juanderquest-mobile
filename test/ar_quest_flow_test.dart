import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_hunt.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_task.dart';
import 'package:juanderquest_app/features/ar_experience/engine/shapes_factory.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_quest_screen.dart';
import 'package:juanderquest_app/features/ar_experience/widgets/ar_overlay.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/screens/qr_scan_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_pass_host.dart';

QuestStepModel _step(String type, [Map<String, dynamic>? verification]) =>
    QuestStepModel.fromJson({
      'order': 3,
      'title': 'Show your pass',
      'checkpoint_type': type,
      if (verification != null) 'verification': verification,
    });

void main() {
  group('host-scan QR tasks', () {
    test('only QR tasks with host_scans_traveler are host-scanned', () {
      expect(isHostScanStep(_step('qr', {'type': 'qr', 'scan_mode': 'host_scans_traveler'})), isTrue);
      expect(isHostScanStep(_step('qr', {'type': 'qr', 'scan_mode': 'traveler_scans'})), isFalse);
      expect(isHostScanStep(_step('qr')), isFalse);
      expect(isHostScanStep(_step('location', {'scan_mode': 'host_scans_traveler'})), isFalse);
    });

    test('the host scanner accepts quest passes; the traveler scanner keeps rejecting them', () {
      final pass = 'JDQPASS:${'x' * 400}';
      expect(extractQuestPass(pass), pass);
      expect(extractQuestPass('MARKER-123'), isNull);
      expect(extractQuestPass(null), isNull);
      // A pass is longer than a checkpoint marker, so the checkpoint scanner never treats it as one.
      expect(extractMarkerCode(pass), isNull);
    });
  });

  group('AR polish', () {
    test('every hunt phase maps to a progress stage', () {
      expect(ArStatusCard.stageOf(ArHuntPhase.locating), 0);
      expect(ArStatusCard.stageOf(ArHuntPhase.outside), 1);
      expect(ArStatusCard.stageOf(ArHuntPhase.searching), 2);
      expect(ArStatusCard.stageOf(ArHuntPhase.aligned), 3);
      expect(ArStatusCard.stageOf(ArHuntPhase.verified), ArStatusCard.stages.length);
      expect(ArStatusCard.stageOf(ArHuntPhase.failed), -1);
    });

    test('AR objects have a readable label', () {
      expect(ArTaskSpec.labelForShape(ShapeType.gem), '3D Gem');
      for (final shape in ShapeType.values) {
        expect(ArTaskSpec.labelForShape(shape), isNotEmpty);
      }
    });

    testWidgets('the status card names the object and shows Collect when locked on', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ArStatusCard(
            phase: ArHuntPhase.aligned,
            error: null,
            objectLabel: '3D Gem',
            onCollect: () {},
            onDone: () {},
            onRetry: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Locked on'), findsOneWidget);
      expect(find.textContaining('3D Gem'), findsOneWidget);
      expect(find.byKey(const ValueKey('ar_collect')), findsOneWidget);
      expect(find.text('Collect'), findsWidgets);
    });

    testWidgets('the reticle draws while holding progress', (tester) async {
      var progress = 0.4;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ArReticle(active: false, progress: () => progress)),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('ar_reticle')), findsOneWidget);
      progress = 1;
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });
}
