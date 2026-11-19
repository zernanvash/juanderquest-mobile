import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/features/navigation/widgets/adventure_arrive_overlay.dart';
import 'package:juanderquest_app/features/trail/models/trail_models.dart';
import 'package:juanderquest_app/features/trail/services/trails_api.dart';
import 'package:juanderquest_app/features/trail/trail_catalog_screen.dart';
import 'package:juanderquest_app/features/trail_vlog/models/vlog_manifest.dart';
import 'package:juanderquest_app/features/trail_vlog/services/trail_vlog_vault.dart';
import 'package:juanderquest_app/features/trail_vlog/services/vlog_camera_adapter.dart';
import 'package:juanderquest_app/features/trail_vlog/services/vlog_compiler_service.dart';
import 'package:juanderquest_app/features/trail_vlog/widgets/pixel_vlog_hud_overlay.dart';
import 'package:juanderquest_app/features/trail_vlog/widgets/pixel_vlog_recorder_sheet.dart';
import 'package:juanderquest_app/features/trail_vlog/widgets/trail_vlog_studio_sheet.dart';
import 'package:latlong2/latlong.dart';

class _FakeVlogCameraAdapter implements VlogCameraAdapter {
  _FakeVlogCameraAdapter({
    required this.tempDir,
    this.audioGranted = true,
  });

  final Directory tempDir;
  final bool audioGranted;

  bool _initialized = false;
  bool _front = false;
  bool _audio = true;
  bool disposed = false;
  int initCount = 0;
  int flipCount = 0;
  int recordCount = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isAudioEnabled => _audio;

  @override
  bool get isFrontCamera => _front;

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize({
    required bool frontCamera,
    required bool enableAudio,
  }) async {
    initCount++;
    if (_front != frontCamera && initCount > 1) {
      flipCount++;
    }
    _front = frontCamera;
    _audio = enableAudio && audioGranted;
    _initialized = true;
  }

  @override
  Future<void> startRecording() async {
    recordCount++;
  }

  @override
  Future<String> stopRecording() async {
    return '${tempDir.path}${Platform.pathSeparator}raw_clip_$recordCount.mp4';
  }

  @override
  Widget buildPreview(BuildContext context) {
    return ColoredBox(
      color: _front ? Colors.teal : Colors.brown,
      child: Center(
        child: Text(
          _front ? 'FRONT CAM PREVIEW' : 'BACK CAM PREVIEW',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _initialized = false;
  }
}

class _InMemoryTrailVlogVault extends TrailVlogVault {
  _InMemoryTrailVlogVault(this.tempDir);

  final Directory tempDir;
  final Map<String, TrailVlogManifest> _store = {};

  @override
  Future<String> compiledOutputPath(String trailId) async =>
      '${tempDir.path}${Platform.pathSeparator}compiled_$trailId.mp4';

  @override
  Future<TrailVlogManifest?> loadManifest(String trailId) async =>
      _store[trailId];

  @override
  Future<TrailVlogManifest> ensureManifest({
    required String trailId,
    required String trailTitle,
    required int totalStops,
    required double totalKm,
    int rewardPoints = 0,
  }) async {
    final existing = _store[trailId];
    if (existing != null) return existing;
    final created = TrailVlogManifest(
      trailId: trailId,
      trailTitle: trailTitle,
      totalStops: totalStops,
      totalKm: totalKm,
      rewardPoints: rewardPoints,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    _store[trailId] = created;
    return created;
  }

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
    final base = await ensureManifest(
      trailId: trailId,
      trailTitle: trailTitle,
      totalStops: totalStops,
      totalKm: totalKm,
      rewardPoints: rewardPoints,
    );
    final entry = VlogClipEntry(
      id: '${kind.key}_$stopPosition',
      kind: kind,
      stopPosition: stopPosition,
      spotId: spotId,
      spotName: spotName,
      municipality: municipality,
      capturedAtIso: DateTime.now().toUtc().toIso8601String(),
      filePath: '/mem/trail_vlogs/$trailId/${kind.key}_$stopPosition.mp4',
      durationMs: durationMs,
      cameraFacing: cameraFacing,
    );
    final nextClips = base.clips
        .where((c) => !(c.kind == kind && c.stopPosition == stopPosition))
        .toList()
      ..add(entry);
    final updated = base.copyWith(clips: nextClips);
    _store[trailId] = updated;
    return updated;
  }

  @override
  Future<TrailVlogManifest?> updatePreferences(
    String trailId, {
    VlogFrameStyle? frameStyle,
    VlogAudioMode? audioMode,
    int? rewardPoints,
  }) async {
    final existing = _store[trailId];
    if (existing == null) return null;
    final updated = existing.copyWith(
      frameStyle: frameStyle ?? existing.frameStyle,
      audioMode: audioMode ?? existing.audioMode,
      rewardPoints: rewardPoints ?? existing.rewardPoints,
    );
    _store[trailId] = updated;
    return updated;
  }

  @override
  Future<TrailVlogManifest?> recordCompilation(
    String trailId,
    VlogCompileResult result,
  ) async {
    final existing = _store[trailId];
    if (existing == null) return null;
    final updated = existing.copyWith(
      compiledPath: () => result.outputPath,
      compiledSizeBytes: () => result.sizeBytes,
    );
    _store[trailId] = updated;
    return updated;
  }

  @override
  Future<List<TrailVlogManifest>> listAllVlogs() async =>
      _store.values.toList();

  @override
  Future<void> deleteTrailVlog(String trailId) async {
    _store.remove(trailId);
  }
}

class _FakeVlogCompilerService extends VlogCompilerService {
  _FakeVlogCompilerService({
    required this.testVault,
    required this.tempDir,
  }) : super(vault: testVault, tempDirProvider: () async => tempDir);

  final TrailVlogVault testVault;
  final Directory tempDir;
  int compileCalls = 0;
  int gallerySaveCalls = 0;
  int shareCalls = 0;
  String? lastSharedPath;

  @override
  Future<VlogCompileResult> compileTrailVlog({
    required BuildContext context,
    required TrailVlogManifest manifest,
    List<TrailStop> stops = const [],
    List<double> routeCoords = const [],
  }) async {
    compileCalls++;
    final outPath = await testVault.compiledOutputPath(manifest.trailId);
    File(outPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [1, 2, 3, 4]);
    final res = VlogCompileResult(
      outputPath: outPath,
      sizeBytes: 1024,
      durationMs: 12000,
    );
    await testVault.recordCompilation(manifest.trailId, res);
    return res;
  }

  @override
  Future<Map<String, String>> extractThumbnails(List<String> clipPaths) async {
    return const {};
  }

  @override
  Future<String> saveToGallery(String filePath, String trailTitle) async {
    gallerySaveCalls++;
    return 'content://media/external/video/media/99';
  }

  @override
  Future<void> shareVlog(String filePath, String trailTitle) async {
    shareCalls++;
    lastSharedPath = filePath;
  }
}

class _InertAuth115 extends AuthNotifier {
  _InertAuth115(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = user == null ? AuthState() : AuthState(user: user, token: 't');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _FakeTrailsApi115 extends TrailsApi {
  _FakeTrailsApi115() : super(ApiClient());

  @override
  Future<TrailCatalog> fetchTrails() async => const TrailCatalog(
        items: [],
      );

  @override
  Future<List<NearbyTrail>> fetchTrailsNear({
    required double lat,
    required double lng,
    double radiusKm = 30,
    String? spotId,
  }) async =>
      const [];
}

class _StaticNavNotifier extends NavigationNotifier {
  _StaticNavNotifier(NavigationState initial)
      : super(
          apiClient: ApiClient(),
          trailsApi: _FakeTrailsApi115(),
          initialDestination: initial.destination,
        ) {
    state = initial;
  }

  @override
  Future<void> initNavigation() async {}

  @override
  Future<void> fetchRoute() async {}

  @override
  Future<void> fetchNearbyTrails() async {}
}

const _sampleTrail = TrailDetail(
  id: 'trail-coastal-115',
  slug: 'coastal-wonders',
  title: 'Coastal Wonders',
  tagline: 'Four coastal stops across Pangasinan',
  tier: TrailTier.starter,
  theme: 'nature',
  municipalities: ['Lingayen', 'Bolinao'],
  stopCount: 4,
  totalMinutes: 180,
  totalKm: 42.5,
  unlockRule: UnlockRule(type: 'free'),
  isUnlocked: true,
  rewardPoints: 100,
  intro: 'Coastal tour.',
  stops: [
    TrailStop(
      position: 1,
      spotId: 's1',
      name: 'Lingayen Beach',
      municipality: 'Lingayen',
      category: 'Beach',
      lat: 16.03,
      lng: 120.23,
      arriveOffsetMin: 10,
      dwellMin: 20,
      legMinutes: 10,
      legKm: 4.0,
      checkinRadiusM: 60,
      checkedIn: true,
      narration: 'Stop 1',
    ),
    TrailStop(
      position: 2,
      spotId: 's2',
      name: 'Hundred Islands',
      municipality: 'Alaminos',
      category: 'Nature',
      lat: 16.20,
      lng: 120.04,
      arriveOffsetMin: 60,
      dwellMin: 30,
      legMinutes: 40,
      legKm: 18.0,
      checkinRadiusM: 60,
      checkedIn: true,
      narration: 'Stop 2',
    ),
    TrailStop(
      position: 3,
      spotId: 's3',
      name: 'Patar White Beach',
      municipality: 'Bolinao',
      category: 'Beach',
      lat: 16.32,
      lng: 119.78,
      arriveOffsetMin: 120,
      dwellMin: 30,
      legMinutes: 35,
      legKm: 12.5,
      checkinRadiusM: 60,
      checkedIn: false,
      narration: 'Stop 3',
    ),
    TrailStop(
      position: 4,
      spotId: 's4',
      name: 'Cape Bolinao Lighthouse',
      municipality: 'Bolinao',
      category: 'Heritage',
      lat: 16.30,
      lng: 119.78,
      arriveOffsetMin: 160,
      dwellMin: 20,
      legMinutes: 20,
      legKm: 8.0,
      checkinRadiusM: 60,
      checkedIn: false,
      narration: 'Stop 4',
    ),
  ],
  preview: [],
);

void main() {
  late Directory tempDir;
  late TrailVlogVault vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jdq_vlog_test_');
    vault = TrailVlogVault(baseDirProvider: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Plan 115 WP-1: TrailVlogVault persistence', () {
    test(
        'saves stop and road clips atomically, reloads, updates prefs, and deletes',
        () async {
      final raw1 = File('${tempDir.path}/src1.mp4')
        ..writeAsBytesSync(const [1, 2, 3, 4]);
      final raw2 = File('${tempDir.path}/src2.mp4')
        ..writeAsBytesSync(const [5, 6, 7, 8]);

      final afterStop = await vault.saveClip(
        trailId: 'trail-1',
        trailTitle: 'Heritage Trail',
        totalStops: 4,
        totalKm: 22.0,
        rewardPoints: 50,
        kind: VlogClipKind.stop,
        stopPosition: 1,
        spotId: 'spot-1',
        spotName: 'Manaoag Basilica',
        municipality: 'Manaoag',
        sourceFilePath: raw1.path,
      );
      expect(afterStop.totalClips, 1);
      expect(afterStop.hasStopClip(1), isTrue);

      final afterRoad = await vault.saveClip(
        trailId: 'trail-1',
        trailTitle: 'Heritage Trail',
        totalStops: 4,
        totalKm: 22.0,
        kind: VlogClipKind.road,
        stopPosition: 1,
        spotName: 'On The Road',
        municipality: 'San Fabian',
        sourceFilePath: raw2.path,
        cameraFacing: 'front',
      );
      expect(afterRoad.totalClips, 2);
      // Road clip on leg 1 comes before stop 1 check-in clip.
      expect(afterRoad.clips.first.kind, VlogClipKind.road);

      final reloaded = await vault.loadManifest('trail-1');
      expect(reloaded, isNotNull);
      expect(reloaded!.totalClips, 2);
      expect(reloaded.rewardPoints, 50);

      await vault.updatePreferences(
        'trail-1',
        frameStyle: VlogFrameStyle.bamboo,
        audioMode: VlogAudioMode.bgmOnly,
      );
      await vault.recordCompilation(
        'trail-1',
        const VlogCompileResult(
          outputPath: '/tmp/out.mp4',
          sizeBytes: 4096,
          durationMs: 11000,
        ),
      );
      final list = await vault.listAllVlogs();
      expect(list, hasLength(1));
      expect(list.first.frameStyle, VlogFrameStyle.bamboo);
      expect(list.first.audioMode, VlogAudioMode.bgmOnly);
      expect(list.first.compiledSizeBytes, 4096);

      await vault.deleteTrailVlog('trail-1');
      expect(await vault.listAllVlogs(), isEmpty);
    });
  });

  group('Plan 115 WP-4: VlogCompilerService.buildSegments', () {
    test(
        '4-stop trail with 2 stop clips, 1 road clip, and 2 skipped stops builds expected sequence + outro',
        () async {
      final raw = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(const [1, 2, 3]);

      await vault.saveClip(
        trailId: _sampleTrail.id,
        trailTitle: _sampleTrail.title,
        totalStops: 4,
        totalKm: _sampleTrail.totalKm,
        rewardPoints: _sampleTrail.rewardPoints,
        kind: VlogClipKind.stop,
        stopPosition: 1,
        spotName: 'Lingayen Beach',
        municipality: 'Lingayen',
        sourceFilePath: raw.path,
      );
      await vault.saveClip(
        trailId: _sampleTrail.id,
        trailTitle: _sampleTrail.title,
        totalStops: 4,
        totalKm: _sampleTrail.totalKm,
        kind: VlogClipKind.road,
        stopPosition: 2,
        spotName: 'On The Road',
        municipality: 'Sual',
        sourceFilePath: raw.path,
      );
      final manifest = await vault.saveClip(
        trailId: _sampleTrail.id,
        trailTitle: _sampleTrail.title,
        totalStops: 4,
        totalKm: _sampleTrail.totalKm,
        kind: VlogClipKind.stop,
        stopPosition: 3,
        spotName: 'Patar White Beach',
        municipality: 'Bolinao',
        sourceFilePath: raw.path,
      );

      final segments = VlogCompilerService.buildSegments(
        manifest,
        stops: _sampleTrail.stops,
      );

      // Expected order:
      // 0: Stop 1 video (3.0s)
      // 1: Leg 2 road video (3.0s)
      // 2: Stop 2 skipped-stop image card (1.5s)
      // 3: Stop 3 video (3.0s)
      // 4: Stop 4 skipped-stop image card (1.5s)
      // 5: Outro passport stamp card (2.0s)
      expect(segments, hasLength(6));
      expect(segments[0].type, 'video');
      expect(segments[0].stopPosition, 1);
      expect(segments[1].type, 'video');
      expect(segments[1].clipKind, VlogClipKind.road);
      expect(segments[2].type, 'image_card');
      expect(segments[2].durationMs, 1500);
      expect(segments[2].label, 'Hundred Islands');
      expect(segments[3].type, 'video');
      expect(segments[3].stopPosition, 3);
      expect(segments[4].type, 'image_card');
      expect(segments[4].durationMs, 1500);
      expect(segments[4].label, 'Cape Bolinao Lighthouse');
      expect(segments[5].type, 'image_card');
      expect(segments[5].isOutro, isTrue);
      expect(segments[5].durationMs, 2000);
    });
  });

  group('Plan 115 WP-2 & WP-3: Recorder, Speed Safety & Navigation Hooks', () {
    testWidgets(
        'PixelVlogRecorderSheet flips camera, runs 3s countdown, saves clip, and handles mic-denied fallback',
        (tester) async {
      final memVault = _InMemoryTrailVlogVault(tempDir);
      final fakeCam = _FakeVlogCameraAdapter(
        tempDir: tempDir,
        audioGranted: false,
      );
      bool? sheetResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailVlogVaultProvider.overrideWithValue(memVault),
            vlogCameraAdapterFactoryProvider.overrideWithValue(() => fakeCam),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    sheetResult = await PixelVlogRecorderSheet.show(
                      context,
                      trailId: 'trail-rec',
                      trailTitle: 'Recorder Trail',
                      totalStops: 3,
                      totalKm: 15.0,
                      kind: VlogClipKind.stop,
                      stopPosition: 1,
                      spotName: 'Lingayen Capitol',
                      municipality: 'Lingayen',
                    );
                  },
                  child: const Text('OPEN REC'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN REC'));
      await tester.pumpAndSettle();

      // Mic permission fallback banner visible
      expect(find.byKey(const ValueKey('vlog_mic_off_notice')), findsOneWidget);
      expect(find.text('BACK CAM PREVIEW'), findsOneWidget);

      // Flip camera before recording
      await tester.tap(find.byKey(const ValueKey('vlog_flip_camera_button')));
      await tester.pumpAndSettle();
      expect(fakeCam.flipCount, 1);
      expect(find.text('FRONT CAM PREVIEW'), findsOneWidget);

      // Start 3.0s recording and let 8-segment countdown finish automatically
      await tester.tap(find.byKey(const ValueKey('vlog_shutter_button')));
      await tester.pump();
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('vlog_captured_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('vlog_retake_button')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('vlog_use_clip_button')), findsOneWidget);

      // Save clip -> persists in vault and disposes adapter
      await tester.tap(find.byKey(const ValueKey('vlog_use_clip_button')));
      await tester.pumpAndSettle();

      expect(sheetResult, isTrue);
      expect(fakeCam.disposed, isTrue);
      final manifest = await memVault.loadManifest('trail-rec');
      expect(manifest, isNotNull);
      expect(manifest!.totalClips, 1);
      expect(manifest.clips.first.cameraFacing, 'front');
    });

    testWidgets(
        'Speed safety lock disables stop vlog CTA in AdventureArriveOverlay and blocks +CLIP on NavigationScreen above 3 m/s',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.pixel,
          home: Scaffold(
            body: AdventureArriveOverlay(
              checkedInStop: _sampleTrail.stops.first,
              nextStop: _sampleTrail.stops[1],
              stops: _sampleTrail.stops,
              totalStops: 4,
              destinationName: 'Bolinao',
              isMovingTooFast: true,
              onRecordStopVlog: () => tapped = true,
              onContinueCheckIn: () {},
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PARK FIRST TO VLOG'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_record_stop_vlog')));
      await tester.pump();
      expect(tapped, isFalse);

      // NavigationScreen driving +CLIP lock when moving > 3.0 m/s
      const dest = NavTarget(
        name: 'Cape Bolinao Lighthouse',
        lat: 16.30,
        lng: 119.78,
      );
      final fastPos = Position(
        latitude: 16.05,
        longitude: 120.20,
        timestamp: DateTime(2026, 11, 19, 10, 0),
        accuracy: 8.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 6.5, // > 3.0 m/s
        speedAccuracy: 0,
      );
      final navState = NavigationState(
        destination: dest,
        isAdventureActive: true,
        isDirectRoute: false,
        selectedTrail: _sampleTrail,
        currentPosition: fastPos,
        route: const RouteModel(
          summary: RouteSummary.empty(),
          coordinates: [LatLng(16.03, 120.23), LatLng(16.30, 119.78)],
          maneuvers: [
            RouteManeuver(
              instruction: 'Drive north',
              distanceMeters: 400,
              timeSeconds: 40,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailVlogVaultProvider
                .overrideWithValue(_InMemoryTrailVlogVault(tempDir)),
            jdqMapFactoryProvider.overrideWithValue(() => FakeJdqMap()),
            mapStyleProvider.overrideWith((_) async => '{}'),
            navigationProvider(dest).overrideWith(
              (_) => _StaticNavNotifier(navState),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const NavigationScreen(destination: dest),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nav_road_vlog_clip')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_road_vlog_clip')));
      await tester.pump();
      expect(find.text('Park first to vlog'), findsOneWidget);
    });
  });

  group('Plan 115 WP-5 & WP-6: Studio Sheet & Trail Catalog Vlogs', () {
    testWidgets(
        'TrailVlogStudioSheet gates VIP frames, toggles audio, compiles on SAVE MP4 & SHARE VLOG, and leaves zero timers under reduced motion',
        (tester) async {
      final memVault = _InMemoryTrailVlogVault(tempDir);
      final manifest = await memVault.saveClip(
        trailId: _sampleTrail.id,
        trailTitle: _sampleTrail.title,
        totalStops: 4,
        totalKm: _sampleTrail.totalKm,
        rewardPoints: 100,
        kind: VlogClipKind.stop,
        stopPosition: 1,
        spotName: 'Lingayen Beach',
        municipality: 'Lingayen',
        sourceFilePath: '/mem/s1.mp4',
      );
      final fakeCompiler =
          _FakeVlogCompilerService(testVault: memVault, tempDir: tempDir);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailVlogVaultProvider.overrideWithValue(memVault),
            vlogCompilerServiceProvider.overrideWithValue(fakeCompiler),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: TrailVlogStudioSheet(
                manifest: manifest,
                stops: _sampleTrail.stops,
                hasVipFramesOverride: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locked VIP frame shows unlock toast
      final bambooBtn = find.byKey(const ValueKey('vlog_frame_bamboo'));
      await tester.ensureVisible(bambooBtn);
      await tester.tap(bambooBtn);
      await tester.pump();
      expect(find.text('Unlock in Shop or Juander Pass'), findsOneWidget);

      // Audio mode toggles
      final bgmOnlyBtn = find.byKey(const ValueKey('vlog_audio_bgm_only'));
      await tester.ensureVisible(bgmOnlyBtn);
      await tester.tap(bgmOnlyBtn);
      await tester.pumpAndSettle();
      final afterAudio = await memVault.loadManifest(_sampleTrail.id);
      expect(afterAudio!.audioMode, VlogAudioMode.bgmOnly);

      // SAVE MP4 compiles once and saves to gallery
      final saveBtn = find.byKey(const ValueKey('vlog_save_gallery_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(fakeCompiler.compileCalls, 1);
      expect(fakeCompiler.gallerySaveCalls, 1);
      expect(
        find.text('Saved to Gallery (Movies/JuanDerQuest)'),
        findsOneWidget,
      );

      // SHARE VLOG reuses compiled MP4 without recompiling
      final shareBtn = find.byKey(const ValueKey('vlog_share_button'));
      await tester.ensureVisible(shareBtn);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();
      expect(fakeCompiler.compileCalls, 1);
      expect(fakeCompiler.shareCalls, 1);
    });

    testWidgets(
        'TrailCatalogScreen My Trails tab displays saved vlogs and opens TrailVlogStudioSheet',
        (tester) async {
      final memVault = _InMemoryTrailVlogVault(tempDir);
      await memVault.saveClip(
        trailId: _sampleTrail.id,
        trailTitle: _sampleTrail.title,
        totalStops: 4,
        totalKm: _sampleTrail.totalKm,
        kind: VlogClipKind.stop,
        stopPosition: 1,
        spotName: 'Lingayen Beach',
        municipality: 'Lingayen',
        sourceFilePath: '/mem/s1.mp4',
      );
      final fakeCompiler =
          _FakeVlogCompilerService(testVault: memVault, tempDir: tempDir);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trailVlogVaultProvider.overrideWithValue(memVault),
            vlogCompilerServiceProvider.overrideWithValue(fakeCompiler),
            trailsApiProvider.overrideWithValue(_FakeTrailsApi115()),
            hasVipVlogFramesProvider.overrideWithValue(true),
            authProvider.overrideWith(
              (ref) => _InertAuth115(
                ref.watch(apiClientProvider),
                ref.watch(authRefreshProvider.notifier),
                UserModel(
                  id: 'u1',
                  seedId: 'scout',
                  displayName: 'Scout',
                  email: 's@jdq.ph',
                  avatarUrl: '',
                  role: 'explorer',
                  demoPoints: 100,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const TrailCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Trails'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('trail_saved_vlogs_section')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('trail_vlog_card_${_sampleTrail.id}')),
        findsOneWidget,
      );

      await tester
          .tap(find.byKey(ValueKey('trail_vlog_open_${_sampleTrail.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('vlog_studio_preview')), findsOneWidget);
      // Premium Bamboo frame is unlocked because hasVipVlogFramesProvider = true
      expect(find.text('Bamboo Frame'), findsOneWidget);
    });

    testWidgets('SkippedStopCard & OutroStampCard render cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: SkippedStopCard(
                    stopPosition: 2,
                    totalStops: 4,
                    spotName: 'Hundred Islands',
                    municipality: 'Alaminos',
                  ),
                ),
                Expanded(
                  child: OutroStampCard(
                    trailTitle: 'Coastal Wonders',
                    totalStops: 4,
                    totalKm: 42.5,
                    rewardPoints: 100,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('TRAIL COMPLETE!'), findsOneWidget);
      expect(find.text('+100 PTS'), findsOneWidget);
      expect(find.text('CHECKED IN · STOP 2 OF 4'), findsOneWidget);
    });
  });
}
