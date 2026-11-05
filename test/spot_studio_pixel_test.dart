import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/screens/spot_discovery_studio_screen.dart';
import 'package:juanderquest_app/features/spots/utils/spot_location_handoff.dart';
import 'package:juanderquest_app/features/spots/utils/spot_posting.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_posting_sheet.dart';

const _recognition = {
  'recognized': true,
  'place_name': 'Patar White Beach',
  'name_suggestions': ['Patar White Beach', 'Patar Beach'],
  'formatted_address': 'Patar Road, Brgy. Patar, Bolinao, Pangasinan',
  'municipality': 'Bolinao',
  'barangay': 'Brgy. Patar',
  'outside_pangasinan': false,
  'suggested_category': 'nature_outdoors',
  'suggested_subcategory': 'beach',
  'suggested_details': {
    'good_for': ['families', 'groups'],
    'best_time': ['early_morning', 'sunset'],
    'amenities': ['parking', 'restrooms'],
    'daily_hours': '06:00 AM - 06:00 PM',
  },
  'story_starters': [
    'Patar White Beach in Brgy. Patar, Bolinao with relaxing views and fresh air.',
    'Great stop for photos and sunset watching, and easy to reach from the main road.',
    'Bring water and sun protection for the walk along the shore.',
    'The light is best just before the sun goes down.',
  ],
  'nearby_duplicates': [],
};

ApiClient _fakeClient({Map<String, dynamic>? recognition = _recognition}) {
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/spots/recognize') {
          if (recognition == null) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          }
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': recognition},
            ),
          );
        }
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 404,
            data: {'success': false},
          ),
        );
      },
    ),
  );
  return client;
}

Widget _sheet(ApiClient client) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(
        home: Scaffold(
          body: SpotPostingSheet(
            initialLat: 16.3268,
            initialLng: 119.7842,
          ),
        ),
      ),
    );

class _InertAuth extends AuthNotifier {
  _InertAuth(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _MemoryDraftStore extends SpotDraftStore {
  @override
  Future<void> save(
    StudioPin pin,
    SpotLocationSource source,
    SpotPostingDraft draft,
  ) async {}

  @override
  Future<SavedSpotDraft?> load() async => null;

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('type chips appear only after a category is picked',
      (tester) async {
    await tester.pumpWidget(_sheet(_fakeClient(recognition: {
      ..._recognition,
      'suggested_category': 'other',
      'suggested_subcategory': 'other',
    })));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('studio_subtype_beach')),
      findsNothing,
    );

    final tile = find.byKey(const ValueKey('studio_category_nature_outdoors'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('studio_subtype_beach')),
      findsOneWidget,
    );
    expect(find.text('Type'), findsOneWidget);
  });

  testWidgets('a story suggestion tap appends to the description',
      (tester) async {
    await tester.pumpWidget(_sheet(_fakeClient()));
    await tester.pumpAndSettle();

    final starter = find.textContaining('+ Patar White Beach in Brgy. Patar');
    await tester.ensureVisible(starter);
    await tester.tap(starter);
    await tester.pump();

    final field = find.descendant(
      of: find.byKey(const ValueKey('studio_description')),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(field).controller!.text,
      contains('Patar White Beach in Brgy. Patar'),
    );
  });

  testWidgets('the bottom bar lists every missing required field',
      (tester) async {
    await tester.pumpWidget(_sheet(_fakeClient(recognition: null)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Add: name, story, town'),
      findsOneWidget,
    );
  });

  testWidgets('more ideas reveals the remaining starters', (tester) async {
    await tester.pumpWidget(_sheet(_fakeClient()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('+ The light is best just before the sun goes down.'),
      findsNothing,
    );
    final more = find.byKey(const ValueKey('studio_more_ideas'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('+ The light is best just before the sun goes down.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'postcard credit hides an auto id and the visitor summary keeps three lines',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final user = UserModel(
      id: 'user-1',
      seedId: 'usr-a9ff511e-e63',
      displayName: 'Kaizero',
      email: 'kaizero@juanderquest.app',
      avatarUrl: '',
      role: 'explorer',
      demoPoints: 0,
    );
    final api = _fakeClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          spotDraftStoreProvider.overrideWithValue(_MemoryDraftStore()),
          authProvider.overrideWith(
            (ref) => _InertAuth(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              user,
            ),
          ),
        ],
        child: MaterialApp(
          home: SpotDiscoveryStudioScreen(
            routePin: const StudioPin(16.3268, 119.7842, 17),
            routeRecognition: SpotRecognitionResult.fromJson(_recognition),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final details = find.byKey(const ValueKey('studio_details_toggle'));
    await tester.scrollUntilVisible(
      details,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(details);
    await tester.pump();

    final summary =
        tester.widget<Text>(find.byKey(const ValueKey('studio_details_summary')));
    expect(summary.maxLines, 3);
    expect(summary.data, contains('06:00 AM'));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('spot_postcard')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Discovered by Kaizero'), findsOneWidget);
    expect(find.textContaining('@@'), findsNothing);
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'studio fits ${size.width}x${size.height} at 1.4x text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final recognition = SpotRecognitionResult.fromJson(_recognition);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_fakeClient()),
              spotDraftStoreProvider.overrideWithValue(_MemoryDraftStore()),
            ],
            child: MaterialApp(
              home: SpotDiscoveryStudioScreen(
                routePin: const StudioPin(16.3268, 119.7842, 17),
                routeRecognition: recognition,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final details = find.byKey(const ValueKey('studio_details_toggle'));
        await tester.scrollUntilVisible(
          details,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(details);
        await tester.pump();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('spot_postcard')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Publish spot'), findsOneWidget);
      },
    );
  }
}
