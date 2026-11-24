import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_idle.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../dashboard/pixel/home_pixel_art.dart';
import '../models/suki_models.dart';
import 'suki_card_skin.dart';

/// Plan 111 §6: adaptive stamp field for 3–20 visits with milestone slots.
class SukiStampField extends StatelessWidget {
  const SukiStampField({
    super.key,
    required this.visits,
    required this.required,
    required this.tiers,
    this.skin = SukiCardSkin.jdqClassic,
  });

  final int visits;
  final int required;
  final List<SukiTier> tiers;
  final SukiCardSkin skin;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final total = required < 1 ? 1 : required;
    final filled = visits.clamp(0, total);
    final byVisit = <int, SukiTier>{
      for (final t in tiers) t.visitNumber: t,
    };

    return LayoutBuilder(builder: (context, constraints) {
      final perRow = total <= 5 ? total : 5;
      final gap = grid.px(1);
      final rawSize = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
      final size = rawSize.clamp(22.0, 52.0).floorToDouble();

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < total; i++)
            _buildSlot(context, i, total, filled, byVisit[i + 1], size),
        ],
      );
    });
  }

  Widget _buildSlot(
    BuildContext context,
    int index,
    int total,
    int filled,
    SukiTier? milestone,
    double size,
  ) {
    final visitNum = index + 1;
    final isFilled = index < filled;
    final isMilestone = milestone != null || visitNum == total;

    Color fill = skin.slotEmptyFill;
    Color border = PixelPalette.greenMid;
    if (isFilled) {
      fill = skin.slotFilledFill;
      border = skin.accentColor;
    } else if (isMilestone) {
      fill = skin.milestoneFill.withValues(alpha: 0.22);
      border = skin.milestoneFill;
    }

    Widget content;
    if (isFilled) {
      content = const PixelShimmer(
        restMs: 3200,
        child: FittedBox(child: PixelSprite(HomePixelArt.stampCheck, scale: 2)),
      );
    } else if (isMilestone) {
      final iconArt = SukiTierArt.byKey(milestone?.iconKey ?? 'gift');
      content = FittedBox(
        key: visitNum == total
            ? const ValueKey('suki_reward_slot')
            : ValueKey('suki_milestone_slot_$visitNum'),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelSprite(iconArt, scale: 2),
              Text(
                '$visitNum',
                textScaler: TextScaler.noScaling,
                style: PixelType.small(context, color: PixelPalette.cream),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Center(
        child: Text(
          '$visitNum',
          textScaler: TextScaler.noScaling,
          style: PixelType.small(context, color: PixelPalette.greenLight),
        ),
      );
    }

    return Container(
      key: ValueKey('suki_slot_$index'),
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 2),
      ),
      child: Center(child: content),
    );
  }
}
