import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_community_section.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier) {
    state = AuthState(
      user: UserModel(
        id: 'me',
        seedId: 'me',
        email: 'me@juanderquest.app',
        displayName: 'Me',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 0,
      ),
      token: 'inert_token',
    );
  }

  @override
  Future<void> refreshProfile() async {}
}

Widget _host(List<RequestOptions> calls) {
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(options);
      final data = options.method == 'GET'
          ? [
              {
                'id': 'n-mine',
                'user_id': 'me',
                'author_name': 'Me',
                'content': 'My tip.',
                'helpful_count': 0
              },
              {
                'id': 'n-other',
                'user_id': 'other',
                'author_name': 'Ana',
                'content': 'Her tip.',
                'helpful_count': 0
              },
            ]
          : options.method == 'PATCH'
              ? {
                  'id': 'n-mine',
                  'content': 'Edited tip.',
                  'edited_at': '2026-11-18T00:00:00Z'
                }
              : {'reports': 1, 'hidden': false};
      handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': data}));
    }),
  );
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authProvider.overrideWith(
        (ref) => _InertAuthNotifier(ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier)),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: const Scaffold(
        body: SingleChildScrollView(
            child: SpotCommunitySection(spotId: 'spot-1', spotName: 'Spot')),
      ),
    ),
  );
}

void main() {
  testWidgets('my note: Edit saves with PATCH and shows EDITED',
      (tester) async {
    final calls = <RequestOptions>[];
    await tester.pumpWidget(_host(calls));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_more_n-mine')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_report_spam')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('note_edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('note_edit_field')), 'Edited tip.');
    await tester.tap(find.byKey(const ValueKey('note_edit_save')));
    await tester.pumpAndSettle();
    final patch = calls.singleWhere((c) => c.method == 'PATCH');
    expect(patch.path, '/spots/spot-1/comments/n-mine');
    expect(find.text('Edited tip.'), findsOneWidget);
    expect(find.textContaining('EDITED'), findsOneWidget);
  });

  testWidgets('my note: Delete asks first, then removes it', (tester) async {
    final calls = <RequestOptions>[];
    await tester.pumpWidget(_host(calls));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_more_n-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_delete_confirm')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'DELETE').single.path,
        '/spots/spot-1/comments/n-mine');
    expect(find.text('My tip.'), findsNothing);
  });

  testWidgets("someone else's note: only Report", (tester) async {
    final calls = <RequestOptions>[];
    await tester.pumpWidget(_host(calls));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_more_n-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_edit')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('note_report_offensive')));
    await tester.pumpAndSettle();
    final post = calls.singleWhere((c) => c.method == 'POST');
    expect(post.path, '/spots/spot-1/comments/n-other/report');
    expect(post.data, {'reason': 'offensive'});
  });
}
