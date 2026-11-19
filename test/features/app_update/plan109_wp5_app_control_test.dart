import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/app_update/data/release_manifest_client.dart';
import 'package:juanderquest_app/features/app_update/domain/update_repository.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';
import 'package:juanderquest_app/features/app_update/providers/app_update_provider.dart';
import 'package:juanderquest_app/features/app_update/providers/startup_update_controller.dart';
import 'package:juanderquest_app/features/app_update/widgets/startup_update_gate.dart';
import 'package:juanderquest_app/features/app_update/widgets/update_dialog.dart';

class _FakeUpdateRepo implements IUpdateRepository {
  AppVersionInfo? release;
  _FakeUpdateRepo(this.release);

  @override
  Future<AppVersionInfo?> fetchBackendVersionMetadata({
    Duration timeout = const Duration(seconds: 3),
  }) async =>
      release;

  @override
  Future<bool> isDartPatchAvailable() async => false;

  @override
  Future<bool> downloadAndInstallDartPatch({
    void Function(double progress)? onProgress,
  }) async =>
      false;

  @override
  Future<bool> syncContentBundle(
    ContentManifestMetadata metadata, {
    void Function(double progress)? onProgress,
  }) async =>
      false;

  @override
  Future<void> restartApp() async {}
}

class _TestAppUpdateNotifier extends AppUpdateNotifier {
  _TestAppUpdateNotifier(IUpdateRepository repo, {int installedBuild = 223})
      : super(repository: repo) {
    state = state.copyWith(
      installedVersionName: '0.3.9',
      installedVersionCode: installedBuild,
    );
  }

  void setRelease(AppVersionInfo info) {
    state = state.copyWith(latestVersion: info);
  }
}

class _MapAdapter implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> responses;
  _MapAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = responses[options.uri.toString()];
    if (payload == null) {
      return ResponseBody.fromString('Not Found', 404);
    }
    return ResponseBody.fromString(
      _encodeJson(payload),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _encodeJson(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return value.toString();
  if (value is String) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    return '"$escaped"';
  }
  if (value is List) {
    return '[${value.map(_encodeJson).join(',')}]';
  }
  if (value is Map) {
    final entries = value.entries
        .map((e) => '${_encodeJson(e.key.toString())}:${_encodeJson(e.value)}')
        .join(',');
    return '{$entries}';
  }
  return _encodeJson(value.toString());
}

Widget _wrapPixelApp(
  Widget child, {
  List<Override> overrides = const [],
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: overrides,
    child: PixelScope(
      settings: const PixelSettings(),
      child: MaterialApp(
        theme: AppTheme.pixel,
        builder: (context, widget) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
            child: widget ?? const SizedBox(),
          );
        },
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'JuanDerQuest',
      packageName: 'dev.zernanvash.juanderquest',
      version: '0.3.9',
      buildNumber: '223',
      buildSignature: '',
    );
  });

  group('Plan 109 WP-5 — AppVersionInfo & ReleaseManifestClient', () {
    test('parses min_supported_build and announcement variants', () {
      final info = AppVersionInfo.fromJson({
        'schemaVersion': 1,
        'versionCode': 223,
        'versionName': '0.3.9',
        'downloadUrl': 'https://example.test/app.apk',
        'min_supported_build': 230,
        'announcement': {
          'text': '  Scheduled maintenance tonight at 11 PM PHT.  ',
          'severity': 'warning',
          'until': '2099-01-01T00:00:00Z',
        },
      });
      expect(info.minSupportedBuild, 230);
      expect(info.effectiveMinSupportedBuild, 230);
      expect(info.announcement, isNotNull);
      expect(
        info.announcement!.text,
        'Scheduled maintenance tonight at 11 PM PHT.',
      );
      expect(info.announcement!.isWarning, isTrue);
      expect(info.announcement!.isExpiredAt(DateTime.utc(2026, 11, 19)), isFalse);

      final infoDefaultSeverity = AppVersionInfo.fromJson({
        'schemaVersion': 1,
        'versionCode': 223,
        'versionName': '0.3.9',
        'downloadUrl': 'https://example.test/app.apk',
        'announcement': {
          'text': 'Fiesta weekend double stamps!',
          'severity': 'unknown_value',
          'until': null,
        },
      });
      expect(infoDefaultSeverity.announcement!.severity, 'info');
      expect(infoDefaultSeverity.announcement!.isWarning, isFalse);

      final blankAnnouncement = AppVersionInfo.fromJson({
        'schemaVersion': 1,
        'versionCode': 223,
        'versionName': '0.3.9',
        'downloadUrl': 'https://example.test/app.apk',
        'announcement': {'text': '   ', 'severity': 'info', 'until': null},
      });
      expect(blankAnnouncement.announcement, isNull);
    });

    test(
        'ReleaseManifestClient preserves API min_supported_build and announcement when GitHub manifest has higher versionCode',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _MapAdapter({
        ReleaseManifestClient.apiManifestUrl: {
          'success': true,
          'data': {
            'schemaVersion': 1,
            'versionCode': 223,
            'versionName': '0.3.9',
            'downloadUrl': 'https://example.test/api.apk',
            'min_supported_build': 225,
            'announcement': {
              'text': 'Please update to v0.3.10.',
              'severity': 'warning',
              'until': null,
            },
          },
        },
        ReleaseManifestClient.githubManifestUrl: {
          'schemaVersion': 1,
          'versionCode': 226,
          'versionName': '0.3.10',
          'downloadUrl': 'https://example.test/gh.apk',
        },
      });

      final client = ReleaseManifestClient(dio: dio);
      final fetched = await client.fetch();
      expect(fetched, isNotNull);
      expect(fetched!.versionCode, 226);
      expect(fetched.minSupportedBuild, 225);
      expect(fetched.effectiveMinSupportedBuild, 225);
      expect(fetched.announcement?.text, 'Please update to v0.3.10.');
      expect(fetched.announcement?.isWarning, isTrue);
    });
  });

  group('Plan 109 WP-5 — StartupUpdateGate & AppAnnouncementHost', () {
    testWidgets(
        'StartupUpdateGate blocks with _BaseRequiredView and build summary when min_supported_build > installed',
        (tester) async {
      final repo = _FakeUpdateRepo(
        AppVersionInfo.fromJson({
          'schemaVersion': 1,
          'versionCode': 225,
          'versionName': '0.3.10',
          'downloadUrl': 'https://example.test/app.apk',
          'min_supported_build': 225,
        }),
      );
      final startup = StartupUpdateController(repo);
      await startup.initStartupGate();

      await tester.pumpWidget(
        _wrapPixelApp(
          const StartupUpdateGate(child: Scaffold(body: Text('APP_HOME'))),
          overrides: [
            updateRepositoryProvider.overrideWithValue(repo),
            startupUpdateControllerProvider.overrideWith((_) => startup),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('PLATFORM UPDATE REQUIRED'), findsOneWidget);
      expect(
        find.text('Minimum required: Build 225 · Installed: Build 223'),
        findsOneWidget,
      );
      expect(find.text('APP_HOME'), findsNothing);
    });

    testWidgets(
        'StartupUpdateGate switches to _BaseRequiredView when appUpdateProvider later fetches higher min_supported_build',
        (tester) async {
      final repo = _FakeUpdateRepo(
        AppVersionInfo.fromJson({
          'schemaVersion': 1,
          'versionCode': 223,
          'versionName': '0.3.9',
          'downloadUrl': 'https://example.test/app.apk',
          'min_supported_build': 223,
        }),
      );
      final startup = StartupUpdateController(repo);
      await startup.initStartupGate();
      final appUpdate = _TestAppUpdateNotifier(repo);

      await tester.pumpWidget(
        _wrapPixelApp(
          const StartupUpdateGate(child: Scaffold(body: Text('APP_HOME'))),
          overrides: [
            updateRepositoryProvider.overrideWithValue(repo),
            startupUpdateControllerProvider.overrideWith((_) => startup),
            appUpdateProvider.overrideWith((_) => appUpdate),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('APP_HOME'), findsOneWidget);

      appUpdate.setRelease(
        AppVersionInfo.fromJson({
          'schemaVersion': 1,
          'versionCode': 224,
          'versionName': '0.3.10',
          'downloadUrl': 'https://example.test/app.apk',
          'min_supported_build': 224,
        }),
      );
      await tester.pump();

      expect(find.text('PLATFORM UPDATE REQUIRED'), findsOneWidget);
      expect(
        find.text('Minimum required: Build 224 · Installed: Build 223'),
        findsOneWidget,
      );
      expect(find.text('APP_HOME'), findsNothing);
    });

    testWidgets(
        'AppAnnouncementBanner renders active info/warning announcements, dismisses, and reappears on text change',
        (tester) async {
      final repo = _FakeUpdateRepo(
        AppVersionInfo.fromJson({
          'schemaVersion': 1,
          'versionCode': 223,
          'versionName': '0.3.9',
          'downloadUrl': 'https://example.test/app.apk',
          'announcement': {
            'text': 'Fiesta event live in Lingayen!',
            'severity': 'info',
            'until': '2099-01-01T00:00:00Z',
          },
        }),
      );
      final startup = StartupUpdateController(repo);
      await startup.initStartupGate();
      final appUpdate = _TestAppUpdateNotifier(repo);
      final dismissed = DismissedAnnouncementNotifier();

      await tester.pumpWidget(
        _wrapPixelApp(
          const StartupUpdateGate(child: Scaffold(body: Text('APP_HOME'))),
          overrides: [
            updateRepositoryProvider.overrideWithValue(repo),
            startupUpdateControllerProvider.overrideWith((_) => startup),
            appUpdateProvider.overrideWith((_) => appUpdate),
            dismissedAnnouncementProvider.overrideWith((_) => dismissed),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Fiesta event live in Lingayen!'), findsOneWidget);
      expect(find.byIcon(Icons.campaign_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('dismiss_app_announcement_btn')));
      await tester.pump();
      expect(find.text('Fiesta event live in Lingayen!'), findsNothing);

      // New announcement text re-shows banner as warning.
      appUpdate.setRelease(
        AppVersionInfo.fromJson({
          'schemaVersion': 1,
          'versionCode': 223,
          'versionName': '0.3.9',
          'downloadUrl': 'https://example.test/app.apk',
          'announcement': {
            'text': 'Server maintenance at 10 PM.',
            'severity': 'warning',
            'until': null,
          },
        }),
      );
      await tester.pump();

      expect(find.text('Server maintenance at 10 PM.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Expired announcements remain hidden', (tester) async {
      final repo = _FakeUpdateRepo(
        AppVersionInfo.fromJson({
          'schemaVersion': 1,
          'versionCode': 223,
          'versionName': '0.3.9',
          'downloadUrl': 'https://example.test/app.apk',
          'announcement': {
            'text': 'Expired notice',
            'severity': 'warning',
            'until': '2020-01-01T00:00:00Z',
          },
        }),
      );
      final startup = StartupUpdateController(repo);
      await startup.initStartupGate();
      final dismissed = DismissedAnnouncementNotifier();

      await tester.pumpWidget(
        _wrapPixelApp(
          const StartupUpdateGate(child: Scaffold(body: Text('APP_HOME'))),
          overrides: [
            updateRepositoryProvider.overrideWithValue(repo),
            startupUpdateControllerProvider.overrideWith((_) => startup),
            dismissedAnnouncementProvider.overrideWith((_) => dismissed),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Expired notice'), findsNothing);
      expect(find.text('APP_HOME'), findsOneWidget);
    });

    testWidgets(
        'UpdateDialog hides Later button and blocks pop when min_supported_build > installedBuild',
        (tester) async {
      final repo = _FakeUpdateRepo(
        AppVersionInfo.fromJson({
          'schemaVersion': 1,
          'versionCode': 224,
          'versionName': '0.3.10',
          'downloadUrl': 'https://example.test/app.apk',
          'min_supported_build': 224,
          'changelog': 'Required security update.',
        }),
      );
      final appUpdate = _TestAppUpdateNotifier(repo);
      appUpdate.setRelease(repo.release!);

      await tester.pumpWidget(
        _wrapPixelApp(
          Scaffold(
            body: UpdateDialog(versionInfo: repo.release!),
          ),
          overrides: [
            updateRepositoryProvider.overrideWithValue(repo),
            appUpdateProvider.overrideWith((_) => appUpdate),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Later'), findsNothing);
      expect(find.text('Update Now'), findsOneWidget);
      final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
      expect(popScope.canPop, isFalse);
    });
  });

  group('Plan 109 WP-5 — Small-viewport 2.0x text overflow checks', () {
    const longAnnouncement =
        'Scheduled server maintenance tonight from 11:00 PM to 11:30 PM PHT. Please finish and submit active quest attempts beforehand!';

    for (final entry in {
      'portrait 320x568': const Size(320, 568),
      'landscape 568x320': const Size(568, 320),
    }.entries) {
      testWidgets('AppAnnouncementHost has 0 overflow on ${entry.key} at 2.0x',
          (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _FakeUpdateRepo(
          AppVersionInfo.fromJson({
            'schemaVersion': 1,
            'versionCode': 223,
            'versionName': '0.3.9',
            'downloadUrl': 'https://example.test/app.apk',
            'announcement': {
              'text': longAnnouncement,
              'severity': 'warning',
              'until': null,
            },
          }),
        );
        final startup = StartupUpdateController(repo);
        await startup.initStartupGate();
        final dismissed = DismissedAnnouncementNotifier();

        await tester.pumpWidget(
          _wrapPixelApp(
            const StartupUpdateGate(child: Scaffold(body: SizedBox())),
            textScale: 2.0,
            overrides: [
              updateRepositoryProvider.overrideWithValue(repo),
              startupUpdateControllerProvider.overrideWith((_) => startup),
              dismissedAnnouncementProvider.overrideWith((_) => dismissed),
            ],
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('dismiss_app_announcement_btn')),
            findsOneWidget);
      });

      testWidgets(
          'StartupUpdateGate baseRequired view has 0 overflow on ${entry.key} at 2.0x',
          (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _FakeUpdateRepo(
          AppVersionInfo.fromJson({
            'schemaVersion': 1,
            'versionCode': 230,
            'versionName': '0.4.0',
            'downloadUrl': 'https://example.test/app.apk',
            'min_supported_build': 230,
            'changelog': 'Critical platform update.',
          }),
        );
        final startup = StartupUpdateController(repo);
        await startup.initStartupGate();

        await tester.pumpWidget(
          _wrapPixelApp(
            const StartupUpdateGate(child: Scaffold(body: SizedBox())),
            textScale: 2.0,
            overrides: [
              updateRepositoryProvider.overrideWithValue(repo),
              startupUpdateControllerProvider.overrideWith((_) => startup),
            ],
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('PLATFORM UPDATE REQUIRED'), findsOneWidget);
      });
    }
  });
}
