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

  /// The six main pages. Detail pages (a spot, a quest, search, notifications,
  /// saved) hide the hotbar; their back button returns to a main page.
  static const mainPages = {
    '/',
    '/dashboard',
    '/explore',
    '/map',
    '/quests',
    '/choice',
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
                      PixelHotbarItem(
                        label: 'HOME',
                        icon: PlaceholderArt.home,
                      ),
                      PixelHotbarItem(
                        label: 'MAP',
                        icon: DesignerArt.navExplore,
                      ),
                      PixelHotbarItem(
                        label: 'QUESTS',
                        icon: DesignerArt.questMarker,
                      ),
                      PixelHotbarItem(
                        label: 'CHOICE',
                        icon: DesignerArt.juanChoice,
                        pressedIcon: DesignerArt.juanChoiceHover,
                      ),
                      PixelHotbarItem(
                        label: 'PROFILE',
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
