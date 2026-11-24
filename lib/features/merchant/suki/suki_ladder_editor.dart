import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../suki/widgets/suki_card_skin.dart';
import 'merchant_suki_models.dart';

const _kindLabels = ['FREE ITEM', '% OFF', '₱ OFF', 'PROMO'];
const _examples = [
  'Free iced coffee',
  'Free halo-halo',
  '10% off your order',
  'Buy 1 Take 1 halo-halo',
];

/// Mutable form state for a single milestone tier row (1–4 per card).
class SukiTierDraft {
  SukiTierDraft({
    required this.visitNumber,
    this.kindIndex = 0,
    String rewardValue = '',
    String rewardText = '',
    this.iconKey = 'gift',
  })  : rewardValueController = TextEditingController(text: rewardValue),
        rewardTextController = TextEditingController(text: rewardText);

  int visitNumber;
  int kindIndex; // 0..3 matching sukiRewardKinds
  String iconKey;
  final TextEditingController rewardValueController;
  final TextEditingController rewardTextController;

  bool get valued => kindIndex == 1 || kindIndex == 2;
  String get rewardKind => sukiRewardKinds[kindIndex.clamp(0, 3)];
  int? get parsedValue => int.tryParse(rewardValueController.text.trim());

  String get rewardTag =>
      sukiRewardTag(rewardKind, valued ? parsedValue : null);

  MerchantSukiTier toPreviewTier() => MerchantSukiTier(
        visitNumber: visitNumber,
        rewardKind: rewardKind,
        rewardValue: valued ? parsedValue?.toDouble() : null,
        rewardText: rewardTextController.text.trim().isEmpty
            ? '…'
            : rewardTextController.text.trim(),
        rewardTag: rewardTag,
        iconKey: iconKey,
      );

  Map<String, dynamic> toPayload() => {
        'visit_number': visitNumber,
        'reward_kind': rewardKind,
        'reward_value': valued ? parsedValue : null,
        'reward_text': rewardTextController.text.trim(),
        'icon_key': iconKey,
      };

  void dispose() {
    rewardValueController.dispose();
    rewardTextController.dispose();
  }
}

/// Plan 111 §6: 1–4 milestone reward ladder editor for the Merchant Loyalty tab.
class SukiLadderEditor extends StatelessWidget {
  const SukiLadderEditor({
    super.key,
    required this.tiers,
    required this.onChanged,
    required this.onAddTier,
    required this.onRemoveTier,
  });

  final List<SukiTierDraft> tiers;
  final VoidCallback onChanged;
  final VoidCallback onAddTier;
  final ValueChanged<int> onRemoveTier;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final single = tiers.length == 1;
    return Column(
      key: const ValueKey('suki_ladder_editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiers.length; i++) ...[
          if (i > 0) SizedBox(height: grid.px(2)),
          _tierCard(context, grid, i, tiers[i], single),
        ],
        if (tiers.length < 4) ...[
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('loyalty_add_tier'),
            label: tr(context,
                en: '+ Tier (${tiers.length}/4)',
                tl: '+ Tier (${tiers.length}/4)'),
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: onAddTier,
          ),
        ],
      ],
    );
  }

  Widget _tierCard(
    BuildContext context,
    PixelGrid grid,
    int index,
    SukiTierDraft tier,
    bool single,
  ) {
    final isPrimary = single || index == tiers.length - 1;
    final gap = SizedBox(height: grid.px(2));
    final minVisit = index == 0 ? (single ? 3 : 1) : tiers[index - 1].visitNumber + 1;
    final maxVisit = index == tiers.length - 1
        ? 20
        : (tiers[index + 1].visitNumber - 1).clamp(minVisit, 20);

    final body = Column(
      key: single ? ValueKey('loyalty_tier_$index') : null,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          if (!single) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    isPrimary
                        ? tr(context,
                            en: 'Final reward (Tier ${index + 1})',
                            tl: 'Huling reward (Tier ${index + 1})')
                        : tr(context,
                            en: 'Milestone ${index + 1}',
                            tl: 'Milestone ${index + 1}'),
                    style: PixelType.title(context),
                  ),
                ),
                PixelButton(
                  key: ValueKey('loyalty_remove_tier_$index'),
                  label: tr(context, en: 'Remove', tl: 'Alisin'),
                  variant: PixelButtonVariant.ghost,
                  onPressed: () => onRemoveTier(index),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
          ],
          Text(tr(context, en: 'Reward type', tl: 'Uri ng reward'),
              style: PixelType.small(context)),
          SizedBox(height: grid.px(1)),
          PixelSegmented(
            key: isPrimary
                ? const ValueKey('loyalty_kind')
                : ValueKey('loyalty_tier_${index}_kind'),
            items: _kindLabels,
            selectedIndex: tier.kindIndex,
            onChanged: (i) {
              tier.kindIndex = i;
              onChanged();
            },
          ),
          if (tier.valued) ...[
            gap,
            PixelTextField(
              key: isPrimary
                  ? const ValueKey('loyalty_value')
                  : ValueKey('loyalty_tier_${index}_value'),
              controller: tier.rewardValueController,
              keyboardType: TextInputType.number,
              label: tier.kindIndex == 1
                  ? tr(context,
                      en: 'Percent off (5 to 50)',
                      tl: 'Porsyento (5 hanggang 50)')
                  : tr(context,
                      en: 'Pesos off (10 to 500)',
                      tl: 'Piso (10 hanggang 500)'),
              onChanged: (_) => onChanged(),
            ),
          ],
          gap,
          PixelTextField(
            key: isPrimary
                ? const ValueKey('loyalty_reward_text')
                : ValueKey('loyalty_tier_${index}_text'),
            controller: tier.rewardTextController,
            label: tr(context, en: 'Reward line', tl: 'Reward'),
            hint: 'Free iced coffee',
            onChanged: (_) => onChanged(),
          ),
          if (isPrimary) ...[
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final example in _examples)
                  PixelChip(
                    example,
                    style: PixelBoxStyle.slot,
                    onTap: () {
                      tier.rewardTextController.text = example;
                      onChanged();
                    },
                  ),
              ],
            ),
          ],
          gap,
          Text(
            isPrimary
                ? tr(context, en: 'Visits needed', tl: 'Bilang ng bisita')
                : tr(context, en: 'Unlocks at visit', tl: 'Bubukas sa bisita'),
            style: PixelType.small(context),
          ),
          SizedBox(height: grid.px(1)),
          Row(
            children: [
              PixelButton(
                key: isPrimary
                    ? const ValueKey('loyalty_visits_minus')
                    : ValueKey('loyalty_tier_${index}_minus'),
                label: '-',
                variant: PixelButtonVariant.secondary,
                onPressed: tier.visitNumber > minVisit
                    ? () {
                        tier.visitNumber--;
                        onChanged();
                      }
                    : null,
              ),
              Expanded(
                child: Text(
                  '${tier.visitNumber}',
                  key: isPrimary
                      ? const ValueKey('loyalty_visits')
                      : ValueKey('loyalty_tier_${index}_visits'),
                  textAlign: TextAlign.center,
                  style: PixelType.numbers(context),
                ),
              ),
              PixelButton(
                key: isPrimary
                    ? const ValueKey('loyalty_visits_plus')
                    : ValueKey('loyalty_tier_${index}_plus'),
                label: '+',
                variant: PixelButtonVariant.secondary,
                onPressed: tier.visitNumber < maxVisit
                    ? () {
                        tier.visitNumber++;
                        onChanged();
                      }
                    : null,
              ),
            ],
          ),
          gap,
          Text(tr(context, en: 'Icon', tl: 'Icon'),
              style: PixelType.small(context)),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              for (final key in merchantSukiIconKeys)
                GestureDetector(
                  key: ValueKey('loyalty_tier_${index}_icon_$key'),
                  onTap: () {
                    tier.iconKey = key;
                    onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: tier.iconKey == key
                          ? PixelPalette.sunLight
                          : PixelPalette.paper,
                      border: Border.all(
                        color: tier.iconKey == key
                            ? PixelPalette.gold
                            : PixelPalette.mist,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: FittedBox(
                            child: PixelSprite(SukiTierArt.byKey(key), scale: 2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(key, style: PixelType.small(context)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
    );
    if (single) return body;
    return PixelPanel(
      key: ValueKey('loyalty_tier_$index'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: body,
    );
  }
}
