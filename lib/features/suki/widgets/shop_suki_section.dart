import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../providers/suki_provider.dart';
import '../suki_scan_flow.dart';

/// Plan 107: the Shop's "Suki Cards" section: my cards with progress,
/// Scan Suki, and a link to all cards.
class ShopSukiSection extends ConsumerWidget {
  const ShopSukiSection({super.key});

  static const _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final cards = ref.watch(mySukiCardsProvider).valueOrNull ?? const [];
    return PixelPanel(
      key: const ValueKey('shop_suki_section'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'Suki Cards', tl: 'Suki Cards'),
            icon: DesignerArt.handshake,
            value: cards.isEmpty ? null : '${cards.length}',
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(1)),
          if (cards.isEmpty)
            Text(
              tr(context,
                  en: 'Collect visits at partner shops. A full card gets the shop\'s reward.',
                  tl: 'Mangolekta ng bisita sa partner shops. May reward ang buong card.'),
              style: PixelType.small(context, color: PixelPalette.slate),
            )
          else
            for (final card in cards.take(_shown))
              GestureDetector(
                key: ValueKey('shop_suki_card_${card.program.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context
                    .push('/suki/${Uri.encodeComponent(card.program.id)}'),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: grid.px(1)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: grid.px(2),
                        runSpacing: grid.px(1),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(card.program.merchant.name,
                              style: PixelType.body(context)),
                          Text(
                              '${card.progress.visits}/${card.progress.required}',
                              style: PixelType.small(context,
                                  color: PixelPalette.slate)),
                          if (card.rewards.any((r) => r.claimable))
                            PixelChip(
                                tr(context,
                                    en: 'Reward ready', tl: 'May reward'),
                                style: PixelBoxStyle.green,
                                textColor: PixelPalette.white),
                        ],
                      ),
                      SizedBox(height: grid.px(1)),
                      PixelProgressBar(
                        value: card.progress.required == 0
                            ? 0
                            : card.progress.visits / card.progress.required,
                      ),
                    ],
                  ),
                ),
              ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              PixelButton(
                key: const ValueKey('shop_scan_suki'),
                label: tr(context, en: 'Scan Suki', tl: 'I-scan ang Suki'),
                onPressed: () => scanSukiStandee(context, ref),
              ),
              PixelButton(
                key: const ValueKey('shop_suki_all'),
                label: tr(context, en: 'All cards', tl: 'Lahat ng card'),
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/suki'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
