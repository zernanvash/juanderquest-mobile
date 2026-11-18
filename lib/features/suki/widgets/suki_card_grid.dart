import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_idle.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../dashboard/pixel/home_pixel_art.dart';

/// Plan 107: one slot per visit needed. Filled slots show a stamp check;
/// the last slot is the reward: a gift gem with its tag
/// (FREE / 10% OFF / ₱20 OFF / PROMO), with the reward line underneath.
class SukiCardGrid extends StatelessWidget {
  const SukiCardGrid({
    super.key,
    required this.visits,
    required this.required,
    required this.rewardTag,
    required this.rewardText,
  });

  final int visits;
  final int required;
  final String rewardTag;
  final String rewardText;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final total = required < 1 ? 1 : required;
    final filled = visits.clamp(0, total);
    final remaining = total - filled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final gap = grid.px(1);
          const perRow = 5;
          final size = ((constraints.maxWidth - gap * (perRow - 1)) / perRow)
              .clamp(24.0, 64.0)
              .floorToDouble();
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < total; i++)
                SizedBox.square(
                  key: ValueKey('suki_slot_$i'),
                  dimension: size,
                  child: _slot(context, i, total, filled),
                ),
            ],
          );
        }),
        SizedBox(height: grid.px(2)),
        Text(
          remaining == 0
              ? tr(context,
                  en: 'Reward ready: $rewardText', tl: 'Handa na: $rewardText')
              : tr(context,
                  en: '$remaining more ${remaining == 1 ? 'visit' : 'visits'} for: $rewardText',
                  tl: '$remaining pang bisita para sa: $rewardText'),
          key: const ValueKey('suki_countdown'),
          style: PixelType.body(context),
        ),
      ],
    );
  }

  Widget _slot(BuildContext context, int i, int total, int filled) {
    final isFilled = i < filled;
    final last = i == total - 1;
    final Widget content;
    if (isFilled) {
      content = const PixelShimmer(
        restMs: 3200,
        child: FittedBox(child: PixelSprite(HomePixelArt.stampCheck, scale: 2)),
      );
    } else if (last) {
      content = FittedBox(
        key: const ValueKey('suki_reward_slot'),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelSprite(DesignerArt.gem, scale: 2),
              Text(
                rewardTag,
                textAlign: TextAlign.center,
                style: PixelType.small(context, color: PixelPalette.redDeep),
              ),
            ],
          ),
        ),
      );
    } else {
      content = FittedBox(
        child: Text('${i + 1}',
            style: PixelType.small(context, color: PixelPalette.slate)),
      );
    }
    return PixelPanel(
      style: (isFilled || last ? PixelBoxStyle.gold : PixelBoxStyle.slot)
          .copyWith(corner: 2, shadowPx: 0),
      padding: 1,
      child: Center(child: content),
    );
  }
}
