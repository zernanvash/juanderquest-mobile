import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_painting.dart';

void main() {
  test(
      'paintPixels keeps size, is opaque, deterministic and uses a small palette',
      () {
    const w = 40, h = 30;
    final src = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        src[i] = x * 6;
        src[i + 1] = y * 8;
        src[i + 2] = (x * y) % 256;
        src[i + 3] = 255;
      }
    }
    final a = paintPixels(src, w, h);
    final b = paintPixels(src, w, h);
    expect(a.length, src.length);
    expect(a, b);
    final colours = <int>{};
    for (var i = 0; i < a.length; i += 4) {
      expect(a[i + 3], 255);
      colours.add(a[i] << 16 | a[i + 1] << 8 | a[i + 2]);
    }
    expect(colours.length, lessThanOrEqualTo(12));
    expect(colours.length, greaterThan(4));
  });
}
