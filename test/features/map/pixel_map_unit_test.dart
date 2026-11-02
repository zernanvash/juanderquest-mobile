import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/features/map/pixel/pixel_map_mode.dart';
import 'package:juanderquest_app/features/map/pixel/pixel_map_palette.dart';
import 'package:juanderquest_app/features/map/pixel/pixel_map_shader.dart';

void main() {
  group('Pixel Map Shader Palette (Plan 75d §6)', () {
    test('contains exactly 19 approved brand-palette colors', () {
      expect(PixelMapPalette.colors.length, 19);
    });

    test('all palette colors match PixelPalette constants without raw hex deviations', () {
      final expectedKeys = <String, int>{
        'paper': PixelPalette.paper.toARGB32(),
        'paperDim': PixelPalette.paperDim.toARGB32(),
        'cream': PixelPalette.cream.toARGB32(),
        'parchment': PixelPalette.parchment.toARGB32(),
        'mist': PixelPalette.mist.toARGB32(),
        'stone': PixelPalette.stone.toARGB32(),
        'white': PixelPalette.white.toARGB32(),
        'slate': PixelPalette.slate.toARGB32(),
        'ink': PixelPalette.ink.toARGB32(),
        'sky': PixelPalette.sky.toARGB32(),
        'blueLight': PixelPalette.blueLight.toARGB32(),
        'blue': PixelPalette.blue.toARGB32(),
        'greenLight': PixelPalette.greenLight.toARGB32(),
        'green': PixelPalette.green.toARGB32(),
        'greenDark': PixelPalette.greenDark.toARGB32(),
        'sunLight': PixelPalette.sunLight.toARGB32(),
        'woodLight': PixelPalette.woodLight.toARGB32(),
        'sun': PixelPalette.sun.toARGB32(),
        'orange': PixelPalette.orange.toARGB32(),
      };

      for (final entry in PixelMapPalette.colors) {
        expect(expectedKeys.containsKey(entry.name), isTrue,
            reason: 'Unexpected palette key ${entry.name}');
        expect(entry.color.toARGB32(), expectedKeys[entry.name],
            reason: '${entry.name} ARGB value must match PixelPalette');

        // RGB float precision within ±0.005 of uint8 / 255.0
        final expectedR = ((entry.color.toARGB32() >> 16) & 0xFF) / 255.0;
        final expectedG = ((entry.color.toARGB32() >> 8) & 0xFF) / 255.0;
        final expectedB = (entry.color.toARGB32() & 0xFF) / 255.0;

        expect(entry.r, closeTo(expectedR, 0.005));
        expect(entry.g, closeTo(expectedG, 0.005));
        expect(entry.b, closeTo(expectedB, 0.005));
      }
    });

    test('shaders/pixel_map.frag shader source matches PixelMapPalette 19 colors', () {
      final shaderFile = File('shaders/pixel_map.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shaders/pixel_map.frag must exist');

      final content = shaderFile.readAsStringSync();
      expect(content, contains('19 colours'));

      for (final entry in PixelMapPalette.colors) {
        // e.g. vec3(0.980, 0.976, 0.961) // paper
        expect(content, contains('// ${entry.name}'),
            reason: 'Shader must document and define ${entry.name}');
      }
    });
  });

  group('Pixel Map Cell Size Math (Plan 75d §6)', () {
    test('computes integer device pixel cell sizes at standard device DPRs', () {
      const artPx = 2.0;
      const cellArt = 2;

      // DPR 2.0 -> devicePerArt = round(2.0 * 2.0) = 4 -> uCell = 4 * 2 = 8.0
      final uCell200 = PixelMapShader.computeUCell(
        artPx: artPx,
        dpr: 2.0,
        cellArt: cellArt,
      );
      expect(uCell200, 8.0);
      expect(uCell200 % 1.0, 0.0);

      // DPR 2.625 (typical 1080p phone) -> round(2.0 * 2.625) = round(5.25) = 5 -> uCell = 10.0
      final uCell262 = PixelMapShader.computeUCell(
        artPx: artPx,
        dpr: 2.625,
        cellArt: cellArt,
      );
      expect(uCell262, 10.0);
      expect(uCell262 % 1.0, 0.0);

      // DPR 3.0 (high-DPI phone) -> round(2.0 * 3.0) = 6 -> uCell = 6 * 2 = 12.0
      final uCell300 = PixelMapShader.computeUCell(
        artPx: artPx,
        dpr: 3.0,
        cellArt: cellArt,
      );
      expect(uCell300, 12.0);
      expect(uCell300 % 1.0, 0.0);
    });
  });

  group('Pixel Map Mode Preference (Plan 75d §6)', () {
    test('defaults to PixelMapMode.real when storage is empty or fails', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecurePixelMapModeStore();

      final mode = await store.read();
      expect(mode, PixelMapMode.real);
    });

    test('persists and restores PixelMapMode.pixel and PixelMapMode.real', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecurePixelMapModeStore();

      await store.write(PixelMapMode.pixel);
      expect(await store.read(), PixelMapMode.pixel);

      await store.write(PixelMapMode.real);
      expect(await store.read(), PixelMapMode.real);
    });
  });
}
