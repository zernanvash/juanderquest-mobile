import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.apiClient);

  @override
  Future<void> fetchSubmissions({bool force = false}) async {}
}

class _SignedInAuth extends AuthNotifier {
  _SignedInAuth(super.client, super.refresh, {String id = 'usr-owner'}) {
    state = AuthState(
      token: 'tok-test',
      user: UserModel(
        id: id,
        seedId: 'juanscout',
        displayName: 'Juan Scout',
        email: 'juan@example.com',
        avatarUrl: '',
        role: 'user',
        demoPoints: 120,
      ),
    );
  }
}

ApiClient _mockApi({
  List<Map<String, dynamic>>? quests,
  bool questsError = false,
  List<Map<String, dynamic>>? progressItems,
  bool progressPublic = false,
  bool progressError = false,
  bool progressPrivate403 = false,
  List<Map<String, dynamic>>? timelinePage1,
  List<Map<String, dynamic>>? timelinePage2,
  bool timelineError = false,
  void Function(bool nextPrivacy)? onPrivacyPut,
}) {
  final client = ApiClient();
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final p = options.path;
        if (p == '/me/showcase' || p.endsWith('/showcase')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': null},
          ));
        }
        if (p.endsWith('/spots')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'spots': []}
            },
          ));
        }
        if (p.endsWith('/quests')) {
          if (questsError) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 500),
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'quests': quests ?? []}
            },
          ));
        }
        if (p == '/me/progress' || p.endsWith('/progress')) {
          if (progressError) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 500),
            ));
          }
          if (progressPrivate403) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 403,
                data: {
                  'success': false,
                  'error': {'code': 'PROGRESS_PRIVATE'}
                },
              ),
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'progress_public': progressPublic,
                'items': progressItems ?? [],
              },
            },
          ));
        }
        if (p == '/me/profile-privacy' && options.method == 'PUT') {
          final next = options.data['progress_public'] == true;
          onPrivacyPut?.call(next);
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'progress_public': next}
            },
          ));
        }
        if (p.endsWith('/timeline')) {
          if (timelineError) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 500),
            ));
          }
          final cursor = options.queryParameters['cursor'];
          if (cursor == 'c2') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'items': timelinePage2 ?? [], 'next_cursor': null},
              },
            ));
          }
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': timelinePage1 ?? [],
                'next_cursor': timelinePage2 != null ? 'c2' : null,
              },
            },
          ));
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': {}},
        ));
      },
    ),
  );
  return client;
}

Widget _wrap({required ApiClient client, Widget? home, String? initialRoute}) {
  if (initialRoute != null) {
    final router = GoRouter(
      initialLocation: initialRoute,
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, state) => ProfileScreen(
            initialTab: state.uri.queryParameters['tab'],
          ),
        ),
        GoRoute(
          path: '/quests/:id',
          builder: (_, __) => const Scaffold(body: Text('Quest Detail')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((r) => _SignedInAuth(
            r.read(apiClientProvider), r.read(authRefreshProvider.notifier))),
        submissionProvider
            .overrideWith((r) => _SubmissionFixture(r.read(apiClientProvider))),
      ],
      child: MaterialApp.router(theme: AppTheme.pixel, routerConfig: router),
    );
  }
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authProvider.overrideWith((r) => _SignedInAuth(
          r.read(apiClientProvider), r.read(authRefreshProvider.notifier))),
      submissionProvider
          .overrideWith((r) => _SubmissionFixture(r.read(apiClientProvider))),
    ],
    child: MaterialApp(theme: AppTheme.pixel, home: home),
  );
}

Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets(
      'Quests, Progress, Timeline data + pagination + privacy toggle work',
      (tester) async {
    bool? savedPrivacy;
    final client = _mockApi(
      quests: [
        {
          'id': 'q1',
          'title': 'Hundred Islands Eco Walk',
          'status': 'draft',
          'reward_points': 50,
          'step_count': 2,
          'spot_name': 'Marcos Island',
        }
      ],
      progressItems: [
        {
          'attempt_id': 'a1',
          'quest_id': 'q2',
          'title': 'Bolinao Heritage Trail',
          'verified_required': 2,
          'total_required': 4,
          'next_task_title': 'Upload Sunset Photo',
          'status': 'in_progress',
          'reward_points': 75,
        },
        {
          'attempt_id': 'a2',
          'quest_id': 'q3',
          'title': 'Dagupan Bangus Quest',
          'verified_required': 1,
          'total_required': 1,
          'status': 'completed',
          'completed_at': '2026-11-16T09:00:00Z',
          'reward_points': 40,
        },
      ],
      timelinePage1: [
        {
          'id': 'spot:s1',
          'kind': 'destination',
          'subject_id': 's1',
          'title': 'Patar White Sand',
          'subtitle': 'Bolinao',
          'href': '/explore/patar',
          'under_review': true,
          'status': 'pending',
          'at': '2026-11-16T10:00:00Z',
        }
      ],
      timelinePage2: [
        {
          'id': 'quest:q3',
          'kind': 'quest_completion',
          'subject_id': 'q3',
          'title': 'Dagupan Bangus Quest',
          'subtitle': '+40 pts',
          'href': '/quests/q3',
          'under_review': false,
          'status': 'completed',
          'at': '2026-11-15T10:00:00Z',
        }
      ],
      onPrivacyPut: (v) => savedPrivacy = v,
    );

    await tester.pumpWidget(_wrap(client: client, home: const ProfileScreen()));
    await _pumpReady(tester);

    // Quests tab
    await tester.tap(find.byKey(const ValueKey('profile_tab_quests')));
    await _pumpReady(tester);
    expect(find.text('Hundred Islands Eco Walk'), findsOneWidget);
    expect(find.text('DRAFT'), findsOneWidget);

    // Progress tab
    await tester.tap(find.byKey(const ValueKey('profile_tab_progress')));
    await _pumpReady(tester);
    expect(find.text('Bolinao Heritage Trail'), findsOneWidget);
    expect(find.textContaining('Step 2 of 4 · Next: Upload Sunset Photo'),
        findsOneWidget);
    expect(find.text('Dagupan Bangus Quest'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('profile_progress_privacy_switch')));
    await _pumpReady(tester);
    expect(savedPrivacy, isTrue);

    // Timeline tab + Load more
    await tester.tap(find.byKey(const ValueKey('profile_tab_timeline')));
    await _pumpReady(tester);
    expect(find.text('Patar White Sand'), findsOneWidget);
    expect(find.text('UNDER REVIEW'), findsOneWidget);

    final loadMore = find.byKey(const ValueKey('profile_timeline_load_more'));
    await tester.ensureVisible(loadMore);
    await _pumpReady(tester);
    await tester.tap(loadMore);
    await _pumpReady(tester);
    expect(find.text('Dagupan Bangus Quest'), findsOneWidget);
  });

  testWidgets(
      'Deep link /profile?tab=progress opens directly on Progress tab and handles empty state',
      (tester) async {
    final emptyClient = _mockApi();
    await tester.pumpWidget(
      _wrap(client: emptyClient, initialRoute: '/profile?tab=progress'),
    );
    await _pumpReady(tester);
    expect(
        find.byKey(const ValueKey('profile_progress_empty')), findsOneWidget);
  });

  testWidgets(
      'Quests, Progress, and Timeline tabs render retryable error states',
      (tester) async {
    final errClient =
        _mockApi(questsError: true, progressError: true, timelineError: true);
    await tester
        .pumpWidget(_wrap(client: errClient, home: const ProfileScreen()));
    await _pumpReady(tester);

    await tester.tap(find.byKey(const ValueKey('profile_tab_quests')));
    await _pumpReady(tester);
    expect(find.byKey(const ValueKey('profile_quests_error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_tab_progress')));
    await _pumpReady(tester);
    expect(
        find.byKey(const ValueKey('profile_progress_error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_tab_timeline')));
    await _pumpReady(tester);
    expect(
        find.byKey(const ValueKey('profile_timeline_error')), findsOneWidget);
  });

  testWidgets(
      '320x568 and 568x320 at 2.0x text scale have 0 overflows and meet tap targets',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final client = _mockApi(
        quests: [
          {
            'id': 'q1',
            'title': 'Alaminos Coastal Cleanup Adventure',
            'status': 'published',
            'reward_points': 100,
            'step_count': 4,
            'spot_name': 'Hundred Islands National Park',
          }
        ],
        progressItems: [
          {
            'attempt_id': 'a1',
            'quest_id': 'q1',
            'title': 'Bolinao Cultural Heritage Challenge',
            'verified_required': 1,
            'total_required': 3,
            'next_task_title': 'Scan QR at Bolinao Lighthouse',
            'status': 'in_progress',
            'reward_points': 75,
          },
        ],
        timelinePage1: [
          {
            'id': 'quiz:qz1',
            'kind': 'quiz_pass',
            'subject_id': 'qz1',
            'title': 'Pangasinan Bangus Culture Quiz',
            'subtitle': 'Dagupan',
            'href': '/quests',
            'under_review': false,
            'status': 'passed',
            'at': '2026-11-16T10:00:00Z',
          }
        ],
      );

      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;

        for (final tab in ['quests', 'progress', 'timeline']) {
          await tester.pumpWidget(
            _wrap(client: client, home: ProfileScreen(initialTab: tab)),
          );
          await _pumpReady(tester);
          expect(tester.takeException(), isNull,
              reason: 'Failed on $tab at $size');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        }
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    } finally {
      handle.dispose();
    }
  });
}
