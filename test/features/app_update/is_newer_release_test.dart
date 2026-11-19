import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/app_update/providers/app_update_provider.dart';

void main() {
  test('a higher CI build is an update', () {
    expect(
      isNewerRelease(
          latestCode: 224,
          latestName: '0.3.10',
          installedCode: 223,
          installedName: '0.3.9'),
      isTrue,
    );
  });

  test(
      'a local debug build of the same version is not prompted (v0.3.9 -> v0.3.9)',
      () {
    expect(
      isNewerRelease(
          latestCode: 223,
          latestName: '0.3.9',
          installedCode: 1,
          installedName: '0.3.9'),
      isFalse,
    );
  });

  test('a local debug build of an older version is still prompted', () {
    expect(
      isNewerRelease(
          latestCode: 223,
          latestName: '0.3.9',
          installedCode: 1,
          installedName: '0.3.8'),
      isTrue,
    );
  });

  test('a CI rebuild of the same version name still updates', () {
    expect(
      isNewerRelease(
          latestCode: 218,
          latestName: '0.3.4',
          installedCode: 217,
          installedName: '0.3.4'),
      isTrue,
    );
  });

  test('same or older code is never an update', () {
    expect(
      isNewerRelease(
          latestCode: 223,
          latestName: '0.3.9',
          installedCode: 223,
          installedName: '0.3.9'),
      isFalse,
    );
  });

  test('a local debug build of a newer version is never offered an older release',
      () {
    expect(
      isNewerRelease(
          latestCode: 223,
          latestName: '0.3.9',
          installedCode: 1,
          installedName: '0.3.10'),
      isFalse,
    );
  });
}
