import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/app_update/data/release_manifest_client.dart';
import 'package:juanderquest_app/features/app_update/domain/update_classification.dart';
import 'package:juanderquest_app/features/app_update/domain/update_repository.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';
import 'package:juanderquest_app/features/app_update/providers/app_update_provider.dart';
import 'package:juanderquest_app/features/app_update/providers/startup_update_controller.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart'
    show AuthNotifier, AuthState, authProvider, authRefreshProvider;
import 'package:juanderquest_app/features/dashboard/home_tips.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_qotd_provider.dart';
import 'package:juanderquest_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_daily_tasks_panel.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_hero.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_promo_panel.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/providers/quest_provider.dart';
import 'package:juanderquest_app/features/spots/providers/hidden_gem_provider.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _MapAdapter implements HttpClientAdapter {
  _MapAdapter(this.responses);
  final Map<String, Map<String, dynamic>> responses;

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
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryHomeTipsStore implements HomeTipsStore {
  @override
  Future<bool> seen() async => true;
  @override
  Future<void> markSeen() async {}
  @override
  Future<void> reset() async {}
}

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'tok');
  }
  @override
  Future<void> refreshProfile() async {}
}

class _InertQuestNotifier extends QuestNotifier {
  _InertQuestNotifier(super.apiClient) {
    state = QuestState(quests: [], isLoading: false);
  }
  @override
  Future<void> fetchQuests({String? category}) async {}
}

class _InertSpotDiscoveryNotifier extends SpotDiscoveryNotifier {
  _InertSpotDiscoveryNotifier(super.ref) {
    state = const SpotDiscoveryState(
      spots: [],
      categories: [],
      isInitialLoading: false,
    );
  }
  @override
  Future<void> initialize() async {}
  @override
  Future<void> load(
      {String query = '',
      String category = '',
      String intent = '',
      bool refresh = false}) async {}
}

class _InertSubmissionNotifier extends SubmissionNotifier {
  _InertSubmissionNotifier(super.apiClient) {
    state = SubmissionState(submissions: [], isLoading: false);
  }
  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _FakeUpdateRepo implements IUpdateRepository {
  _FakeUpdateRepo([this.release]);
  final AppVersionInfo? release;

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

class _InertStartupController extends StartupUpdateController {
  _InertStartupController(super.repository, StartupGateState initial) {
    state = initial;
  }
  @override
  Future<void> initStartupGate() async {}
}

class _InertQotdNotifier extends HomeQotdNotifier {
  _InertQotdNotifier(super.ref) : super(autoLoad: false) {
    state = const AsyncValue.data(
      HomeQotdState(
        date: '2026-11-24',
        questionId: '',
        questionText: '',
        quizTitle: '',
        options: [],
      ),
    );
  }
}

ApiClient _stubApiClient() {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': null},
          ),
        );
      },
    ),
  );
  return api;
}

Widget _wrapDashboard({
  required IUpdateRepository updateRepo,
  required StartupGateState startupState,
  PromoUrlLauncher? urlLauncher,
  double textScale = 1.0,
}) {
  final api = _stubApiClient();
  final user = UserModel(
    id: 'u1',
    seedId: 'u1',
    displayName: 'Juan Traveler',
    email: 'juan@example.test',
    avatarUrl: '',
    role: 'user',
    demoPoints: 25,
    scoutReputation: 120,
  );
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      updateRepositoryProvider.overrideWithValue(updateRepo),
      startupUpdateControllerProvider.overrideWith(
        (ref) => _InertStartupController(updateRepo, startupState),
      ),
      authProvider.overrideWith(
        (ref) => _InertAuthNotifier(
            api, ref.watch(authRefreshProvider.notifier), user),
      ),
      homeTipsStoreProvider.overrideWithValue(_MemoryHomeTipsStore()),
      questProvider.overrideWith((ref) => _InertQuestNotifier(api)),
      spotDiscoveryProvider
          .overrideWith((ref) => _InertSpotDiscoveryNotifier(ref)),
      submissionProvider.overrideWith((ref) => _InertSubmissionNotifier(api)),
      homeQotdProvider.overrideWith((ref) => _InertQotdNotifier(ref)),
      homeDailyProvider.overrideWith(
        (ref) async => const HomeDailyState(
          stamps: 0,
          streak: 1,
          nominalStamps: 5,
          claimToday: false,
          claimDay: 1,
          missions: [],
          date: '2026-11-24',
        ),
      ),
      choiceOverviewProvider.overrideWith(
        (ref) async => const ChoiceOverview(
          current: null,
          nextOpensAt: null,
          nextClosesAt: null,
          nextTheme: null,
          previous: null,
          notice: null,
          votingEnabled: false,
        ),
      ),
      choiceEngagementProvider.overrideWith(
        (ref) async => const ChoiceEngagementSummary(
          currentStreak: 0,
          longestStreak: 0,
          nextMilestone: null,
          verifiedVisits: 0,
          uniqueDestinations: 0,
          municipalities: 0,
          participations: 0,
          challenges: [],
        ),
      ),
      hiddenGemProvider.overrideWith((ref) async => const []),
      if (urlLauncher != null)
        homePromoUrlLauncherProvider.overrideWithValue(urlLauncher),
    ],
    child: PixelScope(
      settings: const PixelSettings(),
      child: MaterialApp.router(
        theme: AppTheme.pixel,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Plan 121 — HomePromoPanelConfig & ReleaseManifestClient', () {
    test(
        'parses valid https promo_panel, derives fallback campaign_id, and rejects insecure URLs',
        () {
      final parsed = HomePromoPanelConfig.tryFromJson({
        'campaign_id': 'wave-1',
        'title': 'Beta Feedback',
        'body': 'Tell us what to improve next.',
        'cta_label': 'Take Survey',
        'url': 'https://forms.gle/abc123',
        'until': '2099-01-01T00:00:00Z',
      });
      expect(parsed, isNotNull);
      expect(parsed!.campaignId, 'wave-1');
      expect(parsed.ctaLabel, 'Take Survey');
      expect(parsed.hasValidHttpsUrl, isTrue);
      expect(parsed.isExpiredAt(DateTime.utc(2026, 11, 24)), isFalse);
      expect(parsed.isExpiredAt(DateTime.utc(2099, 1, 2)), isTrue);

      final fallbackId = HomePromoPanelConfig.tryFromJson({
        'campaign_id': '',
        'title': 'Fallback Promo',
        'url': 'https://forms.gle/xyz',
      });
      expect(fallbackId?.campaignId, 'Fallback Promo|https://forms.gle/xyz');
      expect(fallbackId?.ctaLabel, 'Open Form');

      expect(
        HomePromoPanelConfig.tryFromJson({
          'campaign_id': 'bad-http',
          'title': 'Unsafe',
          'url': 'http://forms.gle/unsafe',
        }),
        isNull,
      );
      expect(
        HomePromoPanelConfig.tryFromJson({
          'campaign_id': 'bad-empty-title',
          'title': '   ',
          'url': 'https://forms.gle/abc',
        }),
        isNull,
      );
    });

    test(
        'ReleaseManifestClient preserves API promo_panel when GitHub manifest has higher versionCode',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _MapAdapter({
        ReleaseManifestClient.apiManifestUrl: {
          'success': true,
          'data': {
            'schemaVersion': 1,
            'versionCode': 227,
            'versionName': '0.4.0',
            'downloadUrl': 'https://example.test/api.apk',
            'promo_panel': {
              'campaign_id': 'beta-wave-1',
              'title': 'Help Shape JuanDerQuest!',
              'body': 'Take our short feedback survey.',
              'cta_label': 'Open Form',
              'url': 'https://forms.gle/wave1',
              'until': null,
            },
          },
        },
        ReleaseManifestClient.githubManifestUrl: {
          'schemaVersion': 1,
          'versionCode': 228,
          'versionName': '0.4.1',
          'downloadUrl': 'https://example.test/gh.apk',
        },
      });

      final fetched = await ReleaseManifestClient(dio: dio).fetch();
      expect(fetched, isNotNull);
      expect(fetched!.versionCode, 228);
      expect(fetched.promoPanel?.campaignId, 'beta-wave-1');
      expect(fetched.promoPanel?.url, 'https://forms.gle/wave1');
    });
  });

  group('Plan 121 — HomePromoPanel widget & DashboardScreen integration', () {
    testWidgets('hides panel when promoPanel is null and leaves no card',
        (tester) async {
      final latest = ReleaseManifestClient.parse({
        'schemaVersion': 1,
        'versionCode': 227,
        'versionName': '0.4.0',
        'downloadUrl': 'https://example.test/api.apk',
        'promo_panel': null,
      });
      final repo = _FakeUpdateRepo(latest);

      await tester.pumpWidget(_wrapDashboard(
        updateRepo: repo,
        startupState:
            StartupGateState(phase: GatePhase.ready, latestVersion: latest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('home_promo_panel')), findsNothing);
      expect(find.byType(HomeHero), findsOneWidget);
      expect(find.byType(HomeDailyTasksPanel), findsOneWidget);
    });

    testWidgets(
        'renders below HomeHero and above HomeDailyTasksPanel, launches https URL on CTA, dismisses via FlutterSecureStorage, and re-shows on new campaign_id',
        (tester) async {
      final openedUris = <Uri>[];
      final latestWave1 = ReleaseManifestClient.parse({
        'schemaVersion': 1,
        'versionCode': 227,
        'versionName': '0.4.0',
        'downloadUrl': 'https://example.test/api.apk',
        'promo_panel': {
          'campaign_id': 'wave-1',
          'title': 'Share Your Beta Feedback!',
          'body': 'Take our 2-minute survey and tell us what to improve.',
          'cta_label': 'Open Survey',
          'url': 'https://forms.gle/wave1',
          'until': '2099-01-01T00:00:00Z',
        },
      });
      final repoWave1 = _FakeUpdateRepo(latestWave1);

      await tester.pumpWidget(_wrapDashboard(
        updateRepo: repoWave1,
        startupState: StartupGateState(
            phase: GatePhase.ready, latestVersion: latestWave1),
        urlLauncher: (uri) async {
          openedUris.add(uri);
          return true;
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final heroRect = tester.getRect(find.byType(HomeHero));
      final promoRect =
          tester.getRect(find.byKey(const ValueKey('home_promo_panel')));
      final dailyRect = tester.getRect(find.byType(HomeDailyTasksPanel));
      expect(promoRect.top, greaterThan(heroRect.bottom));
      expect(dailyRect.top, greaterThan(promoRect.bottom));

      expect(find.text('Share Your Beta Feedback!'), findsOneWidget);
      expect(find.text('OPEN SURVEY'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home_promo_cta')));
      await tester.pump();
      expect(openedUris, [Uri.parse('https://forms.gle/wave1')]);

      await tester.tap(find.byKey(const ValueKey('home_promo_dismiss')));
      await tester.pump();
      expect(find.byKey(const ValueKey('home_promo_panel')), findsNothing);

      // Re-mount with the same campaign_id (stored in FlutterSecureStorage) -> still hidden
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_wrapDashboard(
        updateRepo: repoWave1,
        startupState: StartupGateState(
            phase: GatePhase.ready, latestVersion: latestWave1),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('home_promo_panel')), findsNothing);

      // Rotate to a new campaign_id -> re-appears even though wave-1 was dismissed
      final latestWave2 = ReleaseManifestClient.parse({
        'schemaVersion': 1,
        'versionCode': 227,
        'versionName': '0.4.0',
        'downloadUrl': 'https://example.test/api.apk',
        'promo_panel': {
          'campaign_id': 'wave-2',
          'title': 'Round 2 Survey Live!',
          'body': 'New questions added.',
          'cta_label': 'Open Form',
          'url': 'https://forms.gle/wave2',
          'until': null,
        },
      });
      final repoWave2 = _FakeUpdateRepo(latestWave2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_wrapDashboard(
        updateRepo: repoWave2,
        startupState: StartupGateState(
            phase: GatePhase.ready, latestVersion: latestWave2),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('home_promo_panel')), findsOneWidget);
      expect(find.text('Round 2 Survey Live!'), findsOneWidget);
    });

    testWidgets('hides panel when until timestamp has expired', (tester) async {
      final expiredVersion = AppVersionInfo(
        versionCode: 227,
        versionName: '0.4.0',
        downloadUrl: 'https://example.test/api.apk',
        changelog: 'Expired',
        promoPanel: HomePromoPanelConfig(
          campaignId: 'expired-wave',
          title: 'Expired Promo',
          url: 'https://forms.gle/expired',
          until: DateTime.utc(2020, 1, 1),
        ),
      );
      await tester.pumpWidget(_wrapDashboard(
        updateRepo: _FakeUpdateRepo(expiredVersion),
        startupState: StartupGateState(
            phase: GatePhase.ready, latestVersion: expiredVersion),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('home_promo_panel')), findsNothing);
    });
  });
}
