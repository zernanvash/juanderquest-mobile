import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/pixel/generated/designer_art.g.dart';
import '../core/pixel/generated/pixel_palette.g.dart';
import '../core/pixel/pixel_nav.dart';
import '../core/pixel/placeholder_art.dart';
import '../features/companion/widgets/companion_card.dart';
import '../features/dashboard/home_tips.dart';
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
    '/quests',
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
            body: Column(
              children: [
                Expanded(child: widget.navigationShell),
                if (onMainPage) CompanionCard(tabIndex: currentIndex),
              ],
            ),
            bottomNavigationBar: !onMainPage
                ? null
                : PixelHotbar(
                    key: tipsKeys.hotbar,
                    index: currentIndex,
                    onTap: (index) {
                      if (index == currentIndex) {
                        widget.navigationShell
                            .goBranch(index, initialLocation: true);
                      } else {
                        widget.navigationShell.goBranch(index);
                      }
                    },
                    items: const [
                      // Owner 2026-11-05: Home · Explore · Map · Shop · Profile.
                      // Explore and Map icons are placeholders until the
                      // designer draws them.
                      PixelHotbarItem(
                        label: 'Home',
                        icon: PlaceholderArt.home,
                      ),
                      PixelHotbarItem(
                        label: 'Explore',
                        icon: DesignerArt.search,
                      ),
                      PixelHotbarItem(
                        label: 'Map',
                        icon: DesignerArt.navExplore,
                      ),
                      PixelHotbarItem(
                        label: 'Quests',
                        icon: DesignerArt.questMarker,
                      ),
                      PixelHotbarItem(
                        label: 'Profile',
                        icon: PlaceholderArt.profile,
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
