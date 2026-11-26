// Plan 124d: custom JuanLogs, the Home JuanLog panel, and recorder warnings
// that never block recording (owner 2026-11-26: "just warning but they can
// still use the vlog").
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_vlog_panel.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/active_trail_session_provider.dart';
import 'package:juanderquest_app/features/trail_vlog/models/vlog_manifest.dart';
import 'package:juanderquest_app/features/trail_vlog/services/trail_vlog_vault.dart';
import 'package:juanderquest_app/features/trail_vlog/services/vlog_camera_adapter.dart';
import 'package:juanderquest_app/features/trail_vlog/services/vlog_compiler_service.dart';
import 'package:juanderquest_app/features/trail_vlog/widgets/pixel_vlog_recorder_sheet.dart';

class _FakeCamera implements VlogCameraAdapter {
  bool _initialized = false;
  int recordCount = 0;

  @override
  bool get isInitialized => _initialized;
  @override
  bool get isAudioEnabled => true;
  @override
  bool get isFrontCamera => false;
  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize({
    required bool frontCamera,
    required bool enableAudio,
  }) async =>
      _initialized = true;

  @override
  Future<void> startRecording() async => recordCount++;

  @override
  Future<String> stopRecording() async => '/mem/raw_$recordCount.mp4';

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Colors.brown);

  @override
  Future<void> dispose() async => _initialized = false;
}

/// Records saveClip calls without touching the file system.
class _MemVault extends TrailVlogVault {
  final Map<String, TrailVlogManifest> store = {};

  @override
  Future<TrailVlogManifest?> loadManifest(String trailId) async =>
      store[trailId];

  @override
  Future<TrailVlogManifest> saveClip({
    required String trailId,
    required String trailTitle,
    required int totalStops,
    required double totalKm,
    int rewardPoints = 0,
    required VlogClipKind kind,
    required int stopPosition,
    String? spotId,
    required String spotName,
    required String municipality,
    required String sourceFilePath,
    int durationMs = 3000,
    String cameraFacing = 'back',
  }) async {
    final base = store[trailId] ??
        TrailVlogManifest(
          trailId: trailId,
          trailTitle: trailTitle,
          totalStops: totalStops,
          totalKm: totalKm,
        );
    final updated = base.copyWith(clips: [
      ...base.clips,
      VlogClipEntry(
        id: '${kind.key}_$stopPosition',
        kind: kind,
        stopPosition: stopPosition,
        spotName: spotName,
        municipality: municipality,
        capturedAtIso: '2026-11-26T01:00:00Z',
        filePath: sourceFilePath,
      ),
    ]);
    store[trailId] = updated;
    return updated;
  }
}

class _FixedSession extends ActiveTrailSessionNotifier {
  _FixedSession(super.ref, ActiveTrailSessionState initial) {
    state = initial;
  }
}

const _dest = NavTarget(name: 'Patar White Beach', lat: 16.32, lng: 119.78);

Widget _recorderApp({
  required _MemVault vault,
  required _FakeCamera cam,
  required VlogClipKind kind,
  bool isTrailRunning = true,
  bool isWithinStopTolerance = true,
  double? distance,
  double speed = 0,
}) {
  return ProviderScope(
    overrides: [
      trailVlogVaultProvider.overrideWithValue(vault),
      vlogCameraAdapterFactoryProvider.overrideWithValue(() => cam),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: PixelVlogRecorderSheet(
          trailId: 'custom_1',
          trailTitle: 'My JuanLog',
          totalStops: 0,
          totalKm: 0,
          kind: kind,
          stopPosition: 1,
          spotName: 'My JuanLog',
          municipality: 'Custom JuanLog',
          isTrailRunning: isTrailRunning,
          isWithinStopTolerance: isWithinStopTolerance,
          distanceToStopMeters: distance,
          currentSpeedMs: speed,
        ),
      ),
    ),
  );
}

PixelButton _shutter(WidgetTester tester) => tester
    .widget<PixelButton>(find.byKey(const ValueKey('vlog_shutter_button')));

void main() {
  group('recorder warnings never block (Plan 124d)', () {
    testWidgets('custom log: NO ACTIVE TRAIL warning, records and saves',
        (tester) async {
      final vault = _MemVault();
      final cam = _FakeCamera();
      await tester.pumpWidget(_recorderApp(
        vault: vault,
        cam: cam,
        kind: VlogClipKind.custom,
        isTrailRunning: false,
      ));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('vlog_tolerance_warning')), findsOneWidget);
      expect(find.textContaining('NO ACTIVE TRAIL'), findsOneWidget);
      expect(_shutter(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('vlog_shutter_button')));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vlog_use_clip_button')));
      await tester.pumpAndSettle();

      final saved = vault.store['custom_1']!;
      expect(saved.clips.single.kind, VlogClipKind.custom);
    });

    testWidgets('outside stop tolerance shows the distance; record enabled',
        (tester) async {
      await tester.pumpWidget(_recorderApp(
        vault: _MemVault(),
        cam: _FakeCamera(),
        kind: VlogClipKind.road,
        isWithinStopTolerance: false,
        distance: 412,
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('OUTSIDE STOP TOLERANCE (~412 M AWAY)'),
          findsOneWidget);
      expect(_shutter(tester).onPressed, isNotNull);
    });

    testWidgets('moving fast warns to pull over; record enabled',
        (tester) async {
      await tester.pumpWidget(_recorderApp(
        vault: _MemVault(),
        cam: _FakeCamera(),
        kind: VlogClipKind.road,
        speed: 8,
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('PULL OVER WHEN SAFE'), findsOneWidget);
      expect(_shutter(tester).onPressed, isNotNull);
    });

    testWidgets('trail stop in range: no warning banner', (tester) async {
      await tester.pumpWidget(_recorderApp(
        vault: _MemVault(),
        cam: _FakeCamera(),
        kind: VlogClipKind.stop,
      ));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('vlog_tolerance_warning')), findsNothing);
    });
  });

  group('HomeVlogPanel (Plan 124d)', () {
    Widget panelApp({
      ActiveTrailSessionState? session,
      List<TrailVlogManifest> saved = const [],
    }) {
      return ProviderScope(
        // A new scope per pump: Riverpod ignores changed overrides otherwise.
        key: UniqueKey(),
        overrides: [
          if (session != null)
            activeTrailSessionProvider
                .overrideWith((ref) => _FixedSession(ref, session)),
          homeSavedVlogsProvider.overrideWith((ref) async => saved),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: HomeVlogPanel()),
          ),
        ),
      );
    }

    testWidgets('idle: one row with NEW CUSTOM VLOG; MY VLOGS only when saved',
        (tester) async {
      await tester.pumpWidget(panelApp());
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('home_vlog_new_custom')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_vlog_my_vlogs')), findsNothing);
      expect(
          find.byKey(const ValueKey('home_vlog_running_trail')), findsNothing);

      await tester.pumpWidget(panelApp(saved: const [
        TrailVlogManifest(
          trailId: 'custom_9',
          trailTitle: 'Beach day',
          totalStops: 0,
          totalKm: 0,
          isCustom: true,
        ),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('MY VLOGS (1)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home_vlog_my_vlogs')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_vlog_saved_custom_9')),
          findsOneWidget);
      expect(find.text('CUSTOM · 0 CLIPS'), findsOneWidget);
    });

    testWidgets('running trail: next stop, tolerance badge, resume + record',
        (tester) async {
      await tester.pumpWidget(panelApp(
        session: const ActiveTrailSessionState(
          isRunning: true,
          destination: _dest,
          trailId: 'trail-124d',
          trailTitle: 'Bolinao Coast',
          totalStops: 2,
          nextStopName: 'Patar White Beach',
          nextStopPosition: 2,
          distanceToNextStopM: 1250,
          isWithinStopTolerance: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('BOLINAO COAST'), findsOneWidget);
      expect(find.text('NEXT: Patar White Beach · 1.3 KM'), findsOneWidget);
      expect(find.text('OUTSIDE TOLERANCE'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('home_vlog_resume_trail')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('home_vlog_record_clip')), findsOneWidget);

      await tester.pumpWidget(panelApp(
        session: const ActiveTrailSessionState(
          isRunning: true,
          destination: _dest,
          trailId: 'trail-124d',
          trailTitle: 'Bolinao Coast',
          nextStopName: 'Patar White Beach',
          distanceToNextStopM: 20,
          isWithinStopTolerance: true,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('IN RANGE'), findsOneWidget);
    });
  });

  group('custom JuanLog storage (Plan 124d)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('jdq124d'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
        'createCustomSession + custom clips round-trip; old manifests stay '
        'trail vlogs', () async {
      final vault = TrailVlogVault(baseDirProvider: () async => dir);
      final created = await vault.createCustomSession(title: 'Beach day');
      expect(created.isCustom, isTrue);
      expect(created.trailId, startsWith('custom_'));

      final src = File('${dir.path}${Platform.pathSeparator}raw.mp4')
        ..writeAsBytesSync([1, 2, 3]);
      await vault.saveClip(
        trailId: created.trailId,
        trailTitle: created.trailTitle,
        totalStops: 0,
        totalKm: 0,
        kind: VlogClipKind.custom,
        stopPosition: 1,
        spotName: 'Beach day',
        municipality: 'Custom JuanLog',
        sourceFilePath: src.path,
      );
      final loaded = (await vault.loadManifest(created.trailId))!;
      expect(loaded.isCustom, isTrue);
      expect(loaded.clips.single.kind, VlogClipKind.custom);
      expect(loaded.clips.single.filePath, endsWith('custom_1.mp4'));

      final renamed = await vault.renameVlog(created.trailId, 'Sunset');
      expect(renamed!.trailTitle, 'Sunset');

      final segments = VlogCompilerService.buildSegments(loaded);
      expect(segments.first.clipKind, VlogClipKind.custom);
      expect(segments.last.isOutro, isTrue);

      final legacy = TrailVlogManifest.fromJson(const {
        'trail_id': 't1',
        'trail_title': 'Old',
        'clips': [],
      });
      expect(legacy.isCustom, isFalse);
      expect(VlogClipKind.fromKey('custom'), VlogClipKind.custom);
    });
  });
}
