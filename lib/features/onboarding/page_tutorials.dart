import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/l10n/app_language.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_text.dart';
import 'pixel_tutorial.dart';

/// Every main page that has an interactive Juan tutorial tour.
enum TutorialPage {
  home('home'),
  explore('explore'),
  map('map'),
  quests('quests'),
  questPlay('quest_play'),
  trail('trail'),
  shop('shop'),
  plaza('plaza'),
  profile('profile'),
  quickQr('quick_qr'),
  merchantHub('merchant_hub');

  const TutorialPage(this.key);
  final String key;

  String get storageKey => 'tutorial_seen_$key';
}

abstract interface class TutorialStore {
  Future<bool> isSeen(TutorialPage page);
  Future<void> markSeen(TutorialPage page);
  Future<void> resetPage(TutorialPage page);
  Future<void> resetAll();
}

/// Secure-storage backed tutorial seen flags (`tutorial_seen_<page>`).
/// Returns `true` on storage error (e.g. unmocked unit tests) so unrelated
/// widget tests are never blocked by tutorial overlays.
class SecureTutorialStore implements TutorialStore {
  const SecureTutorialStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<bool> isSeen(TutorialPage page) async {
    try {
      return await _storage.read(key: page.storageKey) == 'true';
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> markSeen(TutorialPage page) async {
    try {
      await _storage.write(key: page.storageKey, value: 'true');
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> resetPage(TutorialPage page) async {
    try {
      await _storage.delete(key: page.storageKey);
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> resetAll() async {
    for (final page in TutorialPage.values) {
      await resetPage(page);
    }
  }
}

/// In-memory store for tutorial widget tests.
class MemoryTutorialStore implements TutorialStore {
  MemoryTutorialStore([Set<TutorialPage>? initialSeen])
      : _seen = {...?initialSeen};

  final Set<TutorialPage> _seen;
  int resetAllCount = 0;

  @override
  Future<bool> isSeen(TutorialPage page) async => _seen.contains(page);

  @override
  Future<void> markSeen(TutorialPage page) async => _seen.add(page);

  @override
  Future<void> resetPage(TutorialPage page) async => _seen.remove(page);

  @override
  Future<void> resetAll() async {
    resetAllCount++;
    _seen.clear();
  }
}

final tutorialStoreProvider = Provider<TutorialStore>(
  (_) => const SecureTutorialStore(),
);

@immutable
class TutorialCoordinatorState {
  const TutorialCoordinatorState({
    this.activePage,
    this.deferNext = false,
  });

  final TutorialPage? activePage;
  final bool deferNext;

  TutorialCoordinatorState copyWith({
    TutorialPage? activePage,
    bool clearActive = false,
    bool? deferNext,
  }) =>
      TutorialCoordinatorState(
        activePage: clearActive ? null : (activePage ?? this.activePage),
        deferNext: deferNext ?? this.deferNext,
      );
}

class TutorialCoordinator extends StateNotifier<TutorialCoordinatorState> {
  TutorialCoordinator(this._store) : super(const TutorialCoordinatorState());

  final TutorialStore _store;
  final Set<TutorialPage> _checking = {};
  final Set<TutorialPage> _completedSession = {};

  /// Defer the next automatic page tour (e.g. arriving via push/deep link).
  void deferNextNavigation() {
    state = state.copyWith(deferNext: true);
  }

  Future<void> maybeStart(
    TutorialPage page, {
    bool isCurrentRoute = true,
  }) async {
    if (!isCurrentRoute) return;
    if (state.activePage != null) return;
    if (state.deferNext) {
      state = state.copyWith(deferNext: false);
      return;
    }
    if (_completedSession.contains(page) || _checking.contains(page)) return;
    _checking.add(page);
    final seen = await _store.isSeen(page);
    _checking.remove(page);
    if (!mounted) return;
    if (seen) {
      _completedSession.add(page);
      return;
    }
    if (state.activePage != null) return;
    state = state.copyWith(activePage: page);
  }

  Future<void> finish(TutorialPage page) async {
    _completedSession.add(page);
    if (state.activePage == page) {
      state = state.copyWith(clearActive: true);
    }
    await _store.markSeen(page);
  }

  Future<void> replayPage(TutorialPage page) async {
    _completedSession.remove(page);
    await _store.resetPage(page);
    if (!mounted) return;
    state = state.copyWith(activePage: page, deferNext: false);
  }

  Future<void> replayAll() async {
    _completedSession.clear();
    await _store.resetAll();
    if (!mounted) return;
    state = const TutorialCoordinatorState();
  }
}

final tutorialCoordinatorProvider =
    StateNotifierProvider<TutorialCoordinator, TutorialCoordinatorState>(
  (ref) => TutorialCoordinator(ref.watch(tutorialStoreProvider)),
);

/// Small "?" button for page app bars to replay that page's tutorial tour.
class TutorialHelpButton extends ConsumerWidget {
  const TutorialHelpButton({
    super.key,
    required this.page,
    this.onBeforeReplay,
  });

  final TutorialPage page;
  final VoidCallback? onBeforeReplay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: ValueKey('tutorial_help_${page.key}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onBeforeReplay?.call();
        ref.read(tutorialCoordinatorProvider.notifier).replayPage(page);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          child: PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '?',
                style: PixelType.title(context, color: PixelPalette.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hosts a page's [PixelTutorialOverlay] above its content, enforcing:
/// - only one tour active at a time
/// - never over a dialog or modal sheet
/// - deferred when arriving via deep link / notification tap
class PageTutorialHost extends ConsumerStatefulWidget {
  const PageTutorialHost({
    super.key,
    required this.page,
    required this.stepsBuilder,
    required this.child,
    this.keepAbove,
    this.suppressed = false,
  });

  final TutorialPage page;
  final List<TutorialStep> Function(BuildContext context) stepsBuilder;
  final Widget child;
  final GlobalKey? keepAbove;
  final bool suppressed;

  @override
  ConsumerState<PageTutorialHost> createState() => _PageTutorialHostState();
}

class _PageTutorialHostState extends ConsumerState<PageTutorialHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  void _maybeStart() {
    if (!mounted || widget.suppressed) return;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    ref.read(tutorialCoordinatorProvider.notifier).maybeStart(
          widget.page,
          isCurrentRoute: routeCurrent,
        );
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tutorialCoordinatorProvider).activePage;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final show = active == widget.page && routeCurrent && !widget.suppressed;
    return Stack(
      children: [
        widget.child,
        if (show)
          Positioned.fill(
            child: PixelTutorialOverlay(
              key: ValueKey('tutorial_overlay_${widget.page.key}'),
              steps: widget.stepsBuilder(context),
              keepAbove: widget.keepAbove,
              onDone: () => ref
                  .read(tutorialCoordinatorProvider.notifier)
                  .finish(widget.page),
            ),
          ),
      ],
    );
  }
}

/// Per-page localized tutorial steps (2–4 short steps each).
List<TutorialStep> buildPageTutorialSteps(
  BuildContext context,
  TutorialPage page, {
  GlobalKey? key1,
  GlobalKey? key2,
  GlobalKey? key3,
  GlobalKey? key4,
}) {
  switch (page) {
    case TutorialPage.home:
      return firstRunSteps(hero: key1, nextStop: key2, hotbar: key3);
    case TutorialPage.explore:
      return [
        TutorialStep(
          tr(context,
              en: 'Search spots or pick a category chip to filter Pangasinan gems.',
              tl: 'Maghanap ng lugar o pumili ng kategorya sa Pangasinan.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Freshly uploaded quests appear in New quests for 24 hours.',
              tl: 'Ang mga bagong quest ay makikita sa New quests nang 24 oras.'),
          target: key2,
        ),
        TutorialStep(
          tr(context,
              en: 'Tap any spot card to see details, cheers, and save it for later.',
              tl: 'Pindutin ang spot card para makita ang detalye, mag-cheer, at mag-save.'),
          target: key3,
        ),
      ];
    case TutorialPage.map:
      return [
        TutorialStep(
          tr(context,
              en: 'Drag with one finger and pinch with two to explore the map.',
              tl: 'I-drag gamit ang isang daliri at i-pinch para mag-zoom sa mapa.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Tap town labels or filter chips to focus on nearby spots and quests.',
              tl: 'Pindutin ang pangalan ng bayan o filter para sa malalapit na lugar.'),
          target: key2,
        ),
        TutorialStep(
          tr(context,
              en: 'Tap My Location anytime to jump back to where you are.',
              tl: 'Pindutin ang My Location para bumalik sa kinaroroonan mo.'),
          target: key3,
        ),
      ];
    case TutorialPage.quests:
      return [
        TutorialStep(
          tr(context,
              en: 'Browse active quests and tap one to see its checkpoints and rewards.',
              tl: 'Tingnan ang mga quest at pindutin ang isa para sa detalye at premyo.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Accept a quest to start its timer and unlock check-ins.',
              tl: 'Tanggapin ang quest para magsimula ang oras at check-in.'),
          target: key2,
        ),
        TutorialStep(
          tr(context,
              en: 'Visit the pin and submit your photo or QR proof before time runs out.',
              tl: 'Pumunta sa pin at magpasa ng litrato o QR proof bago maubos ang oras.'),
        ),
      ];
    case TutorialPage.questPlay:
      return [
        TutorialStep(
          tr(context,
              en: 'Follow the route to your next stop shown at the top.',
              tl: 'Sundan ang ruta papunta sa susunod na stop sa itaas.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'When you arrive inside the circle, tap Check-in to clear the stop.',
              tl: 'Pagdating sa loob ng bilog, pindutin ang Check-in para matapos ang stop.'),
          target: key2,
        ),
        TutorialStep(
          tr(context,
              en: 'Tap +CLIP or VLOG to record your trail moments as you go.',
              tl: 'Pindutin ang +CLIP o VLOG para mag-rekord ng iyong biyahe.'),
          target: key3,
        ),
      ];
    case TutorialPage.trail:
      return [
        TutorialStep(
          tr(context,
              en: 'Pick a curated trail to explore multiple Pangasinan stops in one trip.',
              tl: 'Pumili ng trail para bisitahin ang maraming lugar sa isang biyahe.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Tap Start to launch navigation and track your progress.',
              tl: 'Pindutin ang Start para simulan ang nabigasyon at progreso.'),
          target: key2,
        ),
        TutorialStep(
          tr(context,
              en: 'Your recorded clips and saved vlogs stay ready to replay anytime.',
              tl: 'Ang iyong mga clip at na-save na vlog ay maaaring panoorin anumang oras.'),
          target: key3,
        ),
      ];
    case TutorialPage.shop:
      return [
        TutorialStep(
          tr(context,
              en: 'Browse local vouchers, cosmetics, and merchant Suki cards here.',
              tl: 'Tingnan ang mga voucher, cosmetics, at Suki card dito.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Collect Suki stamps at partner shops to unlock bonus perks.',
              tl: 'Mag-ipon ng Suki stamp sa mga partner shop para sa dagdag na perks.'),
          target: key2,
        ),
        TutorialStep(
          tr(context,
              en: 'Link a wallet if a reward or item needs on-chain claim.',
              tl: 'Ikonekta ang wallet kung kailangan ng on-chain claim.'),
        ),
      ];
    case TutorialPage.plaza:
      return [
        TutorialStep(
          tr(context,
              en: 'Share a spot update or travel story with the community.',
              tl: 'Magbahagi ng update o kwento ng biyahe sa komunidad.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Tap Cheer to support fellow travelers or Comment to reply.',
              tl: 'Pindutin ang Cheer para suportahan ang iba o Comment para sumagot.'),
          target: key2,
        ),
      ];
    case TutorialPage.profile:
      return [
        TutorialStep(
          tr(context,
              en: 'Track your explorer level, XP, and earned badges here.',
              tl: 'Makikita rito ang iyong level, XP, at mga naipong badge.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Check your saved spots and quest history anytime.',
              tl: 'Tingnan ang mga na-save na lugar at kasaysayan ng quest.'),
          target: key2,
        ),
        TutorialStep(
          tr(context,
              en: 'Open Settings to change language, text size, or replay tutorials.',
              tl: 'Buksan ang Settings para sa wika, laki ng teksto, o ulitin ang mga gabay.'),
          target: key3,
        ),
      ];
    case TutorialPage.quickQr:
      return [
        TutorialStep(
          tr(context,
              en: 'Use Scan to check in at quest QR codes or claim Suki stamps.',
              tl: 'Gamitin ang Scan para sa quest QR code o Suki stamp.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Switch to My QR so merchants or friends can scan your code.',
              tl: 'Lumipat sa My QR para ma-scan ng merchant o kaibigan ang code mo.'),
          target: key2,
        ),
      ];
    case TutorialPage.merchantHub:
      return [
        TutorialStep(
          tr(context,
              en: 'Use Counter Scan to validate customer Suki cards and vouchers.',
              tl: 'Gamitin ang Counter Scan para i-validate ang Suki card at voucher.'),
          target: key1,
        ),
        TutorialStep(
          tr(context,
              en: 'Manage your shop vouchers and view visitor analytics here.',
              tl: 'Pamahalaan ang mga voucher at tingnan ang analytics ng tindahan.'),
          target: key2,
        ),
      ];
  }
}
