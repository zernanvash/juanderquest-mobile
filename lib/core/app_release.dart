/// Release channel shown next to the app version
/// (owner, 2026-11-02: "mark this app as beta v0.2.1").
/// The version number comes from pubspec.yaml `version:`: 0.1.n is the classic app,
/// 0.2.n the pixel app (owner, 2026-11-02); bump n on every release.
const String kReleaseChannel = 'Beta';

/// "v0.2.1 Beta": the version as travelers see it.
String versionLabel(String versionName) => 'v$versionName $kReleaseChannel';
