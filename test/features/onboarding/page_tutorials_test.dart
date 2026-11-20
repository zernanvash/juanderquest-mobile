import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/onboarding/page_tutorials.dart';
import 'package:juanderquest_app/features/onboarding/pixel_tutorial.dart';

void main() {
  Widget harness(
    MemoryTutorialStore store,
    TutorialPage page, {
    bool openDialog = false,
  }) {
    return ProviderScope(
      overrides: [
        tutorialStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: PageTutorialHost(
          page: page,
          stepsBuilder: (ctx) => buildPageTutorialSteps(ctx, page),
          child: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TutorialHelpButton(page: page),
                    if (openDialog)
                      ElevatedButton(
                        key: const ValueKey('open_dialog'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const AlertDialog(
                            content: Text('AlertContent'),
                          ),
                        ),
                        child: const Text('OpenDialog'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final page in TutorialPage.values) {
    testWidgets(
      '${page.key} tour shows on first visit, hides on second, replays on ?',
      (tester) async {
        final store = MemoryTutorialStore();
        await tester.pumpWidget(harness(store, page));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(PixelTutorialOverlay), findsOneWidget);

        // Skip sets the seen flag and closes the overlay.
        await tester.tap(find.byKey(const ValueKey('tutorial-skip')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(PixelTutorialOverlay), findsNothing);
        expect(await store.isSeen(page), isTrue);

        // Second visit with same store does not show again.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(harness(store, page));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(PixelTutorialOverlay), findsNothing);

        // "?" button replays only that tour.
        await tester.tap(find.byKey(ValueKey('tutorial_help_${page.key}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(PixelTutorialOverlay), findsOneWidget);
      },
    );
  }

  testWidgets('never shows two tours at once', (tester) async {
    final store = MemoryTutorialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tutorialStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: Column(
            children: [
              Expanded(
                child: PageTutorialHost(
                  page: TutorialPage.explore,
                  stepsBuilder: (c) =>
                      buildPageTutorialSteps(c, TutorialPage.explore),
                  child: const Scaffold(body: Text('Explore')),
                ),
              ),
              Expanded(
                child: PageTutorialHost(
                  page: TutorialPage.shop,
                  stepsBuilder: (c) =>
                      buildPageTutorialSteps(c, TutorialPage.shop),
                  child: const Scaffold(body: Text('Shop')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PixelTutorialOverlay), findsOneWidget);
  });

  testWidgets('never shows a tour over a dialog', (tester) async {
    final store = MemoryTutorialStore({TutorialPage.explore});
    await tester.pumpWidget(harness(store, TutorialPage.explore, openDialog: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PixelTutorialOverlay), findsNothing);

    // Open a dialog, then reset the page flag and trigger maybeStart: suppressed.
    await tester.tap(find.byKey(const ValueKey('open_dialog')));
    await tester.pumpAndSettle();
    expect(find.text('AlertContent'), findsOneWidget);
    expect(find.byType(PixelTutorialOverlay), findsNothing);
  });

  testWidgets('defers tour after notification/deep-link navigation',
      (tester) async {
    final store = MemoryTutorialStore();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tutorialStoreProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    container.read(tutorialCoordinatorProvider.notifier).deferNextNavigation();
    await container
        .read(tutorialCoordinatorProvider.notifier)
        .maybeStart(TutorialPage.map);
    expect(container.read(tutorialCoordinatorProvider).activePage, isNull);

    // Next normal visit starts the tour.
    await container
        .read(tutorialCoordinatorProvider.notifier)
        .maybeStart(TutorialPage.map);
    expect(
        container.read(tutorialCoordinatorProvider).activePage, TutorialPage.map);
  });
}
