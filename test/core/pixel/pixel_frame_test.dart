import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_frame.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';

void main() {
  group('PixelFrameSkin.resolve', () {
    test('no preview and no frame cosmetic: no frame', () {
      expect(PixelFrameSkin.resolve(null, null), isNull);
      expect(PixelFrameSkin.resolve(null, {'title': {}}), isNull);
    });

    test('an equipped frame with asset.panel picks that frame', () {
      final cosmetics = <String, dynamic>{
        'frame': {
          'asset': {'panel': 'bamboo'},
        },
      };
      expect(PixelFrameSkin.resolve(null, cosmetics), PixelFrameSkin.bamboo);
    });

    test('an avatar-only frame (no panel) leaves the panel alone', () {
      final cosmetics = <String, dynamic>{
        'frame': {
          'asset': {
            'colors': ['#ffd166'],
          },
        },
      };
      expect(PixelFrameSkin.resolve(null, cosmetics), isNull);
    });

    test('the Pixel Lab preview wins; unknown names give no frame', () {
      expect(PixelFrameSkin.resolve('bamboo', null), PixelFrameSkin.bamboo);
      expect(PixelFrameSkin.resolve('nope', null), isNull);
    });
  });

  test('every frame ships all nine pieces at the documented sizes', () {
    for (final skin in PixelFrameSkin.all) {
      for (final name in [
        'corner-tl',
        'corner-tr',
        'corner-bl',
        'corner-br',
        'edge-top',
        'edge-bottom',
        'edge-left',
        'edge-right',
        'fill',
      ]) {
        final f = File('${skin.dir}/$name.png');
        expect(f.existsSync(), isTrue, reason: f.path);
        // PNG header: width and height are big-endian at bytes 16..23.
        final b = f.readAsBytesSync();
        final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
        final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
        if (name.startsWith('corner')) {
          expect([w, h], [skin.corner, skin.corner], reason: name);
        } else if (name == 'edge-top' || name == 'edge-bottom') {
          expect(h, skin.edge, reason: name);
        } else if (name == 'edge-left' || name == 'edge-right') {
          expect(w, skin.edge, reason: name);
        }
      }
    }
  });

  testWidgets('a framed panel insets its child by edge + padding',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: PixelFramedPanel(
                  skin: PixelFrameSkin.bamboo,
                  padding: 6,
                  child: SizedBox(key: ValueKey('kid'), height: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Let the pieces decode.
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200),
        ));
    await tester.pump();

    final panel = tester.getRect(find.byType(PixelFramedPanel));
    final kid = tester.getRect(find.byKey(const ValueKey('kid')));
    final inset = kid.left - panel.left;
    expect(inset, greaterThan(0));
    expect(kid.top - panel.top, closeTo(inset, 0.01));
    expect(panel.right - kid.right, closeTo(inset, 0.01));
    expect(tester.takeException(), isNull);
  });
}
