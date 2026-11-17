import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/auth/screens/login_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';

class _IdleAuthNotifier extends AuthNotifier {
  _IdleAuthNotifier() : super(ApiClient(), AuthRefreshNotifier()) {
    state = AuthState();
  }
}

void main() {
  testWidgets('Plan 101c: LoginScreen meets Android tap-target guideline',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => _IdleAuthNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Plan 101c: QuestDetailScreen meets Android tap-target guideline',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final quest = QuestModel(
        id: 'tap-quest-1',
        title: 'Heritage Walk',
        description: 'Visit historic landmarks.',
        category: 'heritage',
        locationName: 'Dagupan',
        gpsLat: 16.043,
        gpsLng: 120.333,
        radiusMeters: 120,
        rewardPoints: 50,
        markerImageUrl: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => _IdleAuthNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: QuestDetailScreen(quest: quest),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });
}
