/// Owner 2026-11-18: search that "tolerates spelling mistakes and those
/// stuffs". Used by the profile's posted spots and by Explore.
///
/// Every query word must match some word of the item (as a substring, a
/// prefix, or within a small edit distance: 1 typo for words up to 5
/// letters, 2 for longer ones). Accents and punctuation are ignored.
abstract final class FuzzySearch {
  /// Lower case, accents folded, punctuation dropped, split into words.
  static List<String> words(String text) => normalize(text)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList(growable: false);

  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final folded = _fold[ch] ?? ch;
      buffer.write(RegExp(r'[a-z0-9]').hasMatch(folded) ? folded : ' ');
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _fold = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  /// A score for how well [query] matches [fields] (higher is better), or
  /// null when it does not match. An empty query matches everything (0).
  static double? score(String query, Iterable<String> fields) {
    final q = words(query);
    if (q.isEmpty) return 0;
    final itemWords = <String>[for (final f in fields) ...words(f)];
    if (itemWords.isEmpty) return null;
    final whole = itemWords.join(' ');
    var total = 0.0;
    for (final qw in q) {
      var best = 0.0;
      for (final w in itemWords) {
        final s = _wordScore(qw, w);
        if (s > best) best = s;
        if (best == 3) break;
      }
      if (best == 0 && whole.contains(qw)) best = 1.5;
      if (best == 0) return null;
      total += best;
    }
    // Earlier fields (the name) count a little more.
    final first = fields.isEmpty ? '' : normalize(fields.first);
    final nq = normalize(query);
    if (first.contains(nq)) total += 1;
    if (first == nq) total += 1;
    return total;
  }

  static double _wordScore(String q, String w) {
    if (w == q) return 3;
    if (w.startsWith(q)) return 2.5;
    if (w.contains(q) && q.length >= 3) return 2;
    final allowed = q.length <= 2 ? 0 : (q.length <= 5 ? 1 : 2);
    if (allowed == 0) return 0;
    // Compare with the word, and with its start (typing a prefix with a typo).
    final d = _distance(q, w);
    if (d <= allowed) return 1.5 - d * 0.25;
    if (w.length > q.length) {
      final dp = _distance(q, w.substring(0, q.length));
      if (dp <= allowed) return 1.25 - dp * 0.25;
    }
    return 0;
  }

  /// Damerau-Levenshtein (optimal string alignment) distance.
  static int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final d = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = d[i - 1][j] + 1;
        if (d[i][j - 1] + 1 < v) v = d[i][j - 1] + 1;
        if (d[i - 1][j - 1] + cost < v) v = d[i - 1][j - 1] + cost;
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1] &&
            d[i - 2][j - 2] + 1 < v) {
          v = d[i - 2][j - 2] + 1;
        }
        d[i][j] = v;
      }
    }
    return d[a.length][b.length];
  }

  /// [items] that match [query], best first; all of them, in their own
  /// order, when the query is empty.
  static List<T> filter<T>(
    Iterable<T> items,
    String query,
    Iterable<String> Function(T item) fields,
  ) {
    if (words(query).isEmpty) return items.toList();
    final scored = <(T, double, int)>[];
    var i = 0;
    for (final item in items) {
      final s = score(query, fields(item));
      if (s != null) scored.add((item, s, i));
      i++;
    }
    scored.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : a.$3.compareTo(b.$3);
    });
    return [for (final s in scored) s.$1];
  }
}
