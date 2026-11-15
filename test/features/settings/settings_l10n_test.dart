import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/merchant/models/merchant_models.dart';
import 'package:juanderquest_app/features/merchant/providers/merchant_hub_provider.dart';
import 'package:juanderquest_app/features/settings/screens/settings_screen.dart';

class _InertAuth extends AuthNotifier {
  _InertAuth(super.apiClient, super.refreshNotifier, UserModel user) {
    state = AuthState(user: user, token: 'inert_token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _MemoryStore implements PixelSettingsStore {
  PixelSettings? saved;

  @override
  Future<PixelSettings?> read() async => saved;

  @override
  Future<void> write(PixelSettings settings) async => saved = settings;
}

final _user = UserModel(
  id: 'u-l10n',
  seedId: 'l10n_scout',
  displayName: 'Juan Dela Cruz',
  email: 'juan@juanderquest.ph',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 0,
);

/// Plan 93b WP-8: one-line Settings rows and a Pure English / Tagalog switch.
void main() {
  testWidgets('rows have no sub-text and the language switch relabels Settings',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryStore();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        pixelSettingsStoreProvider.overrideWithValue(store),
        merchantHubStatusProvider
            .overrideWith((ref) async => MerchantHubStatus.none),
        authProvider.overrideWith((ref) => _InertAuth(
              ref.watch(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              _user,
            )),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    // Former sub-texts are gone.
    for (final old in const [
      'Profile banners, frames, titles and name colours',
      'The town you are from, for My Town',
      'Tune which destinations we recommend',
      'Juan shows you around Home again',
      'Universidad de Dagupan capstone authors',
    ]) {
      expect(find.text(old), findsNothing, reason: old);
    }
    expect(find.text('Pure English'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings_language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings_language_tagalog')));
    await tester.pumpAndSettle();

    expect(find.text('Mga Setting'), findsOneWidget);
    expect(find.text('Hitsura ng Profile'), findsOneWidget);
    expect(find.text('Wika'), findsOneWidget);
    expect(find.text('Tagalog'), findsOneWidget);
    expect(find.text('Mag-log Out'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(store.saved?.language, AppLanguage.tagalog);
  });

  test('language survives a save and load, defaulting to English', () {
    const tagalog = PixelSettings(language: AppLanguage.tagalog);
    final restored = PixelSettings.fromJson(jsonEncode(tagalog.toJson()));
    expect(restored?.language, AppLanguage.tagalog);
    expect(restored, tagalog);
    expect(PixelSettings.fromJson('{"font":"Silkscreen"}')?.language,
        AppLanguage.english);
  });
}
