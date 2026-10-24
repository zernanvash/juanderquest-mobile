import 'dart:math' as math;
import 'dart:typed_data';

typedef BannerRandom = double Function();

/// JS-compatible mulberry32. Every intermediate is explicitly reduced to
/// unsigned 32-bit so Dart VM and browser seeds stay in the same sequence.
BannerRandom mulberry32(int seed) {
  var a = seed & 0xffffffff;
  int imul32(int x, int y) => (x * y) & 0xffffffff;
  return () {
    a = (a + 0x6d2b79f5) & 0xffffffff;
    var t = imul32((a ^ (a >> 15)) & 0xffffffff, 1 | a);
    t = ((t + imul32((t ^ (t >> 7)) & 0xffffffff, 61 | t)) ^ t) & 0xffffffff;
    return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296;
  };
}

int fnv1a32(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xffffffff;
  }
  return hash;
}

double clamp01(double value, [double min = 0, double max = 1]) => value < min
    ? min
    : value > max
        ? max
        : value;

double smoothstep(double a, double b, double x) {
  final t = clamp01((x - a) / (b - a));
  return t * t * (3 - 2 * t);
}

class ValueNoise {
  ValueNoise(BannerRandom random) {
    for (var i = 0; i < 256; i++) {
      permutation[i] = i;
      values[i] = random();
    }
    for (var i = 255; i > 0; i--) {
      final j = (random() * (i + 1)).floor();
      final temp = permutation[i];
      permutation[i] = permutation[j];
      permutation[j] = temp;
    }
    for (var i = 0; i < 256; i++) {
      permutation[i + 256] = permutation[i];
    }
  }

  final Uint16List permutation = Uint16List(512);
  final Float32List values = Float32List(256);

  double call(double x, double y) {
    final xi = x.floor(), yi = y.floor();
    final xf = x - xi, yf = y - yi;
    final xx = xi & 255, yy = yi & 255;
    final a = values[permutation[permutation[xx] + yy]];
    final b = values[permutation[permutation[xx + 1] + yy]];
    final c = values[permutation[permutation[xx] + yy + 1]];
    final d = values[permutation[permutation[xx + 1] + yy + 1]];
    final u = xf * xf * (3 - 2 * xf), w = yf * yf * (3 - 2 * yf);
    return a + (b - a) * u + (c - a) * w + (a - b - c + d) * u * w;
  }
}

double fbm(ValueNoise noise, double x, double y, [int octaves = 5]) {
  var sum = 0.0, amplitude = .5, frequency = 1.0, max = 0.0;
  for (var i = 0; i < octaves; i++) {
    sum += amplitude *
        noise.call(x * frequency + i * 17.3, y * frequency - i * 9.1);
    max += amplitude;
    amplitude *= .5;
    frequency *= 2.03;
  }
  return sum / max;
}

List<int> rgb(String hex) => [
      int.parse(hex.substring(1, 3), radix: 16),
      int.parse(hex.substring(3, 5), radix: 16),
      int.parse(hex.substring(5, 7), radix: 16),
    ];

List<double> mixRgb(List<int> a, List<int> b, double t) => [
      a[0] + (b[0] - a[0]) * t,
      a[1] + (b[1] - a[1]) * t,
      a[2] + (b[2] - a[2]) * t,
    ];

int mixChannel(double value) => value.round().clamp(0, 255);

double distance(double x1, double y1, double x2, double y2) =>
    math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
