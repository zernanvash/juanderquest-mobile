import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/theme/app_theme.dart';
import '../models/suki_models.dart';
import '../providers/suki_provider.dart';
import '../suki_scan_flow.dart';

/// A quick fix for sorting nearby cards; never asks for permission here.
Future<({double? lat, double? lng})> _quickFix() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );
      return (lat: p.latitude, lng: p.longitude);
    }
  } catch (_) {
    // No fix: the server sorts by shop name.
  }
  return (lat: null, lng: null);
}

/// Where "near you" is measured from (tests replace it).
final sukiQuickFixProvider =
    Provider<Future<({double? lat, double? lng})> Function()>(
        (ref) => _quickFix);

/// Nearby cards for the `/suki` page.
final sukiNearbyHereProvider =
    FutureProvider.autoDispose<List<SukiProgram>>((ref) async {
  final at = await ref.read(sukiQuickFixProvider)();
  try {
    return await ref.read(sukiApiProvider).nearby(lat: at.lat, lng: at.lng);
  } catch (error) {
    if (isSukiDisabled(error)) return const SukiProgramList.comingSoon();
    rethrow;
  }
});

/// Plan 107 (`/suki`): my Suki Cards, cards near me, and Scan Suki.
class SukiCardsScreen extends ConsumerStatefulWidget {
  const SukiCardsScreen({super.key, this.autoScan = false});

  /// Home's Scan Suki tile opens `/suki?scan=1` and starts the scanner.
  final bool autoScan;

  @override
  ConsumerState<SukiCardsScreen> createState() => _SukiCardsScreenState();
}

class _SukiCardsScreenState extends ConsumerState<SukiCardsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) scanSukiStandee(context, ref);
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(sukiNearbyHereProvider);
    ref.invalidate(mySukiCardsProvider);
    try {
      await ref.read(mySukiCardsProvider.future);
    } catch (_) {
      // v0.3.10: the error panel shows it; never an uncaught refresh error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(mySukiCardsProvider);
    final nearby = ref.watch(sukiNearbyHereProvider);
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        final canPop = Navigator.of(context).canPop();
        final mine = cards.valueOrNull ?? const <SukiCard>[];
        final mineIds = {for (final c in mine) c.program.id};
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context, en: 'Suki Cards', tl: 'Suki Cards'),
                  onBack:
                      canPop ? () => Navigator.of(context).maybePop() : null,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: PixelPalette.green,
                    backgroundColor: PixelPalette.parchment,
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          grid.gutter,
                          grid.px(3),
                          grid.gutter,
                          grid.px(8) + MediaQuery.paddingOf(context).bottom),
                      children: [
                        PixelButton(
                          key: const ValueKey('suki_scan_button'),
                          label: tr(context,
                              en: 'Scan Suki', tl: 'I-scan ang Suki'),
                          expand: true,
                          onPressed: () => scanSukiStandee(context, ref),
                        ),
                        SizedBox(height: grid.px(3)),
                        ...cards.when(
                          loading: () => [
                            Center(
                                child: PixelLoader(
                                    label: tr(context,
                                        en: 'Loading cards',
                                        tl: 'Kinukuha ang cards')))
                          ],
                          error: (error, _) => [SukiErrorPanel(error: error)],
                          data: (list) => list.isEmpty
                              ? [
                                  PixelEmptyState(
                                    key: const ValueKey('suki_empty'),
                                    icon: DesignerArt.handshake,
                                    title: tr(context,
                                        en: 'No Suki Cards yet',
                                        tl: 'Wala pang Suki Card'),
                                    message: tr(context,
                                        en: 'Scan the Suki QR at a partner shop counter. Every visit fills a slot; a full card gets the shop\'s reward.',
                                        tl: 'I-scan ang Suki QR sa counter ng partner shop. Bawat bisita ay isang slot; ang buong card ay may reward.'),
                                  ),
                                ]
                              : [
                                  PixelPanel(
                                    key: const ValueKey('suki_my_cards'),
                                    style: PixelBoxStyle.parchment,
                                    padding: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        PixelSectionTitle(
                                          tr(context,
                                              en: 'My cards',
                                              tl: 'Mga card ko'),
                                          icon: DesignerArt.handshake,
                                          value: '${list.length}',
                                          valueColor: PixelPalette.greenDark,
                                        ),
                                        for (var i = 0;
                                            i < list.length;
                                            i++) ...[
                                          if (i > 0) _divider(grid),
                                          SukiCardTile(card: list[i]),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                        ),
                        SizedBox(height: grid.px(3)),
                        nearby.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, _) => isSukiDisabled(error)
                              ? SukiErrorPanel(error: error)
                              : const SizedBox.shrink(),
                          data: (programs) {
                            if (isSukiComingSoonState(programs)) {
                              return const SukiComingSoonPanel();
                            }
                            final others = [
                              for (final p in programs)
                                if (!mineIds.contains(p.id)) p
                            ];
                            if (others.isEmpty) return const SizedBox.shrink();
                            return PixelPanel(
                              key: const ValueKey('suki_nearby'),
                              style: PixelBoxStyle.parchment,
                              padding: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  PixelSectionTitle(
                                    tr(context,
                                        en: 'Suki shops near you',
                                        tl: 'Suki shops malapit sa iyo'),
                                    icon: DesignerArt.spotMarker,
                                  ),
                                  for (var i = 0; i < others.length; i++) ...[
                                    if (i > 0) _divider(grid),
                                    SukiProgramTile(program: others[i]),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

Widget _divider(PixelGrid grid) =>
    Container(height: grid.unit, color: PixelPalette.paperDim);

/// "Coming soon" panel shown when Suki is switched off.
class SukiComingSoonPanel extends StatelessWidget {
  const SukiComingSoonPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      key: const ValueKey('suki_coming_soon'),
      style: PixelBoxStyle.slot,
      padding: 2,
      child: Text(
        sukiComingSoonText(context),
        textAlign: TextAlign.center,
        style: PixelType.body(context, color: PixelPalette.ink),
      ),
    );
  }
}

/// "Coming soon" when Suki is switched off, else the plain error.
class SukiErrorPanel extends StatelessWidget {
  const SukiErrorPanel({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final disabled = isSukiDisabled(error);
    return PixelPanel(
      key: ValueKey(disabled ? 'suki_coming_soon' : 'suki_error'),
      style: disabled ? PixelBoxStyle.slot : PixelBoxStyle.red,
      padding: 2,
      child: Text(
        sukiErrorText(context, error),
        textAlign: TextAlign.center,
        style: PixelType.body(context,
            color: disabled ? PixelPalette.ink : PixelPalette.white),
      ),
    );
  }
}

/// One card row: shop, progress and an open reward.
class SukiCardTile extends StatelessWidget {
  const SukiCardTile({super.key, required this.card});

  final SukiCard card;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final p = card.program;
    final progress = card.progress;
    final open = card.rewards.where((r) => r.claimable).length;
    return GestureDetector(
      key: ValueKey('suki_card_${p.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/suki/${Uri.encodeComponent(p.id)}'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.merchant.name, style: PixelType.body(context)),
            Text(
              [
                if (p.merchant.municipality != null) p.merchant.municipality!,
                p.title
              ].join(' · '),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            PixelProgressBar(
              value: progress.required == 0
                  ? 0
                  : progress.visits / progress.required,
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${progress.visits}/${progress.required}',
                    style: PixelType.body(context)),
                PixelChip(p.rewardTag, style: PixelBoxStyle.gold),
                if (open > 0)
                  PixelChip(tr(context, en: 'Reward ready', tl: 'May reward'),
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white),
                if (progress.visitedToday)
                  Text(tr(context, en: 'Visited today', tl: 'Bumisita ngayon'),
                      style: PixelType.small(context,
                          color: PixelPalette.greenDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A shop's program the traveler has no card for yet.
class SukiProgramTile extends StatelessWidget {
  const SukiProgramTile({super.key, required this.program});

  final SukiProgram program;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final p = program;
    final distance = p.distanceM == null
        ? null
        : (p.distanceM! < 1000
            ? '${p.distanceM} m'
            : '${(p.distanceM! / 1000).toStringAsFixed(1)} km');
    return GestureDetector(
      key: ValueKey('suki_program_${p.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/suki/${Uri.encodeComponent(p.id)}'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.merchant.name, style: PixelType.body(context)),
            Text(
              [
                if (p.merchant.municipality != null) p.merchant.municipality!,
                if (distance != null) distance,
              ].join(' · '),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PixelChip(p.rewardTag, style: PixelBoxStyle.gold),
                Text(
                  tr(context,
                      en: '${p.visitsRequired} visits: ${p.rewardText}',
                      tl: '${p.visitsRequired} bisita: ${p.rewardText}'),
                  style: PixelType.small(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
