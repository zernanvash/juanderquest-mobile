import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'maplibre_style_spike.dart';

const _styleUrl = 'https://juanderquest.app/map/style.json';

Future<Map<String, dynamic>> _loadStyle() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(_styleUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Style request returned ${response.statusCode}');
    }
    final raw = await response.transform(utf8.decoder).join();
    return jsonDecode(
      absolutizeSpikeStyle(raw, Uri.parse(_styleUrl).origin),
    ) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

void main() => runApp(const MaterialApp(home: MapLibreGlSpike()));

class MapLibreGlSpike extends StatefulWidget {
  const MapLibreGlSpike({super.key});

  @override
  State<MapLibreGlSpike> createState() => _MapLibreGlSpikeState();
}

class _MapLibreGlSpikeState extends State<MapLibreGlSpike> {
  final _elapsed = Stopwatch()..start();
  late final Future<Map<String, dynamic>> _styleFuture;
  MapLibreMapController? _controller;
  Timer? _renderPoll;
  List<String> _vectorLayerIds = const [];
  List<String> _placeLayerIds = const [];
  String _status = 'Fetching style…';
  String _firstVisibleTiles = 'waiting';
  String _queryStatus = 'Tap map to query place features';
  Size _mapSize = Size.zero;
  int _cameraIdleCount = 0;
  bool _areasReady = false;
  String _cameraStatus = 'Dagupan, zoom 14';

  @override
  void initState() {
    super.initState();
    _styleFuture = _loadStyle();
  }

  @override
  void dispose() {
    _renderPoll?.cancel();
    super.dispose();
  }

  Future<void> _checkVisibleTiles() async {
    final controller = _controller;
    if (controller == null || _vectorLayerIds.isEmpty || _mapSize.isEmpty) {
      return;
    }
    try {
      final features = await controller.queryRenderedFeaturesInRect(
        Rect.fromLTWH(0, 0, _mapSize.width, _mapSize.height),
        _vectorLayerIds,
        null,
      );
      if (features.isNotEmpty && mounted && _firstVisibleTiles == 'waiting') {
        setState(() {
          _firstVisibleTiles = '${_elapsed.elapsedMilliseconds} ms';
          _status = '${features.length} rendered vector features';
        });
        _renderPoll?.cancel();
      }
    } catch (error) {
      debugPrint('[MapLibre GL spike] visible-feature poll error: $error');
    }
  }

  void _onStyleLoaded() {
    if (!mounted) return;
    setState(
        () => _status = 'Style loaded; waiting for visible vector features');
    _renderPoll?.cancel();
    _renderPoll = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_checkVisibleTiles()),
    );
    unawaited(_addAdminPlaces());
  }

  Future<void> _addAdminPlaces() async {
    final controller = _controller;
    if (controller == null) return;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(
        'https://api.juanderquest.app/api/v1/areas'
        '?bbox=120.25,15.98,120.42,16.13&zoom=13',
      ));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Areas returned ${response.statusCode}');
      }
      final payload = jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      final areas = (payload['data'] as List).cast<Map<String, dynamic>>();
      await controller.addGeoJsonSource('admin-places', {
        'type': 'FeatureCollection',
        'features': areas
            .map((area) => {
                  'type': 'Feature',
                  'id': area['id'],
                  'properties': {'id': area['id'], 'name': area['name']},
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [area['label_lng'], area['label_lat']],
                  },
                })
            .toList(),
      });
      await controller.addSymbolLayer(
        'admin-places',
        'admin-places-label',
        const SymbolLayerProperties(
          textField: ['get', 'name'],
          textFont: ['Noto Sans Bold'],
          textSize: 16,
          textColor: '#24382f',
          textHaloColor: '#ffffff',
          textHaloWidth: 2,
        ),
        enableInteraction: false,
      );
      if (mounted) {
        setState(() {
          _areasReady = true;
          _queryStatus =
              '${areas.length} API areas loaded; tap a name for its id';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _queryStatus = 'Areas proof failed: $error');
    } finally {
      client.close(force: true);
    }
  }

  void _onCameraIdle() {
    _cameraIdleCount++;
    final camera = _controller?.cameraPosition;
    if (mounted && camera != null) {
      setState(() {
        _cameraStatus = 'z=${camera.zoom.toStringAsFixed(1)} '
            'bearing=${camera.bearing.toStringAsFixed(1)} '
            'tilt=${camera.tilt.toStringAsFixed(1)}';
      });
    }
    unawaited(_checkVisibleTiles());
  }

  Future<void> _queryPlace(math.Point<double> point, LatLng coordinate) async {
    final controller = _controller;
    if (controller == null || _placeLayerIds.isEmpty) return;
    try {
      final features = await controller.queryRenderedFeatures(
        point,
        _placeLayerIds,
        null,
      );
      final place =
          features.isEmpty ? null : features.first as Map<dynamic, dynamic>;
      final properties = place?['properties'];
      final result = properties is Map
          ? 'area id=${properties['id']} at '
              '${coordinate.latitude.toStringAsFixed(4)}, '
              '${coordinate.longitude.toStringAsFixed(4)}: ${jsonEncode(properties)}'
          : 'No rendered place feature at '
              '${coordinate.latitude.toStringAsFixed(4)}, '
              '${coordinate.longitude.toStringAsFixed(4)}';
      setState(() => _queryStatus = result);
      debugPrint('[MapLibre GL spike] $result');
    } catch (error) {
      setState(() => _queryStatus = 'Feature query failed: $error');
      debugPrint('[MapLibre GL spike] feature query error: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _styleFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text('Style load failed: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final style = snapshot.data!;
              final layers = style['layers'] as List<dynamic>? ?? const [];
              _vectorLayerIds = layers
                  .whereType<Map<String, dynamic>>()
                  .where((layer) => layer['source'] == 'openmaptiles')
                  .map((layer) => layer['id'])
                  .whereType<String>()
                  .toList();
              _placeLayerIds = layers
                  .whereType<Map<String, dynamic>>()
                  .where((layer) => layer['source-layer'] == 'place')
                  .map((layer) => layer['id'])
                  .whereType<String>()
                  .toList();
              if (_areasReady) _placeLayerIds = ['admin-places-label'];

              return LayoutBuilder(
                builder: (context, constraints) {
                  _mapSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    children: [
                      MapLibreMap(
                        styleString: jsonEncode(style),
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(16.043, 120.334),
                          zoom: 14,
                        ),
                        trackCameraPosition: true,
                        compassViewPosition: CompassViewPosition.bottomRight,
                        compassViewMargins: const math.Point(12, 64),
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        onMapCreated: (controller) => _controller = controller,
                        onStyleLoadedCallback: _onStyleLoaded,
                        onCameraIdle: _onCameraIdle,
                        onMapClick: _queryPlace,
                      ),
                      Positioned(
                        left: 8,
                        bottom: 48,
                        child: ElevatedButton(
                          onPressed: () => _controller?.animateCamera(
                            CameraUpdate.newCameraPosition(const CameraPosition(
                              target: LatLng(16.043, 120.334),
                              zoom: 14,
                            )),
                          ),
                          child: const Text('Dagupan z14'),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 8,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'maplibre_gl 0.27.1 — first visible tile: '
                              '$_firstVisibleTiles | idle callbacks: $_cameraIdleCount\n'
                              '$_status\n$_cameraStatus\n$_queryStatus',
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 8,
                        bottom: 8,
                        child: Text(
                          '© OpenStreetMap contributors  © OpenMapTiles',
                          style: TextStyle(backgroundColor: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      );
}
