import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/auth/screens/forgot_password_screen.dart';
import 'package:juanderquest_app/features/spots/screens/interests_screen.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_community_section.dart';

class _InertAuth extends AuthNotifier {
  _InertAuth(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert');
  }

  @override
  Future<void> refreshProfile() async {}
}

/// Records requests and answers them from [routes] ("METHOD path" -> data).
class FakeApi {
  final ApiClient client = ApiClient();
  final List<RequestOptions> requests = [];
  final Map<String, Object? Function(RequestOptions)> routes;

  FakeApi(this.routes) {
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        final route = routes['${options.method} ${options.path}'];
        if (route == null) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(
                requestOptions: options,
                statusCode: 404,
                data: {'success': false}),
          ));
        }
        final data = route(options);
        if (data is DioException) return handler.reject(data);
        handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data));
      }),
    );
  }

  List<String> get calls => [for (final r in requests) '${r.method} ${r.path}'];
}

DioException apiError(RequestOptions o, int status, String code, String msg) =>
    DioException(
      requestOptions: o,
      response: Response(
        requestOptions: o,
        statusCode: status,
        data: {
          'success': false,
          'error': {'code': code, 'message': msg}
        },
      ),
    );

Future<void> pump(WidgetTester tester, FakeApi api, Widget child,
    {bool fullScreen = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api.client),
      authProvider.overrideWith((ref) => _InertAuth(
            ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier),
            UserModel(
              id: 'u1',
              seedId: 's1',
              displayName: 'Juan',
              email: 'juan@example.com',
              avatarUrl: '',
              role: 'explorer',
              demoPoints: 0,
            ),
          )),
    ],
    child: MaterialApp(
        home: fullScreen
            ? child
            : Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('SpotCommunitySection', () {
    FakeApi api() => FakeApi({
          'GET /spots/s1/comments': (_) => {
                'success': true,
                'data': [
                  {
                    'id': 'log-1',
                    'author_name': 'Scout Aira',
                    'tag': 'local_tip',
                    'content': 'Go at low tide.',
                    'helpful_count': 3,
                    'created_at': '2026-10-20T10:00:00Z',
                  }
                ]
              },
          'POST /spots/s1/comments': (o) => {
                'success': true,
                'data': {
                  'id': 'log-2',
                  'author_name': 'Juan',
                  'tag': (o.data as Map)['tag'],
                  'content': (o.data as Map)['content'],
                  'helpful_count': 0,
                }
              },
          'POST /spots/s1/comments/log-1/helpful': (_) => {
                'success': true,
                'data': {'helpful_count': 4}
              },
          'PUT /spots/s1/like': (_) => {'success': true},
          'POST /spots/s1/reports': (_) => {'success': true},
        });

    testWidgets('shows notes, posts one, marks helpful and likes',
        (tester) async {
      final fake = api();
      await pump(
          tester,
          fake,
          const SpotCommunitySection(
              spotId: 's1', spotName: 'Hundred Islands'));
      expect(find.text('Go at low tide.'), findsOneWidget);
      expect(find.text('Helpful (3)'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('spot_comment_input')), 'Bring cash.');
      await tester.tap(find.byKey(const ValueKey('spot_comment_post')));
      await tester.pumpAndSettle();
      expect(find.text('Bring cash.'), findsOneWidget);
      final posted = fake.requests.firstWhere(
          (r) => r.method == 'POST' && r.path == '/spots/s1/comments');
      expect(posted.data, {'content': 'Bring cash.', 'tag': 'general'});

      await tester.tap(find.text('Helpful (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Helpful (4)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('spot_like')));
      await tester.pumpAndSettle();
      expect(fake.calls, contains('PUT /spots/s1/like'));
      expect(find.text('Liked'), findsOneWidget);
    });

    testWidgets('reports a problem with a reason', (tester) async {
      final fake = api();
      await pump(
          tester,
          fake,
          const SpotCommunitySection(
              spotId: 's1', spotName: 'Hundred Islands'));
      await tester.tap(find.byKey(const ValueKey('spot_report')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('report_site_closed_or_hazard')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report_send')));
      await tester.pumpAndSettle();
      final sent =
          fake.requests.firstWhere((r) => r.path == '/spots/s1/reports');
      expect(sent.data, {'reason': 'site_closed_or_hazard'});
      expect(find.textContaining('moderators'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('email -> code -> new password', (tester) async {
      final fake = FakeApi({
        'POST /auth/password/forgot': (_) => {'success': true, 'data': {}},
        'POST /auth/password/verify-code': (o) => (o.data as Map)['code'] ==
                '123456'
            ? {
                'success': true,
                'data': {'reset_grant': '7d1f3c6e-1111-4222-8333-944455556666'}
              }
            : apiError(o, 400, 'INVALID_CODE',
                'Recovery code is invalid or has expired.'),
        'POST /auth/password/reset': (_) => {'success': true, 'data': {}},
      });
      await pump(tester, fake, const ForgotPasswordScreen(), fullScreen: true);

      await tester.enterText(
          find.byKey(const ValueKey('recovery_email')), 'not-an-email');
      await tester.tap(find.byKey(const ValueKey('recovery_send')));
      await tester.pump();
      expect(find.byKey(const ValueKey('recovery_error')), findsOneWidget);
      expect(fake.requests, isEmpty);

      await tester.enterText(
          find.byKey(const ValueKey('recovery_email')), 'juan@example.com');
      await tester.tap(find.byKey(const ValueKey('recovery_send')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('recovery_code')), '000000');
      await tester.tap(find.byKey(const ValueKey('recovery_verify')));
      await tester.pumpAndSettle();
      expect(find.text('Recovery code is invalid or has expired.'),
          findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('recovery_code')), '123456');
      await tester.tap(find.byKey(const ValueKey('recovery_verify')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('recovery_password')), 'newpass123');
      await tester.enterText(
          find.byKey(const ValueKey('recovery_confirm')), 'different1');
      await tester.tap(find.byKey(const ValueKey('recovery_reset')));
      await tester.pump();
      expect(find.text('The two passwords do not match.'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('recovery_confirm')), 'newpass123');
      await tester.tap(find.byKey(const ValueKey('recovery_reset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recovery_done')), findsOneWidget);
      final reset =
          fake.requests.firstWhere((r) => r.path == '/auth/password/reset');
      expect(reset.data, {
        'reset_grant': '7d1f3c6e-1111-4222-8333-944455556666',
        'new_password': 'newpass123',
      });
    });
  });

  group('InterestsScreen', () {
    testWidgets('saves the chosen categories', (tester) async {
      final fake = FakeApi({
        'GET /me/discovery-preferences': (_) => {
              'success': true,
              'data': {'categories': [], 'onboarding_state': 'pending'}
            },
        'PUT /me/discovery-preferences': (_) => {'success': true, 'data': {}},
      });
      await pump(tester, fake, const InterestsScreen(), fullScreen: true);
      await tester.tap(find.byKey(const ValueKey('interest_nature_outdoors')));
      await tester.tap(find.byKey(const ValueKey('interest_eat_drink')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('interests_save')));
      await tester.pump(const Duration(milliseconds: 300));
      final put = fake.requests.firstWhere((r) => r.method == 'PUT');
      final body = put.data as Map;
      expect((body['categories'] as List).toSet(),
          {'nature_outdoors', 'eat_drink'});
      expect(body['onboarding_state'], 'completed');
    });
  });
}
