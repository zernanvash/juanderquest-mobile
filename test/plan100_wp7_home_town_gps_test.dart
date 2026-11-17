import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_hero.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/settings/home_town.dart';

class _InertAuth extends AuthNotifier {
  _InertAuth(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = user == null ? AuthState() : AuthState(user: user, token: 't');
  }

  @override
  Future<void> refreshProfile() async {}
}

void main() {
  final testUser = UserModel(
    id: 'user-wp7',
    seedId: 'juan_wp7',
    displayName: 'Juan Explorer',
    email: 'juan@example.test',
    avatarUrl: '',
    role: 'user',
    demoPoints: 120,
  );

  Widget wrapHomeHero(HomeTownInfo info, {double textScale = 1.0}) {
    final api = ApiClient();
    final refresh = AuthRefreshNotifier();
    return ProviderScope(
      key: ObjectKey(info),
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _InertAuth(api, refresh, testUser)),
        homeTownProvider.overrideWith((ref) async => info),
        homeTownSightingProvider.overrideWith((ref) async {}),
        profileStatsProvider.overrideWithValue(
          ProfileStatsModel(
            completedQuestsCount: 2,
            pendingSubmissionsCount: 0,
            totalPointsEarned: 120,
            ecoPioneerState: BadgeState.locked,
            heritageKeeperState: BadgeState.locked,
            foodExplorerState: BadgeState.locked,
          ),
        ),
        choiceEngagementProvider.overrideWith(
          (ref) => Completer<ChoiceEngagementSummary>().future,
        ),
        homeDailyProvider.overrideWith(
          (ref) => Completer<HomeDailyState>().future,
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeHero(user: testUser),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('HomeHero shows GPS town, finding progress, and manual town',
      (tester) async {
    await tester.pumpWidget(
      wrapHomeHero(
        const HomeTownInfo(
          town: 'Dagupan City',
          source: 'gps',
          gpsEnabled: true,
          currentDays: 5,
          options: ['Dagupan City', 'Bolinao'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dagupan City · from GPS'), findsOneWidget);

    await tester.pumpWidget(
      wrapHomeHero(
        const HomeTownInfo(
          town: null,
          gpsEnabled: true,
          currentDays: 2,
          requiredDays: 5,
          options: ['Dagupan City', 'Bolinao'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home town: finding… (2/5 days)'), findsOneWidget);

    await tester.pumpWidget(
      wrapHomeHero(
        const HomeTownInfo(
          town: 'Bolinao',
          source: 'manual',
          gpsEnabled: false,
          options: ['Dagupan City', 'Bolinao'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bolinao'), findsOneWidget);
  });

  testWidgets('HomeHero fits 320x568 and 568x320 at 2.0x text scale',
      (tester) async {
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapHomeHero(
          const HomeTownInfo(
            town: null,
            gpsEnabled: true,
            currentDays: 3,
            requiredDays: 5,
            options: ['Dagupan City'],
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Settings Home town switch disables manual picker when ON and enables when OFF',
      (tester) async {
    final api = ApiClient();
    final refresh = AuthRefreshNotifier();
    var gpsEnabled = true;
    String? savedTown;

    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/me/home-town' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'home_municipality': savedTown,
                    'home_town_source': savedTown == null ? null : 'manual',
                    'home_town_gps': gpsEnabled,
                    'days_progress': {
                      'current_days': 2,
                      'required_days': 5,
                      'leading_town': 'Dagupan City',
                    },
                    'options': ['Dagupan City', 'Bolinao'],
                  },
                },
              ),
            );
          }
          if (options.path == '/me/home-town/gps' && options.method == 'PUT') {
            gpsEnabled = options.data['enabled'] as bool;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'home_municipality': savedTown,
                    'home_town_source': savedTown == null ? null : 'manual',
                    'home_town_gps': gpsEnabled,
                    'days_progress': {
                      'current_days': 2,
                      'required_days': 5,
                      'leading_town': 'Dagupan City',
                    },
                  },
                },
              ),
            );
          }
          if (options.path == '/me/home-town' && options.method == 'PUT') {
            savedTown = options.data['municipality'] as String?;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'home_municipality': savedTown,
                    'home_town_source': 'manual',
                    'home_town_gps': false,
                  },
                },
              ),
            );
          }
          return handler.next(options);
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider
              .overrideWith((ref) => _InertAuth(api, refresh, testUser)),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showHomeTownPicker(context, ref),
                child: const Text('Open Home town'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Home town'));
    await tester.pumpAndSettle();

    expect(find.text('Set my home town from GPS'), findsOneWidget);
    expect(find.text('finding… (2/5 days)'), findsOneWidget);

    // The town list scrolls inside the sheet (QA 2026-11-17).
    Future<void> showBolinao() => tester.scrollUntilVisible(
          find.byKey(const ValueKey('home_town_Bolinao')),
          40,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('home_town_list')),
            matching: find.byType(Scrollable),
          ),
        );

    // Tapping Bolinao while GPS is ON does nothing (read-only)
    await showBolinao();
    await tester.tap(find.byKey(const ValueKey('home_town_Bolinao')));
    await tester.pumpAndSettle();
    expect(find.text('Set my home town from GPS'), findsOneWidget);

    // Turn GPS OFF
    await tester.tap(find.byKey(const ValueKey('home_town_gps_switch')));
    await tester.pumpAndSettle();

    // Now tapping Bolinao saves and closes dialog
    await showBolinao();
    await tester.tap(find.byKey(const ValueKey('home_town_Bolinao')));
    await tester.pumpAndSettle();
    expect(find.text('Set my home town from GPS'), findsNothing);
    expect(savedTown, 'Bolinao');
  });
}
