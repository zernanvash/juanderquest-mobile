import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/audio/game_audio.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';

void main() {
  test('music and button sounds are on by default and survive a save', () {
    const fresh = PixelSettings();
    expect(fresh.music, isTrue);
    expect(fresh.sounds, isTrue);

    final off = fresh.copyWith(music: false, sounds: false);
    final restored = PixelSettings.fromJson(jsonEncode(off.toJson()))!;
    expect(restored.music, isFalse);
    expect(restored.sounds, isFalse);
    expect(restored, off);

    // Settings saved before 2026-11-16 have no keys: both default to on.
    final old = PixelSettings.fromJson('{"font":"Silkscreen","fontV":2}')!;
    expect(old.music, isTrue);
    expect(old.sounds, isTrue);
  });

  test('configure() follows the settings for button sounds', () {
    GameAudio.instance.configure(music: false, sounds: true);
    expect(GameAudio.instance.buttonSounds.value, isTrue);
    GameAudio.instance.configure(music: false, sounds: false);
    expect(GameAudio.instance.buttonSounds.value, isFalse);
  });

  testWidgets('balance coin spins continuously with no pause', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home:
          const Scaffold(body: Center(child: MjdqAmount(100, idleSpin: true))),
    ));
    expect(find.byType(PixelAnimation), findsOneWidget);
    PixelArt shown() =>
        tester.widget<PixelSprite>(find.byType(PixelSprite)).art;
    final seen = <PixelArt>{};
    for (var i = 0; i < 14; i++) {
      seen.add(shown());
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 1.4 s at 10 fps shows the whole 7-frame turn, still animating.
    expect(seen.length, 7);
    expect(find.byType(PixelAnimation), findsOneWidget);
  });
}
