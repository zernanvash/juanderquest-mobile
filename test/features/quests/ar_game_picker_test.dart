import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/quests/builder/builder_models.dart';
import 'package:juanderquest_app/features/quests/builder/widgets/task_settings_panel.dart';

// Plan 77 WP-3: the AR task's GAME picker in the mobile quest builder.
void main() {
  const fence = GeoFence(lat: 16.035, lng: 120.335, radiusMeters: 50);
  BuilderTask arTask(String game) => BuilderTask(
        key: 't1',
        stepOrder: 1,
        title: 'Play at the plaza',
        description: 'Win the game here.',
        required: true,
        checkpointType: 'ar',
        verification: ArVerification(fence: fence, game: game),
      );

  Future<void> pump(WidgetTester tester, BuilderTask task,
      {Size size = const Size(320, 568), ValueChanged<BuilderTask>? onChanged}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: TaskSettingsPanel(
              task: task,
              destinationDefaultFence: fence,
              destinationSpotId: 'spot-1',
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('collect shows the object picker; a game hides it and offers TRY IT', (tester) async {
    await pump(tester, arTask('collect'));
    expect(find.byKey(const ValueKey('ar_game_collect')), findsOneWidget);
    expect(find.text('3D Virtual Object'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_game_try')), findsNothing);

    await pump(tester, arTask('pana'));
    expect(find.text('3D Virtual Object'), findsNothing);
    expect(find.text('Needs 9 m of open ground'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_game_try')), findsOneWidget);
  });

  testWidgets('picking a game keeps the fence', (tester) async {
    BuilderTask? changed;
    await pump(tester, arTask('collect'), onChanged: (t) => changed = t);
    await tester.ensureVisible(find.byKey(const ValueKey('ar_game_sipa')));
    await tester.tap(find.byKey(const ValueKey('ar_game_sipa')));
    final ver = changed!.verification as ArVerification;
    expect((ver.game, ver.fence.lat, ver.fence.radiusMeters), ('sipa', fence.lat, 50));
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('the picker fits at ${size.width.toInt()}x${size.height.toInt()} with 2x text', (tester) async {
      await pump(tester, arTask('tumbang_preso'), size: size);
    });
  }
}
