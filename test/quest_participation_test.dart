import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';

class _SignedInAuth extends AuthNotifier {
  _SignedInAuth(super.client, super.refresh) {
    state = AuthState(
      token: 'test-token',
      user: UserModel(
        id: 'traveler-1',
        seedId: 'traveler-1',
        displayName: 'Traveler',
        email: 'traveler@example.test',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 0,
      ),
    );
  }
}

void main() {
  testWidgets('legacy quest detail fits 320px at double text scale',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final quest = QuestModel(
      id: 'legacy',
      title: 'Coastal visit',
      description: 'Explore the coast.',
      category: 'eco',
      locationName: 'Coast',
      gpsLat: 16,
      gpsLng: 120,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
    );
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: QuestDetailScreen(quest: quest)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepting a quest uses server attempt and enables proof submission',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final client = ApiClient();
    var starts = 0;

    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/quests/quest-1/progress') {
          final hasAttempt = starts > 0;
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'has_completed': false,
                'active_attempt': hasAttempt
                    ? {
                        'id': 'attempt-1',
                        'quest_id': 'quest-1',
                        'user_id': 'traveler-1',
                        'status': 'in_progress',
                        'verified_steps': 0,
                        'required_steps': 1,
                        'steps': [
                          {
                            'step_order': 1,
                            'title': 'Photo evidence',
                            'description': 'Document the cleanup.',
                            'checkpoint_type': 'photo',
                            'required': true,
                            'status': 'ready',
                          }
                        ],
                      }
                    : null,
              },
            },
          ));
        }
        if (options.path == '/quests/quest-1/attempts') {
          starts++;
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {
                'id': 'attempt-1',
                'quest_id': 'quest-1',
                'user_id': 'traveler-1',
                'status': 'in_progress',
              },
            },
          ));
        }
        return handler.reject(DioException(requestOptions: options));
      },
    ));

    final quest = QuestModel(
      id: 'quest-1',
      title: 'Coastal cleanup',
      description: 'Help care for this destination.',
      category: 'eco',
      locationName: 'Coast',
      gpsLat: 16,
      gpsLng: 120,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
      steps: const [
        QuestStepModel(
          order: 1,
          title: 'Photo evidence',
          description: 'Document the cleanup.',
          checkpointType: 'photo',
          required: true,
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((ref) => _SignedInAuth(
            ref.read(apiClientProvider), ref.read(authRefreshProvider.notifier))),
      ],
      child: MaterialApp(home: QuestDetailScreen(quest: quest)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Step 1: Photo evidence'), findsOneWidget);
    await tester.ensureVisible(find.text('Accept quest'));
    await tester.tap(find.text('Accept quest'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(find.textContaining('Quest accepted.'), findsOneWidget);
    expect(find.text('Submit Photo Proof'), findsOneWidget);
  });

  testWidgets('displays QR step with interactive verification modal',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final client = ApiClient();
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/quests/quest-qr/progress') {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'has_completed': false,
                'active_attempt': {
                  'id': 'attempt-qr',
                  'quest_id': 'quest-qr',
                  'user_id': 'traveler-1',
                  'status': 'in_progress',
                  'verified_steps': 0,
                  'required_steps': 1,
                  'steps': [
                    {
                      'step_order': 1,
                      'title': 'Scan Heritage Plaque',
                      'description': 'Scan the marker QR code on the monument.',
                      'checkpoint_type': 'qr',
                      'required': true,
                      'status': 'ready',
                    }
                  ],
                },
              },
            },
          ));
        }
        return handler.reject(DioException(requestOptions: options));
      },
    ));

    final quest = QuestModel(
      id: 'quest-qr',
      title: 'Heritage Marker Trail',
      description: 'Discover history.',
      category: 'cultural',
      locationName: 'Monument',
      gpsLat: 16,
      gpsLng: 120,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
      steps: const [
        QuestStepModel(
          order: 1,
          title: 'Scan Heritage Plaque',
          description: 'Scan the marker QR code on the monument.',
          checkpointType: 'qr',
          required: true,
          status: 'ready',
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((ref) => _SignedInAuth(
            ref.read(apiClientProvider), ref.read(authRefreshProvider.notifier))),
      ],
      child: MaterialApp(home: QuestDetailScreen(quest: quest)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Scan QR Code'), findsOneWidget);
    await tester.ensureVisible(find.text('Scan QR Code'));
    await tester.tap(find.text('Scan QR Code'));
    await tester.pumpAndSettle();

    // Verify modal elements are displayed
    expect(find.text('Scan Checkpoint QR'), findsOneWidget);
    expect(find.text('Verify QR'), findsOneWidget);
  });

  testWidgets('displays photo modal with default unselected gallery privacy opt-in',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final client = ApiClient();
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/quests/quest-photo/progress') {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'has_completed': false,
                'active_attempt': {
                  'id': 'attempt-photo',
                  'quest_id': 'quest-photo',
                  'user_id': 'traveler-1',
                  'status': 'in_progress',
                  'verified_steps': 0,
                  'required_steps': 1,
                  'steps': [
                    {
                      'step_order': 1,
                      'title': 'Eco Cleanup Documentation',
                      'description': 'Capture cleanup evidence.',
                      'checkpoint_type': 'photo',
                      'required': true,
                      'status': 'ready',
                    }
                  ],
                },
              },
            },
          ));
        }
        return handler.reject(DioException(requestOptions: options));
      },
    ));

    final quest = QuestModel(
      id: 'quest-photo',
      title: 'Eco Cleanup Quest',
      description: 'Preserve the beach.',
      category: 'eco',
      locationName: 'Beach',
      gpsLat: 16,
      gpsLng: 120,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
      steps: const [
        QuestStepModel(
          order: 1,
          title: 'Eco Cleanup Documentation',
          description: 'Capture cleanup evidence.',
          checkpointType: 'photo',
          required: true,
          status: 'ready',
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((ref) => _SignedInAuth(
            ref.read(apiClientProvider), ref.read(authRefreshProvider.notifier))),
      ],
      child: MaterialApp(home: QuestDetailScreen(quest: quest)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Submit Photo Proof'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit Photo Proof'));
    await tester.tap(find.text('Submit Photo Proof'));
    await tester.pumpAndSettle();

    expect(find.text('Feature photo in destination gallery upon review approval'),
        findsOneWidget);
    // Verify privacy opt-in checkbox is unchecked by default
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    final checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, false);
  });
}
