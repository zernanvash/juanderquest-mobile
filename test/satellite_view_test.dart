import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/config/map_config.dart';
import 'package:juanderquest_app/core/widgets/base_tile_layer.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';

void main() {
  test('satellite imagery needs a key and loads Esri World Imagery directly', () {
    expect(MapConfig.satelliteAvailable(''), isFalse);
    expect(MapConfig.satelliteAvailable('abc'), isTrue);
    final url = MapConfig.satelliteTileUrl('a+b/c');
    expect(url, startsWith('https://ibasemaps-api.arcgis.com/arcgis/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'));
    expect(url, endsWith('?token=a%2Bb%2Fc'));
  });

  test('satellite imagery goes under the first label layer of the vector style', () {
    const style = '{"layers":[{"id":"bg","type":"background"},{"id":"roads","type":"line"},'
        '{"id":"road-names","type":"symbol"},{"id":"pois","type":"symbol"}]}';
    expect(MapLibreJdqMap.firstSymbolLayerId(style), 'road-names');
    expect(MapLibreJdqMap.firstSymbolLayerId('https://example.com/style.json'), isNull);
    expect(MapLibreJdqMap.firstSymbolLayerId('{"layers":[]}'), isNull);
  });

  testWidgets('the switch is hidden without a key', (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SatelliteToggleButton(available: false)))));
    expect(find.byKey(const ValueKey('satellite_toggle')), findsNothing);
  });

  for (final compact in [false, true]) {
    testWidgets('the switch flips the shared Map / Satellite choice (compact: $compact)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              home: Scaffold(body: Center(child: SatelliteToggleButton(available: true, compact: compact))))));
      if (!compact) expect(find.text('Satellite'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('satellite_toggle')));
      await tester.pump();
      expect(container.read(satelliteModeProvider), isTrue);
      if (!compact) expect(find.text('Map'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('satellite_toggle')));
      await tester.pump();
      expect(container.read(satelliteModeProvider), isFalse);
    });
  }
}
