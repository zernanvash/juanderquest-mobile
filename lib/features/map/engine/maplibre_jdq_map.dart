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

class TownLabelMetrics {
  final double fontSizeDp;
  final FontWeight fontWeight;
  final double padHDp;
  final double padVDp;
  final double outlineDp;
  final double underlineDp;
  final double effectiveFontSizeDp;

  const TownLabelMetrics({
    required this.fontSizeDp,
    required this.fontWeight,
    this.padHDp = 6.0,
    this.padVDp = 4.0,
    this.outlineDp = 1.5,
    this.underlineDp = 2.0,
    required this.effectiveFontSizeDp,
  });
}

TownLabelMetrics computeTownLabelMetrics({
  required String text,
  required String level,
}) {
  final normalizedLevel = level.toLowerCase();
  final double baseFontSizeDp;
  final FontWeight fontWeight;
  switch (normalizedLevel) {
    case 'province':
      baseFontSizeDp = 16.0;
      fontWeight = FontWeight.bold;
      break;
    case 'barangay':
      baseFontSizeDp = 12.0;
      fontWeight = FontWeight.normal;
      break;
    case 'city':
    case 'municipality':
    case 'town':
    default:
      baseFontSizeDp = 14.0;
      fontWeight = FontWeight.bold;
      break;
  }

  const padHDp = 6.0;
  const maxLabelWidthDp = 180.0;
  const maxTextWidthDp = maxLabelWidthDp - (padHDp * 2); // 168.0

  final tp = TextPainter(
    text: TextSpan(
      text: text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Silkscreen',
        fontFamilyFallback: const ['Monocraft'],
        fontSize: baseFontSizeDp,
        fontWeight: fontWeight,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double effectiveFontSizeDp = baseFontSizeDp;
  if (tp.width > maxTextWidthDp) {
    final scale = maxTextWidthDp / tp.width;
    effectiveFontSizeDp =
        math.max(10.0, math.min(baseFontSizeDp, baseFontSizeDp * scale));
  }

  return TownLabelMetrics(
    fontSizeDp: baseFontSizeDp,
    fontWeight: fontWeight,
    padHDp: padHDp,
    padVDp: 4.0,
    outlineDp: 1.5,
    underlineDp: 2.0,
    effectiveFontSizeDp: effectiveFontSizeDp,
  );
}

Future<Uint8List?> rasterizeTownLabel(
  String text, {
  required String level,
  required bool isFocused,
  required double dpr,
}) async {
  try {
    final metrics = computeTownLabelMetrics(text: text, level: level);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fontSizePx = metrics.effectiveFontSizeDp * dpr;

    final tp = TextPainter(
      text: TextSpan(
        text: text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Silkscreen',
          fontFamilyFallback: const ['Monocraft'],
          fontSize: fontSizePx,
          fontWeight: metrics.fontWeight,
          color: const Color(0xFF3E1F0A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textW = tp.width;
    final textH = tp.height;
    final padH = metrics.padHDp * dpr;
    final padV = metrics.padVDp * dpr;
    final strokeWidth =
        math.max(1.0, (metrics.outlineDp * dpr).roundToDouble());
    final underlineH = (metrics.underlineDp * dpr).roundToDouble();
    final w = (textW + padH * 2).ceilToDouble();
    final h = (textH + padV * 2 + underlineH).ceilToDouble();

    final rect = Rect.fromLTWH(0, 0, w, h);

    // Background badge fill: cream (#FFF8E1) or gold (#FFB703) when focused
    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isFocused ? const Color(0xFFFFB703) : const Color(0xFFFFF8E1);
    canvas.drawRect(rect, bgPaint);

    // Crisp woodDeep stroke (#3E1F0A) on whole device pixels
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF3E1F0A);
    canvas.drawRect(rect.deflate(strokeWidth / 2), borderPaint);

    // Pixel text inside
    tp.paint(canvas, Offset(padH, padV));

    // Clickable pixel underline indicator at bottom
    final underlinePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isFocused ? const Color(0xFF8B5E00) : const Color(0xFF8B6B4A);
    canvas.drawRect(
      Rect.fromLTWH(padH, h - padV - underlineH, textW, underlineH),
      underlinePaint,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
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
  bool _satellite = false, _hasSatellite = false;
  VoidCallback? _failed;
  bool? _lastOverlap;
  static final Map<String, Uint8List> _labelBitmapCache = {};
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
    bool reducedMotion = false,
  }) => _safe(() async {
    final update = gl.CameraUpdate.newLatLngZoom(_ll(point), zoom);
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
