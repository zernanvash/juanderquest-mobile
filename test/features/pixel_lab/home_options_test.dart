import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/features/pixel_lab/home_options.dart';
import 'package:juanderquest_app/features/pixel_lab/pixel_lab_screen.dart';

class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('route:$label')));
}

GoRouter _router(Widget home) => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: '/profile', builder: (_, __) => const _Probe('/profile')),
        GoRoute(path: '/quests', builder: (_, __) => const _Probe('/quests')),
        GoRoute(path: '/history', builder: (_, __) => const _Probe('/history')),
        GoRoute(path: '/choice', builder: (_, __) => const _Probe('/choice')),
        GoRoute(path: '/saved', builder: (_, __) => const _Probe('/saved')),
        GoRoute(path: '/explore', builder: (_, __) => const _Probe('/explore')),
        GoRoute(path: '/map', builder: (_, __) => const _Probe('/map')),
      ],
    );

Future<void> _pumpPreview(
  WidgetTester tester,
  HomeOptionLayout layout, {
  HomeOptionData data = sampleHomeOptionData,
  Set<HomeGroup> failed = const {},
  VoidCallback? onRetry,
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: _router(
          HomeOptionPreview(
            layout: layout,
            data: data,
            failed: failed,
            onRetry: onRetry,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Home option A · character sheet', () {
    testWidgets('shows every data group with sample data', (tester) async {
      await _pumpPreview(tester, HomeOptionLayout.characterSheet);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('mJDQ balance'), findsOneWidget);
      expect(find.text('125400'), findsOneWidget);
      expect(find.text('Visit streak'), findsNothing);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('In progress'), findsWidgets);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Stamps'), findsOneWidget);
      expect(find.text('JuanChoice'), findsOneWidget);
      expect(find.text('Pick your next stop'), findsOneWidget);
      expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);
      expect(find.text('Patar Beach Cleanup'), findsOneWidget);
    });

    testWidgets('taps every group row to its page', (tester) async {
      for (final entry in const [
        ('home_a_identity', '/profile'),
        ('home_a_xp', '/profile'),
        ('home_a_mjdq', '/profile'),
        ('home_a_streak', '/profile'),
        ('home_a_in_progress', '/quests'),
        ('home_a_pending', '/history'),
        ('home_a_stamps', '/profile'),
        ('home_a_community', '/choice'),
        ('home_a_latest_proof', '/history'),
        ('home_a_explore', '/explore'),
      ]) {
        await _pumpPreview(tester, HomeOptionLayout.characterSheet);
        await tester.tap(find.byKey(ValueKey(entry.$1)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('route:${entry.$2}', skipOffstage: false),
            findsOneWidget);
      }
    });

    testWidgets('empty and error states', (tester) async {
      await _pumpPreview(tester, HomeOptionLayout.characterSheet,
          data: emptyHomeOptionData);
      expect(find.text('No quests in progress yet.'), findsOneWidget);
      expect(find.text('No proof submitted yet.'), findsOneWidget);

      var retries = 0;
      await _pumpPreview(
        tester,
        HomeOptionLayout.characterSheet,
        failed: HomeGroup.values.toSet(),
        onRetry: () => retries++,
      );
      expect(find.text('This section could not be loaded.'), findsNWidgets(7));
      await tester.tap(find.byKey(const ValueKey('home_a_retry_identity')));
      await tester.pump();
      expect(retries, 1);
    });
  });

  group('Home option B · quest log', () {
    testWidgets('shows the hero and switches the three wood tabs',
        (tester) async {
      await _pumpPreview(tester, HomeOptionLayout.questLog);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('PROGRESS'), findsOneWidget);
      expect(find.text('QUESTS'), findsWidgets);
      expect(find.text('COLLECTION'), findsOneWidget);
      expect(find.text('mJDQ balance'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home_b_tab_quests')));
      await tester.pump();
      expect(find.text('Today · Check in at Patar Beach'), findsOneWidget);
      expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home_b_tab_collection')));
      await tester.pump();
      expect(find.text('Passport stamps'), findsOneWidget);
      expect(find.text('Saved spots'), findsOneWidget);
    });

    testWidgets('taps group rows and next steps', (tester) async {
      for (final entry in const [
        ('home_b_streak', '/profile'),
        ('home_b_pending', '/history'),
        ('home_b_community', '/choice'),
        ('home_b_quests', '/quests'),
      ]) {
        await _pumpPreview(tester, HomeOptionLayout.questLog);
        await tester.tap(find.byKey(ValueKey(entry.$1)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('route:${entry.$2}', skipOffstage: false),
            findsOneWidget);
      }
    });

    testWidgets('empty state and all-groups error', (tester) async {
      await _pumpPreview(tester, HomeOptionLayout.questLog,
          data: emptyHomeOptionData);
      await tester.tap(find.byKey(const ValueKey('home_b_tab_quests')));
      await tester.pump();
      expect(find.text('No quests in progress yet.'), findsOneWidget);

      var retries = 0;
      await _pumpPreview(
        tester,
        HomeOptionLayout.questLog,
        failed: HomeGroup.values.toSet(),
        onRetry: () => retries++,
      );
      expect(find.text('This section could not be loaded.'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('home_b_retry_identity')));
      await tester.pump();
      expect(retries, 1);
    });
  });

  group('Home option C · HUD', () {
    testWidgets('shows the stat strip, mission, quests and community',
        (tester) async {
      await _pumpPreview(tester, HomeOptionLayout.hud);
      expect(find.text('mJDQ'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Today · Check in at Patar Beach'), findsOneWidget);
      expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Stamps'), findsOneWidget);
      expect(find.text('JuanChoice'), findsOneWidget);
      expect(find.text('Pick your next stop'), findsOneWidget);
    });

    testWidgets('taps stat groups and next steps', (tester) async {
      for (final entry in const [
        ('home_c_mjdq', '/profile'),
        ('home_c_streak', '/profile'),
        ('home_c_pending', '/history'),
        ('home_c_stamps', '/profile'),
        ('home_c_community', '/choice'),
        ('home_c_explore', '/explore'),
        ('home_c_map', '/map'),
      ]) {
        await _pumpPreview(tester, HomeOptionLayout.hud);
        await tester.tap(find.byKey(ValueKey(entry.$1)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('route:${entry.$2}', skipOffstage: false),
            findsOneWidget);
      }
    });

    testWidgets('empty state and retryable errors', (tester) async {
      await _pumpPreview(tester, HomeOptionLayout.hud,
          data: emptyHomeOptionData);
      expect(find.text('No quests in progress yet.'), findsOneWidget);

      var retries = 0;
      await _pumpPreview(
        tester,
        HomeOptionLayout.hud,
        failed: HomeGroup.values.toSet(),
        onRetry: () => retries++,
      );
      expect(find.text('This section could not be loaded.'), findsNWidgets(7));
      await tester.tap(find.byKey(const ValueKey('home_c_retry_wallet')));
      await tester.pump();
      expect(retries, 1);
    });
  });

  testWidgets('Pixel lab section opens the three full-screen previews',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PixelLabScreen())),
    );
    await tester.pump();

    expect(find.text('HOME LAYOUT · PICK ONE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_option_a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Home · A Character Sheet'), findsOneWidget);
  });
}
