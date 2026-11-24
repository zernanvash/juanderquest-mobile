import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/suki_models.dart';
import '../providers/suki_provider.dart';
import '../screens/suki_points_history_screen.dart';
import 'suki_card_skin.dart';

/// Plan 111 §6: Suki Points balance & redeemable points reward menu.
/// Hidden when points are not enabled for this shop.
class SukiPointsMenu extends ConsumerStatefulWidget {
  const SukiPointsMenu({
    super.key,
    required this.program,
    required this.points,
    required this.menu,
    this.cardId,
  });

  final SukiProgram program;
  final SukiPointsState points;
  final List<SukiPointsMenuItem> menu;
  final String? cardId;

  @override
  ConsumerState<SukiPointsMenu> createState() => _SukiPointsMenuState();
}

class _SukiPointsMenuState extends ConsumerState<SukiPointsMenu> {
  String? _busyItemId;

  Future<void> _redeem(SukiPointsMenuItem item) async {
    final confirm = await showPixelDialog<bool>(
      context: context,
      title: tr(context, en: 'Redeem points?', tl: 'Gamitin ang points?'),
      message: tr(context,
          en: 'Spend ${item.pointsCost} Suki Points for "${item.title}"?',
          tl: 'Gamitin ang ${item.pointsCost} Suki Points para sa "${item.title}"?'),
      actions: [
        Builder(
          builder: (ctx) => PixelButton(
            key: const ValueKey('suki_redeem_confirm'),
            label: tr(ctx, en: 'Redeem', tl: 'Kunin'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
        Builder(
          builder: (ctx) => PixelButton(
            label: tr(ctx, en: 'Cancel', tl: 'Kanselahin'),
            variant: PixelButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
      ],
    );
    if (confirm != true || !mounted) return;
    setState(() => _busyItemId = item.id);
    try {
      final result =
          await ref.read(sukiApiProvider).redeemPoints(itemId: item.id);
      ref.invalidate(sukiProgramProvider(widget.program.id));
      ref.invalidate(mySukiCardsProvider);
      if (mounted) {
        showPixelToast(
          context,
          tr(context,
              en: 'Unlocked ${result.reward.rewardText}! Show your code at the counter.',
              tl: 'Nakuha ang ${result.reward.rewardText}! Ipakita ang code sa counter.'),
        );
      }
    } catch (error) {
      if (mounted) {
        showPixelToast(context, sukiErrorText(context, error));
      }
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  void _openHistory() {
    final cardId = widget.cardId ?? '';
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final encodedId = Uri.encodeComponent(widget.program.id);
      final encodedCard = Uri.encodeQueryComponent(cardId);
      final encodedTitle = Uri.encodeQueryComponent(widget.program.merchant.name);
      router.push('/suki/$encodedId/points?cardId=$encodedCard&title=$encodedTitle');
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SukiPointsHistoryScreen(
          programId: widget.program.id,
          cardId: cardId.isEmpty ? null : cardId,
          shopName: widget.program.merchant.name,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.points.enabled) return const SizedBox.shrink();
    final grid = PixelGrid.of(context);
    final activeItems = widget.menu.where((i) => i.isActive).toList();
    return PixelPanel(
      key: const ValueKey('suki_points_menu'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, en: 'Suki Points', tl: 'Suki Points'),
                    style: PixelType.title(context),
                  ),
                  Text(
                    tr(context,
                        en: '${widget.points.balance} pts available · +${widget.program.points.perVisit}/visit',
                        tl: '${widget.points.balance} pts · +${widget.program.points.perVisit}/bisita'),
                    key: const ValueKey('suki_points_balance'),
                    style: PixelType.small(context, color: PixelPalette.greenDark),
                  ),
                ],
              ),
              if (widget.cardId != null && widget.cardId!.isNotEmpty)
                PixelButton(
                  key: const ValueKey('suki_points_history_btn'),
                  label: tr(context, en: 'History', tl: 'Kasaysayan'),
                  variant: PixelButtonVariant.secondary,
                  onPressed: _openHistory,
                ),
            ],
          ),
          if (activeItems.isEmpty) ...[
            SizedBox(height: grid.px(2)),
            Text(
              tr(context,
                  en: 'Collect points each visit. No points rewards listed yet.',
                  tl: 'Mag-ipon ng points bawat bisita. Wala pang reward item sa menu.'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ] else ...[
            SizedBox(height: grid.px(2)),
            for (var i = 0; i < activeItems.length; i++) ...[
              if (i > 0) Container(height: grid.unit, color: PixelPalette.paperDim),
              _itemRow(context, grid, activeItems[i]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _itemRow(
      BuildContext context, PixelGrid grid, SukiPointsMenuItem item) {
    final canAfford = widget.cardId != null &&
        widget.cardId!.isNotEmpty &&
        widget.points.balance >= item.pointsCost;
    final busy = _busyItemId == item.id;
    return Padding(
      key: ValueKey('suki_points_item_${item.id}'),
      padding: EdgeInsets.symmetric(vertical: grid.px(1)),
      child: Wrap(
        spacing: grid.px(2),
        runSpacing: grid.px(1),
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelSprite(SukiTierArt.byKey(item.iconKey), scale: 2),
              Text(item.title, style: PixelType.body(context)),
              PixelChip('${item.pointsCost} pts', style: PixelBoxStyle.gold),
            ],
          ),
          PixelButton(
            key: ValueKey('suki_redeem_${item.id}'),
            label: tr(context, en: 'Redeem', tl: 'Kunin'),
            loading: busy,
            onPressed: (canAfford && _busyItemId == null)
                ? () => _redeem(item)
                : null,
          ),
        ],
      ),
    );
  }
}
