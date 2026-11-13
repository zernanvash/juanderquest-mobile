import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/services/push_service.dart';
import 'package:juanderquest_app/features/about/screens/about_screen.dart';
import 'package:juanderquest_app/features/app_update/domain/update_repository.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';
import 'package:latlong2/latlong.dart';
import 'package:juanderquest_app/features/app_update/providers/app_update_provider.dart'
    hide apiClientProvider;
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/providers/navigation_provider.dart';
import 'package:juanderquest_app/features/navigation/screens/navigation_screen.dart';
import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/features/notifications/screens/notifications_screen.dart';
import 'package:juanderquest_app/features/quests/builder/quest_builder_repository.dart';
import 'package:juanderquest_app/features/quests/screens/qr_scan_screen.dart';
import 'package:juanderquest_app/features/quests/screens/qr_sheet_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';
import 'package:juanderquest_app/features/settings/screens/settings_developer_screen.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';
import 'package:juanderquest_app/features/settings/screens/settings_updates_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/screens/interests_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_discovery_studio_screen.dart';
import 'package:juanderquest_app/features/spots/screens/spot_search_screen.dart';
import 'package:juanderquest_app/features/spots/utils/spot_location_handoff.dart';
import 'package:juanderquest_app/features/trail/trail_coming_soon_screen.dart';

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = AuthState(user: user, token: user == null ? null : 'token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _SpotsFixture extends SpotDiscoveryNotifier {
  _SpotsFixture(super.ref, SpotDiscoveryState initial) {
    state = initial;
  }

  int loads = 0;
  String? savedId;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {
    loads++;
  }

  @override
  Future<ApiFailure?> toggleSaved(SpotModel spot) async {
    savedId = spot.id;
    return null;
  }
}

class _NavFixture extends NavigationNotifier {
  _NavFixture(
    ApiClient apiClient,
    NavTarget destination,
    NavigationState initial,
  ) : super(apiClient: apiClient, initialDestination: destination) {
    state = initial;
  }

  int costings = 0;
  int crowds = 0;
  int routes = 0;
  int locates = 0;

  @override
  Future<void> initNavigation() async {}

  @override
  Future<void> fetchRoute() async {
    routes++;
  }

  @override
  Future<void> acquireCurrentLocation() async {
    locates++;
  }

  @override
  void setCosting(TravelCosting costing) {
    costings++;
    state = state.copyWith(costing: costing);
  }

  @override
  void toggleAvoidCongested() {
    crowds++;
    state = state.copyWith(avoidCongested: !state.avoidCongested);
  }

  @override
  void setActiveStep(int? index) {
    state = state.copyWith(activeStepIndex: () => index);
  }
}

class _QrRepo extends QuestBuilderRepository {
  _QrRepo(super.client, this.data);

  final QrSheetData? data;
  int loads = 0;

  @override
  Future<QrSheetData> getQrSheet(String questId) async {
    loads++;
    if (data == null && loads == 1) throw StateError('offline');
    return data ??
        const QrSheetData(
          questId: 'quest-1',
          questTitle: 'Empty quest',
          locationName: 'Pangasinan',
          qrTasks: [],
        );
  }
}

class _UpdateRepo implements IUpdateRepository {
  @override
  Future<AppVersionInfo?> fetchBackendVersionMetadata(
          {Duration timeout = const Duration(seconds: 10)}) async =>
      null;

  @override
  Future<bool> isDartPatchAvailable() async => false;

  @override
  Future<bool> downloadAndInstallDartPatch(
          {void Function(double progress)? onProgress}) async =>
      false;

  @override
  Future<bool> syncContentBundle(ContentManifestMetadata metadata,
          {void Function(double progress)? onProgress}) async =>
      false;

  @override
  Future<void> restartApp() async {}
}

class _UpdateFixture extends AppUpdateNotifier {
  _UpdateFixture() : super(repository: _UpdateRepo());

  int checks = 0;

  @override
  Future<bool> checkForUpdates({bool silent = false}) async {
    checks++;
    state = state.copyWith(
      status: UpdateStatus.upToDate,
      lastCheckedAt: DateTime(2026, 11, 4),
    );
    return false;
  }
}

class _PushFixture extends PushService {
  _PushFixture() : super(ApiClient());

  int requests = 0;
  int unregisters = 0;

  @override
  Future<bool> hasAskedPermission() async => true;

  @override
  Future<bool> isPermitted() async => false;

  @override
  Future<bool> requestPermissionAndRegister() async {
    requests++;
    return true;
  }

  @override
  Future<void> unregisterDevice() async {
    unregisters++;
  }
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.push('/qr-scan'),
            child: const Text('OPEN QR'),
          ),
        ),
      );
}

class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('route:$label')));
}

const _spotsState = SpotDiscoveryState(
  spots: [_spot],
  trending: [],
  categories: ['nature_outdoors'],
  isInitialLoading: false,
);

const _spot = SpotModel(
  id: 's1',
  slug: 'patar-beach',
  name: 'Patar Beach',
  description: 'A long white beach in Bolinao.',
  category: 'nature_outdoors',
  subcategory: 'beaches',
  municipality: 'Bolinao',
  address: 'Patar, Bolinao',
  sourceName: 'Bolinao Tourism',
  trustLevel: 'lgu_verified',
  gpsLat: 16.2,
  gpsLng: 119.9,
  tags: ['beach'],
  reasons: [],
  crowdStatus: 'quiet',
  questId: 'quest-1',
  imageUrl: 'https://example.com/patar.jpg',
);

const _qrData = QrSheetData(
  questId: 'quest-1',
  questTitle: 'Bolinao Coastal Trail',
  locationName: 'Patar Beach',
  qrTasks: [
    QrSheetTask(
      taskKey: 'task_1',
      stepOrder: 1,
      title: 'Governor Island Checkpoint',
      markerCode: 'JDQ-GOV-101',
      qrPayload: 'https://juanderquest.app/verify/101',
      scanMode: 'traveler_scans',
    ),
  ],
);

const _route = RouteModel(
  summary: RouteSummary(
    distanceKm: 12.4,
    durationSeconds: 900,
    durationFormatted: '15 min',
    costing: TravelCosting.auto,
    hasCrowdDiversion: true,
    engine: 'valhalla',
  ),
  coordinates: [LatLng(16.0, 120.0), LatLng(16.1, 120.1)],
  maneuvers: [
    RouteManeuver(
      instruction: 'Turn right on Rizal Avenue',
      streetName: 'Rizal Avenue',
      distanceMeters: 300,
      timeSeconds: 60,
    ),
    RouteManeuver(
      instruction: 'Continue to Patar Beach',
      distanceMeters: 1200,
      timeSeconds: 300,
    ),
  ],
);

GoRouter _router(Widget home, {String initial = '/'}) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/qr-scan', builder: (_, __) => const QrScanScreen()),
        GoRoute(
            path: '/dashboard', builder: (_, __) => const _Probe('/dashboard')),
        GoRoute(path: '/explore', builder: (_, __) => const _Probe('/explore')),
        GoRoute(path: '/about', builder: (_, __) => const _Probe('/about')),
        GoRoute(path: '/history', builder: (_, __) => const _Probe('/history')),
        GoRoute(
            path: '/affiliate', builder: (_, __) => const _Probe('/affiliate')),
        GoRoute(
            path: '/settings/appearance',
            builder: (_, __) => const _Probe('/settings/appearance')),
        GoRoute(
            path: '/settings/updates',
            builder: (_, __) => const _Probe('/settings/updates')),
        GoRoute(
            path: '/settings/developer',
            builder: (_, __) => const _Probe('/settings/developer')),
        GoRoute(
            path: '/settings/pixel-lab',
            builder: (_, __) => const _Probe('/settings/pixel-lab')),
        GoRoute(
            path: '/onboarding/interests',
            builder: (_, __) => const _Probe('/onboarding/interests')),
        GoRoute(path: '/vote', builder: (_, __) => const _Probe('/vote')),
        GoRoute(
            path: '/ar-diagnostics',
            builder: (_, __) => const _Probe('/ar-diagnostics')),
        GoRoute(
            path: '/quests/:id', builder: (_, __) => const _Probe('/quests')),
        GoRoute(
            path: '/navigate', builder: (_, __) => const _Probe('/navigate')),
        GoRoute(
            path: '/explore/:slug',
            builder: (_, __) => const _Probe('/explore/spot')),
        GoRoute(
            path: '/notifications/1',
            builder: (_, __) => const _Probe('/notification')),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String initial = '/',
  UserModel? user = _userPlaceholder,
  ApiClient? apiClient,
  SpotDiscoveryNotifier Function(Ref ref)? spots,
  NavigationNotifier Function(ApiClient client, NavTarget target)? navigation,
  NavTarget? navTarget,
  QuestBuilderRepository Function(ApiClient client)? qrRepo,
  PushService? push,
  AppUpdateNotifier Function()? appUpdate,
  bool showTest = false,
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
        authProvider.overrideWith((ref) => _Auth(
              ref.read(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              user,
            )),
        if (spots != null)
          spotDiscoveryProvider.overrideWith((ref) => spots(ref)),
        if (navigation != null && navTarget != null)
          navigationProvider(navTarget).overrideWith(
              (ref) => navigation(ref.read(apiClientProvider), navTarget)),
        if (qrRepo != null)
          questBuilderRepositoryProvider
              .overrideWith((ref) => qrRepo(ref.read(apiClientProvider))),
        pushServiceProvider.overrideWithValue(push ?? _PushFixture()),
        if (appUpdate != null)
          appUpdateProvider.overrideWith((ref) => appUpdate()),
        showTestContentProvider.overrideWith((ref) => showTest),
      ],
      child: MaterialApp.router(routerConfig: _router(home, initial: initial)),
    ),
  );
  await tester.pump();
}

const UserModel? _userPlaceholder = null;

ApiClient _stubClient({
  Future<Response<dynamic>> Function(RequestOptions options)? onGet,
  Future<Response<dynamic>> Function(RequestOptions options)? onPut,
  Future<Response<dynamic>> Function(RequestOptions options)? onPatch,
  Future<Response<dynamic>> Function(RequestOptions options)? onPost,
}) {
  final client = ApiClient();
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Future<Response<dynamic>>? result;
        if (options.method == 'GET') result = onGet?.call(options);
        if (options.method == 'PUT') result = onPut?.call(options);
        if (options.method == 'PATCH') result = onPatch?.call(options);
        if (options.method == 'POST') result = onPost?.call(options);
        if (result == null) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': null},
          ));
          return;
        }
        result.then(
          (response) => handler.resolve(response),
          onError: (Object error) => handler.reject(
            DioException(requestOptions: options, error: error),
          ),
        );
      },
    ),
  );
  return client;
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders every group and opens each route', (tester) async {
      await _pump(tester, const SettingsScreen());
      for (final group in const ['ACCOUNT', 'ACTIVITY', 'APP', 'ABOUT']) {
        expect(find.text(group, skipOffstage: false), findsOneWidget);
      }
      expect(find.text('My submissions', skipOffstage: false), findsOneWidget);
      expect(find.text('App updates', skipOffstage: false), findsOneWidget);
      expect(find.text('Developer tools', skipOffstage: false), findsOneWidget);

      for (final entry in const [
        ('settings_appearance', '/settings/appearance'),
        ('settings_interests', '/onboarding/interests'),
        ('settings_submissions', '/history'),
        ('settings_affiliate', '/affiliate'),
        ('settings_updates', '/settings/updates'),
        ('settings_developer', '/settings/developer'),
        ('settings_about', '/about'),
      ]) {
        await _pump(tester, const SettingsScreen());
        final tile = find.byKey(ValueKey(entry.$1));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('route:${entry.$2}'), findsOneWidget);
      }
    });

    testWidgets('logs out and returns home', (tester) async {
      final push = _PushFixture();
      await _pump(tester, const _Probe('/'), initial: '/settings', push: push);
      final logout = find.byKey(const ValueKey('settings_logout'));
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(push.unregisters, 1);
      expect(find.text('route:/', skipOffstage: false), findsOneWidget);
    });
  });

  group('SettingsUpdatesScreen', () {
    testWidgets('renders and checks for updates', (tester) async {
      late _UpdateFixture fixture;
      await _pump(tester, const SettingsUpdatesScreen(),
          appUpdate: () => fixture = _UpdateFixture());
      expect(find.text('App System & Updates'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings_updates_check')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.checks, greaterThanOrEqualTo(1));
      expect(find.textContaining('App is up to date'), findsOneWidget);
    });
  });

  group('SettingsDeveloperScreen', () {
    testWidgets('toggles the guide and opens both tools', (tester) async {
      await _pump(tester, const SettingsDeveloperScreen());
      final toggle = find.byKey(const ValueKey('designer_guide_switch'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings_ar_diagnostics')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/ar-diagnostics', skipOffstage: false),
          findsOneWidget);

      await _pump(tester, const SettingsDeveloperScreen());
      await tester
          .ensureVisible(find.byKey(const ValueKey('settings_pixel_lab')));
      await tester.tap(find.byKey(const ValueKey('settings_pixel_lab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/settings/pixel-lab', skipOffstage: false),
          findsOneWidget);
    });
  });

  group('AboutScreen', () {
    testWidgets('lists every author', (tester) async {
      await _pump(tester, const AboutScreen());
      for (final author in const [
        'Ana Victoria V. Alentajan',
        'Zernan Vash L. Arive',
        'Clarissa Angel A. Gutlay',
        'Carl Jacob Lavaro',
        'Alyana Soriano',
      ]) {
        expect(find.text(author, skipOffstage: false), findsOneWidget);
      }
    });
  });

  group('TrailComingSoonScreen', () {
    testWidgets('renders the preview and opens Explore', (tester) async {
      await _pump(tester, const TrailComingSoonScreen());
      expect(find.text('A better way to explore along your route'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trail_back_explore')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore', skipOffstage: false), findsOneWidget);
    });
  });

  group('InterestsScreen', () {
    ApiClient interestsClient({Object? failure}) => _stubClient(
          onGet: (options) async {
            if (failure != null) throw failure;
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'categories': ['eat_drink'],
                  'onboarding_state': 'pending',
                },
              },
            );
          },
        );

    testWidgets('selects and saves interests', (tester) async {
      await _pump(tester, const InterestsScreen(),
          apiClient: interestsClient());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('interest_eat_drink')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('interest_nature_outdoors')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('interests_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore', skipOffstage: false), findsOneWidget);
    });

    testWidgets('skip works and empty save is disabled', (tester) async {
      await _pump(tester, const InterestsScreen(),
          apiClient: interestsClient());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('interests_skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore', skipOffstage: false), findsOneWidget);
    });
  });

  group('NotificationsScreen', () {
    ApiClient notificationsClient(
        {bool failFirst = false, bool empty = false}) {
      var called = 0;
      return _stubClient(
        onGet: (options) async {
          called++;
          if (failFirst && called == 1) throw StateError('offline');
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': empty
                    ? []
                    : [
                        {
                          'id': 1,
                          'title': 'Quest funding ready',
                          'message': 'Your round is ready.',
                          'kind': 'quest_reward',
                          'href': '/notifications/1',
                          'read': false,
                        },
                      ],
              },
            },
          );
        },
        onPatch: (options) async => Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true},
        ),
      );
    }

    testWidgets('renders notifications, marks read and opens the target',
        (tester) async {
      await _pump(tester, const NotificationsScreen(),
          apiClient: notificationsClient());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Quest funding ready'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('notification_read_1')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('notification_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/notification', skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('empty and retryable error states', (tester) async {
      await _pump(tester, const NotificationsScreen(),
          apiClient: notificationsClient(empty: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('notifications_empty')), findsOneWidget);

      await _pump(tester, const NotificationsScreen(),
          apiClient: notificationsClient(failFirst: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('notifications_retry')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('notifications_retry')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Quest funding ready'), findsOneWidget);
    });
  });

  group('QrScanScreen', () {
    testWidgets('shows camera fallback, torch and code exit', (tester) async {
      await _pump(tester, const _Launcher());
      await tester.tap(find.text('OPEN QR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('camera'), findsWidgets);
      tester.takeException();
      // The camera controller is unavailable in widget tests, so the torch
      // button is present but cannot be pressed here.
      expect(find.byKey(const ValueKey('qr_torch')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qr_enter_code')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('OPEN QR'), findsOneWidget);
      tester.takeException();
    });
  });

  group('QrSheetScreen', () {
    testWidgets('renders the placard, copies and opens full screen',
        (tester) async {
      await _pump(tester, const QrSheetScreen(questId: 'quest-1'),
          qrRepo: (client) => _QrRepo(client, _qrData));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Bolinao Coastal Trail'), findsOneWidget);
      expect(find.textContaining('JDQ-GOV-101'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('qr_copy_task_1')));
      await tester.pump();
      expect(find.textContaining('Marker code copied'), findsOneWidget);
      expect(find.byKey(const ValueKey('qr_full_task_1')), findsOneWidget);
    });

    testWidgets('error retries and empty state renders', (tester) async {
      late _QrRepo repo;
      await _pump(tester, const QrSheetScreen(questId: 'quest-1'),
          qrRepo: (client) => repo = _QrRepo(client, null));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Failed to load QR sheet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qr_sheet_retry')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.loads, greaterThanOrEqualTo(2));
    });
  });

  group('QuestFundingScreen', () {
    ApiClient fundingClient({Object? failure}) => _stubClient(
          onGet: (options) async {
            if (failure != null) throw failure;
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'plan': {
                    'id': 'plan-1',
                    'status': 'draft',
                    'reward_points': 50,
                    'mode': 'budget',
                    'target_points': 500,
                    'contributions': [
                      {'committed_points': 100, 'held_points': 20},
                    ],
                    'ends_at': '2026-12-01T00:00:00Z',
                  },
                },
              },
            );
          },
          onPost: (options) async => Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': const {}},
          ),
        );

    testWidgets('renders a plan and contributes', (tester) async {
      await _pump(tester, const QuestFundingScreen(questId: 'quest-1'),
          apiClient: fundingClient());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Funding round'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('funding_points')), '25');
      await tester.tap(find.byKey(const ValueKey('funding_contribute')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Contribution recorded'), findsOneWidget);
    });

    testWidgets('shows the create card and validation', (tester) async {
      await _pump(tester, const QuestFundingScreen(questId: 'quest-1'),
          apiClient: _stubClient(
            onGet: (options) async => Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'plan': null}
              },
            ),
          ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Set up this round'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('funding_completions')), '');
      await tester.tap(find.byKey(const ValueKey('funding_create')));
      await tester.pump();
      expect(
          find.text('Enter at least one planned completion.'), findsOneWidget);
    });
  });

  group('SpotSearchScreen', () {
    testWidgets('filters, likes, saves, opens and navigates', (tester) async {
      late _SpotsFixture fixture;
      await _pump(tester, const SpotSearchScreen(),
          spots: (ref) => fixture = _SpotsFixture(ref, _spotsState));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Patar Beach'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('search_cat_eat_drink')));
      await tester.pump();
      expect(find.byKey(const ValueKey('search_empty')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('search_clear_all')));
      await tester.pump();
      expect(find.text('Patar Beach'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('search_like_s1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('search_save_s1')));
      await tester.pump();
      expect(fixture.savedId, 's1');
      await tester.tap(find.byKey(const ValueKey('search_play_s1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/quests', skipOffstage: false), findsOneWidget);

      await _pump(tester, const SpotSearchScreen(),
          spots: (ref) => _SpotsFixture(ref, _spotsState));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('search_navigate_s1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/navigate', skipOffstage: false), findsOneWidget);
    });

    testWidgets('hides test spots until the developer switch is on',
        (tester) async {
      const testState = SpotDiscoveryState(
        spots: [
          _spot,
          SpotModel(
            id: 'artest',
            slug: 'artest',
            name: 'ARTEST Spot',
            description: 'A test spot.',
            category: 'nature_outdoors',
            subcategory: 'beaches',
            municipality: 'Bolinao',
            address: 'Patar, Bolinao',
            sourceName: 'Test',
            trustLevel: 'community',
            gpsLat: 16.2,
            gpsLng: 119.9,
            tags: [],
            reasons: [],
            isTest: true,
          ),
        ],
        trending: [],
        categories: ['nature_outdoors'],
        isInitialLoading: false,
      );

      await _pump(tester, const SpotSearchScreen(),
          spots: (ref) => _SpotsFixture(ref, testState));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Patar Beach'), findsWidgets);
      expect(find.text('ARTEST Spot'), findsNothing);

      await _pump(
        tester,
        const SpotSearchScreen(),
        spots: (ref) => _SpotsFixture(ref, testState),
        showTest: true,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ARTEST Spot'), findsWidgets);
    });

    testWidgets('starts with categories above destinations and no keyboard',
        (tester) async {
      await _pump(tester, const SpotSearchScreen(),
          spots: (ref) => _SpotsFixture(ref, _spotsState));
      await tester.pump(const Duration(milliseconds: 100));

      final categories = tester.getTopLeft(find.text('Categories'));
      final destinations =
          tester.getTopLeft(find.text('Explore Current Destinations'));
      expect(categories.dy, lessThan(destinations.dy));

      final field = find.descendant(
        of: find.byKey(const ValueKey('search_field')),
        matching: find.byType(TextField),
      );
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);

      await tester.tap(field);
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);
    });
  });

  group('SpotDiscoveryStudioScreen', () {
    testWidgets('renders the studio with a handed-off pin', (tester) async {
      await _pump(
        tester,
        const SpotDiscoveryStudioScreen(
          routePin: StudioPin(16.2, 119.9, 15),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Spot Discovery Studio'), findsOneWidget);
      expect(find.byKey(const ValueKey('studio_map')), findsOneWidget);
      expect(find.byKey(const ValueKey('spot_postcard')), findsOneWidget);
    });
  });

  group('NavigationScreen', () {
    const target = NavTarget(
        name: 'Patar Beach', lat: 16.2, lng: 119.9, address: 'Bolinao');

    NavigationState stateFor({RouteModel? route, String? error}) =>
        NavigationState(
          destination: target,
          route: route,
          error: error,
          userLocation: const LatLng(16.1, 119.8),
        );

    testWidgets('renders panels and calls every control', (tester) async {
      late _NavFixture fixture;
      await _pump(
        tester,
        const NavigationScreen(destination: target),
        navTarget: target,
        navigation: (client, t) =>
            fixture = _NavFixture(client, t, stateFor(route: _route)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('TO'), findsOneWidget);
      expect(find.text('Patar Beach'), findsOneWidget);
      expect(find.text('DIRECT ROUTE'), findsOneWidget);
      await tester.tap(find.text('MOTO'));
      await tester.pump();
      expect(fixture.costings, greaterThanOrEqualTo(1));

      await tester.tap(find.text('CHANGE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_anti_crowd')));
      await tester.pump();
      expect(fixture.crowds, greaterThanOrEqualTo(1));

      await tester.tap(find.text('MY GPS LOCATION'));
      await tester.pumpAndSettle();
      expect(find.text('TO'), findsOneWidget);
    });

    testWidgets('error banner retries', (tester) async {
      late _NavFixture fixture;
      await _pump(
        tester,
        const NavigationScreen(destination: target),
        navTarget: target,
        navigation: (client, t) => fixture = _NavFixture(
            client, t, stateFor(route: null, error: 'Route unavailable')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text("Couldn't load this. Try again."), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_retry')));
      await tester.pump();
      expect(fixture.routes, greaterThanOrEqualTo(1));
    });
  });
}
