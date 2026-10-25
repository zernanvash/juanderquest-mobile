import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map.dart';
import 'package:juanderquest_app/features/map/engine/jdq_map_canvas.dart';
import 'package:juanderquest_app/features/map/widgets/map_orientation_button.dart';
import 'package:juanderquest_app/features/map/engine/style_loader.dart';
import 'package:latlong2/latlong.dart';
import 'package:juanderquest_app/features/map/widgets/map_origin_card.dart';

Map<String, dynamic> style() => {
      'version': 8,
      'layers': <Object>[],
      'sources': {
        'openmaptiles': {
          'type': 'vector',
          'tiles': ['/vt/{z}/{x}/{y}.mvt']
        }
      },
      'glyphs': '/map/fonts/{fontstack}/{range}.pbf',
      'sprite': '/map/sprite',
    };

class _Adapter implements HttpClientAdapter {
  bool fail = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    if (fail) throw StateError('offline');
    expect(options.headers['Authorization'], isNull);
    return ResponseBody.fromString(
        '{"version":8,"sources":{"v":{"tiles":["/vt/{z}/{x}/{y}.mvt"]}},"layers":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }
}

class _NeverReadyMap extends FakeJdqMap {
  @override
  Widget build(
          {required VoidCallback onReady, required VoidCallback onFailure}) =>
      const SizedBox.expand();
}

void main() {
  test('non-debug builds ignore even an invalid persisted map origin', () {
    expect(effectiveMapOrigin('http://127.0.0.1:3120', debug: false),
        mapSiteOrigin);
    expect(effectiveMapOrigin('not a URL', debug: false), mapSiteOrigin);
    expect(effectiveMapOrigin('http://127.0.0.1:3120', debug: true),
        'http://127.0.0.1:3120');
  });
  testWidgets('native creation timeout also falls back after style loads',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: JdqMapCanvas(
            map: _NeverReadyMap(),
            style: Future.value('{}'),
            fallback: const Text('raster'),
            onFallback: () {})));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Basic map'), findsOneWidget);
  });
  testWidgets('developer map-site card fits small screens at 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(child: MapOriginCard())))));
    await tester.pump();
    expect(find.text('Save map site'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('absolutizes without encoding templates or mutating input', () {
    final raw = style();
    final result = absolutizeStyle(raw, 'https://juanderquest.app/');
    expect(result['sources']['openmaptiles']['tiles'],
        ['https://juanderquest.app/vt/{z}/{x}/{y}.mvt']);
    expect(result['glyphs'],
        'https://juanderquest.app/map/fonts/{fontstack}/{range}.pbf');
    expect(result['sprite'], 'https://juanderquest.app/map/sprite');
    expect(raw['glyphs'], '/map/fonts/{fontstack}/{range}.pbf');
  });
  testWidgets('map orientation reset button is hidden while north-up and level',
      (tester) async {
    var resets = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MapOrientationButton(
                bearing: 0, tilt: 0, onPressed: () => resets++))));
    expect(find.byTooltip('Reset map north and tilt'), findsNothing);
    expect(resets, 0);
  });
  testWidgets('map orientation reset button appears for rotation or tilt',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MapOrientationButton(
                bearing: 15, tilt: 0, onPressed: _noop))));
    expect(find.byTooltip('Reset map north and tilt'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MapOrientationButton(
                bearing: 0, tilt: 12, onPressed: _noop))));
    expect(find.byTooltip('Reset map north and tilt'), findsOneWidget);
  });
  testWidgets('map orientation reset button invokes resetOrientation callback',
      (tester) async {
    var resets = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MapOrientationButton(
                bearing: 15, tilt: 0, onPressed: () => resets++))));
    await tester.tap(find.byTooltip('Reset map north and tilt'));
    expect(resets, 1);
  });
  test('fake map north reset clears bearing and pitch without moving camera',
      () async {
    final fake = FakeJdqMap();
    fake.camera = const JdqCamera(
        center: LatLng(16, 120),
        zoom: 14,
        bearing: 82,
        tilt: 48,
        southWest: LatLng(15, 119),
        northEast: LatLng(17, 121));

    await fake.resetOrientation();

    expect(fake.camera.bearing, 0);
    expect(fake.camera.tilt, 0);
    expect(fake.camera.center, const LatLng(16, 120));
    expect(fake.camera.zoom, 14);
  });
  test('camera copies keep bearing and tilt', () {
    const camera = JdqCamera(
        center: LatLng(16, 120),
        zoom: 14,
        bearing: 30,
        tilt: 45,
        southWest: LatLng(15, 119),
        northEast: LatLng(17, 121));
    final resized = camera.copyWith(size: const Size(400, 800));
    expect(resized.bearing, 30);
    expect(resized.tilt, 45);
    expect(resized.size, const Size(400, 800));
    expect(mapNeedsOrientationReset(resized.bearing, resized.tilt), isTrue);
  });
  test('rejects credentials, query, paths and unsupported origin schemes', () {
    for (final origin in [
      'file:///tmp',
      'https://user:pass@host',
      'https://host/path',
      'https://host?token=secret',
      'https://host/#fragment'
    ]) {
      expect(() => validateMapOrigin(origin), throwsFormatException);
    }
    expect(
        validateMapOrigin('http://127.0.0.1:3120/'), 'http://127.0.0.1:3120');
  });
  test('last-good cache works offline and is isolated per origin', () async {
    final directory = await Directory.systemTemp.createTemp('jdq-style-test-');
    addTearDown(() => directory.delete(recursive: true));
    final adapter = _Adapter();
    final loader = StyleLoader(
        client: Dio()..httpClientAdapter = adapter,
        directory: () async => directory);
    final first = await loader.load('https://juanderquest.app');
    adapter.fail = true;
    expect(await loader.load('https://juanderquest.app'), first);
    await expectLater(loader.load('http://127.0.0.1:3120'), throwsA(anything));
  });
  testWidgets('fake surface loads once and preserves a native-free map',
      (tester) async {
    final fake = FakeJdqMap();
    await tester.pumpWidget(MaterialApp(
        home: JdqMapCanvas(
            map: fake,
            style: Future.value('{}'),
            fallback: const Text('raster'),
            onFallback: () {})));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('fake-jdq-map')), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('Basic map'), findsNothing);
    expect(fake.style, '{}');
    await fake.easeTo(const LatLng(16, 120), 14);
    expect(fake.camera.zoom, 14);
  });
  testWidgets('style error automatically selects Basic map', (tester) async {
    var failures = 0;
    final pending = Completer<String>();
    await tester.pumpWidget(MaterialApp(
        home: JdqMapCanvas(
            map: FakeJdqMap(),
            style: pending.future,
            fallback: const Text('raster'),
            onFallback: () => failures++)));
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('Basic map'), findsOneWidget);
    expect(find.text('raster'), findsOneWidget);
    expect(failures, 1);
  });
  testWidgets(
      '10s deadline covers hung style; late result cannot replace fallback',
      (tester) async {
    final pending = Completer<String>();
    await tester.pumpWidget(MaterialApp(
        home: JdqMapCanvas(
            map: FakeJdqMap(),
            style: pending.future,
            fallback: const Text('raster'),
            onFallback: () {})));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Basic map'), findsOneWidget);
    pending.complete('{}');
    await tester.pump();
    expect(find.text('raster'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-jdq-map')), findsNothing);
  });
}

void _noop() {}
