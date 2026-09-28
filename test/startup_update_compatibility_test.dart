import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:juanderquest_app/features/app_update/domain/update_classification.dart';
import 'package:juanderquest_app/features/app_update/domain/update_repository.dart';
import 'package:juanderquest_app/features/app_update/models/app_version_info.dart';
import 'package:juanderquest_app/features/app_update/providers/startup_update_controller.dart';

class _ReleaseRepository implements IUpdateRepository {
  final AppVersionInfo release;
  _ReleaseRepository(this.release);

  @override
  Future<AppVersionInfo?> fetchBackendVersionMetadata({Duration timeout = const Duration(seconds: 3)}) async => release;
  @override
  Future<bool> isDartPatchAvailable() async => false;
  @override
  Future<bool> downloadAndInstallDartPatch({void Function(double progress)? onProgress}) async => false;
  @override
  Future<bool> syncContentBundle(ContentManifestMetadata metadata, {void Function(double progress)? onProgress}) async => false;
  @override
  Future<void> restartApp() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GatePhase> phaseForInstalledBuild(String buildNumber) async {
    PackageInfo.setMockInitialValues(
      appName: 'JuanDerQuest', packageName: 'dev.zernanvash.juanderquest',
      version: '1.2.3', buildNumber: buildNumber, buildSignature: '',
    );
    final release = AppVersionInfo.fromJson({
      'schemaVersion': 1,
      'versionCode': 123,
      'versionName': '1.2.3',
      'downloadUrl': 'https://example.test/app.apk',
      'forceUpdate': true,
      'minSupportedVersionCode': 123,
      'minimumBaseVersionCode': 123,
      'baseReleaseRequired': true,
      'updatePolicy': 'mandatory',
    });
    final controller = StartupUpdateController(_ReleaseRepository(release));
    await controller.initStartupGate();
    final phase = controller.debugState.phase;
    controller.dispose();
    return phase;
  }

  test('mandatory release blocks an older installed APK', () async {
    expect(await phaseForInstalledBuild('122'), GatePhase.baseRequired);
  });

  test('the required APK itself passes the startup gate', () async {
    expect(await phaseForInstalledBuild('123'), GatePhase.ready);
  });

  test('a newer compatible APK passes the startup gate', () async {
    expect(await phaseForInstalledBuild('124'), GatePhase.ready);
  });
}
