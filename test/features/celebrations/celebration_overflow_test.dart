import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/celebrations/celebration.dart';

class _MemoryPixelSettingsStore implements PixelSettingsStore {
  PixelSettings? value;

  @override
  Future<PixelSettings?> read() async => value;

  @override
  Future<void> write(PixelSettings settings) async {
    value = settings;
  }
}

Widget _wrapScene(Celebration celebration, Size size, double textScale) {
  return ProviderScope(
    overrides: [
      pixelSettingsStoreProvider.overrideWithValue(_MemoryPixelSettingsStore()),
    ],
    child: MaterialApp(
      theme: AppTheme.pixel,
      home: PixelScope(
        settings: const PixelSettings(),
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: CelebrationPage(celebration: celebration),
        ),
      ),
    ),
  );
}

void main() {
  group('Celebration Overflow Tests (320x568 and 568x320 at 1.4x text clamp max)', () {
    const portrait = Size(320, 568);
    const landscape = Size(568, 320);
    const textScale = 1.4;

    final scenes = <String, Celebration>{
      'QuestComplete': const QuestComplete(
        questTitle: 'Hundred Islands Eco Run Super Long Title For Testing',
        reward: 125,
      ),
      'LevelUp': const LevelUp(
        fromLevel: 9,
        toLevel: 10,
      ),
      'StampEarned': const StampEarned(
        stampName: 'JuanChoice Voter Long Name Extra Text',
        stamp: DesignerArt.juanChoice,
      ),
    };

    for (final entry in scenes.entries) {
      testWidgets('${entry.key} zero overflow in portrait 320x568 at 2.0x text', (tester) async {
        tester.view.physicalSize = portrait;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapScene(entry.value, portrait, textScale));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.byType(CelebrationPage), findsOneWidget);
      });

      testWidgets('${entry.key} zero overflow in landscape 568x320 at 2.0x text', (tester) async {
        tester.view.physicalSize = landscape;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapScene(entry.value, landscape, textScale));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.byType(CelebrationPage), findsOneWidget);
      });
    }
  });
}
