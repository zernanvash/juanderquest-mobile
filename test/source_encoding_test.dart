import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Twice in the pixel work a "·" was saved as broken bytes and showed on the
// phone as "Â·" / "A◆" (2026-11-04 quest detail, 2026-11-05 Home). Every Dart
// source must be valid UTF-8 without replacement characters or that pattern.
void main() {
  test('no broken characters in lib/ sources', () {
    final bad = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final String text;
      try {
        text = entity.readAsStringSync();
      } on FileSystemException {
        bad.add('${entity.path}: not UTF-8');
        continue;
      }
      if (text.contains('\u{FFFD}') || text.contains('Â·')) {
        bad.add(entity.path);
      }
    }
    expect(bad, isEmpty, reason: 'Broken characters in: ${bad.join(', ')}');
  });
}
