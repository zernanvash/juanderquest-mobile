import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/theme/app_theme.dart';
import '../models/merchant_models.dart';
import '../providers/merchant_hub_provider.dart';

const _maxActiveVouchers = 20;

String _voucherErrorText(Object error, String fallback) {
  if (error is DioException) {
    final body = error.response?.data;
    final msg = body is Map && body['error'] is Map
        ? body['error']['message']?.toString()
        : null;
    if (msg != null && msg.isNotEmpty) return msg;
  }
  return fallback;
}

/// Plan 110b: Merchant self-service voucher catalog CRUD (`GET/POST/PATCH/DELETE /merchant/vouchers*`).
class MerchantVouchersScreen extends ConsumerStatefulWidget {
  const MerchantVouchersScreen({super.key});

  @override
  ConsumerState<MerchantVouchersScreen> createState() =>
      _MerchantVouchersScreenState();
}

class _MerchantVouchersScreenState
    extends ConsumerState<MerchantVouchersScreen> {
  MerchantManagedVoucherList? _data;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(merchantApiProvider).manageVouchers();
      if (mounted) setState(() => (_data = list, _error = null));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([MerchantManagedVoucher? existing]) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final costCtrl =
        TextEditingController(text: existing?.costPoints.toString() ?? '50');
    final stockCtrl =
        TextEditingController(text: existing?.stockLimit?.toString() ?? '');
    final validCtrl =
        TextEditingController(text: existing?.validDays?.toString() ?? '');
    var iconKey = merchantVoucherIconKeys.contains(existing?.iconKey)
        ? existing!.iconKey!
        : 'gift';
    var isActive = existing?.isActive ?? true;

    final saved = await showPixelDialog<bool>(
      context: context,
      title: existing == null
          ? tr(context, en: 'New voucher', tl: 'Bagong voucher')
          : tr(context, en: 'Edit voucher', tl: 'I-edit ang voucher'),
      content: StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PixelTextField(
                key: const ValueKey('voucher_form_title'),
                controller: titleCtrl,
                label: tr(ctx, en: 'Title', tl: 'Pamagat'),
                hint: 'Free Iced Latte',
              ),
              const SizedBox(height: 8),
              PixelTextField(
                key: const ValueKey('voucher_form_description'),
                controller: descCtrl,
                label: tr(ctx, en: 'Description', tl: 'Detalye'),
                hint: 'Present at counter during cafe hours.',
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              PixelTextField(
                key: const ValueKey('voucher_form_cost'),
                controller: costCtrl,
                label: tr(ctx, en: 'Cost (mJDQ)', tl: 'Halaga (mJDQ)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              PixelTextField(
                key: const ValueKey('voucher_form_stock'),
                controller: stockCtrl,
                label: tr(ctx,
                    en: 'Stock cap (blank = unlimited)',
                    tl: 'Dami (blangko = walang limit)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              PixelTextField(
                key: const ValueKey('voucher_form_valid_days'),
                controller: validCtrl,
                label: tr(ctx,
                    en: 'Valid days (1-365, blank = none)',
                    tl: 'Bisa sa araw (1-365)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Text(tr(ctx, en: 'Icon', tl: 'Icon'),
                  style: PixelType.small(ctx, color: PixelPalette.slate)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final keyName in merchantVoucherIconKeys)
                    GestureDetector(
                      key: ValueKey('voucher_form_icon_$keyName'),
                      onTap: () => setModalState(() => iconKey = keyName),
                      child: PixelChip(
                        keyName,
                        style: iconKey == keyName
                            ? PixelBoxStyle.gold
                            : PixelBoxStyle.slot,
                      ),
                    ),
                ],
              ),
              if (existing != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  key: const ValueKey('voucher_form_active_toggle'),
                  onTap: () => setModalState(() => isActive = !isActive),
                  child: PixelPanel(
                    style:
                        isActive ? PixelBoxStyle.parchment : PixelBoxStyle.slot,
                    padding: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr(ctx,
                                  en: 'Offer status',
                                  tl: 'Estado ng voucher'),
                              style: PixelType.small(ctx),
                            ),
                          ),
                          PixelChip(
                            isActive ? 'ACTIVE' : 'ARCHIVED',
                            style: isActive
                                ? PixelBoxStyle.green
                                : PixelBoxStyle.stone,
                            textColor: PixelPalette.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Builder(
          builder: (ctx) => PixelButton(
            label: tr(ctx, en: 'Cancel', tl: 'Kanselahin'),
            variant: PixelButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => PixelButton(
            key: const ValueKey('voucher_form_save'),
            label: tr(ctx, en: 'Save', tl: 'I-save'),
            onPressed: () {
              final t = titleCtrl.text.trim();
              final d = descCtrl.text.trim();
              final c = int.tryParse(costCtrl.text.trim());
              final sText = stockCtrl.text.trim();
              final vText = validCtrl.text.trim();
              final s = sText.isEmpty ? null : int.tryParse(sText);
              final v = vText.isEmpty ? null : int.tryParse(vText);
              if (t.length < 3 || d.length < 3) {
                showPixelToast(
                    ctx,
                    tr(ctx,
                        en: 'Title and description need 3+ characters.',
                        tl: 'Kailangan ng 3+ letra sa pamagat at detalye.'));
                return;
              }
              if (c == null || c < 1 || c > 100000) {
                showPixelToast(
                    ctx,
                    tr(ctx,
                        en: 'Cost must be between 1 and 100,000 mJDQ.',
                        tl: 'Dapat 1 hanggang 100,000 mJDQ.'));
                return;
              }
              if (sText.isNotEmpty && (s == null || s < 1 || s > 100000)) {
                showPixelToast(
                    ctx,
                    tr(ctx,
                        en: 'Stock limit must be 1 to 100,000 or blank.',
                        tl: 'Ang stock limit ay 1 hanggang 100,000 lang.'));
                return;
              }
              if (vText.isNotEmpty && (v == null || v < 1 || v > 365)) {
                showPixelToast(
                    ctx,
                    tr(ctx,
                        en: 'Valid days must be 1 to 365 or blank.',
                        tl: 'Ang valid days ay 1 hanggang 365 lang.'));
                return;
              }
              Navigator.of(ctx).pop(true);
            },
          ),
        ),
      ],
    );

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final cost = int.tryParse(costCtrl.text.trim()) ?? 50;
    final stock = stockCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(stockCtrl.text.trim());
    final validDays = validCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(validCtrl.text.trim());

    titleCtrl.dispose();
    descCtrl.dispose();
    costCtrl.dispose();
    stockCtrl.dispose();
    validCtrl.dispose();

    if (saved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(merchantApiProvider);
      if (existing == null) {
        await api.createVoucher(
          title: title,
          description: desc,
          costPoints: cost,
          stockLimit: stock,
          validDays: validDays,
          iconKey: iconKey,
        );
      } else {
        await api.updateVoucher(existing.id, {
          'title': title,
          'description': desc,
          'cost_points': cost,
          'stock_limit': stock,
          'valid_days': validDays,
          'icon_key': iconKey,
          'is_active': isActive,
        });
      }
      if (!mounted) return;
      showPixelToast(
          context, tr(context, en: 'Voucher saved.', tl: 'Na-save na.'));
      await _load();
    } catch (error) {
      if (mounted) {
        showPixelToast(
            context, _voucherErrorText(error, 'Could not save voucher.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive(MerchantManagedVoucher voucher) async {
    final ok = await showPixelDialog<bool>(
      context: context,
      title: tr(context, en: 'Archive voucher?', tl: 'I-archive ang voucher?'),
      message: tr(context,
          en: 'Travelers will no longer see "${voucher.title}" in Shop.',
          tl: 'Hindi na ito makikita ng mga biyahero sa Shop.'),
      actions: [
        Builder(
          builder: (ctx) => PixelButton(
            label: tr(ctx, en: 'Keep', tl: 'Panatilihin'),
            variant: PixelButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => PixelButton(
            key: const ValueKey('voucher_archive_confirm'),
            label: tr(ctx, en: 'Archive', tl: 'I-archive'),
            variant: PixelButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(merchantApiProvider).archiveVoucher(voucher.id);
      if (!mounted) return;
      showPixelToast(
          context, tr(context, en: 'Voucher archived.', tl: 'Na-archive na.'));
      await _load();
    } catch (error) {
      if (mounted) {
        showPixelToast(
            context, _voucherErrorText(error, 'Could not archive voucher.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        final data = _data;
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context, en: 'Shop vouchers', tl: 'Mga voucher'),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: _loading && data == null
                      ? const Center(
                          child: PixelLoader(label: 'Loading vouchers'))
                      : data == null
                          ? Center(
                              child: PixelEmptyState(
                                icon: DesignerArt.handshake,
                                title: tr(context,
                                    en: 'Vouchers unavailable',
                                    tl: 'Hindi makuha'),
                                message: _voucherErrorText(
                                    _error ?? '', 'Please try again.'),
                                action: PixelButton(
                                  label: tr(context,
                                      en: 'Retry', tl: 'Subukang muli'),
                                  onPressed: _load,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: PixelPalette.green,
                              backgroundColor: PixelPalette.parchment,
                              onRefresh: _load,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                    grid.gutter,
                                    grid.px(3),
                                    grid.gutter,
                                    grid.px(8) +
                                        MediaQuery.paddingOf(context).bottom),
                                children: [
                                  PixelPanel(
                                    style: PixelBoxStyle.wood,
                                    padding: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        PixelSectionTitle(
                                          tr(context,
                                              en: 'Voucher catalog',
                                              tl: 'Katalogo ng voucher'),
                                          icon: DesignerArt.handshake,
                                          colors: PixelText3DColors.cream,
                                          value:
                                              '${data.activeCount}/$_maxActiveVouchers',
                                          valueColor: PixelPalette.gold,
                                        ),
                                        SizedBox(height: grid.px(1)),
                                        Text(
                                          tr(context,
                                              en: 'Manage rewards travelers can redeem with mJDQ.',
                                              tl: 'Pamahalaan ang mga voucher sa Shop.'),
                                          style: PixelType.small(context,
                                              color: PixelPalette.cream),
                                        ),
                                        if (data.isOwner) ...[
                                          SizedBox(height: grid.px(2)),
                                          PixelButton(
                                            key: const ValueKey(
                                                'merchant_voucher_add'),
                                            label: tr(context,
                                                en: '+ New voucher',
                                                tl: '+ Bagong voucher'),
                                            expand: true,
                                            onPressed: _busy ||
                                                    data.activeCount >=
                                                        _maxActiveVouchers
                                                ? null
                                                : () => _openEditor(),
                                          ),
                                        ] else ...[
                                          SizedBox(height: grid.px(2)),
                                          PixelChip(
                                            tr(context,
                                                en: 'Read-only · owner edits offers',
                                                tl: 'May-ari lang ang nag-eedit'),
                                            key: const ValueKey(
                                                'merchant_vouchers_staff_notice'),
                                            style: PixelBoxStyle.slot,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  if (data.items.isEmpty)
                                    PixelEmptyState(
                                      key: const ValueKey(
                                          'merchant_vouchers_empty'),
                                      icon: DesignerArt.handshake,
                                      title: tr(context,
                                          en: 'No vouchers yet',
                                          tl: 'Wala pang voucher'),
                                      message: tr(context,
                                          en: 'Create your first offer to attract travelers.',
                                          tl: 'Gumawa ng unang voucher para sa mga biyahero.'),
                                    )
                                  else
                                    for (final v in data.items) ...[
                                      _voucherCard(context, grid, v, data.isOwner),
                                      SizedBox(height: grid.px(2)),
                                    ],
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

  Widget _voucherCard(
    BuildContext context,
    PixelGrid grid,
    MerchantManagedVoucher v,
    bool isOwner,
  ) {
    final stockText = v.stockLimit != null
        ? '${v.redeemedCount}/${v.stockLimit} claimed'
        : '${v.redeemedCount} claimed';
    return PixelPanel(
      key: ValueKey('merchant_managed_voucher_${v.id}'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              PixelChip(
                v.isActive ? 'ACTIVE' : 'ARCHIVED',
                style: v.isActive ? PixelBoxStyle.green : PixelBoxStyle.stone,
                textColor: PixelPalette.white,
              ),
              PixelChip(
                v.availability == 'live' ? 'LIVE' : 'PREVIEW',
                style: v.availability == 'live'
                    ? PixelBoxStyle.gold
                    : PixelBoxStyle.slot,
              ),
              PixelChip('${v.costPoints} mJDQ', style: PixelBoxStyle.slot),
              PixelChip(stockText, style: PixelBoxStyle.slot),
              PixelChip('${v.usedCount} used', style: PixelBoxStyle.slot),
              if (v.validDays != null)
                PixelChip('Valid ${v.validDays}d', style: PixelBoxStyle.slot),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(v.title, style: PixelType.title(context)),
          if (v.description.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(v.description,
                style: PixelType.body(context, color: PixelPalette.slate)),
          ],
          if (isOwner) ...[
            SizedBox(height: grid.px(2)),
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              children: [
                PixelButton(
                  key: ValueKey('merchant_voucher_edit_${v.id}'),
                  label: tr(context, en: 'Edit', tl: 'I-edit'),
                  variant: PixelButtonVariant.secondary,
                  onPressed: _busy ? null : () => _openEditor(v),
                ),
                if (v.isActive)
                  PixelButton(
                    key: ValueKey('merchant_voucher_archive_${v.id}'),
                    label: tr(context, en: 'Archive', tl: 'I-archive'),
                    variant: PixelButtonVariant.danger,
                    onPressed: _busy ? null : () => _archive(v),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
