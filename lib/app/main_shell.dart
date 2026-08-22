import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/companion/widgets/companion_card.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPress;
  int _previousIndex = 0;

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _previousIndex = oldWidget.navigationShell.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isForward = currentIndex >= _previousIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

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
      child: Scaffold(
        body: Column(children: [
          Expanded(
              child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) {
              final slideInOffset =
                  isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
              final slideOutOffset =
                  isForward ? const Offset(-0.3, 0.0) : const Offset(0.3, 0.0);

              if (child.key == ValueKey<int>(currentIndex)) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: slideInOffset,
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              } else {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: slideOutOffset,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              }
            },
            child: KeyedSubtree(
              key: ValueKey<int>(currentIndex),
              child: widget.navigationShell,
            ),
          )),
          CompanionCard(tabIndex: currentIndex),
        ]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
                top: BorderSide(
                    color: const Color(0xFFD5C4AC).withValues(alpha: 0.4))),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF3F6653),
            unselectedItemColor: const Color(0xFF837560),
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            onTap: (index) {
              if (index == currentIndex) {
                widget.navigationShell.goBranch(index, initialLocation: true);
              } else {
                widget.navigationShell.goBranch(index);
              }
            },
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.explore_rounded), label: 'Explore'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.map_rounded), label: 'Map'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.how_to_vote_rounded), label: 'Vote'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_rounded), label: 'Shop'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
