import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// "Painting" pixelation (owner 2026-11-05): not a plain mosaic, but a small
/// hand-painted look like a block-game painting. The photo is shrunk to
/// [width] pixels, reduced to its own [colors]-colour palette (k-means), and
/// mapped back with a light 4×4 ordered dither plus a fixed per-pixel jitter
/// that reads as brush texture. Same technique as indexed-colour mode in
/// pixel editors (Aseprite) and Pixel It; a few milliseconds per photo.
Uint8List paintPixels(
  Uint8List rgba,
  int width,
  int height, {
  int colors = 12,
}) {
  final n = width * height;
  final out = Uint8List(n * 4);
  if (n == 0) return out;

  // 1. Palette: k-means over the pixels, seeded evenly by brightness.
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) => _luma(rgba, a).compareTo(_luma(rgba, b)));
  final k = colors.clamp(1, n);
  final pr = List<double>.filled(k, 0), pg = List<double>.filled(k, 0);
  final pb = List<double>.filled(k, 0);
  for (var c = 0; c < k; c++) {
    final i = order[((c + 0.5) * n / k).floor().clamp(0, n - 1)] * 4;
    pr[c] = rgba[i].toDouble();
    pg[c] = rgba[i + 1].toDouble();
    pb[c] = rgba[i + 2].toDouble();
  }
  final assign = Int32List(n);
  for (var iter = 0; iter < 6; iter++) {
    final sr = List<double>.filled(k, 0), sg = List<double>.filled(k, 0);
    final sb = List<double>.filled(k, 0), cnt = List<int>.filled(k, 0);
    for (var p = 0; p < n; p++) {
      final i = p * 4;
      final c = _nearest(rgba[i], rgba[i + 1], rgba[i + 2], pr, pg, pb);
      assign[p] = c;
      sr[c] += rgba[i];
      sg[c] += rgba[i + 1];
      sb[c] += rgba[i + 2];
      cnt[c]++;
    }
    for (var c = 0; c < k; c++) {
      if (cnt[c] == 0) continue;
      pr[c] = sr[c] / cnt[c];
      pg[c] = sg[c] / cnt[c];
      pb[c] = sb[c] / cnt[c];
    }
  }

  // A touch more contrast and colour, like painted pigment.
  for (var c = 0; c < k; c++) {
    final l = 0.299 * pr[c] + 0.587 * pg[c] + 0.114 * pb[c];
    double punch(double v) => ((l + (v - l) * 1.25) - 128) * 1.08 + 128;
    pr[c] = punch(pr[c]).clamp(0, 255);
    pg[c] = punch(pg[c]).clamp(0, 255);
    pb[c] = punch(pb[c]).clamp(0, 255);
  }

  // 2. Map back with a light ordered dither + fixed brush jitter.
  const bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = y * width + x;
      final i = p * 4;
      final d = (bayer[(y & 3) * 4 + (x & 3)] / 16 - 0.5) * 22 +
          (_hash(x, y) - 0.5) * 14;
      final c = _nearest(
        (rgba[i] + d).clamp(0, 255),
        (rgba[i + 1] + d).clamp(0, 255),
        (rgba[i + 2] + d).clamp(0, 255),
        pr,
        pg,
        pb,
      );
      out[i] = pr[c].round();
      out[i + 1] = pg[c].round();
      out[i + 2] = pb[c].round();
      out[i + 3] = 255;
    }
  }
  return out;
}

double _luma(Uint8List rgba, int p) =>
    0.299 * rgba[p * 4] + 0.587 * rgba[p * 4 + 1] + 0.114 * rgba[p * 4 + 2];

int _nearest(
    num r, num g, num b, List<double> pr, List<double> pg, List<double> pb) {
  var best = 0;
  var bestD = double.infinity;
  for (var c = 0; c < pr.length; c++) {
    final dr = r - pr[c], dg = g - pg[c], db = b - pb[c];
    // Weighted RGB distance (closer to how the eye judges colour).
    final dist = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
    if (dist < bestD) {
      bestD = dist;
      best = c;
    }
  }
  return best;
}

double _hash(int x, int y) {
  var h = (x * 374761393 + y * 668265263) & 0x7fffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
  return (h & 0xffff) / 0xffff;
}

/// Shows [image] as a painting-style pixel image, filling its box (cover).
/// Each source is processed once and cached.
class PixelPainting extends StatefulWidget {
  const PixelPainting({
    super.key,
    required this.image,
    this.width = 40,
    this.alignment = Alignment.center,
  });

  final ImageProvider image;
  final int width;
  final Alignment alignment;

  @override
  State<PixelPainting> createState() => _PixelPaintingState();
}

class _PixelPaintingState extends State<PixelPainting> {
  static final Map<Object, Future<ui.Image?>> _cache = {};
  ui.Image? _painted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(PixelPainting old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image || old.width != widget.width) _load();
  }

  void _load() {
    final key = (widget.image, widget.width);
    final source = ResizeImage(widget.image, width: widget.width);
    final future = _cache.putIfAbsent(
      key,
      () => _render(source, createLocalImageConfiguration(context)),
    );
    future.then((img) {
      if (img == null) {
        _cache.remove(key); // retry next time (e.g. offline)
      } else if (mounted) {
        setState(() => _painted = img);
      }
    });
  }

  static Future<ui.Image?> _render(
    ImageProvider source,
    ImageConfiguration config,
  ) async {
    final done = Completer<ui.Image?>();
    final stream = source.resolve(config);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) async {
      stream.removeListener(listener);
      try {
        final img = info.image;
        final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) return done.complete(null);
        final pixels =
            paintPixels(data.buffer.asUint8List(), img.width, img.height);
        ui.decodeImageFromPixels(
          pixels,
          img.width,
          img.height,
          ui.PixelFormat.rgba8888,
          done.complete,
        );
      } catch (_) {
        if (!done.isCompleted) done.complete(null);
      }
    }, onError: (_, __) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete(null);
    });
    stream.addListener(listener);
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    final img = _painted;
    if (img == null) return const SizedBox.expand();
    return RawImage(
      image: img,
      fit: BoxFit.cover,
      alignment: widget.alignment,
      filterQuality: FilterQuality.none,
    );
  }
}
