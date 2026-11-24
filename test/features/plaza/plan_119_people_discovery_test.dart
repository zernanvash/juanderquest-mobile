import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_text_3d.dart';
import 'package:juanderquest_app/core/services/push_service.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/plaza/people_screen.dart';
import 'package:juanderquest_app/features/plaza/plaza_models.dart';
import 'package:juanderquest_app/features/plaza/plaza_provider.dart';
import 'package:juanderquest_app/features/plaza/plaza_screen.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.handler});

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakePushService extends PushService {
  _FakePushService(super.api);

  @override
  Future<bool> hasAskedPermission() async => true;
}

class _EmptyPlazaFeedNotifier extends PlazaFeedNotifier {
  _EmptyPlazaFeedNotifier(super.api) : super() {
    state = const AsyncValue.data(<ActivityItemModel>[]);
  }

  @override
  String get scope => 'following';

  @override
  Future<void> loadFeed({bool reset = false, bool quiet = false}) async {}
}

void main() {
  group('Plan 119: People Discovery', () {
    testWidgets(
      'Find tab loads "Suggested for you", supports optimistic Follow/Unfollow + rollback, and dismisses with ×',
      (tester) async {
        final calls = <String>[];
        bool failNextFollow = false;

        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          calls.add('${options.method} ${options.path}');
          if (options.method == 'GET' && options.path == '/users/suggestions') {
            return _jsonResponse({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'u-sug-1',
                    'display_name': 'Ana Santos',
                    'handle': 'ana_santos',
                    'avatar_url': null,
                    'is_following': false,
                  },
                  {
                    'id': 'u-sug-2',
                    'display_name': 'Ben Cruz',
                    'handle': 'ben_cruz',
                    'avatar_url': null,
                    'is_following': false,
                  },
                ],
                'has_more': false,
              },
            });
          }
          if (options.method == 'PUT' &&
              options.path == '/users/u-sug-1/follow') {
            if (failNextFollow) {
              return _jsonResponse({
                'success': false,
                'error': {
                  'code': 'PRIVATE_PROFILE',
                  'message':
                      'Make your profile public in Settings to follow travelers.',
                },
              }, status: 403);
            }
            return _jsonResponse({
              'success': true,
              'data': {'is_following': true, 'following_count': 1},
            });
          }
          if (options.method == 'DELETE' &&
              options.path == '/users/u-sug-1/follow') {
            return ResponseBody.fromString('', 204);
          }
          if (options.method == 'POST' &&
              options.path == '/users/suggestions/u-sug-2/dismiss') {
            return ResponseBody.fromString('', 204);
          }
          if (options.method == 'GET' &&
              options.path == '/users/me/following') {
            return _jsonResponse({
              'success': true,
              'data': {'items': [], 'has_more': false},
            });
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              plazaFeedProvider.overrideWith(
                (ref) => _EmptyPlazaFeedNotifier(api),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.pixel,
              home: const PeopleScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
              (w) => w is PixelSectionTitle && w.text == 'Suggested for you'),
          findsOneWidget,
        );
        expect(find.text('Ana Santos'), findsOneWidget);
        expect(find.text('@ana_santos'), findsOneWidget);
        expect(find.byKey(const ValueKey('person_follow_u-sug-1')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('person_dismiss_u-sug-1')),
            findsOneWidget);
        // No reason/hometown labels
        expect(find.textContaining('mutual'), findsNothing);
        expect(find.textContaining('hometown'), findsNothing);

        // Tap Follow -> optimistic Following + PUT
        await tester.tap(find.byKey(const ValueKey('person_follow_u-sug-1')));
        await tester.pumpAndSettle();
        expect(calls, contains('PUT /users/u-sug-1/follow'));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('person_follow_u-sug-1')),
            matching: find.text('Following'),
          ),
          findsOneWidget,
        );

        // Tap again -> DELETE
        await tester.tap(find.byKey(const ValueKey('person_follow_u-sug-1')));
        await tester.pumpAndSettle();
        expect(calls, contains('DELETE /users/u-sug-1/follow'));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('person_follow_u-sug-1')),
            matching: find.text('Follow'),
          ),
          findsOneWidget,
        );

        // Server error rolls back and shows toast
        failNextFollow = true;
        await tester.tap(find.byKey(const ValueKey('person_follow_u-sug-1')));
        await tester.pumpAndSettle();
        expect(
          find.text(
              'Make your profile public in Settings to follow travelers.'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('person_follow_u-sug-1')),
            matching: find.text('Follow'),
          ),
          findsOneWidget,
        );

        // Tap dismiss × -> optimistically removes u-sug-2 + POST dismiss
        await tester.tap(find.byKey(const ValueKey('person_dismiss_u-sug-2')));
        await tester.pumpAndSettle();
        expect(calls, contains('POST /users/suggestions/u-sug-2/dismiss'));
        expect(find.text('Ben Cruz'), findsNothing);
      },
    );

    testWidgets(
      'Typing @maria debounces search, shows results without × dismiss, and clearing returns to suggestions',
      (tester) async {
        final searchQueries = <String>[];
        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          if (options.method == 'GET' && options.path == '/users/suggestions') {
            return _jsonResponse({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'u-sug-1',
                    'display_name': 'Ana Santos',
                    'handle': 'ana_santos',
                    'avatar_url': null,
                    'is_following': false,
                  },
                ],
                'has_more': false,
              },
            });
          }
          if (options.method == 'GET' && options.path == '/search') {
            searchQueries.add('${options.queryParameters['q']}');
            return _jsonResponse({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'u-maria',
                    'display_name': 'Maria Clara',
                    'handle': 'maria_clara',
                    'avatar_url': null,
                    'is_following': false,
                  },
                ],
                'has_more': false,
              },
            });
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(api)],
            child: MaterialApp(
              theme: AppTheme.pixel,
              home: const PeopleScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
              (w) => w is PixelSectionTitle && w.text == 'Suggested for you'),
          findsOneWidget,
        );

        await tester.enterText(
            find.byKey(const ValueKey('people_search')), '@maria');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(searchQueries, contains('@maria'));
        expect(find.text('Maria Clara'), findsOneWidget);
        expect(find.byKey(const ValueKey('person_follow_u-maria')),
            findsOneWidget);
        expect(
            find.byKey(const ValueKey('person_dismiss_u-maria')), findsNothing);

        // Clear search -> returns to suggestions
        await tester.tap(find.byKey(const ValueKey('people_search_clear')));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
              (w) => w is PixelSectionTitle && w.text == 'Suggested for you'),
          findsOneWidget,
        );
        expect(find.text('Ana Santos'), findsOneWidget);
      },
    );

    testWidgets(
      'Zero RenderFlex overflows at 320x568 and 568x320 at 2.0x text scale across Find, Search, Following, and Followers',
      (tester) async {
        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          if (options.path == '/users/suggestions') {
            return _jsonResponse({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'u-1',
                    'display_name': 'Very Long Traveler Display Name Here',
                    'handle': 'very_long_traveler_handle',
                    'avatar_url': null,
                    'is_following': false,
                  },
                ],
                'has_more': true,
              },
            });
          }
          if (options.path == '/search') {
            return _jsonResponse({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'u-2',
                    'display_name': 'Maria Clara De Los Santos',
                    'handle': 'maria_clara_delos_santos',
                    'avatar_url': null,
                    'is_following': true,
                  },
                ],
                'has_more': false,
              },
            });
          }
          if (options.path == '/users/me/following' ||
              options.path == '/users/me/followers') {
            return _jsonResponse({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'u-3',
                    'display_name': 'Follower Person Name',
                    'handle': 'follower_handle',
                    'avatar_url': null,
                    'is_following': options.path.endsWith('following'),
                  },
                ],
                'has_more': false,
              },
            });
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        for (final size in [const Size(320, 568), const Size(568, 320)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [apiClientProvider.overrideWithValue(api)],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: MaterialApp(
                  theme: AppTheme.pixel,
                  home: PeopleScreen(key: ValueKey('people_$size')),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Search results
          await tester.enterText(
              find.byKey(const ValueKey('people_search')), 'maria');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Following tab
          await tester.tap(
            find.descendant(
              of: find.byKey(const ValueKey('people_tabs')),
              matching: find.text('Following'),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Followers tab
          await tester.tap(
            find.descendant(
              of: find.byKey(const ValueKey('people_tabs')),
              matching: find.text('Followers'),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'PlazaScreen "Find people" button navigates to /plaza/people Find tab',
      (tester) async {
        final api = ApiClient();
        api.dio.httpClientAdapter = _StubAdapter(handler: (options) async {
          if (options.path == '/users/suggestions') {
            return _jsonResponse({
              'success': true,
              'data': {'items': [], 'has_more': false},
            });
          }
          return _jsonResponse({'success': true, 'data': {}});
        });

        final router = GoRouter(
          initialLocation: '/plaza',
          routes: [
            GoRoute(
              path: '/plaza',
              builder: (_, __) => const PlazaScreen(),
            ),
            GoRoute(
              path: '/plaza/people',
              builder: (_, __) => const PeopleScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              plazaFeedProvider.overrideWith(
                (ref) => _EmptyPlazaFeedNotifier(api),
              ),
              plazaStandingsProvider.overrideWith(
                (ref, arg) async => {
                  'entries': [],
                  'me': null,
                },
              ),
              pushServiceProvider.overrideWithValue(_FakePushService(api)),
            ],
            child: MaterialApp.router(
              theme: AppTheme.pixel,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final findPeopleBtn = find.text('Find people');
        expect(findPeopleBtn, findsOneWidget);
        await tester.tap(findPeopleBtn);
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
              (w) => w is PixelSectionTitle && w.text == 'Suggested for you'),
          findsOneWidget,
        );
      },
    );
  });
}
