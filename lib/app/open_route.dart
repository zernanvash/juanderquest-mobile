import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Tab roots: each is its own shell branch with its own history.
const tabRoutes = {'/dashboard', '/explore', '/map', '/shop', '/profile'};

/// Opens [route] from a menu, panel or button. A tab root switches to that
/// tab; pushing it would stack it on the current tab (owner 2026-11-17: Map
/// from the menu, then Home, then Explore showed the Map).
void openRoute(BuildContext context, String route) =>
    openRouteWith(GoRouter.of(context), route);

/// [openRoute] for code above the navigator (push and in-app banners).
void openRouteWith(GoRouter router, String route) {
  if (tabRoutes.contains(Uri.parse(route).path)) {
    router.go(route);
  } else {
    router.push(route);
  }
}
