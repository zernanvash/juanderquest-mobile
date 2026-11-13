import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;
import '../../../core/config/map_config.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../pixel/map_marker_art.dart';
import '../utils/admin_areas.dart';
import 'building_layer_style.dart';
import 'jdq_map.dart';
import 'map_mask.dart';
import 'style_loader.dart';

final jdqMapFactoryProvider = Provider<JdqMap Function()>(
  (ref) => MapLibreJdqMap.new,
);
final mapStyleProvider = FutureProvider.autoDispose<String>(
  (ref) async => StyleLoader().load(await MapOriginStore.read()),
);

/// Map town/barangay label style (owner 2026-11-09: "remove the box text
/// background ... optimize the text in the map but still very visible and
/// readable, just like how google maps do"). Plain pixel-font text with a
/// cream halo, no box: towns dark and bold, barangays small, grey and spaced.
class TownLabelMetrics {
  final double fontSizeDp;
  final FontWeight fontWeight;
  final double haloDp;
  final double letterSpacingDp;
  final Color color;
  final double effectiveFontSizeDp;

  const TownLabelMetrics({
    required this.fontSizeDp,
    required this.fontWeight,
    required this.haloDp,
    required this.letterSpacingDp,
    required this.color,
    required this.effectiveFontSizeDp,
  });
}

const _labelInk = Color(0xFF3E1F0A); // woodDeep
const _labelMuted = Color(0xFF7A6656); // barangay grey-brown
const _labelHalo = Color(0xFFFFF8E1); // cream
const _labelFocus = Color(0xFF8B4A00); // focused: deep amber
const _labelFocusHalo = Color(0xFFFFD166); // focused halo: soft gold

TownLabelMetrics computeTownLabelMetrics({
  required String text,
  required String level,
}) {
  final double size;
  final FontWeight weight;
  final double spacing;
  final Color color;
  switch (level.toLowerCase()) {
    case 'province':
      size = 15;
      weight = FontWeight.bold;
      spacing = 1.5;
      color = _labelInk;
      break;
    case 'barangay':
      size = 10;
      weight = FontWeight.normal;
      spacing = 1.2;
      color = _labelMuted;
      break;
    default: // city, municipality, town
      size = 13;
      weight = FontWeight.bold;
      spacing = 0.5;
      color = _labelInk;
  }

  // Long names shrink to fit 180 dp, down to 9 dp.
  const maxWidthDp = 180.0;
  final tp = TextPainter(
    text: TextSpan(text: text.toUpperCase(), style: _labelStyle(size, weight, spacing, color)),
    textDirection: TextDirection.ltr,
  )..layout();
  var effective = size;
  if (tp.width > maxWidthDp) {
    effective = math.max(9.0, size * maxWidthDp / tp.width);
  }
  return TownLabelMetrics(
    fontSizeDp: size,
    fontWeight: weight,
    haloDp: 2.0,
    letterSpacingDp: spacing,
    color: color,
    effectiveFontSizeDp: effective,
  );
}

TextStyle _labelStyle(double size, FontWeight weight, double spacing, Color color, {Paint? foreground}) => TextStyle(
      fontFamily: 'Silkscreen',
      fontFamilyFallback: const ['Monocraft'],
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: foreground == null ? color : null,
      foreground: foreground,
    );

Future<Uint8List?> rasterizeTownLabel(
  String text, {
  required String level,
  required bool isFocused,
  required double dpr,
}) async {
  try {
    final m = computeTownLabelMetrics(text: text, level: level);
    final size = m.effectiveFontSizeDp * dpr;
    final spacing = m.letterSpacingDp * dpr;
    // Whole device pixels keep the pixel font crisp.
    final halo = math.max(1.0, (m.haloDp * dpr).roundToDouble());
    final upper = text.toUpperCase();

    TextPainter painter(TextStyle style) =>
        TextPainter(text: TextSpan(text: upper, style: style), textDirection: TextDirection.ltr)..layout();

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = halo * 2
      ..strokeJoin = StrokeJoin.miter
      ..color = isFocused ? _labelFocusHalo : _labelHalo;
    final back = painter(_labelStyle(size, m.fontWeight, spacing, m.color, foreground: haloPaint));
    final front = painter(_labelStyle(size, m.fontWeight, spacing, isFocused ? _labelFocus : m.color));

    final w = (front.width + halo * 2).ceil();
    final h = (front.height + halo * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final at = Offset(halo, halo);
    back.paint(canvas, at);
    front.paint(canvas, at);
    final img = await recorder.endRecording().toImage(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> rasterizeRoutePointMarker({
  required String label,
  required JdqRoutePointKind kind,
  required double dpr,
  bool isPulsed = false,
}) async {
  try {
    final double sizeDp =
        (kind == JdqRoutePointKind.stop && isPulsed) ? 28.0 : 24.0;
    final double sizePx = (sizeDp * dpr).roundToDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final Color bg;
    final Color textColor;
    switch (kind) {
      case JdqRoutePointKind.start:
        bg = const Color(0xFF0284C7);
        textColor = const Color(0xFFFAF9F5);
        break;
      case JdqRoutePointKind.end:
        bg = const Color(0xFFD62828);
        textColor = const Color(0xFFFAF9F5);
        break;
      case JdqRoutePointKind.stop:
        bg = const Color(0xFFFFB703);
        textColor = const Color(0xFF3E1F0A);
        break;
      case JdqRoutePointKind.detour:
        bg = const Color(0xFFF4A261);
        textColor = const Color(0xFF3E1F0A);
        break;
      case JdqRoutePointKind.done:
        bg = const Color(0xFF2D6A4F);
        textColor = const Color(0xFFFAF9F5);
        break;
      case JdqRoutePointKind.puck:
        bg = const Color(0xFF2563EB);
        textColor = const Color(0xFFFAF9F5);
        break;
    }

    if (kind == JdqRoutePointKind.puck) {
      final baseSide = (28.0 * dpr).roundToDouble();
      final side = isPulsed ? (32.0 * dpr).roundToDouble() : baseSide;
      final offset = (side - baseSide) / 2;
      if (isPulsed) {
        final ringPaint = Paint()
          ..color = const Color(0xFF0D1B2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, 2.0 * dpr);
        canvas.drawRect(
          Rect.fromLTWH(dpr, dpr, side - dpr * 2, side - dpr * 2),
          ringPaint,
        );
      }
      final cx = side / 2;
      final pad = 2.0 * dpr + offset;
      final outer = ui.Path()
        ..moveTo(cx, pad)
        ..lineTo(side - pad, side - pad)
        ..lineTo(cx, side - 6.0 * dpr - offset)
        ..lineTo(pad, side - pad)
        ..close();
      canvas.drawPath(
        outer,
        Paint()
          ..color = const Color(0xFF0D1B2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, 2.0 * dpr)
          ..strokeJoin = StrokeJoin.miter,
      );
      canvas.drawPath(outer, Paint()..color = const Color(0xFFFFF8E1));
      final inner = ui.Path()
        ..moveTo(cx, pad + 3.0 * dpr)
        ..lineTo(side - pad - 3.0 * dpr, side - pad - 2.0 * dpr)
        ..lineTo(cx, side - 8.0 * dpr - offset)
        ..lineTo(pad + 3.0 * dpr, side - pad - 2.0 * dpr)
        ..close();
      canvas.drawPath(inner, Paint()..color = bg);
      final img =
          await recorder.endRecording().toImage(side.round(), side.round());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    }

    if (kind == JdqRoutePointKind.end) {
      // Pixel red pin sprite (20x24 dp)
      final w = (20.0 * dpr).roundToDouble();
      final h = (24.0 * dpr).roundToDouble();
      final p = (2.0 * dpr).roundToDouble();
      final inkPaint = Paint()..color = const Color(0xFF0D1B2A);
      final redPaint = Paint()..color = bg;
      final creamPaint = Paint()..color = const Color(0xFFFFF8E1);
      // Ink outline
      canvas.drawRect(Rect.fromLTWH(p, 0, w - 2 * p, p * 7), inkPaint);
      canvas.drawRect(Rect.fromLTWH(0, p, w, p * 5), inkPaint);
      canvas.drawRect(Rect.fromLTWH(p * 2, p * 7, w - 4 * p, p * 2), inkPaint);
      canvas.drawRect(Rect.fromLTWH(p * 3, p * 9, w - 6 * p, p * 2), inkPaint);
      canvas.drawRect(Rect.fromLTWH(p * 4, p * 11, w - 8 * p, p), inkPaint);
      // Red body
      canvas.drawRect(Rect.fromLTWH(p, p, w - 2 * p, p * 5), redPaint);
      canvas.drawRect(Rect.fromLTWH(p * 2, p * 6, w - 4 * p, p * 2), redPaint);
      canvas.drawRect(Rect.fromLTWH(p * 3, p * 8, w - 6 * p, p * 2), redPaint);
      canvas.drawRect(Rect.fromLTWH(p * 4, p * 10, w - 8 * p, p), redPaint);
      // Cream center dot
      canvas.drawRect(Rect.fromLTWH(p * 3.5, p * 2.5, p * 3, p * 3), creamPaint);
      final img = await recorder.endRecording().toImage(w.round(), h.round());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    }

    if (kind == JdqRoutePointKind.start) {
      final side = ((isPulsed ? 16.0 : 12.0) * dpr).roundToDouble();
      final edge = math.max(1.0, (2.0 * dpr).roundToDouble());
      canvas.drawRect(Rect.fromLTWH(0, 0, side, side), Paint()..color = const Color(0xFFFFF8E1));
      canvas.drawRect(Rect.fromLTWH(edge, edge, side - edge * 2, side - edge * 2), Paint()..color = bg);
      final img = await recorder.endRecording().toImage(side.round(), side.round());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    }

    // Outer 1.5dp wood casing
    final borderThickness = math.max(1.0, (1.5 * dpr).roundToDouble());
    final outerPaint = Paint()
      ..color = const Color(0xFF3E1F0A)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, sizePx, sizePx), outerPaint);

    // Inner background
    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        borderThickness,
        borderThickness,
        sizePx - (borderThickness * 2),
        sizePx - (borderThickness * 2),
      ),
      bgPaint,
    );

    // Draw label
    final double fontSize = (11.0 * dpr);
    final textSpan = TextSpan(
      text: label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Silkscreen',
        fontFamilyFallback: const ['Monocraft'],
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: sizePx);

    final textOffset = Offset(
      (sizePx - textPainter.width) / 2,
      (sizePx - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    final img = await recorder.endRecording().toImage(sizePx.round(), sizePx.round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

class MapLibreJdqMap extends JdqMap {
  gl.MapLibreMapController? _controller;
  final _location = ValueNotifier(false);
  bool _disposed = false, _ready = false;
  String _style = '';
  List<AdminArea> _places = [];
  List<JdqPin> _pins = [];
  AreaShape? _focus;
  JdqRouteOverlay? _routeOverlay;
  bool _satellite = false, _hasSatellite = false;
  VoidCallback? _failed;
  bool? _lastOverlap;
  static final Map<String, Uint8List> _labelBitmapCache = {};
  static final Map<String, Uint8List> _routeMarkerBitmapCache = {};
  gl.LatLng _ll(LatLng point) => gl.LatLng(point.latitude, point.longitude);
  Future<void> _safe(Future<void> Function() action) async {
    if (_disposed || !_ready) return;
    try {
      await action();
    } catch (_) {
      if (!_disposed) _failed?.call();
    }
  }

  @override
  Future<void> setStyle(String style) async {
    _style = style;
  }

  @override
  Future<void> easeTo(
    LatLng point,
    double zoom, {
    double? bearing,
    double? tilt,
    bool reducedMotion = false,
  }) => _safe(() async {
    final pos = _controller!.cameraPosition;
    final update = bearing == null && tilt == null
        ? gl.CameraUpdate.newLatLngZoom(_ll(point), zoom)
        : gl.CameraUpdate.newCameraPosition(gl.CameraPosition(
            target: _ll(point),
            zoom: zoom,
            bearing: bearing ?? pos?.bearing ?? 0,
            tilt: tilt ?? pos?.tilt ?? 0,
          ));
    if (reducedMotion) {
      await _controller!.moveCamera(update);
    } else {
      await _controller!.animateCamera(
        update,
        duration: const Duration(milliseconds: 700),
      );
    }
  });

  @override
  Future<void> resetOrientation() => _safe(() async {
    final position = _controller!.cameraPosition;
    if (position == null) return;
    await _controller!.animateCamera(
      gl.CameraUpdate.newCameraPosition(
        gl.CameraPosition(
          target: position.target,
          zoom: position.zoom,
          bearing: 0,
          tilt: 0,
        ),
      ),
      duration: const Duration(milliseconds: 350),
    );
  });
  @override
  Future<void> fitBounds(
    LatLng southWest,
    LatLng northEast,
    EdgeInsets padding,
  ) => _safe(() async {
    await _controller!.animateCamera(
      gl.CameraUpdate.newLatLngBounds(
        gl.LatLngBounds(southwest: _ll(southWest), northeast: _ll(northEast)),
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
      duration: const Duration(milliseconds: 700),
    );
  });
  Map<String, dynamic> _collection(List<Map<String, dynamic>> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };
  Map<String, dynamic> _point(LatLng point, Map<String, dynamic> properties) =>
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [point.longitude, point.latitude],
        },
        'properties': properties,
      };

  List<String> _findPlaceLabelLayers() {
    try {
      final parsed = jsonDecode(_style);
      if (parsed is Map && parsed['layers'] is List) {
        return (parsed['layers'] as List)
            .whereType<Map>()
            .map((l) => l['id'] as String?)
            .where((id) =>
                id != null &&
                (id.startsWith('place_') ||
                    id.contains('place-label') ||
                    id.contains('place_label')))
            .cast<String>()
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _updateBasePlaceLayerVisibility(bool hide) async {
    final c = _controller;
    if (c == null) return;
    for (final layerId in _findPlaceLabelLayers()) {
      try {
        await c.setLayerVisibility(layerId, !hide);
      } catch (_) {}
    }
  }

  @override
  Future<void> setPlaces(List<AdminArea> places) async {
    _places = places;
    await _safe(() async {
      final c = _controller!;
      final dpr =
          ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ??
              2.0;

      for (final p in places) {
        final level = p.level.toLowerCase();
        final isFocused = _focus != null &&
            _focus!.contains(p.label.latitude, p.label.longitude);
        final state = isFocused ? 'focused' : 'normal';
        final key = '${p.name}|$level|$state|${dpr.toStringAsFixed(1)}';
        var bytes = _labelBitmapCache[key];
        if (bytes == null) {
          bytes = await rasterizeTownLabel(
            p.name,
            level: p.level,
            isFocused: isFocused,
            dpr: dpr,
          );
          if (bytes != null) _labelBitmapCache[key] = bytes;
        }
        if (bytes != null) {
          await c.addImage('admin-label-${p.id}', bytes);
        }
      }

      await c.setGeoJsonSource(
        'admin-places',
        _collection([
          for (final p in places)
            _point(p.label, {
              'id': p.id,
              'name': p.name,
              'icon': 'admin-label-${p.id}',
            }),
        ]),
      );

      await _updateBasePlaceLayerVisibility(places.isNotEmpty);
    });
  }

  @override
  Future<void> setPins(List<JdqPin> pins) async {
    _pins = pins;
    await _safe(
      () => _controller!.setGeoJsonSource(
        'jdq-pins',
        _collection([
          for (final p in pins)
            _point(p.point, {'id': p.id, 'name': p.label, 'quest': p.quest}),
        ]),
      ),
    );
  }

  @override
  Future<void> setFocusArea(AreaShape shape) async {
    _focus = shape;
    await _updateFocus();
  }

  @override
  Future<void> clearFocus() async {
    _focus = null;
    await _updateFocus();
  }

  @override
  Future<void> setRouteOverlay(JdqRouteOverlay? overlay) async {
    _routeOverlay = overlay;
    await _updateRouteOverlay();
  }

  static int _pointZOrder(JdqRoutePointKind kind) {
    switch (kind) {
      case JdqRoutePointKind.start:
        return 0;
      case JdqRoutePointKind.detour:
        return 1;
      case JdqRoutePointKind.end:
        return 2;
      case JdqRoutePointKind.done:
        return 3;
      case JdqRoutePointKind.stop:
        return 4;
      case JdqRoutePointKind.puck:
        return 5;
    }
  }

  Future<void> _updateRouteOverlay() => _safe(() async {
        final c = _controller!;
        final overlay = _routeOverlay;
        if (overlay == null || overlay.line.isEmpty) {
          await c.setGeoJsonSource('jdq-route-overlay', _collection([]));
          return;
        }

        final dpr = WidgetsBinding.instance.platformDispatcher.views.firstOrNull?.devicePixelRatio ?? 2.0;

        for (final pt in overlay.points) {
          final key =
              '${pt.label}|${pt.kind.name}|${pt.isPulsed}|${dpr.toStringAsFixed(1)}';
          final imgName =
              'jdq-route-point-${pt.label}-${pt.kind.name}${pt.isPulsed ? '-p' : ''}';
          var bytes = _routeMarkerBitmapCache[key];
          if (bytes == null) {
            bytes = await rasterizeRoutePointMarker(
              label: pt.label,
              kind: pt.kind,
              dpr: dpr,
              isPulsed: pt.isPulsed,
            );
            if (bytes != null) _routeMarkerBitmapCache[key] = bytes;
          }
          if (bytes != null) {
            await c.addImage(imgName, bytes);
          }
        }

        final lineColorHex = overlay.color != null
            ? '#${overlay.color!.value.toRadixString(16).padLeft(8, '0').substring(2)}'
            : (overlay.degraded ? '#6F6352' : '#0284C7');

        final orderedPoints = List<JdqRoutePoint>.from(overlay.points)
          ..sort((a, b) => _pointZOrder(a.kind).compareTo(_pointZOrder(b.kind)));

        final features = <Map<String, dynamic>>[
          {
            'type': 'Feature',
            'properties': {
              'kind': 'line',
              'color': lineColorHex,
              'degraded': overlay.degraded,
            },
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (final p in overlay.line) [p.longitude, p.latitude],
              ],
            },
          },
          for (final pt in orderedPoints)
            {
              'type': 'Feature',
              'properties': {
                'kind': 'point',
                'label': pt.label,
                'pointKind': pt.kind.name,
                'bearing': pt.bearing ?? 0.0,
                'icon':
                    'jdq-route-point-${pt.label}-${pt.kind.name}${pt.isPulsed ? '-p' : ''}',
              },
              'geometry': {
                'type': 'Point',
                'coordinates': [pt.point.longitude, pt.point.latitude],
              },
            },
        ];

        await c.setGeoJsonSource('jdq-route-overlay', _collection(features));

        if (overlay.fitBounds && overlay.line.isNotEmpty) {
          double minLat = overlay.line.first.latitude;
          double maxLat = overlay.line.first.latitude;
          double minLng = overlay.line.first.longitude;
          double maxLng = overlay.line.first.longitude;
          for (final p in overlay.line) {
            if (p.latitude < minLat) minLat = p.latitude;
            if (p.latitude > maxLat) maxLat = p.latitude;
            if (p.longitude < minLng) minLng = p.longitude;
            if (p.longitude > maxLng) maxLng = p.longitude;
          }
          for (final pt in overlay.points) {
            if (pt.point.latitude < minLat) minLat = pt.point.latitude;
            if (pt.point.latitude > maxLat) maxLat = pt.point.latitude;
            if (pt.point.longitude < minLng) minLng = pt.point.longitude;
            if (pt.point.longitude > maxLng) maxLng = pt.point.longitude;
          }
          await fitBounds(
            LatLng(minLat, minLng),
            LatLng(maxLat, maxLng),
            const EdgeInsets.only(top: 140, bottom: 220, left: 32, right: 32),
          );
        }
      });

  Map<String, dynamic> _areaShapeToGeoJson(AreaShape shape) {
    List<List<double>> ring(List<LatLng> points) => [
      for (final p in points) [p.longitude, p.latitude],
    ];

    if (shape.polygons.length == 1) {
      return {
        'type': 'Polygon',
        'coordinates': [
          ring(shape.polygons[0].outer),
          for (final h in shape.polygons[0].holes) ring(h),
        ],
      };
    }
    return {
      'type': 'MultiPolygon',
      'coordinates': [
        for (final p in shape.polygons)
          [
            ring(p.outer),
            for (final h in p.holes) ring(h),
          ],
      ],
    };
  }

  Future<void> _updatePinOverlap() => _safe(() async {
    final c = _controller;
    if (c == null) return;
    final allow = _focus != null || camera.zoom >= 13.0;
    if (_lastOverlap == allow) return;
    _lastOverlap = allow;
    try {
      await c.setLayerProperties(
        'jdq-pin-symbols',
        gl.SymbolLayerProperties(
          iconImage: const [
            'case',
            ['get', 'quest'],
            'jdq-pin-quest',
            'jdq-pin-spot',
          ],
          iconSize: 1.0,
          iconAllowOverlap: allow,
          iconAnchor: 'bottom',
        ),
      );
    } catch (_) {}
  });

  Future<void> _updateFocus() => _safe(() async {
    final c = _controller!;
    if (_focus == null) {
      await c.setGeoJsonSource('jdq-focus', _collection([]));
      await c.setGeoJsonSource('jdq-focus-mask', _collection([]));
      await _updatePinOverlap();
      await setPlaces(_places);
      return;
    }

    final shapeGeoJson = _areaShapeToGeoJson(_focus!);
    final maskGeometry = buildInvertedMask(shapeGeoJson);

    if (maskGeometry != null) {
      await c.setGeoJsonSource(
        'jdq-focus-mask',
        _collection([
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': maskGeometry,
          },
        ]),
      );
    } else {
      await c.setGeoJsonSource('jdq-focus-mask', _collection([]));
    }

    List<List<double>> ring(List<LatLng> points) => [
      for (final p in points) [p.longitude, p.latitude],
    ];

    await c.setGeoJsonSource(
      'jdq-focus',
      _collection([
        for (final p in _focus!.polygons)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                ring(p.outer),
                for (final h in p.holes) ring(h),
              ],
            },
          },
      ]),
    );

    await _updatePinOverlap();
    await setPlaces(_places);
  });
  @override
  Future<void> setSatellite(bool on) async {
    _satellite = on;
    if (!_hasSatellite) return;
    await _safe(() => _controller!.setLayerVisibility('jdq-satellite', on));
  }

  /// Imagery goes under the first label layer so streets and places stay readable.
  static String? firstSymbolLayerId(String style) {
    try {
      final layers = (jsonDecode(style) as Map<String, dynamic>)['layers'];
      if (layers is! List) return null;
      for (final layer in layers) {
        if (layer is Map &&
            layer['type'] == 'symbol' &&
            layer['id'] is String) {
          return layer['id'] as String;
        }
      }
    } catch (_) {
      /* A style URL or malformed JSON: put imagery under our own layers. */
    }
    return null;
  }

  Future<void> _addSatellite(gl.MapLibreMapController c) async {
    if (!MapConfig.satelliteAvailable()) return;
    try {
      await c.addSource(
        'jdq-satellite',
        gl.RasterSourceProperties(
          tiles: [MapConfig.satelliteTileUrl()],
          tileSize: 256,
          maxzoom: MapConfig.maxNativeZoom.toDouble(),
          attribution: MapConfig.satelliteAttribution,
        ),
      );
      await c.addRasterLayer(
        'jdq-satellite',
        'jdq-satellite',
        const gl.RasterLayerProperties(),
        belowLayerId: firstSymbolLayerId(_style) ?? 'jdq-focus-fill',
      );
      await c.setLayerVisibility('jdq-satellite', _satellite);
      _hasSatellite = true;
    } catch (_) {
      /* Imagery is optional; the vector map stays usable. */
    }
  }

  @override
  void setMyLocation(bool enabled) {
    if (!_disposed) _location.value = enabled;
  }

  Future<Uint8List?> _rasterizeToPng(PixelArt art, {int scale = 2}) async {
    try {
      final img = art.image();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final targetW = art.width * scale;
      final targetH = art.height * scale;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false,
      );
      final scaled = await recorder.endRecording().toImage(targetW, targetH);
      final byteData = await scaled.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loaded(VoidCallback onReady) async {
    if (_disposed) return;
    try {
      final c = _controller!;
      for (final source in [
        'admin-places',
        'jdq-pins',
        'jdq-focus',
        'jdq-focus-mask',
        'jdq-route-overlay',
      ]) {
        await c.addGeoJsonSource(source, _collection([]));
      }
      await c.addFillLayer(
        'jdq-focus-mask',
        'jdq-focus-mask-layer',
        const gl.FillLayerProperties(
          fillColor: '#0D1B2A',
          fillOpacity: 0.32,
        ),
      );
      await c.addFillLayer(
        'jdq-focus',
        'jdq-focus-fill',
        const gl.FillLayerProperties(
          fillColor: '#FFF8E1',
          fillOpacity: 0.08,
        ),
      );
      await c.addLineLayer(
        'jdq-focus',
        'jdq-focus-casing',
        const gl.LineLayerProperties(
          lineColor: '#3E1F0A',
          lineWidth: 4.5,
        ),
      );
      await c.addLineLayer(
        'jdq-focus',
        'jdq-focus-line',
        const gl.LineLayerProperties(
          lineColor: '#FFB703',
          lineWidth: 2.5,
        ),
      );

      await c.addLineLayer(
        'jdq-route-overlay',
        'jdq-route-casing',
        const gl.LineLayerProperties(
          lineColor: '#0D1B2A',
          lineWidth: 10.0,
          lineCap: 'square',
          lineJoin: 'miter',
        ),
        filter: ['==', 'kind', 'line'],
      );
      await c.addLineLayer(
        'jdq-route-overlay',
        'jdq-route-line',
        const gl.LineLayerProperties(
          lineColor: ['get', 'color'],
          lineWidth: 6.0,
          lineCap: 'square',
          lineJoin: 'miter',
        ),
        filter: [
          'all',
          ['==', 'kind', 'line'],
          ['!=', 'degraded', true],
        ],
      );
      await c.addLineLayer(
        'jdq-route-overlay',
        'jdq-route-line-dashed',
        const gl.LineLayerProperties(
          lineColor: ['get', 'color'],
          lineWidth: 6.0,
          lineCap: 'square',
          lineJoin: 'miter',
          lineDasharray: [2.0, 2.0],
        ),
        filter: [
          'all',
          ['==', 'kind', 'line'],
          ['==', 'degraded', true],
        ],
      );
      await c.addSymbolLayer(
        'jdq-route-overlay',
        'jdq-route-point-symbols',
        const gl.SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: 1.0,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
        ),
        filter: [
          'all',
          ['==', 'kind', 'point'],
          ['!=', 'pointKind', 'puck'],
        ],
      );
      await c.addSymbolLayer(
        'jdq-route-overlay',
        'jdq-route-puck-symbol',
        const gl.SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: 1.0,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconRotationAlignment: 'map',
          iconRotate: ['get', 'bearing'],
        ),
        filter: [
          'all',
          ['==', 'kind', 'point'],
          ['==', 'pointKind', 'puck'],
        ],
      );

      await c.addSymbolLayer(
        'admin-places',
        'admin-place-labels',
        const gl.SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: 1.0,
          iconAllowOverlap: false,
          iconPadding: 4.0,
          iconAnchor: 'center',
        ),
      );

      bool symbolsAdded = false;
      try {
        final questBytes = await _rasterizeToPng(
          DesignerArt.questMarker,
          scale: 2,
        );
        final spotBytes = await _rasterizeToPng(MapMarkerArt.spotPin, scale: 3);
        if (questBytes != null && spotBytes != null) {
          await c.addImage('jdq-pin-quest', questBytes);
          await c.addImage('jdq-pin-spot', spotBytes);
          final allowOverlap = _focus != null || camera.zoom >= 13.0;
          _lastOverlap = allowOverlap;
          await c.addSymbolLayer(
            'jdq-pins',
            'jdq-pin-symbols',
            gl.SymbolLayerProperties(
              iconImage: const [
                'case',
                ['get', 'quest'],
                'jdq-pin-quest',
                'jdq-pin-spot',
              ],
              iconSize: 1.0,
              iconAllowOverlap: allowOverlap,
              iconAnchor: 'bottom',
            ),
          );
          symbolsAdded = true;
        }
      } catch (_) {
        symbolsAdded = false;
      }

      if (!symbolsAdded) {
        // Fallback: circle dots
        await c.addCircleLayer(
          'jdq-pins',
          'jdq-pin-dots',
          const gl.CircleLayerProperties(
            circleRadius: 6,
            circleColor: '#2D6A4F',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        );
      }

      await c.addFillExtrusionLayer(
        'openmaptiles',
        'jdq-buildings',
        buildingLayerProperties(opacity: 0),
        sourceLayer: 'building',
        minzoom: 13,
      );
      await _addSatellite(c);
      _ready = true;
      await setPlaces(_places);
      await setPins(_pins);
      await _updateFocus();
      await _updateRouteOverlay();
      await _idle();
      if (!_disposed) onReady();
    } catch (_) {
      if (!_disposed) _failed?.call();
    }
  }

  Future<void> _idle() async {
    if (_disposed || !_ready) return;
    try {
      final c = _controller!;
      final position = c.cameraPosition;
      if (position == null) return;
      final bounds = await c.getVisibleRegion();
      if (_disposed) return;
      camera = JdqCamera(
        center: LatLng(position.target.latitude, position.target.longitude),
        zoom: position.zoom,
        bearing: position.bearing,
        tilt: position.tilt,
        southWest: LatLng(
          bounds.southwest.latitude,
          bounds.southwest.longitude,
        ),
        northEast: LatLng(
          bounds.northeast.latitude,
          bounds.northeast.longitude,
        ),
        size: camera.size,
      );
      await c.setLayerProperties(
        'jdq-buildings',
        buildingLayerProperties(opacity: position.tilt > 30 ? 0.85 : 0.0),
      );
      await _updatePinOverlap();
      onCameraIdle?.call();
    } catch (_) {
      /* A disposed native surface may finish a pending callback. */
    }
  }

  Future<void> _tap(math.Point<double> point, gl.LatLng coordinate) async {
    if (!_ready || _disposed) return;
    try {
      final c = _controller!;
      final hits = await c.queryRenderedFeatures(point, [
        'jdq-pin-symbols',
        'jdq-pin-dots',
        'admin-place-labels',
      ], null);
      if (_disposed) return;
      for (final hit in hits) {
        if (hit is! Map) continue;
        final id = (hit['properties'] as Map?)?['id'];
        if (id is! String) continue;
        if (id.startsWith('spot:') || id.startsWith('quest:')) {
          onTapPin?.call(id);
        } else {
          onTapPlace?.call(id);
        }
        return;
      }

      // If point query missed, query a small box around the tap (±8 dp) for admin-place-labels only
      try {
        final boxHits = await c.queryRenderedFeaturesInRect(
          Rect.fromLTRB(
            point.x - 8.0,
            point.y - 8.0,
            point.x + 8.0,
            point.y + 8.0,
          ),
          ['admin-place-labels'],
          null,
        );
        if (_disposed) return;
        for (final hit in boxHits) {
          if (hit is! Map) continue;
          final id = (hit['properties'] as Map?)?['id'];
          if (id is! String) continue;
          onTapPlace?.call(id);
          return;
        }
      } catch (_) {
        /* queryRenderedFeaturesInRect fallback */
      }

      onTapEmpty?.call(LatLng(coordinate.latitude, coordinate.longitude));
    } catch (_) {
      /* Ignore a tap during surface disposal. */
    }
  }

  @override
  Widget build({
    required VoidCallback onReady,
    required VoidCallback onFailure,
  }) {
    _failed = onFailure;
    return LayoutBuilder(
      builder: (context, constraints) {
        camera = camera.copyWith(size: constraints.biggest);
        return ValueListenableBuilder<bool>(
          valueListenable: _location,
          builder: (_, enabled, __) => gl.MapLibreMap(
            styleString: _style,
            initialCameraPosition: gl.CameraPosition(
              target: _ll(camera.center),
              zoom: camera.zoom,
            ),
            minMaxZoomPreference: const gl.MinMaxZoomPreference(5, 19),
            cameraTargetBounds: gl.CameraTargetBounds(
              gl.LatLngBounds(
                southwest: const gl.LatLng(4.5, 116),
                northeast: const gl.LatLng(21.5, 127),
              ),
            ),
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            compassEnabled: false,
            attributionButtonPosition: gl.AttributionButtonPosition.bottomLeft,
            trackCameraPosition: true,
            myLocationEnabled: enabled,
            // MapLibre otherwise consumes taps on rendered symbol features
            // instead of forwarding them to onMapClick. Our place-label
            // selection is resolved by querying the admin-place layer from
            // that callback, so feature taps must also trigger map clicks.
            featureTapsTriggersMapClick: true,
            onMapCreated: (controller) => _controller = controller,
            onStyleLoadedCallback: () => unawaited(_loaded(onReady)),
            onCameraIdle: () => unawaited(_idle()),
            onMapClick: _tap,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    onCameraIdle = null;
    _location.dispose();
    // MapLibreMap owns and disposes its controller with its platform view.
  }
}
