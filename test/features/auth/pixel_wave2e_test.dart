import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/app_update/domain/update_classification.dart';
import 'package:juanderquest_app/features/app_update/domain/update_repository.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';
import 'package:juanderquest_app/features/app_update/providers/app_update_provider.dart';
import 'package:juanderquest_app/features/app_update/providers/startup_update_controller.dart';
import 'package:juanderquest_app/features/app_update/widgets/startup_update_gate.dart';
import 'package:juanderquest_app/features/app_update/widgets/update_dialog.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/auth/screens/login_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(ApiClient(), AuthRefreshNotifier()) {
    state = AuthState();
  }

  int signInCalls = 0;
  int registerCalls = 0;

  @override
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (email == 'error@example.com') {
      state = AuthState(error: 'Invalid credentials. Please retry.');
      return false;
    }
    state = AuthState(
      token: 'jwt_test_token',
      user: UserModel(
        id: 'usr_1',
        seedId: 'juan',
        displayName: 'Juan',
        email: 'juan@example.com',
        avatarUrl: '',
        role: 'traveler',
        demoPoints: 150,
      ),
    );
    return true;
  }

  @override
  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    registerCalls++;
    return {'requiresVerification': false};
  }
}

class _FakeUpdateRepository implements IUpdateRepository {
  @override
  Future<AppVersionInfo?> fetchBackendVersionMetadata(
          {Duration timeout = const Duration(seconds: 3)}) async =>
      null;

  @override
  Future<bool> isDartPatchAvailable() async => false;

  @override
  Future<bool> downloadAndInstallDartPatch(
          {void Function(double progress)? onProgress}) async =>
      false;

  @override
  Future<bool> syncContentBundle(ContentManifestMetadata metadata,
          {void Function(double progress)? onProgress}) async =>
      false;

  @override
  Future<void> restartApp() async {}
}

class _TestAppUpdateNotifier extends AppUpdateNotifier {
  _TestAppUpdateNotifier(AppUpdateState initial)
      : super(repository: _FakeUpdateRepository()) {
    state = initial;
  }

  int downloadCalls = 0;

  @override
  Future<void> startDownloadAndInstall({bool forceRedownload = false}) async {
    downloadCalls++;
  }
}

class _TestStartupUpdateController extends StartupUpdateController {
  _TestStartupUpdateController(StartupGateState initial)
      : super(_FakeUpdateRepository()) {
    state = initial;
  }

  @override
  Future<void> initStartupGate() async {}
}

Widget _buildAuthTestApp({
  required Widget child,
  _FakeAuthNotifier? authNotifier,
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => authNotifier ?? _FakeAuthNotifier()),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: child,
    ),
  );
}

void main() {
  group('LoginScreen Pixel Wave 2e Tests', () {
    testWidgets('renders sign in tab with data, toggles password visibility',
        (tester) async {
      await tester.pumpWidget(_buildAuthTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tab_signin')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_signup')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_email')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_password')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_sign_in')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_wallet_sign_in')), findsOneWidget);

      // Password visibility toggle
      expect(find.text('SHOW PASSWORD'), findsOneWidget);
      await tester.tap(find.text('SHOW PASSWORD'));
      await tester.pumpAndSettle();
      expect(find.text('HIDE PASSWORD'), findsOneWidget);
    });

    testWidgets('empty validation shows error panel on sign in',
        (tester) async {
      await tester.pumpWidget(_buildAuthTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('auth_sign_in')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth_error')), findsOneWidget);
      expect(find.text('Enter a valid email and your password.'), findsOneWidget);
    });

    testWidgets('switches to sign up tab and validates empty fields and terms',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildAuthTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab_signup')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth_display_name')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_age_eligibility')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_terms')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_create_account')), findsOneWidget);

      // Tap submit with empty name
      await tester.ensureVisible(find.byKey(const ValueKey('auth_create_account')));
      await tester.tap(find.byKey(const ValueKey('auth_create_account')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name (at least 2 characters).'), findsOneWidget);

      // Enter name, tap submit without email
      await tester.enterText(
          find.byKey(const ValueKey('auth_display_name')), 'Juan Dela Cruz');
      await tester.ensureVisible(find.byKey(const ValueKey('auth_create_account')));
      await tester.tap(find.byKey(const ValueKey('auth_create_account')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      // Enter email, tap submit without password
      await tester.enterText(
          find.byKey(const ValueKey('auth_email')), 'juan@example.com');
      await tester.ensureVisible(find.byKey(const ValueKey('auth_create_account')));
      await tester.tap(find.byKey(const ValueKey('auth_create_account')));
      await tester.pumpAndSettle();
      expect(
          find.text('Use a password with at least 8 characters.'), findsOneWidget);

      // Enter password, tap submit without checking terms
      await tester.enterText(
          find.byKey(const ValueKey('auth_password')), 'securepass123');
      await tester.ensureVisible(find.byKey(const ValueKey('auth_create_account')));
      await tester.tap(find.byKey(const ValueKey('auth_create_account')));
      await tester.pumpAndSettle();
      expect(
          find.text('Confirm age eligibility and accept the terms to continue.'),
          findsOneWidget);
    });

    testWidgets('valid registration calls registerWithEmail', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_buildAuthTestApp(
        child: const LoginScreen(),
        authNotifier: fake,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab_signup')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth_display_name')), 'Juan Dela Cruz');
      await tester.enterText(
          find.byKey(const ValueKey('auth_email')), 'juan@example.com');
      await tester.enterText(
          find.byKey(const ValueKey('auth_password')), 'securepass123');
      await tester.ensureVisible(find.byKey(const ValueKey('auth_age_eligibility')));
      await tester.tap(find.byKey(const ValueKey('auth_age_eligibility')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth_terms')));
      await tester.tap(find.byKey(const ValueKey('auth_terms')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth_create_account')));
      await tester.tap(find.byKey(const ValueKey('auth_create_account')));
      await tester.pumpAndSettle();
      expect(fake.registerCalls, 1);
    });

    testWidgets('error response from sign-in renders pixel error panel',
        (tester) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_buildAuthTestApp(
        child: const LoginScreen(),
        authNotifier: fake,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('auth_email')), 'error@example.com');
      await tester.enterText(
          find.byKey(const ValueKey('auth_password')), 'wrongpassword');
      await tester.tap(find.byKey(const ValueKey('auth_sign_in')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth_error')), findsOneWidget);
      expect(find.text('Invalid credentials. Please retry.'), findsOneWidget);
      expect(fake.signInCalls, 1);
    });

    testWidgets('tap continue with wallet attempts signature service',
        (tester) async {
      await tester.pumpWidget(_buildAuthTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('auth_wallet_sign_in')));
      await tester.pumpAndSettle();

      // Handled gracefully via SnackBar fallback when modal uninitialized in headless test
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('UpdateDialog Pixel Wave 2e Tests', () {
    testWidgets('renders with version data, taps Later to dismiss',
        (tester) async {
      const info = AppVersionInfo(
        versionCode: 200,
        versionName: '2.0.0',
        downloadUrl: 'https://example.com/update.apk',
        changelog: 'Awesome pixel redesign features added.',
      );

      final notifier = _TestAppUpdateNotifier(
        const AppUpdateState(status: UpdateStatus.updateAvailable),
      );

      bool popped = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    await showDialog(
                      context: ctx,
                      builder: (_) => const UpdateDialog(versionInfo: info),
                    );
                    popped = true;
                  },
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('UPDATE AVAILABLE!'), findsOneWidget);
      expect(find.text("WHAT'S NEW:"), findsOneWidget);
      expect(find.text('Awesome pixel redesign features added.'), findsOneWidget);
      expect(find.text('LATER'), findsOneWidget);
      expect(find.text('UPDATE NOW'), findsOneWidget);

      await tester.tap(find.text('LATER'));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
    });

    testWidgets('taps Update Now triggers startDownloadAndInstall',
        (tester) async {
      const info = AppVersionInfo(
        versionCode: 200,
        versionName: '2.0.0',
        downloadUrl: 'https://example.com/update.apk',
        changelog: 'Test changelog',
      );

      final notifier = _TestAppUpdateNotifier(
        const AppUpdateState(status: UpdateStatus.updateAvailable),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const Scaffold(body: UpdateDialog(versionInfo: info)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('UPDATE NOW'));
      await tester.pumpAndSettle();
      expect(notifier.downloadCalls, 1);
    });

    testWidgets('renders downloading progress state', (tester) async {
      const info = AppVersionInfo(
        versionCode: 200,
        versionName: '2.0.0',
        downloadUrl: 'https://example.com/update.apk',
        changelog: '',
      );

      final notifier = _TestAppUpdateNotifier(
        const AppUpdateState(
          status: UpdateStatus.downloading,
          downloadProgress: 65,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const Scaffold(body: UpdateDialog(versionInfo: info)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Downloading update: 65%'), findsOneWidget);
      expect(find.text('DOWNLOADING...'), findsOneWidget);
    });

    testWidgets('renders ready to install state and taps Install Now',
        (tester) async {
      const info = AppVersionInfo(
        versionCode: 200,
        versionName: '2.0.0',
        downloadUrl: 'https://example.com/update.apk',
        changelog: '',
      );

      final notifier = _TestAppUpdateNotifier(
        const AppUpdateState(status: UpdateStatus.readyToInstall),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const Scaffold(body: UpdateDialog(versionInfo: info)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Package downloaded and ready to install.'), findsOneWidget);
      expect(find.text('INSTALL NOW'), findsOneWidget);
      expect(find.text('Re-download update package'), findsOneWidget);

      await tester.tap(find.text('INSTALL NOW'));
      await tester.pumpAndSettle();
      expect(notifier.downloadCalls, 1);

      await tester.tap(find.text('Re-download update package'));
      await tester.pumpAndSettle();
      expect(notifier.downloadCalls, 2);
    });

    testWidgets('renders error state when download fails', (tester) async {
      const info = AppVersionInfo(
        versionCode: 200,
        versionName: '2.0.0',
        downloadUrl: 'https://example.com/update.apk',
        changelog: '',
      );

      final notifier = _TestAppUpdateNotifier(
        const AppUpdateState(
          status: UpdateStatus.error,
          errorMessage: 'Connection timed out while fetching update.',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const Scaffold(body: UpdateDialog(versionInfo: info)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connection timed out while fetching update.'),
          findsOneWidget);
    });

    testWidgets('forceUpdate hides Later button', (tester) async {
      const info = AppVersionInfo(
        versionCode: 200,
        versionName: '2.0.0',
        downloadUrl: 'https://example.com/update.apk',
        changelog: 'Mandatory security update',
        forceUpdate: true,
      );

      final notifier = _TestAppUpdateNotifier(
        const AppUpdateState(status: UpdateStatus.updateAvailable),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const Scaffold(body: UpdateDialog(versionInfo: info)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LATER'), findsNothing);
      expect(find.text('UPDATE NOW'), findsOneWidget);
    });
  });

  group('StartupUpdateGate Pixel Wave 2e Tests', () {
    testWidgets('renders child when gateState is ready', (tester) async {
      final controller = _TestStartupUpdateController(
        const StartupGateState(phase: GatePhase.ready),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupUpdateControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const StartupUpdateGate(
              child: Text('APP CONTENT READY'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('APP CONTENT READY'), findsOneWidget);
    });

    testWidgets('renders loading view when gateState is checking',
        (tester) async {
      final controller = _TestStartupUpdateController(
        const StartupGateState(
          phase: GatePhase.checking,
          statusMessage: 'Connecting to JuanderQuest services...',
          installedVersionName: '1.0.0',
          installedVersionCode: 100,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupUpdateControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const StartupUpdateGate(
              child: Text('APP CONTENT READY'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('JUANDERQUEST'), findsOneWidget);
      expect(find.text('Connecting to JuanderQuest services...'), findsOneWidget);
      expect(find.textContaining('Build 100'), findsOneWidget);
      expect(find.text('APP CONTENT READY'), findsNothing);
    });

    testWidgets('renders base required view with download button',
        (tester) async {
      final controller = _TestStartupUpdateController(
        const StartupGateState(
          phase: GatePhase.baseRequired,
          latestVersion: AppVersionInfo(
            versionCode: 150,
            versionName: '1.5.0',
            downloadUrl: 'https://example.com/base.apk',
            changelog: 'Major platform upgrade',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupUpdateControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.pixel,
            home: const StartupUpdateGate(
              child: Text('APP CONTENT READY'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PLATFORM UPDATE REQUIRED'), findsOneWidget);
      expect(find.text("WHAT'S NEW:"), findsOneWidget);
      expect(find.text('Major platform upgrade'), findsOneWidget);
      expect(find.text('DOWNLOAD BASE APK'), findsOneWidget);
      expect(find.text('APP CONTENT READY'), findsNothing);
    });
  });
}
