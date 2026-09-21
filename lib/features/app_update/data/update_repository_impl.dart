import '../domain/update_repository.dart';
import '../models/app_version_info.dart';
import 'content_manifest_service.dart';
import 'shorebird_update_service.dart';
import 'release_manifest_client.dart';

class UpdateRepositoryImpl implements IUpdateRepository {
  final ReleaseManifestClient _manifestClient;
  final ShorebirdUpdateService _shorebirdService;
  final ContentManifestService _contentService;

  UpdateRepositoryImpl({
    ReleaseManifestClient? manifestClient,
    ShorebirdUpdateService? shorebirdService,
    ContentManifestService? contentService,
  })  : _manifestClient = manifestClient ?? ReleaseManifestClient(),
        _shorebirdService = shorebirdService ?? ShorebirdUpdateService(),
        _contentService = contentService ?? ContentManifestService();

  @override
  Future<AppVersionInfo?> fetchBackendVersionMetadata({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return _manifestClient.fetch(timeout: timeout);
  }

  @override
  Future<bool> isDartPatchAvailable() async {
    return _shorebirdService.checkForPatchUpdate();
  }

  @override
  Future<bool> downloadAndInstallDartPatch({
    void Function(double progress)? onProgress,
  }) async {
    return _shorebirdService.downloadPatch(onProgress: onProgress);
  }

  @override
  Future<bool> syncContentBundle(
    ContentManifestMetadata metadata, {
    void Function(double progress)? onProgress,
  }) async {
    return _contentService.syncContentBundle(metadata, onProgress: onProgress);
  }

  @override
  Future<void> restartApp() async {
    return _shorebirdService.restartApp();
  }
}
