import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/app_update/data/release_manifest_client.dart';

void main() {
  const validHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Map<String, dynamic> validManifest() => {
        'schemaVersion': 1,
        'packageName': 'dev.zernanvash.juanderquest',
        'versionCode': 101,
        'versionName': '1.0.0',
        'downloadUrl':
            'https://github.com/zernanvash/juanderquest-mobile/releases/latest/download/juanderquest-latest.apk',
        'sha256': validHash,
        'sizeBytes': 6 * 1024 * 1024,
        'changelog': 'Test release',
      };

  test('accepts a valid GitHub release manifest', () {
    final release = ReleaseManifestClient.parse(validManifest());

    expect(release.versionCode, 101);
    expect(release.packageName, 'dev.zernanvash.juanderquest');
    expect(release.sha256, validHash);
  });

  test('rejects a manifest for another Android package', () {
    final manifest = validManifest()
      ..['packageName'] = 'dev.example.impostor';

    expect(
      () => ReleaseManifestClient.parse(manifest),
      throwsFormatException,
    );
  });

  test('rejects insecure downloads and malformed hashes', () {
    final manifest = validManifest()
      ..['downloadUrl'] = 'http://example.test/app.apk'
      ..['sha256'] = 'not-a-hash';

    expect(
      () => ReleaseManifestClient.parse(manifest),
      throwsFormatException,
    );
  });
}
