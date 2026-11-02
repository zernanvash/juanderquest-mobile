import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/app_release.dart';

void main() {
  test('the version is labelled Beta and pubspec holds the release line', () {
    expect(versionLabel('0.2.1'), 'v0.2.1 Beta');
    // CI reads the version name from this exact line (release tag android-v<name>+<code>).
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version: '));
    // 0.1.n = the classic (non-pixel) app, 0.2.n = the pixel app; bump n every release.
    expect(line, matches(RegExp(r'^version: 0\.[12]\.\d+\+1$')));
  });
}
