import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/app_update/domain/update_classification.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';

AppVersionInfo _manifest({
  int versionCode = 175,
  int? buildNumber,
  int? minSupportedBuildNumber,
  int minSupportedVersionCode = 150,
  int? signingKeyGeneration,
  bool forceUpdate = false,
  bool baseReleaseRequired = false,
  UpdatePolicy policy = UpdatePolicy.optional,
}) {
  return AppVersionInfo(
    versionCode: versionCode,
    versionName: '1.0.0',
    downloadUrl: 'https://example.test/app.apk',
    changelog: '',
    forceUpdate: forceUpdate,
    minSupportedVersionCode: minSupportedVersionCode,
    baseReleaseRequired: baseReleaseRequired,
    updatePolicy: policy,
    buildNumber: buildNumber,
    minSupportedBuildNumber: minSupportedBuildNumber,
    signingKeyGeneration: signingKeyGeneration,
  );
}

void main() {
  group('classifyUpdate', () {
    test('none when no manifest or no newer build', () {
      expect(classifyUpdate(installedBuild: 10, manifest: null), UpdateClass.none);
      expect(classifyUpdate(installedBuild: 175, manifest: _manifest()), UpdateClass.none);
      expect(classifyUpdate(installedBuild: 176, manifest: _manifest()), UpdateClass.none);
    });

    test('prefers buildNumber over versionCode when present (per-ABI splits)', () {
      final perAbi = _manifest(versionCode: 20000 + 175, buildNumber: 175);
      expect(classifyUpdate(installedBuild: 175, manifest: perAbi), UpdateClass.none);
      expect(classifyUpdate(installedBuild: 174, manifest: perAbi), UpdateClass.optional);
    });

    test('required when force, mandatory policy, or below the min supported build', () {
      expect(classifyUpdate(installedBuild: 174, manifest: _manifest(forceUpdate: true)), UpdateClass.required);
      expect(
        classifyUpdate(installedBuild: 174, manifest: _manifest(policy: UpdatePolicy.mandatory)),
        UpdateClass.required,
      );
      expect(
        classifyUpdate(installedBuild: 100, manifest: _manifest(minSupportedBuildNumber: 150)),
        UpdateClass.required,
      );
    });

    test('recommended for a base release, optional otherwise', () {
      expect(
        classifyUpdate(installedBuild: 174, manifest: _manifest(baseReleaseRequired: true)),
        UpdateClass.recommended,
      );
      expect(classifyUpdate(installedBuild: 174, manifest: _manifest()), UpdateClass.optional);
    });

    test('reinstallRequired when the manifest needs a newer signing generation', () {
      final newerKeys = _manifest(signingKeyGeneration: 2);
      expect(
        classifyUpdate(installedBuild: 174, manifest: newerKeys, installedGeneration: 1),
        UpdateClass.reinstallRequired,
      );
      expect(
        classifyUpdate(installedBuild: 174, manifest: newerKeys, installedGeneration: 2),
        UpdateClass.optional,
      );
    });

    test('reinstall classification wins even when the build is current', () {
      final newerKeys = _manifest(buildNumber: 100, signingKeyGeneration: 3);
      expect(
        classifyUpdate(installedBuild: 175, manifest: newerKeys, installedGeneration: 2),
        UpdateClass.reinstallRequired,
      );
    });
  });
}
