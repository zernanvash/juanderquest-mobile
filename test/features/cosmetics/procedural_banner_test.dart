import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/cosmetics/procedural/banner_math.dart';
import 'package:juanderquest_app/features/cosmetics/procedural/procedural_banner_painter.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/profile_banner.dart';
import 'package:juanderquest_app/features/shop/models/cosmetic_item.dart';

const _palettes = <String, List<List<String>>>{
  'sunset': [
    ['#2b2a5c', '#c8577a', '#f6a85a', '#ffe2a0', '#3c3a6b', '#141634'],
    ['#3b1027', '#a8323e', '#f27b3f', '#ffd27a', '#5a1f2f', '#1c0b14'],
  ],
  'islands': [
    ['#0a3a5a', '#1792ad', '#73dccd', '#efdcae', '#2c6637', '#68a952'],
    ['#1a1c47', '#355c8e', '#8fb3c8', '#e6bf93', '#213b2b', '#4b7448'],
  ],
  'bangus': [
    ['#0f5e72', '#06283a', '#2d4c63', '#dfe9ee', '#9ee7f0'],
    ['#11403f', '#041a1c', '#6b5a24', '#f6e7b4', '#ffe7a3'],
  ],
  'asin': [
    ['#b8c3c9', '#f7f8f6', '#eef2f6', '#f6eef0', '#ffffff'],
    ['#6b8794', '#d5e8ee', '#c3dde8', '#e9dcd8', '#ffffff'],
  ],
  'habi': [
    ['#f2ebdc', '#1f3a6b', '#b5352b', '#e1a93a', '#13284d'],
    ['#1b1210', '#c7372f', '#f2e6cf', '#e2b23a', '#7a1e18'],
  ],
  'alitaptap': [
    ['#050b1a', '#12233a', '#04070d', '#d8ff7a', '#0a1a26'],
    ['#04131a', '#0f3a44', '#020a0c', '#9cffd6', '#06222a'],
  ],
  'topo': [
    ['#eef0e2', '#a9b48d', '#6f7d55', '#d24b2a', '#1d5c46'],
    ['#13201b', '#2d4a3d', '#4f7a63', '#ffb547', '#9ff0c8'],
  ],
  'banderitas': [
    ['#3fa7d6', '#bfe7f2', '#e63946', '#f4c430', '#2a9d8f', '#f1faee'],
    ['#9bb7e0', '#f3e6f0', '#f28fad', '#ffd56b', '#7fd1b9', '#ffffff'],
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('banner random helpers match the approved JavaScript reference', () {
    expect(fnv1a32('guest|banner-lingayen-sunset'), 2503267308);
    final random = mulberry32(1);
    expect(random(), closeTo(0.6270739405881613, 1e-12));
    expect(random(), closeTo(0.002735721180215478, 1e-12));
    expect(random(), closeTo(0.5274470399599522, 1e-12));
  });

  test('cosmetic item preserves the API-provided viewer seed', () {
    final item = CosmeticItem.fromJson({
      'id': 'banner-lingayen-sunset',
      'kind': 'banner',
      'name': 'Lingayen Sunset',
      'rarity': 'common',
      'asset': {'style': 'procedural', 'generator': 'sunset'},
      'seed': 2503267308,
      'owned': false,
      'equipped': false,
      'buyable': true,
    });
    expect(item.seed, 2503267308);
  });

  for (final entry in _palettes.entries) {
    for (var paletteIndex = 0; paletteIndex < 2; paletteIndex++) {
      test('paints ${entry.key} palette $paletteIndex deterministically',
          () async {
        final colors = entry.value[paletteIndex];
        final first = await _render(entry.key, 'palette-$paletteIndex', colors);
        final second =
            await _render(entry.key, 'palette-$paletteIndex', colors);
        expect(first, isNotEmpty);
        expect(second, orderedEquals(first));
      });
    }
  }

  testWidgets('reduced motion keeps a procedural banner on its still frame',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: ProfileBanner(
              asset: {
                'style': 'procedural',
                'generator': 'sunset',
                'palette': 'golden',
                'colors': ['#2b2a5c', '#c8577a', '#f6a85a', '#ffe2a0'],
              },
              seed: 2503267308,
              animate: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

Future<Uint8List> _render(
  String generator,
  String palette,
  List<String> colors,
) async {
  final time = ValueNotifier<double>(6);
  final painter = ProceduralBannerPainter(
    asset: {
      'style': 'procedural',
      'generator': generator,
      'palette': palette,
      'colors': colors,
    },
    seed: 2503267308,
    time: time,
  );
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Size(360, 120));
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 120);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final result = bytes!.buffer.asUint8List().toList(growable: false);
  image.dispose();
  picture.dispose();
  painter.disposeCache();
  time.dispose();
  return Uint8List.fromList(result);
}
