import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_language.dart';
import '../core/pixel/generated/designer_art.g.dart';
import '../core/pixel/generated/pixel_palette.g.dart';
import '../core/pixel/pixel_nav.dart';
import '../features/companion/widgets/companion_card.dart';
import '../features/dashboard/home_tips.dart';
import '../features/dashboard/widgets/main_menu_overlay.dart';
import '../features/onboarding/pixel_tutorial.dart';
import '../features/juanchoice/providers/juanchoice_provider.dart';
import '../features/quests/providers/campaign_provider.dart';
import '../features/quests/providers/quest_provider.dart';
import '../features/spots/providers/spot_discovery_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  /// Current path; the hotbar shows only on the main pages (owner 2026-11-04).
  final String location;

  const MainShell({
    super.key,
    required this.navigationShell,
    this.location = '/dashboard',
  });

  /// The main pages (one per tab). Detail pages (a spot, a quest, search, notifications,
  /// saved) hide the hotbar; their back button returns to a main page.
  static const mainPages = {
    '/',
    '/dashboard',
    '/explore',
    '/map',
    '/shop',
    '/profile',
  };

  static bool showsHotbar(String path) {
    final p = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return mainPages.contains(p);
  }

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPress;
  bool _menuOpen = false;

  /// Bottom-bar tabs and the shell branch each opens. The Map (branch 2) left
  /// the bar (owner 2026-11-16); it opens from the map button by Search.
  static const _tabBranches = [0, 1, 3, 4];

  void _setMenu(bool open) {
    if (_menuOpen != open) setState(() => _menuOpen = open);
  }

  @override
  void initState() {
    super.initState();
    // Preload tourism spots, quest markers, and active event campaigns in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(spotDiscoveryProvider.notifier).load();
      ref.read(questProvider.notifier).fetchQuests();
      ref.read(campaignProvider.notifier).fetchCampaigns();
      ref.read(choiceSpotlightProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final tips = ref.watch(homeTipsControllerProvider);
    final tipsKeys = ref.watch(homeTipsKeysProvider);
    final onMainPage = MainShell.showsHotbar(widget.location);
    final showTips = tips.showing && currentIndex == 0 && onMainPage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (showTips) {
          ref.read(homeTipsControllerProvider.notifier).skip();
          return;
        }

        if (_menuOpen) {
          _setMenu(false);
          return;
        }

        // A detail page (notifications, a spot, a quest…) goes back to where
        // it came from; with no history, to its main page. Only main pages
        // fall through to "switch to Home" and "press back again to exit".
        if (!onMainPage) {
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            widget.navigationShell
                .goBranch(currentIndex, initialLocation: true);
          }
          return;
        }

        if (currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: PixelPalette.paper,
            body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: widget.navigationShell),
                    if (onMainPage) CompanionCard(tabIndex: currentIndex),
                  ],
                ),
                // The main menu: the page dims, the menu rises out of pixel
                // embers above the bar.
                if (onMainPage)
                  Positioned.fill(
                    child: MainMenuOverlay(
                      open: _menuOpen,
                      onClose: () => _setMenu(false),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: !onMainPage
                ? null
                : PixelHotbar(
                    key: tipsKeys.hotbar,
                    index: _tabBranches.indexOf(currentIndex),
                    onTap: (tab) {
                      _setMenu(false);
                      final branch = _tabBranches[tab];
                      if (branch == currentIndex) {
                        widget.navigationShell
                            .goBranch(branch, initialLocation: true);
                      } else {
                        widget.navigationShell.goBranch(branch);
                      }
                    },
                    // Owner 2026-11-16: a MENU button opens the main menu.
                    center: KeyedSubtree(
                      key: tipsKeys.nextStop,
                      child: PixelMenuButton(
                        open: _menuOpen,
                        label: tr(context, en: 'Menu', tl: 'Menu'),
                        closeLabel: tr(context, en: 'Close', tl: 'Isara'),
                        onPressed: () => _setMenu(!_menuOpen),
                      ),
                    ),
                    items: [
                      // Owner 2026-11-16: Home · Explore · MENU · Shop ·
                      // Profile (the Map moved next to Search).
                      // Plan 93b WP-8: labels follow Settings -> Language.
                      PixelHotbarItem(
                        label: tr(context, en: 'Home', tl: 'Tahanan'),
                        icon: DesignerArt.navHome,
                      ),
                      PixelHotbarItem(
                        label: tr(context, en: 'Explore', tl: 'Tuklasin'),
                        // Owner 2026-11-16: the original navExplore compass.
                        icon: DesignerArt.navExplore,
                      ),
                      PixelHotbarItem(
                        label: tr(context, en: 'Shop', tl: 'Tindahan'),
                        icon: DesignerArt.navShop,
                      ),
                      const PixelHotbarItem(
                        label: 'Profile',
                        icon: DesignerArt.navProfile,
                      ),
                    ],
                  ),
          ),
          if (showTips)
            Positioned.fill(
              child: PixelTutorialOverlay(
                steps: firstRunSteps(
                  hero: tipsKeys.hero,
                  nextStop: tipsKeys.nextStop,
                  hotbar: tipsKeys.hotbar,
                ),
                keepAbove: tipsKeys.hotbar,
                onDone: () =>
                    ref.read(homeTipsControllerProvider.notifier).finish(),
              ),
            ),
        ],
      ),
    );
  }
}
