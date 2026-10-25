import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;
import '../utils/admin_areas.dart';
import 'building_layer_style.dart';
import 'jdq_map.dart';
import 'style_loader.dart';

final jdqMapFactoryProvider =
    Provider<JdqMap Function()>((ref) => MapLibreJdqMap.new);
final mapStyleProvider = FutureProvider.autoDispose<String>(
    (ref) async => StyleLoader().load(await MapOriginStore.read()));

class MapLibreJdqMap extends JdqMap {
  gl.MapLibreMapController? _controller;
  final _location = ValueNotifier(false);
  bool _disposed = false, _ready = false;
  String _style = '';
  List<AdminArea> _places = [];
  List<JdqPin> _pins = [];
  AreaShape? _focus;
  VoidCallback? _failed;
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
  Future<void> easeTo(LatLng point, double zoom,
          {bool reducedMotion = false}) =>
      _safe(() async {
        final update = gl.CameraUpdate.newLatLngZoom(_ll(point), zoom);
        if (reducedMotion) {
          await _controller!.moveCamera(update);
        } else {
          await _controller!.animateCamera(update,
              duration: const Duration(milliseconds: 700));
        }
      });

  @override
  Future<void> resetOrientation() => _safe(() async {
        final position = _controller!.cameraPosition;
        if (position == null) return;
        await _controller!.animateCamera(
          gl.CameraUpdate.newCameraPosition(gl.CameraPosition(
            target: position.target,
            zoom: position.zoom,
            bearing: 0,
            tilt: 0,
          )),
          duration: const Duration(milliseconds: 350),
        );
      });
  @override
  Future<void> fitBounds(
          LatLng southWest, LatLng northEast, EdgeInsets padding) =>
      _safe(() async {
        await _controller!.animateCamera(
            gl.CameraUpdate.newLatLngBounds(
                gl.LatLngBounds(
                    southwest: _ll(southWest), northeast: _ll(northEast)),
                left: padding.left,
                top: padding.top,
                right: padding.right,
                bottom: padding.bottom),
            duration: const Duration(milliseconds: 700));
      });
  Map<String, dynamic> _collection(List<Map<String, dynamic>> features) =>
      {'type': 'FeatureCollection', 'features': features};
  Map<String, dynamic> _point(LatLng point, Map<String, dynamic> properties) =>
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [point.longitude, point.latitude]
        },
        'properties': properties,
      };
  @override
  Future<void> setPlaces(List<AdminArea> places) async {
    _places = places;
    await _safe(() => _controller!.setGeoJsonSource(
        'admin-places',
        _collection([
          for (final p in places) _point(p.label, {'id': p.id, 'name': p.name})
        ])));
  }

  @override
  Future<void> setPins(List<JdqPin> pins) async {
    _pins = pins;
    await _safe(() => _controller!.setGeoJsonSource(
        'jdq-pins',
        _collection([
          for (final p in pins)
            _point(p.point, {'id': p.id, 'name': p.label, 'quest': p.quest}),
        ])));
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

  Future<void> _updateFocus() => _safe(() async {
        List<List<double>> ring(List<LatLng> points) => [
              for (final p in points) [p.longitude, p.latitude],
            ];
        await _controller!.setGeoJsonSource(
            'jdq-focus',
            _collection([
              if (_focus != null)
                for (final p in _focus!.polygons)
                  {
                    'type': 'Feature',
                    'properties': <String, dynamic>{},
                    'geometry': {
                      'type': 'Polygon',
                      'coordinates': [
                        ring(p.outer),
                        for (final h in p.holes) ring(h)
                      ],
                    }
                  },
            ]));
      });
  @override
  void setMyLocation(bool enabled) {
    if (!_disposed) _location.value = enabled;
  }

  Future<void> _loaded(VoidCallback onReady) async {
    if (_disposed) return;
    try {
      final c = _controller!;
      for (final source in ['admin-places', 'jdq-pins', 'jdq-focus']) {
        await c.addGeoJsonSource(source, _collection([]));
      }
      await c.addFillLayer(
          'jdq-focus',
          'jdq-focus-fill',
          const gl.FillLayerProperties(
              fillColor: '#2D6A4F', fillOpacity: 0.12));
      await c.addLineLayer('jdq-focus', 'jdq-focus-line',
          const gl.LineLayerProperties(lineColor: '#2D6A4F', lineWidth: 2.5));
      await c.addSymbolLayer(
          'admin-places',
          'admin-place-labels',
          const gl.SymbolLayerProperties(
              textField: ['get', 'name'],
              textFont: ['Noto Sans Bold'],
              textSize: 14,
              textColor: '#263F32',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1.5,
              textAllowOverlap: false));
      // Transitional pin presentation; Phase 2 supplies the JDQ symbol artwork.
      await c.addCircleLayer(
          'jdq-pins',
          'jdq-pin-dots',
          const gl.CircleLayerProperties(
              circleRadius: 6,
              circleColor: '#2D6A4F',
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2));
      await c.addFillExtrusionLayer(
          'openmaptiles',
          'jdq-buildings',
          buildingLayerProperties(opacity: 0),
          sourceLayer: 'building',
          minzoom: 13);
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
          southWest:
              LatLng(bounds.southwest.latitude, bounds.southwest.longitude),
          northEast:
              LatLng(bounds.northeast.latitude, bounds.northeast.longitude),
          size: camera.size);
      await c.setLayerProperties(
          'jdq-buildings',
          buildingLayerProperties(opacity: position.tilt > 30 ? 0.85 : 0.0));
      onCameraIdle?.call();
    } catch (_) {/* A disposed native surface may finish a pending callback. */}
  }

  Future<void> _tap(math.Point<double> point, gl.LatLng coordinate) async {
    if (!_ready || _disposed) return;
    try {
      final hits = await _controller!.queryRenderedFeatures(
          point, ['jdq-pin-dots', 'admin-place-labels'], null);
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
      onTapEmpty?.call(LatLng(coordinate.latitude, coordinate.longitude));
    } catch (_) {/* Ignore a tap during surface disposal. */}
  }

  @override
  Widget build(
      {required VoidCallback onReady, required VoidCallback onFailure}) {
    _failed = onFailure;
    return LayoutBuilder(builder: (context, constraints) {
      camera = camera.copyWith(size: constraints.biggest);
      return ValueListenableBuilder<bool>(
          valueListenable: _location,
          builder: (_, enabled, __) => gl.MapLibreMap(
              styleString: _style,
              initialCameraPosition: gl.CameraPosition(
                  target: _ll(camera.center), zoom: camera.zoom),
              minMaxZoomPreference: const gl.MinMaxZoomPreference(5, 19),
              cameraTargetBounds: gl.CameraTargetBounds(gl.LatLngBounds(
                  southwest: const gl.LatLng(4.5, 116),
                  northeast: const gl.LatLng(21.5, 127))),
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              compassEnabled: false,
              attributionButtonPosition:
                  gl.AttributionButtonPosition.bottomLeft,
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
              onMapClick: _tap));
    });
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
