import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'banner_math.dart';

/// Canvas port of the eight approved Banner Lab recipes. Seed and palette are
/// provided by the API; this painter never derives identity on-device.
class ProceduralBannerPainter extends CustomPainter {
  ProceduralBannerPainter({
    required this.asset,
    required this.seed,
    required this.time,
  }) : super(repaint: time);

  final Map<String, dynamic> asset;
  final int seed;
  final ValueListenable<double> time;
  ui.Picture? _basePicture;
  Size? _baseSize;
  List<_Fish>? _fish;
  List<List<double>>? _bubbles;
  List<_Firefly>? _fireflies;
  double _lastT = 6;
  double _simTime = 0;
  double _phase = 0;

  String get generator => asset['generator']?.toString() ?? '';
  List<String> get colors =>
      ((asset['colors'] as List?) ?? const ['#3f6653', '#95d5b2'])
          .map((value) => value.toString())
          .toList();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final now = time.value;
    final dt = (now - _lastT).clamp(0, .05).toDouble();
    _lastT = now;
    switch (generator) {
      case 'sunset':
        _paintSunset(canvas, size, now);
        break;
      case 'bangus':
        _paintBangus(canvas, size, now, dt);
        break;
      case 'banderitas':
        _paintBanderitas(canvas, size, now);
        break;
      case 'habi':
        _paintHabi(canvas, size, now);
        break;
      case 'islands':
        _paintIslands(canvas, size, now);
        break;
      case 'asin':
        _paintAsin(canvas, size, now);
        break;
      case 'topo':
        _paintTopo(canvas, size, now);
        break;
      case 'alitaptap':
        _paintAlitaptap(canvas, size, now, dt);
        break;
      default:
        _paintFallback(canvas, size);
    }
  }

  Color _c(int index, [int fallback = 0]) =>
      _color(colors[index.clamp(0, colors.length - 1)]);
  Color _color(String hex, [double opacity = 1]) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xff')))
          .withOpacity(opacity);
    } catch (_) {
      return Colors.green.withOpacity(opacity);
    }
  }

  Color _rgba(String hex, double opacity) => _color(hex, opacity.clamp(0, 1));
  double _cosh(double value) => (math.exp(value) + math.exp(-value)) / 2;
  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;
  void _linear(Canvas canvas, Size size, List<Color> palette,
      [Alignment begin = Alignment.topCenter,
      Alignment end = Alignment.bottomCenter]) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(colors: palette, begin: begin, end: end)
              .createShader(Offset.zero & size));
  }

  BannerRandom _random([int salt = 0]) =>
      mulberry32((seed ^ salt) & 0xffffffff);

  void _paintFallback(Canvas canvas, Size size) {
    _linear(canvas, size, [_c(0), _c(1, 0)], Alignment.topLeft,
        Alignment.bottomRight);
  }

  void _paintSunset(Canvas canvas, Size s, double t) {
    final rng = _random();
    final horizon = s.height * (.54 + rng() * .08),
        sunX = s.width * (.18 + rng() * .64),
        radius = s.height * .15;
    _linear(canvas, Size(s.width, horizon), [_c(0), _c(1), _c(2)],
        Alignment.topCenter, Alignment.bottomCenter);
    final glow =
        Rect.fromCircle(center: Offset(sunX, horizon), radius: s.height * 1.1);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, s.width, horizon),
        Paint()
          ..shader = RadialGradient(
                  colors: [_rgba(colors[3], .55), _rgba(colors[3], 0)])
              .createShader(glow));
    for (var i = 0; i < 6; i++) {
      final x0 = rng() * s.width,
          y = horizon * (.12 + rng() * .6),
          w = s.height * (.5 + rng() * 1.3),
          h = s.height * (.035 + rng() * .05),
          v = s.height * (.01 + rng() * .03);
      final x = (x0 + t * v) % (s.width + w * 2) - w;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: w * 2, height: h * 2),
          _fill(_rgba(colors[2], .35)));
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y + h * .4), width: w * 1.6, height: h * .9),
          _fill(_rgba(colors[3], .25)));
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, s.width, horizon));
    canvas.drawCircle(
        Offset(sunX, horizon - radius * .3 + math.sin(t * .22) * radius * .08),
        radius,
        _fill(_c(3)));
    canvas.restore();
    final waterRect = Rect.fromLTWH(0, horizon, s.width, s.height - horizon);
    canvas.drawRect(
        waterRect,
        Paint()
          ..shader =
              LinearGradient(colors: [_c(4), _c(5)]).createShader(waterRect));
    for (var i = 0; i < 44; i++) {
      final a = rng(),
          b = rng(),
          phase = rng() * 6.28,
          k = math.pow(a, 1.5).toDouble(),
          y = horizon + k * (s.height - horizon);
      final w = radius * (.5 + k * 2.2), x = sunX + (b - .5) * w * 2;
      final alpha =
          math.pow(math.max(0, math.sin(t * 2.6 + phase)), 3).toDouble();
      canvas.drawRect(
          Rect.fromLTWH(x - w * .18, y, w * .36, math.max(1, s.height * .006)),
          _fill(_rgba(colors[3], alpha * .9)));
    }
    final rngBands = _random();
    for (var band = 0; band < 8; band++) {
      final frequency1 = (.006 + rngBands() * .01) * 600 / s.height;
      final frequency2 = (.014 + rngBands() * .02) * 600 / s.height;
      final phase = rngBands() * 6.28,
          speed = .6 + rngBands() * .8,
          k = (band + 1) / 8;
      final y0 = horizon + math.pow(k, 1.7) * (s.height - horizon),
          amp = s.height * .008 * (1 + k * 2);
      final path = Path();
      for (double x = 0; x <= s.width; x += 6) {
        final y = y0 +
            amp *
                (math.sin(x * frequency1 + t * speed + phase) +
                    .5 * math.sin(x * frequency2 - t * speed * 1.3));
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
          path,
          _stroke(
              _rgba(colors[2], .18 + k * .12), math.max(1, s.height * .004)));
    }
  }

  void _initFish(Size s) {
    if (_fish != null && _baseSize == s) return;
    _baseSize = s;
    final rng = _random();
    final n = (26 + s.width / s.height * 5).round(), scale = s.height * .05;
    _fish = List.generate(
        n,
        (_) => _Fish(
            rng() * s.width,
            s.height * (.2 + rng() * .6),
            (rng() - .3) * s.height * .3,
            (rng() - .5) * s.height * .1,
            rng() * 6.28));
    _bubbles = List.generate(
        16, (_) => [rng() * s.width, rng() * s.height, .5 + rng()]);
    _phase = rng() * 6.28;
    _simTime = 0;
    for (var i = 0; i < 240; i++) {
      _stepFish(s, 1 / 30);
    }
    _lastT = 6;
    // Keep the scale variable consumed so the random stream mirrors the lab.
    if (scale.isNaN) _phase = 0;
  }

  void _stepFish(Size s, double dt) {
    final fish = _fish!;
    _simTime += dt;
    final tx = s.width * (.5 + .44 * math.sin(_simTime * .11 + _phase));
    final ty = s.height * (.5 + .24 * math.sin(_simTime * .29 + _phase * 2));
    final radius = s.height * .24, separation = s.height * .05 * 2.3;
    for (final f in fish) {
      var cx = 0.0, cy = 0.0, ax = 0.0, ay = 0.0, sx = 0.0, sy = 0.0;
      var count = 0;
      for (final o in fish) {
        if (identical(o, f)) continue;
        final dx = o.x - f.x, dy = o.y - f.y, d = distance(o.x, o.y, f.x, f.y);
        if (d < radius) {
          cx += o.x;
          cy += o.y;
          ax += o.vx;
          ay += o.vy;
          count++;
          if (d < separation) {
            sx -= dx / (d + .01);
            sy -= dy / (d + .01);
          }
        }
      }
      var fx = (tx - f.x) * .25, fy = (ty - f.y) * .4;
      if (count > 0) {
        fx += (cx / count - f.x) * .9 + (ax / count - f.vx) * 1.1;
        fy += (cy / count - f.y) * .9 + (ay / count - f.vy) * 1.1;
      }
      fx += sx * s.height * 1.2;
      fy += sy * s.height * 1.2;
      if (f.y < s.height * .12) fy += s.height * 2;
      if (f.y > s.height * .88) fy -= s.height * 2;
      f.vx += fx * dt;
      f.vy += fy * dt;
      final speed = math.sqrt(f.vx * f.vx + f.vy * f.vy),
          low = s.height * .22,
          high = s.height * .42;
      if (speed < low || speed > high) {
        final m = (speed < low ? low : high) / (speed == 0 ? 1 : speed);
        f.vx *= m;
        f.vy *= m;
      }
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      if (f.x > s.width + s.height * .15) f.x = -s.height * .15;
      if (f.x < -s.height * .15) f.x = s.width + s.height * .15;
    }
  }

  void _paintBangus(Canvas canvas, Size s, double t, double dt) {
    _initFish(s);
    if (dt > 0) _stepFish(s, dt);
    _linear(canvas, s, [_c(0), _c(1)]);
    for (var i = 0; i < 5; i++) {
      final x = s.width * (.1 + i * .2) + math.sin(t * .3 + i) * s.width * .04;
      final path = Path()
        ..moveTo(x - s.height * .06, 0)
        ..lineTo(x + s.height * .06, 0)
        ..lineTo(x + s.height * .5, s.height)
        ..lineTo(x + s.height * .1, s.height)
        ..close();
      canvas.drawPath(
          path, _fill(_rgba(colors[4], .05 + .03 * math.sin(t * .7 + i * 2))));
    }
    for (final bubble in _bubbles!) {
      final y =
          ((bubble[1] - t * s.height * .12 * bubble[2]) % s.height + s.height) %
              s.height;
      canvas.drawCircle(
          Offset(bubble[0] + math.sin(t * 2 + bubble[2] * 9) * 3, y),
          s.height * .006 * bubble[2],
          _stroke(_rgba(colors[4], .35), 1));
    }
    for (final f in _fish!) {
      canvas.save();
      canvas.translate(f.x, f.y);
      canvas.rotate(math.atan2(f.vy, f.vx));
      final size = s.height * .05,
          tail = math.sin(t * 11 + f.phase) * size * .22;
      final p = Path()
        ..moveTo(-size * 1.2, 0)
        ..lineTo(-size * 2.05, -size * .55 + tail)
        ..lineTo(-size * 1.75, tail * .5)
        ..lineTo(-size * 2.05, size * .55 + tail)
        ..close();
      canvas.drawPath(p, _fill(_c(2)));
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: size * 2.7, height: size * .8),
          _fill(_c(3)));
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset.zero, width: size * 2.7, height: size * .8),
          math.pi,
          math.pi,
          true,
          _fill(_c(2)));
      canvas.drawCircle(Offset(size * .95, -size * .08), size * .09,
          _fill(const Color(0xff0b1a22)));
      canvas.restore();
    }
  }

  void _paintBanderitas(Canvas canvas, Size s, double t) {
    final rng = _random();
    _linear(canvas, s, [_c(0), _c(1)]);
    final fan = Paint()..color = Colors.white.withOpacity(.05);
    canvas.save();
    canvas.translate(s.width * .5, s.height * 1.15);
    canvas.rotate(t * .03);
    for (var i = 0; i < 18; i++) {
      canvas.rotate(math.pi / 9);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(s.width, -s.height * .12)
        ..lineTo(s.width, s.height * .12)
        ..close();
      canvas.drawPath(path, fan);
    }
    canvas.restore();
    final k = 1.7, denom = _cosh(k) - 1, flagWidth = s.height * .09;
    double cat(double u) => (_cosh(k * (2 * u - 1)) - 1) / denom;
    for (var row = 0; row < 3; row++) {
      final yl = s.height * (.04 + row * .16 + rng() * .05),
          yr = s.height * (.04 + row * .16 + rng() * .05),
          sag = s.height * (.18 + rng() * .1),
          phase = rng() * 6.28;
      double yAt(double u) =>
          yl +
          (yr - yl) * u +
          sag * (1 + .05 * math.sin(t * .8 + phase)) * (1 - cat(u));
      final cord = Path();
      for (double x = 0; x <= s.width; x += 8) {
        final p = Offset(x, yAt(x / s.width));
        if (x == 0) {
          cord.moveTo(p.dx, p.dy);
        } else {
          cord.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
          cord, _stroke(const Color(0x8c1e1e28), math.max(1, s.height * .005)));
      final count = math.max(6, (s.width / (flagWidth * 1.25)).round());
      for (var flag = 0; flag < count; flag++) {
        final u = (flag + .5) / count,
            x = u * s.width,
            y = yAt(u),
            angle = math.atan2(yAt(u + .01) - yAt(u - .01), s.width * .02) +
                math.sin(t * 2.1 + flag * .7 + row) * .22;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        final path = Path()
          ..moveTo(-flagWidth / 2, 0)
          ..lineTo(flagWidth / 2, 0);
        if (row.isEven) {
          path
            ..lineTo(0, flagWidth * 1.2)
            ..close();
        } else {
          path
            ..lineTo(flagWidth / 2, flagWidth * 1.1)
            ..lineTo(0, flagWidth * .8)
            ..lineTo(-flagWidth / 2, flagWidth * 1.1)
            ..close();
        }
        canvas.drawPath(
            path, _fill(_c(2 + (flag + row) % math.min(4, colors.length - 2))));
        canvas.restore();
      }
    }
  }

  void _paintHabi(Canvas canvas, Size s, double t) {
    final rng = _random();
    final rows = 16, cell = s.height / rows, cols = (s.width / cell).ceil();
    final period = 8 + (rng() * 4).floor() * 2,
        mod = 3 + (rng() * 2).floor(),
        offset = (rng() * period).floor();
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        var color = 0;
        if (j < 2 || j >= rows - 2) {
          color = j == 0 || j == rows - 1 ? 4 : 2;
        } else {
          final u = (i + offset) % period,
              v = (j - 2) % period,
              d = (u - period / 2).abs() + (v - period / 2).abs();
          color = d < 1
              ? 3
              : d % mod == 0
                  ? 1
                  : d % mod == 2
                      ? 2
                      : 0;
        }
        final rect = Rect.fromLTWH(i * cell, j * cell, cell + .6, cell + .6);
        canvas.drawRect(rect, _fill(_c(color)));
        if ((i + j).isEven) {
          canvas.drawRect(
              Rect.fromLTWH(i * cell, j * cell + cell * .15, cell, cell * .18),
              _fill(Colors.black.withOpacity(.1)));
        } else {
          canvas.drawRect(
              Rect.fromLTWH(i * cell + cell * .15, j * cell, cell * .18, cell),
              _fill(Colors.white.withOpacity(.1)));
        }
      }
    }
    final row = (t * .9 % rows).floor(), x = (t * .9 % 1) * s.width;
    canvas.drawRect(Rect.fromLTWH(0, row * cell, x, cell),
        _fill(Colors.white.withOpacity(.1)));
    canvas.drawRect(
        Rect.fromLTWH(
            x - cell * 1.2, row * cell + cell * .3, cell * 2.4, cell * .4),
        _fill(_c(3).withOpacity(.95)));
    final shineX = ((t * .12 % 1.6) - .3) * s.width;
    canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.transparent,
            Colors.white.withOpacity(.12),
            Colors.transparent
          ]).createShader(
              Rect.fromLTWH(shineX - s.height, 0, s.height * 2, s.height)));
  }

  void _ensurePicture(Size s, String kind) {
    if (_basePicture != null && _baseSize == s) return;
    _basePicture?.dispose();
    _baseSize = s;
    final recorder = ui.PictureRecorder(),
        c = Canvas(recorder),
        rng = _random(),
        noise = ValueNoise(rng);
    if (kind == 'islands') {
      _buildIslands(c, s, rng, noise);
    }
    if (kind == 'asin') {
      _buildAsin(c, s, rng, noise);
    }
    if (kind == 'topo') {
      _buildTopo(c, s, rng, noise);
    }
    if (kind == 'alitaptap') {
      _buildFireflyBackground(c, s, rng, noise);
    }
    _basePicture = recorder.endRecording();
  }

  void _paintIslands(Canvas canvas, Size s, double t) {
    _ensurePicture(s, 'islands');
    canvas.drawPicture(_basePicture!);
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var row = 0; row < 12; row++) {
      final phase = row * .7, alpha = .05 + .03 * math.sin(t * .7 + row * 2);
      final x = s.width * (.08 + row * .075) +
          math.sin(t * .3 + phase) * s.width * .025;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + s.height * .16, s.height)
        ..lineTo(x + s.height * .23, s.height)
        ..lineTo(x + s.height * .07, 0)
        ..close();
      canvas.drawPath(path, paint..color = _rgba(colors[2], alpha));
    }
  }

  void _buildIslands(
      Canvas canvas, Size s, BannerRandom rng, ValueNoise noise) {
    const width = 240, height = 80;
    final field = List<double>.filled(width * height, 0);
    final frequency = 3.6 + rng() * 1.4;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        field[y * width + x] =
            fbm(noise, x / height * frequency, y / height * frequency);
      }
    }
    final sorted = [...field]..sort();
    final threshold = sorted[(field.length * (.74 + rng() * .06)).floor()];
    final palette = colors.map((value) => rgb(value)).toList();
    canvas.save();
    canvas.scale(s.width / width, s.height / height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x, v = field[i];
        List<double> color;
        if (v > threshold) {
          final k = clamp01((v - threshold) / .13);
          if (k < .16) {
            color = mixRgb(palette[3], palette[3], 0);
          } else {
            color = mixRgb(palette[4], palette[5], smoothstep(.16, 1, k));
            final slope = (v - (x > 0 ? field[i - 1] : v)) * 900;
            color = mixRgb(
                color.map((v) => v.round()).toList(),
                slope > 0 ? [255, 255, 240] : [0, 0, 0],
                clamp01(slope.abs()) * .25);
          }
        } else {
          final d = clamp01((threshold - v) / .2);
          color = d < .5
              ? mixRgb(palette[2], palette[1], d * 2)
              : mixRgb(palette[1], palette[0], (d - .5) * 2);
        }
        canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.02, 1.02),
            _fill(Color.fromARGB(255, mixChannel(color[0]),
                mixChannel(color[1]), mixChannel(color[2]))));
      }
    }
    canvas.restore();
  }

  void _paintAsin(Canvas canvas, Size s, double t) {
    _ensurePicture(s, 'asin');
    canvas.drawPicture(_basePicture!);
    final p = ((t * .07 % 1.5) - .25) * s.width * 1.4;
    final rect = Rect.fromLTWH(p - s.height, 0, s.height * 2, s.height * .6);
    canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(colors: [
            Colors.transparent,
            _rgba(colors.last, .18),
            Colors.transparent
          ]).createShader(rect));
    final rng = _random(77);
    for (var i = 0; i < 60; i++) {
      final x = rng() * s.width,
          y = rng() * s.height,
          radius = .6 + rng() * 1.4,
          phase = rng() * 6.28;
      final alpha =
          math.pow(math.max(0, math.sin(t * radius + phase)), 10).toDouble();
      if (alpha < .02) continue;
      final length = s.height * .05 * alpha;
      final paint =
          _stroke(_rgba(colors.last, alpha), math.max(1, s.height * .006));
      canvas.drawLine(Offset(x - length, y), Offset(x + length, y), paint);
      canvas.drawLine(Offset(x, y - length), Offset(x, y + length), paint);
    }
  }

  void _buildAsin(Canvas canvas, Size s, BannerRandom rng, ValueNoise noise) {
    const width = 240, height = 80;
    final cell = s.height / (2.6 + rng() * 1.2),
        cols = (s.width / cell).ceil() + 2,
        rows = (s.height / cell).ceil() + 2;
    final points = <List<double>>[];
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        points.add([
          (i - .5 + rng()) * cell,
          (j - .5 + rng()) * cell,
          (rng() * 3).floorToDouble()
        ]);
      }
    }
    final colorsRgb = colors.map(rgb).toList();
    canvas.save();
    canvas.scale(s.width / width, s.height / height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final X = x * s.height / height,
            Y = y * s.height / height,
            ci = (X / cell + .5).floor(),
            cj = (Y / cell + .5).floor();
        var f1 = 1e9, f2 = 1e9, id = 0;
        for (var dj = -1; dj <= 1; dj++) {
          for (var di = -1; di <= 1; di++) {
            final ii = (ci + di).clamp(0, cols - 1),
                jj = (cj + dj).clamp(0, rows - 1),
                q = points[jj * cols + ii];
            final d = distance(q[0], q[1], X, Y);
            if (d < f1) {
              f2 = f1;
              f1 = d;
              id = q[2].toInt();
            } else if (d < f2) {
              f2 = d;
            }
          }
        }
        var color = mixRgb(
            colorsRgb[1 + id],
            [200, 210, 215],
            clamp01(f1 / cell) * .25 +
                fbm(noise, X / s.height * 9, Y / s.height * 9, 3) * .12);
        color = mixRgb(color.map((v) => v.round()).toList(), colorsRgb[0],
            1 - smoothstep(cell * .02, cell * .07, f2 - f1));
        canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.02, 1.02),
            _fill(Color.fromARGB(255, mixChannel(color[0]),
                mixChannel(color[1]), mixChannel(color[2]))));
      }
    }
    canvas.restore();
  }

  void _paintTopo(Canvas canvas, Size s, double t) {
    _ensurePicture(s, 'topo');
    canvas.drawPicture(_basePicture!);
    final rng = _random(91),
        waypoints = List.generate(
            5,
            (i) => Offset(s.width * (.1 + i * .2 + (rng() - .5) * .06),
                s.height * (.22 + rng() * .5)));
    final path = Path()..moveTo(waypoints.first.dx, waypoints.first.dy);
    for (var i = 1; i < waypoints.length; i++) {
      final prev = waypoints[i - 1], next = waypoints[i];
      path.quadraticBezierTo(
          (prev.dx + next.dx) / 2, prev.dy, next.dx, next.dy);
    }
    canvas.drawPath(
        path,
        _stroke(_rgba(colors[3], .22), s.height * .03)
          ..strokeCap = StrokeCap.round);
    final dashed = Path();
    for (var i = 0; i < waypoints.length; i++) {
      final point = waypoints[i];
      if (i == 0) {
        dashed.moveTo(point.dx, point.dy);
      } else {
        dashed.lineTo(point.dx, point.dy);
      }
    }
    _drawDashedPath(
      canvas,
      dashed,
      _stroke(_c(3), math.max(1.5, s.height * .011))
        ..strokeCap = StrokeCap.round,
      s.height * .035,
      s.height * .028,
      t * s.height * .12,
    );
    for (final p in waypoints.take(4)) {
      canvas.drawCircle(p, s.height * .022, _fill(_c(0)));
      canvas.drawCircle(
          p, s.height * .022, _stroke(_c(4), math.max(1, s.height * .008)));
    }
    final end = waypoints.last, progress = t * .9 % 1;
    canvas.drawCircle(end, s.height * (.03 + progress * .09),
        _stroke(_rgba(colors[3], 1 - progress), math.max(1, s.height * .008)));
    canvas.drawCircle(
        Offset(s.width * (.2 + (t * .05 % 1) * .6), s.height * .55),
        s.height * .03,
        _fill(_c(4)));
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashLength,
    double gapLength,
    double phase,
  ) {
    final cycle = dashLength + gapLength;
    if (cycle <= 0) return;
    final offset = phase % cycle;
    for (final metric in path.computeMetrics()) {
      var start = -offset;
      while (start < metric.length) {
        final end = start + dashLength;
        final visibleStart = math.max(0.0, start);
        final visibleEnd = math.min(metric.length, end);
        if (visibleEnd > visibleStart) {
          canvas.drawPath(metric.extractPath(visibleStart, visibleEnd), paint);
        }
        start += cycle;
      }
    }
  }

  void _buildTopo(Canvas canvas, Size s, BannerRandom rng, ValueNoise noise) {
    const gy = 34;
    final gx = (gy * s.width / s.height).round(), frequency = 2 + rng();
    final values = List<double>.generate(
        (gy + 1) * (gx + 1),
        (index) => fbm(noise, index % (gx + 1) / gy * frequency,
            index ~/ (gx + 1) / gy * frequency, 4));
    final lo = values.reduce(math.min),
        hi = values.reduce(math.max),
        cx = s.width / gx,
        cy = s.height / gy;
    canvas.drawRect(Offset.zero & s, _fill(_c(0)));
    for (var j = 0; j < gy; j++) {
      for (var i = 0; i < gx; i++) {
        final v = (values[j * (gx + 1) + i] - lo) / (hi - lo);
        canvas.drawRect(Rect.fromLTWH(i * cx, j * cy, cx + .5, cy + .5),
            _fill(_rgba(colors[1], v * .22)));
      }
    }
    for (var level = 1; level < 16; level++) {
      final iso = lo + (hi - lo) * level / 16,
          major = level % 4 == 0,
          path = Path();
      for (var j = 0; j < gy; j++) {
        for (var i = 0; i < gx; i++) {
          final a = values[j * (gx + 1) + i],
              b = values[j * (gx + 1) + i + 1],
              d = values[(j + 1) * (gx + 1) + i],
              c = values[(j + 1) * (gx + 1) + i + 1],
              edges = <Offset>[];
          void edge(
              double p, double q, double x1, double y1, double x2, double y2) {
            if ((p < iso) != (q < iso)) {
              final f = (iso - p) / (q - p);
              edges.add(
                  Offset((x1 + (x2 - x1) * f) * cx, (y1 + (y2 - y1) * f) * cy));
            }
          }

          edge(a, b, i.toDouble(), j.toDouble(), i + 1.0, j.toDouble());
          edge(b, c, i + 1.0, j.toDouble(), i + 1.0, j + 1.0);
          edge(d, c, i.toDouble(), j + 1.0, i + 1.0, j + 1.0);
          edge(a, d, i.toDouble(), j.toDouble(), i.toDouble(), j + 1.0);
          for (var k = 0; k + 1 < edges.length; k += 2) {
            path.moveTo(edges[k].dx, edges[k].dy);
            path.lineTo(edges[k + 1].dx, edges[k + 1].dy);
          }
        }
      }
      canvas.drawPath(
          path,
          _stroke(_c(major ? 2 : 1),
              math.max(1, s.height * (major ? .007 : .0035))));
    }
  }

  void _buildFireflyBackground(
      Canvas canvas, Size s, BannerRandom rng, ValueNoise noise) {
    const waterLine = .76;
    _linear(canvas, Size(s.width, s.height * waterLine), [_c(0), _c(1)]);
    for (var i = 0; i < 70; i++) {
      canvas.drawRect(
          Rect.fromLTWH(
              rng() * s.width, rng() * s.height * waterLine * .5, 1, 1),
          _fill(Colors.white.withOpacity(.2 + rng() * .5)));
    }
    final hill = Path()..moveTo(0, s.height * .6);
    for (double x = 0; x <= s.width; x += s.height * .04) {
      final top = s.height * (.42 + .16 * noise.call(x / s.height * 1.3, 3));
      hill.lineTo(x, top);
    }
    hill
      ..lineTo(s.width, s.height * waterLine)
      ..lineTo(0, s.height * waterLine)
      ..close();
    canvas.drawPath(hill, _fill(_c(2)));
    canvas.drawRect(
        Rect.fromLTWH(0, s.height * (waterLine - .02), s.width, s.height * .02),
        _fill(_c(2)));
  }

  void _paintAlitaptap(Canvas canvas, Size s, double t, double dt) {
    _ensurePicture(s, 'alitaptap');
    canvas.drawPicture(_basePicture!);
    _initFireflies(s);
    if (dt > 0) _stepFireflies(dt);
    final waterLine = s.height * .76;
    canvas.drawRect(
        Rect.fromLTWH(0, waterLine, s.width, s.height - waterLine),
        Paint()
          ..shader = LinearGradient(colors: [_c(4), _c(0)]).createShader(
              Rect.fromLTWH(0, waterLine, s.width, s.height - waterLine)));
    for (final f in _fireflies!) {
      final brightness = math.pow(math.max(0, math.cos(f.theta)), 8).toDouble();
      final x = f.x + math.sin(_simTime * .4 + f.phase) * s.height * .03,
          y = f.y + math.cos(_simTime * .3 + f.phase) * s.height * .02,
          radius = s.height * (.02 + .07 * brightness);
      if (brightness > .02) {
        canvas.drawCircle(
            Offset(x, y),
            radius,
            Paint()
              ..shader = RadialGradient(colors: [
                _rgba(colors[3], .9 * brightness),
                _rgba(colors[3], 0)
              ]).createShader(
                  Rect.fromCircle(center: Offset(x, y), radius: radius)));
      }
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, y),
              width: math.max(1.5, s.height * .008),
              height: math.max(1.5, s.height * .008)),
          _fill(_rgba(colors[3], .45 + .55 * brightness)));
      final ry = waterLine * 2 - y;
      if (ry < s.height) {
        canvas.drawRect(
            Rect.fromLTWH(
                x - radius * .5, ry, radius, math.max(1, s.height * .006)),
            _fill(_rgba(colors[3], .35 * brightness)));
      }
    }
  }

  void _initFireflies(Size s) {
    if (_fireflies != null) return;
    final rng = _random(23), count = (40 + s.width / s.height * 8).round();
    _fireflies = List.generate(
        count,
        (_) => _Firefly(
            rng() * s.width,
            s.height * (.2 + rng() * .48),
            math.pi * 2 * (.6 + (rng() - .5) * .16),
            rng() * 6.28,
            rng() * 6.28));
    _simTime = rng() * 6;
  }

  void _stepFireflies(double dt) {
    _simTime += dt;
    final cycle = (_simTime / 26).floor();
    if (cycle != _cycle) {
      _cycle = cycle;
      final rng = _random(cycle);
      for (final f in _fireflies!) {
        f.theta = rng() * 6.28;
      }
    }
    final u = _simTime % 26 / 26, coupling = u < .7 ? 2.6 * u / .7 : 2.6;
    var cr = 0.0, ci = 0.0;
    for (final f in _fireflies!) {
      cr += math.cos(f.theta);
      ci += math.sin(f.theta);
    }
    cr /= _fireflies!.length;
    ci /= _fireflies!.length;
    final r = math.sqrt(cr * cr + ci * ci), psi = math.atan2(ci, cr);
    for (final f in _fireflies!) {
      f.theta += (f.omega + coupling * r * math.sin(psi - f.theta)) * dt;
    }
  }

  var _cycle = -1;

  @override
  bool shouldRepaint(covariant ProceduralBannerPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.generator != generator ||
      oldDelegate.asset != asset;

  void disposeCache() {
    _basePicture?.dispose();
    _basePicture = null;
    _baseSize = null;
  }
}

class _Fish {
  _Fish(this.x, this.y, this.vx, this.vy, this.phase);
  double x, y, vx, vy;
  final double phase;
}

class _Firefly {
  _Firefly(this.x, this.y, this.omega, this.theta, this.phase);
  final double x, y, omega, phase;
  double theta;
}
