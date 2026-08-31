import '../models/app_version_info.dart';

abstract class IUpdateRepository {
  Future<AppVersionInfo?> fetchBackendVersionMetadata({Duration timeout});
  Future<bool> isDartPatchAvailable();
  Future<bool> downloadAndInstallDartPatch({void Function(double progress)? onProgress});
  Future<bool> syncContentBundle(ContentManifestMetadata metadata, {void Function(double progress)? onProgress});
  Future<void> restartApp();
}
