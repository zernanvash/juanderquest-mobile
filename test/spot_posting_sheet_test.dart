import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/utils/spot_posting.dart';
import 'package:juanderquest_app/features/spots/widgets/pin_aim_card.dart';
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
  ],
  'nearby_duplicates': [],
};

/// Fake API: GET /spots/recognize returns [recognition] (or fails when null); POST /spots via [onPost].
ApiClient fakeClient({Map<String, dynamic>? recognition = _recognition, Response Function(RequestOptions)? onPost, List<dynamic>? posted}) {
  final client = ApiClient();
  client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    if (options.path == '/spots/recognize') {
      if (recognition == null) {
        return handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
      }
      return handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'success': true, 'data': recognition}));
    }
    if (options.path == '/spots' && options.method == 'POST') {
      posted?.add(options.data);
      return handler.resolve(onPost!(options));
    }
    return handler.next(options);
  }));
  return client;
}

Response created(RequestOptions options) => Response(
      requestOptions: options,
      statusCode: 201,
      data: {
        'success': true,
        'data': {'id': 'spot-sheet-1', 'slug': 'patar', 'name': 'Patar White Beach', 'gps_lat': 16.3268, 'gps_lng': 119.7842},
      },
    );

Widget wrapSheet(ApiClient client) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: const MaterialApp(
      home: Scaffold(body: SpotPostingSheet(initialLat: 16.3268, initialLng: 119.7842)),
    ),
  );
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pre-fills the one-page draft from recognition, with no steps or raw coordinates', (tester) async {
    await tester.pumpWidget(wrapSheet(fakeClient()));
    await tester.pumpAndSettle();

    expect(find.text('Brgy. Patar, Bolinao'), findsOneWidget);
    expect(find.text('Patar Road, Brgy. Patar, Bolinao, Pangasinan'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Patar White Beach'), findsOneWidget);
    expect(find.text('✨ Auto-recognized from map'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('30s video'), findsOneWidget);
    expect(find.textContaining('Families & kids & Groups & barkada'), findsOneWidget);
    expect(find.textContaining('Step 1 of'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(find.textContaining('16.3268'), findsNothing);
    expect(find.textContaining('119.7842'), findsNothing);
  });

  testWidgets('one story-starter tap completes the description and one tap publishes', (tester) async {
    final posted = <dynamic>[];
    await tester.pumpWidget(wrapSheet(fakeClient(onPost: created, posted: posted)));
    await tester.pumpAndSettle();
    expect(find.text('Tap a story starter or add a short description'), findsOneWidget);

    await tapVisible(tester, find.textContaining('+ Patar White Beach in Brgy. Patar'));
    expect(find.text('✓ Description looks good'), findsOneWidget);
    expect(find.text('✓ Ready to publish'), findsOneWidget);

    await tester.tap(find.text('Publish spot'));
    await tester.pumpAndSettle();
    expect(find.text('Destination published'), findsOneWidget);
    final payload = posted.single as Map;
    expect(payload['name'], 'Patar White Beach');
    expect(payload['municipality'], 'Bolinao');
    expect(payload['category'], 'nature_outdoors');
    expect(payload['subcategory'], 'beach');
    expect(payload['good_for'], ['families', 'groups']);
    expect(payload['best_time'], ['early_morning', 'sunset']);
    expect(payload['hours'], {'daily': '06:00 AM - 06:00 PM'});
    expect(payload['description'], 'Patar White Beach in Brgy. Patar, Bolinao with relaxing views and fresh air.');
    expect(payload['gps_lat'], 16.3268);
  });

  testWidgets('asks for a name when none was recognized and offers suggestion chips', (tester) async {
    await tester.pumpWidget(wrapSheet(fakeClient(recognition: {..._recognition, 'place_name': null, 'name_suggestions': ['Patar Viewpoint']})));
    await tester.pumpAndSettle();
    expect(find.text('Add a name for this place'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(ActionChip, 'Patar Viewpoint'));
    expect(find.widgetWithText(TextField, 'Patar Viewpoint'), findsOneWidget);
  });

  testWidgets('works offline with generic starters when recognition fails', (tester) async {
    await tester.pumpWidget(wrapSheet(fakeClient(recognition: null)));
    await tester.pumpAndSettle();
    expect(find.text('Selected spot on map'), findsOneWidget);
    expect(find.textContaining('+ A scenic spot with relaxing views'), findsOneWidget);
    await tapVisible(tester, find.text('Edit address manually'));
    expect(find.widgetWithText(TextField, 'Municipality / city'), findsOneWidget);
  });

  testWidgets('keeps the draft when publishing fails and retries successfully', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(wrapSheet(fakeClient(onPost: (options) {
      attempts += 1;
      if (attempts == 1) {
        return Response(requestOptions: options, statusCode: 503, data: {
          'success': false,
          'error': {'message': 'Destination temporarily unavailable.'},
        });
      }
      return created(options);
    })));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.textContaining('+ Great stop for photos'));
    await tester.tap(find.text('Publish spot'));
    await tester.pumpAndSettle();
    expect(find.text('Destination temporarily unavailable.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Patar White Beach'), findsOneWidget);
    await tester.tap(find.text('Publish spot'));
    await tester.pumpAndSettle();
    expect(find.text('Destination published'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('Adjust pin returns the draft so the map can resume aiming', (tester) async {
    SpotPostingSheetResult? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fakeClient())],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<SpotPostingSheetResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const SpotPostingSheet(initialLat: 16.3268, initialLng: 119.7842),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Adjust pin'));
    expect(result?.movePinRequested, isTrue);
    expect(result?.draft.name, 'Patar White Beach');
  });

  testWidgets('aim card recognizes the crosshair after a debounce, fits 320 px at 2x text, and continues', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    double? lat;
    SpotRecognitionResult? continued;
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fakeClient(recognition: {
        ..._recognition,
        'nearby_duplicates': [
          {'id': 'spot-patar', 'name': 'Patar Rock Formation', 'distance_meters': 42},
        ],
      }))],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                child: PinAimCard(
                  lat: 16.3268,
                  lng: 119.7842,
                  onUseMyLocation: () {},
                  onCancel: () {},
                  onContinue: (a, b, rec) {
                    lat = a;
                    continued = rec;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Recognizing this place…'), findsOneWidget);
    await tester.pump(kRecognizeDebounce);
    await tester.pumpAndSettle();
    expect(find.text('Patar White Beach'), findsOneWidget);
    expect(find.text('Patar Road, Brgy. Patar, Bolinao, Pangasinan'), findsOneWidget);
    expect(find.textContaining('Looks close to Patar Rock Formation (42 m away)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Continue with this place'));
    await tester.tap(find.text('Continue with this place'));
    expect(lat, 16.3268);
    expect(continued?.placeName, 'Patar White Beach');
  });
}
