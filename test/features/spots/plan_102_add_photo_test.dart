import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_add_photo_sheet.dart';

class _InertAuthNotifier extends AuthNotifier {
  _InertAuthNotifier(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = user == null
        ? AuthState()
        : AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

const _spot = SpotModel(
  id: 'spot-102',
  slug: 'bolinao-lighthouse',
  name: 'Cape Bolinao Lighthouse',
  description: 'Historic coastal beacon in Pangasinan.',
  category: 'culture_heritage',
  subcategory: 'landmark',
  municipality: 'Bolinao',
  address: 'Patar, Bolinao',
  sourceName: 'LGU Bolinao',
  trustLevel: 'lgu_verified',
  gpsLat: 16.3069,
  gpsLng: 119.7867,
  tags: ['lighthouse'],
  reasons: [],
);

final _user = UserModel(
  id: 'u-102',
  seedId: 'u-102',
  email: 'scout@juanderquest.app',
  displayName: 'Scout 102',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 50,
);

final _png1x1 = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  group('Plan 102 Add photo sheet', () {
    testWidgets('signed-out ADD PHOTO opens sign-in and comes back',
        (tester) async {
      final client = ApiClient(enableRetries: false);
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': []},
            ),
          ),
        ),
      );
      String? redirect;
      final router = GoRouter(
        initialLocation: '/spot',
        routes: [
          GoRoute(
            path: '/spot',
            builder: (_, __) => const SpotDetailScreen(spot: _spot),
          ),
          GoRoute(
            path: '/',
            builder: (_, state) {
              redirect = state.uri.queryParameters['redirect'];
              return const Scaffold(body: Text('Login Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            authProvider.overrideWith(
              (ref) => _InertAuthNotifier(
                ref.watch(apiClientProvider),
                ref.watch(authRefreshProvider.notifier),
                null,
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.pixel,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('spot_add_photo')));
      await tester.pumpAndSettle();

      expect(redirect, '/spot');
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets(
        'SpotAddPhotoSheet picks photo, uploads to /spot-media, posts to /spots/:id/photos, and pops true',
        (tester) async {
      final calls = <(String, String, dynamic)>[];
      final client = ApiClient(enableRetries: false);
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add((options.method, options.path, options.data));
            if (options.path == '/spot-media') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'success': true,
                    'data': {
                      'asset_id': 'asset-uploaded-1',
                      'url': '/api/v1/uploads/spot-photos/test.png',
                    },
                  },
                ),
              );
            }
            if (options.path == '/spots/spot-102/photos') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'success': true,
                    'data': {'id': 'sps-1', 'status': 'pending'},
                  },
                ),
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': []},
              ),
            );
          },
        ),
      );

      bool? poppedResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            authProvider.overrideWith(
              (ref) => _InertAuthNotifier(
                ref.watch(apiClientProvider),
                ref.watch(authRefreshProvider.notifier),
                _user,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    poppedResult = await SpotAddPhotoSheet.show(
                      context,
                      spot: _spot,
                      pickPhotoOverride: (_) async => PickedSpotPhoto(
                        bytes: _png1x1,
                        filename: 'beacon.png',
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('spot_add_photo_gallery')));
      await tester.pumpAndSettle();

      expect(find.text('beacon.png'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('spot_add_photo_caption')),
        'Golden hour by the cliff',
      );
      await tester.tap(find.byKey(const ValueKey('spot_add_photo_submit')));
      await tester.pumpAndSettle();

      expect(poppedResult, isTrue);
      expect(calls.any((c) => c.$1 == 'POST' && c.$2 == '/spot-media'), isTrue);
      final submitCall = calls.firstWhere(
          (c) => c.$1 == 'POST' && c.$2 == '/spots/spot-102/photos');
      expect(submitCall.$3, {
        'asset_id': 'asset-uploaded-1',
        'caption': 'Golden hour by the cliff',
      });
    });

    testWidgets(
        'SpotAddPhotoSheet has zero overflow at 320x568 and 568x320 with 2x text',
        (tester) async {
      for (final size in const [Size(320, 568), Size(568, 320)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.pixel,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: const Scaffold(
                  body: SpotAddPhotoSheet(spot: _spot),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
