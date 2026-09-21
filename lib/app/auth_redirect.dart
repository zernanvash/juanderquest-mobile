String? resolveAuthRedirect({
  required bool loggedIn,
  required String matchedLocation,
  required Uri uri,
}) {
  final onLogin = matchedLocation == '/';
  final publicDiscovery = matchedLocation == '/explore' ||
      matchedLocation.startsWith('/explore/') ||
      matchedLocation == '/choice' || matchedLocation.startsWith('/choice/');
  if (!loggedIn && !onLogin && !publicDiscovery) {
    return '/?redirect=${Uri.encodeComponent(uri.toString())}';
  }
  if (loggedIn && onLogin) {
    final destination = uri.queryParameters['redirect'];
    final safe = destination != null && destination.startsWith('/') &&
        !destination.startsWith('//') && !destination.startsWith('/\\');
    return safe ? destination : '/explore';
  }
  return null;
}
