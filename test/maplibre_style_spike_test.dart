import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/maplibre_style_spike.dart';

void main() {
  test('absolutizes origins without percent-encoding vector templates', () {
    const input = '''
      {
        "glyphs": "/map/fonts/{fontstack}/{range}.pbf",
        "sprite": "/map/sprite",
        "sources": {
          "openmaptiles": {
            "type": "vector",
            "tiles": ["/vt/{z}/{x}/{y}.mvt"]
          }
        }
      }
    ''';

    final result = jsonDecode(
      absolutizeSpikeStyle(input, 'https://juanderquest.app/'),
    ) as Map<String, dynamic>;
    final source = result['sources']['openmaptiles'] as Map<String, dynamic>;

    expect(source['tiles'], ['https://juanderquest.app/vt/{z}/{x}/{y}.mvt']);
    expect(result['glyphs'],
        'https://juanderquest.app/map/fonts/{fontstack}/{range}.pbf');
    expect(result['sprite'], 'https://juanderquest.app/map/sprite');
    expect(jsonEncode(result), contains('{z}/{x}/{y}'));
    expect(jsonEncode(result), contains('{fontstack}/{range}'));
    expect(jsonEncode(result), isNot(contains('%7B')));
  });

  test('preserves already-absolute URLs', () {
    const input =
        '{"glyphs":"https://cdn.example/fonts/{fontstack}/{range}.pbf",'
        '"sources":{"v":{"tiles":["https://tiles.example/{z}/{x}/{y}.mvt"]}}}';

    final result = absolutizeSpikeStyle(input, 'https://juanderquest.app');

    expect(result, contains('https://cdn.example/fonts/{fontstack}/{range}.pbf'));
    expect(result, contains('https://tiles.example/{z}/{x}/{y}.mvt'));
  });
}
