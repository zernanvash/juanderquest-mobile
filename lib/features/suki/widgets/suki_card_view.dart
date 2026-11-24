import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../merchant/suki/suki_badge_art.dart';
import '../models/suki_models.dart';
import 'suki_card_skin.dart';
import 'suki_stamp_field.dart';

/// Plan 111 §6: physical loyalty card (1.586:1 proportion) with 3D Y-axis flip.
class SukiCardView extends StatefulWidget {
  const SukiCardView({
    super.key,
    required this.program,
    this.card,
    this.tiers = const [],
    this.points = const SukiPointsState(),
    this.holder,
    this.onShowPass,
    this.onShopTap,
  });

  final SukiProgram program;
  final SukiCardProgress? card;
  final List<SukiTier> tiers;
  final SukiPointsState points;
  final SukiHolder? holder;
  final VoidCallback? onShowPass;
  final VoidCallback? onShopTap;

  @override
  State<SukiCardView> createState() => _SukiCardViewState();
}

class _SukiCardViewState extends State<SukiCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() => _showBack = !_showBack);
    if (_showBack) {
      _flip.forward();
    } else {
      _flip.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final skin = SukiCardSkin.byKey(widget.program.skinKey);
    final tiers =
        widget.tiers.isNotEmpty ? widget.tiers : widget.program.effectiveTiers;
    final visits = widget.card?.visits ?? 0;
    final required = widget.card?.required ?? widget.program.visitsRequired;

    return LayoutBuilder(builder: (context, constraints) {
      final minHeight = (constraints.maxWidth / 1.586).clamp(168.0, 260.0);
      return GestureDetector(
        key: const ValueKey('suki_card_flip_surface'),
        onTap: _toggleFlip,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = _flip.value * math.pi;
            final isBack = angle > math.pi / 2;
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle);
            final child = isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _backFace(context, grid, skin, tiers, minHeight),
                  )
                : _frontFace(
                    context, grid, skin, tiers, visits, required, minHeight);
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: child,
            );
          },
        ),
      );
    });
  }

  Widget _frontFace(
    BuildContext context,
    PixelGrid grid,
    SukiCardSkin skin,
    List<SukiTier> tiers,
    int visits,
    int required,
    double minHeight,
  ) {
    final p = widget.program;
    final remaining = (required - visits).clamp(0, required);
    final nextTier = tiers.cast<SukiTier?>().firstWhere(
          (t) => t!.visitNumber > visits,
          orElse: () => tiers.isNotEmpty ? tiers.last : null,
        );
    final targetText = nextTier?.rewardText ?? p.rewardText;
    final targetRemaining =
        nextTier != null ? (nextTier.visitNumber - visits).clamp(0, required) : remaining;
    final cardNo = widget.card?.cardNo ?? '';

    return Container(
      key: const ValueKey('suki_card_front'),
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skin.frontTop, skin.frontBottom],
        ),
        border: Border.all(color: skin.borderColor, width: 2),
      ),
      padding: EdgeInsets.all(grid.px(2)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PixelSprite(SukiBadgeArt.sukiCard, scale: 2),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      key: const ValueKey('suki_card_shop_page'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onShopTap,
                      child: Text(
                        widget.onShopTap != null
                            ? '${p.merchant.name} >'
                            : p.merchant.name,
                        style: PixelType.title(context, color: skin.headerTextColor),
                      ),
                    ),
                    Text(
                      [
                        if (p.merchant.municipality != null)
                          p.merchant.municipality!,
                        p.title,
                      ].join(' · '),
                      style: PixelType.small(context, color: skin.mutedTextColor),
                    ),
                  ],
                ),
              ),
              PixelChip(
                tr(context, en: 'Flip', tl: 'Baliktad'),
                key: const ValueKey('suki_card_flip'),
                style: PixelBoxStyle.gold,
                onTap: _toggleFlip,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          SukiStampField(
            visits: visits,
            required: required,
            tiers: tiers,
            skin: skin,
          ),
          SizedBox(height: grid.px(2)),
          Text(
            targetRemaining == 0
                ? tr(context,
                    en: 'Reward ready: $targetText',
                    tl: 'Handa na: $targetText')
                : tr(context,
                    en: '$targetRemaining more ${targetRemaining == 1 ? 'visit' : 'visits'} for: $targetText',
                    tl: '$targetRemaining pang bisita para sa: $targetText'),
            key: const ValueKey('suki_countdown'),
            style: PixelType.body(context, color: skin.bodyTextColor),
          ),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (cardNo.isNotEmpty)
                Text(
                  cardNo,
                  key: const ValueKey('suki_card_number'),
                  style: PixelType.small(context, color: skin.accentColor),
                ),
              if (widget.points.enabled)
                PixelChip(
                  tr(context,
                      en: '${widget.points.balance} pts',
                      tl: '${widget.points.balance} pts'),
                  key: const ValueKey('suki_card_points_chip'),
                  style: PixelBoxStyle.gold,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _backFace(
    BuildContext context,
    PixelGrid grid,
    SukiCardSkin skin,
    List<SukiTier> tiers,
    double minHeight,
  ) {
    final cardNo = widget.card?.cardNo ?? '';
    final holderName = widget.holder?.displayName ??
        tr(context, en: 'Suki Explorer', tl: 'Suki Explorer');
    return Container(
      key: const ValueKey('suki_card_back'),
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skin.backTop, skin.backBottom],
        ),
        border: Border.all(color: skin.borderColor, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PixelPalette.ink,
            padding: EdgeInsets.symmetric(
              horizontal: grid.px(2),
              vertical: grid.px(1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cardNo.isNotEmpty ? cardNo : 'JUANDERQUEST SUKI',
                    style: PixelType.small(context, color: skin.accentColor),
                  ),
                ),
                PixelChip(
                  tr(context, en: 'Front', tl: 'Harap'),
                  key: const ValueKey('suki_card_flip_front'),
                  style: PixelBoxStyle.gold,
                  onTap: _toggleFlip,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(grid.px(2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holderName,
                  style: PixelType.body(context, color: skin.headerTextColor),
                ),
                SizedBox(height: grid.px(1)),
                for (final t in tiers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Visit ${t.visitNumber}: ${t.rewardTag} · ${t.rewardText}',
                      style: PixelType.small(context, color: skin.bodyTextColor),
                    ),
                  ),
                if (widget.onShowPass != null) ...[
                  SizedBox(height: grid.px(2)),
                  PixelButton(
                    key: const ValueKey('suki_card_back_pass'),
                    label: tr(context,
                        en: 'Show counter pass', tl: 'Ipakita ang pass'),
                    variant: PixelButtonVariant.secondary,
                    onPressed: widget.onShowPass,
                  ),
                ],
                SizedBox(height: grid.px(1)),
                Text(
                  tr(context,
                      en: 'One visit per Manila day at the shop counter.',
                      tl: 'Isang bisita bawat araw sa counter ng tindahan.'),
                  style: PixelType.small(context, color: skin.mutedTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
