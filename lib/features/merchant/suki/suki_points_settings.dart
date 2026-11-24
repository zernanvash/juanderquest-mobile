import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../suki/widgets/suki_card_skin.dart';
import '../providers/merchant_hub_provider.dart';
import 'merchant_suki_codes.dart';
import 'merchant_suki_models.dart';

/// Plan 111 §6: Suki Points settings block inside the Merchant Suki Card form.
class SukiPointsSettingsPanel extends StatelessWidget {
  const SukiPointsSettingsPanel({
    super.key,
    required this.globalEnabled,
    required this.pointsEnabled,
    required this.onTogglePoints,
    required this.pointsPerVisitController,
    required this.pesosPerPointController,
    required this.maxPointsPerVisitController,
    required this.onChanged,
  });

  final bool globalEnabled;
  final bool pointsEnabled;
  final ValueChanged<bool> onTogglePoints;
  final TextEditingController pointsPerVisitController;
  final TextEditingController pesosPerPointController;
  final TextEditingController maxPointsPerVisitController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final gap = SizedBox(height: grid.px(2));
    return PixelPanel(
      key: const ValueKey('loyalty_points_settings'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, en: 'Suki Points', tl: 'Suki Points'),
              style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(
            globalEnabled
                ? tr(context,
                    en: 'Optional: award points per visit (and per peso on staff scan) that customers trade for menu rewards.',
                    tl: 'Opsyonal: magbigay ng points bawat bisita na maipapalit sa menu rewards.')
                : tr(context,
                    en: 'Suki Points is currently turned off platform-wide; your preferences will activate once enabled.',
                    tl: 'Naka-off pa ang Suki Points sa buong platform; maise-save ang iyong settings.'),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          gap,
          PixelSegmented(
            key: const ValueKey('loyalty_points_toggle'),
            items: [
              tr(context, en: 'Off', tl: 'Off'),
              tr(context, en: 'On', tl: 'On'),
            ],
            selectedIndex: pointsEnabled ? 1 : 0,
            onChanged: (i) => onTogglePoints(i == 1),
          ),
          if (pointsEnabled) ...[
            gap,
            PixelTextField(
              key: const ValueKey('loyalty_points_per_visit'),
              controller: pointsPerVisitController,
              keyboardType: TextInputType.number,
              label: tr(context,
                  en: 'Points per visit (0–100)',
                  tl: 'Points bawat bisita (0–100)'),
              onChanged: (_) => onChanged(),
            ),
            gap,
            PixelTextField(
              key: const ValueKey('loyalty_pesos_per_point'),
              controller: pesosPerPointController,
              keyboardType: TextInputType.number,
              label: tr(context,
                  en: 'Pesos per bonus point (optional, 1–1000)',
                  tl: 'Piso bawat bonus point (opsyonal, 1–1000)'),
              hint: '20',
              onChanged: (_) => onChanged(),
            ),
            gap,
            PixelTextField(
              key: const ValueKey('loyalty_max_points_per_visit'),
              controller: maxPointsPerVisitController,
              keyboardType: TextInputType.number,
              label: tr(context,
                  en: 'Max spend points per visit (1–2000)',
                  tl: 'Max spend points bawat bisita (1–2000)'),
              onChanged: (_) => onChanged(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Plan 111 §6: Merchant CRUD editor for up to 12 Suki Points menu items.
class SukiPointsMenuEditor extends StatefulWidget {
  const SukiPointsMenuEditor({
    super.key,
    required this.api,
    required this.items,
    required this.onRefresh,
  });

  final MerchantApi api;
  final List<MerchantSukiPointsMenuItem> items;
  final Future<void> Function() onRefresh;

  @override
  State<SukiPointsMenuEditor> createState() => _SukiPointsMenuEditorState();
}

class _SukiPointsMenuEditorState extends State<SukiPointsMenuEditor> {
  bool _busy = false;

  Future<void> _addItem() async {
    final titleCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '50');
    var iconKey = 'gift';
    String? problem;

    final saved = await showPixelDialog<bool>(
      context: context,
      title: tr(context, en: 'Add points reward', tl: 'Magdagdag ng reward'),
      content: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelTextField(
              key: const ValueKey('points_menu_title'),
              controller: titleCtrl,
              label: tr(ctx, en: 'Reward name', tl: 'Pangalan ng reward'),
              hint: 'Free Iced Latte',
            ),
            const SizedBox(height: 8),
            PixelTextField(
              key: const ValueKey('points_menu_cost'),
              controller: costCtrl,
              keyboardType: TextInputType.number,
              label: tr(ctx,
                  en: 'Points cost (10–100000)', tl: 'Points (10–100000)'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final k in merchantSukiIconKeys)
                  PixelChip(
                    k,
                    style: iconKey == k
                        ? PixelBoxStyle.gold
                        : PixelBoxStyle.slot,
                    onTap: () => setState(() => iconKey = k),
                  ),
              ],
            ),
            if (problem != null) ...[
              const SizedBox(height: 6),
              Text(problem!,
                  style: PixelType.small(ctx, color: PixelPalette.redDeep)),
            ],
            const SizedBox(height: 8),
            PixelButton(
              key: const ValueKey('points_menu_save'),
              label: tr(ctx, en: 'Add', tl: 'Idagdag'),
              expand: true,
              onPressed: () {
                final t = titleCtrl.text.trim();
                final c = int.tryParse(costCtrl.text.trim());
                if (t.length < 3 || t.length > 80) {
                  setState(() => problem = tr(ctx,
                      en: 'Name must be 3 to 80 characters.',
                      tl: '3 hanggang 80 titik.'));
                  return;
                }
                if (c == null || c < 10 || c > 100000) {
                  setState(() => problem = tr(ctx,
                      en: 'Points cost must be 10 to 100000.',
                      tl: '10 hanggang 100000 points.'));
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
            ),
            const SizedBox(height: 6),
            PixelButton(
              label: tr(ctx, en: 'Cancel', tl: 'Kanselahin'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
      actions: const [],
    );

    final title = titleCtrl.text.trim();
    final cost = int.tryParse(costCtrl.text.trim()) ?? 50;
    titleCtrl.dispose();
    costCtrl.dispose();
    if (saved != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.api.createSukiPointsMenuItem(
        title: title,
        pointsCost: cost,
        iconKey: iconKey,
        sortOrder: widget.items.length,
      );
      await widget.onRefresh();
    } catch (error) {
      if (mounted) {
        showPixelToast(context, merchantSukiErrorText(context, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteItem(MerchantSukiPointsMenuItem item) async {
    setState(() => _busy = true);
    try {
      await widget.api.deleteSukiPointsMenuItem(item.id);
      await widget.onRefresh();
    } catch (error) {
      if (mounted) {
        showPixelToast(context, merchantSukiErrorText(context, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final activeCount = widget.items.where((i) => i.isActive).length;
    return PixelPanel(
      key: const ValueKey('loyalty_points_menu_editor'),
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
              Text(
                tr(context,
                    en: 'Points menu ($activeCount/12)',
                    tl: 'Points menu ($activeCount/12)'),
                style: PixelType.title(context),
              ),
              if (activeCount < 12)
                PixelButton(
                  key: const ValueKey('loyalty_points_menu_add'),
                  label: tr(context, en: '+ Add item', tl: '+ Dagdag'),
                  variant: PixelButtonVariant.secondary,
                  loading: _busy,
                  onPressed: _addItem,
                ),
            ],
          ),
          SizedBox(height: grid.px(1)),
          if (widget.items.isEmpty)
            Text(
              tr(context,
                  en: 'No points rewards yet. Add items customers can redeem with Suki Points.',
                  tl: 'Wala pang points reward. Magdagdag para maipalit ng customers.'),
              style: PixelType.small(context, color: PixelPalette.slate),
            )
          else
            for (var i = 0; i < widget.items.length; i++) ...[
              if (i > 0)
                Container(height: grid.unit, color: PixelPalette.paperDim),
              Padding(
                padding: EdgeInsets.symmetric(vertical: grid.px(1)),
                child: Wrap(
                  spacing: grid.px(1),
                  runSpacing: grid.px(1),
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: grid.px(1),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PixelSprite(SukiTierArt.byKey(widget.items[i].iconKey),
                            scale: 2),
                        Text(widget.items[i].title,
                            style: PixelType.body(context)),
                        PixelChip('${widget.items[i].pointsCost} pts',
                            style: PixelBoxStyle.gold),
                      ],
                    ),
                    PixelButton(
                      key: ValueKey('loyalty_points_menu_del_${widget.items[i].id}'),
                      label: tr(context, en: 'Delete', tl: 'Burahin'),
                      variant: PixelButtonVariant.ghost,
                      onPressed: _busy ? null : () => _deleteItem(widget.items[i]),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
