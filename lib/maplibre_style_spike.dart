import 'dart:convert';

/// Spike-only style URL rewrite. Keep vector-template braces literal because
/// native tile and glyph requests substitute them after the URL is installed.
String absolutizeSpikeStyle(String styleJson, String origin) {
  final style = jsonDecode(styleJson) as Map<String, dynamic>;
  final base = origin.replaceFirst(RegExp(r'/+$'), '');
  String absolutize(String value) =>
      value.startsWith('/') ? '$base$value' : value;

  final glyphs = style['glyphs'];
  if (glyphs is String) style['glyphs'] = absolutize(glyphs);
  final sprite = style['sprite'];
  if (sprite is String) style['sprite'] = absolutize(sprite);

  final sources = style['sources'];
  if (sources is Map<String, dynamic>) {
    for (final source in sources.values.whereType<Map<String, dynamic>>()) {
      final tiles = source['tiles'];
      if (tiles is List) {
        source['tiles'] = tiles
            .map((tile) => tile is String ? absolutize(tile) : tile)
            .toList();
      }
      final url = source['url'];
      if (url is String) source['url'] = absolutize(url);
    }
  }
  return jsonEncode(style);
}
