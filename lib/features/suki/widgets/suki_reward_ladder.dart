import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../models/suki_models.dart';
import 'suki_card_skin.dart';

/// Plan 111 §6: vertical milestone ladder showing unlocked, claimed & upcoming tiers.
class SukiRewardLadder extends StatelessWidget {
  const SukiRewardLadder({
    super.key,
    required this.tiers,
    required this.visits,
  });

  final List<SukiTier> tiers;
  final int visits;

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) return const SizedBox.shrink();
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const ValueKey('suki_reward_ladder'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'Reward ladder', tl: 'Mga reward'),
            icon: SukiTierArt.byKey(tiers.last.iconKey),
            value: '${tiers.length}',
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(1)),
          for (var i = 0; i < tiers.length; i++) ...[
            if (i > 0) Container(height: grid.unit, color: PixelPalette.paperDim),
            _tierRow(context, grid, tiers[i]),
          ],
        ],
      ),
    );
  }

  Widget _tierRow(BuildContext context, PixelGrid grid, SukiTier tier) {
    final (statusLabel, style, textColor) = switch (tier.state) {
      'claimed' => (
          tr(context, en: 'Claimed', tl: 'Nakuha na'),
          PixelBoxStyle.stone,
          PixelPalette.white,
        ),
      'issued' => (
          tr(context, en: 'Unlocked!', tl: 'Bukás na!'),
          PixelBoxStyle.green,
          PixelPalette.white,
        ),
      _ => () {
          final left = (tier.visitNumber - visits).clamp(0, tier.visitNumber);
          return (
            left == 0
                ? tr(context, en: 'Visit ${tier.visitNumber}', tl: 'Bisita ${tier.visitNumber}')
                : tr(context,
                    en: 'Visit ${tier.visitNumber} ($left left)',
                    tl: 'Bisita ${tier.visitNumber} ($left pa)'),
            PixelBoxStyle.slot,
            PixelPalette.ink,
          );
        }(),
    };

    return Padding(
      key: ValueKey('suki_ladder_tier_${tier.visitNumber}'),
      padding: EdgeInsets.symmetric(vertical: grid.px(1)),
      child: Wrap(
        spacing: grid.px(2),
        runSpacing: grid.px(1),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PixelSprite(SukiTierArt.byKey(tier.iconKey), scale: 2),
          PixelChip(tier.rewardTag, style: PixelBoxStyle.gold),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: Text(tier.rewardText, style: PixelType.body(context)),
          ),
          PixelChip(statusLabel, style: style, textColor: textColor),
        ],
      ),
    );
  }
}
