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
import '../../auth/providers/auth_provider.dart';
import '../models/merchant_models.dart';
import '../providers/merchant_hub_provider.dart';

const _maxActiveStaff = 5;

String _staffErrorText(Object error, String fallback) {
  if (error is DioException) {
    final body = error.response?.data;
    final msg = body is Map && body['error'] is Map
        ? body['error']['message']?.toString()
        : null;
    if (msg != null && msg.isNotEmpty) return msg;
  }
  return fallback;
}

/// Plan 110b: Cashier / staff management (`GET/POST/DELETE /merchant/staff`).
class MerchantStaffScreen extends ConsumerStatefulWidget {
  const MerchantStaffScreen({super.key});

  @override
  ConsumerState<MerchantStaffScreen> createState() =>
      _MerchantStaffScreenState();
}

class _MerchantStaffScreenState extends ConsumerState<MerchantStaffScreen> {
  final _emailCtrl = TextEditingController();
  MerchantStaffList? _data;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(merchantApiProvider).staff();
      if (mounted) setState(() => (_data = list, _error = null));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isOwner(MerchantStaffList list) {
    final me = ref.watch(authProvider).user?.id;
    if (me != null) {
      return list.items.any((m) => m.isOwner && m.isActive && m.userId == me);
    }
    return list.items.any((m) =>
        m.isOwner && m.isActive && !(m.email?.contains('***') ?? false));
  }

  Future<void> _add() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      showPixelToast(
          context,
          tr(context,
              en: 'Enter a valid email address.',
              tl: 'Maglagay ng tamang email.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(merchantApiProvider).addStaff(email);
      _emailCtrl.clear();
      if (!mounted) return;
      showPixelToast(
          context, tr(context, en: 'Cashier added.', tl: 'Naidagdag na.'));
      await _load();
    } catch (error) {
      if (mounted) {
        showPixelToast(
            context, _staffErrorText(error, 'Could not add cashier.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(MerchantStaffMember member) async {
    final ok = await showPixelDialog<bool>(
      context: context,
      title: tr(context, en: 'Revoke cashier?', tl: 'Tanggalin ang staff?'),
      message: tr(context,
          en: '${member.displayName} will lose counter scanner access.',
          tl: 'Mawawalan ng access sa counter scanner.'),
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
            key: const ValueKey('merchant_staff_revoke_confirm'),
            label: tr(ctx, en: 'Revoke', tl: 'Tanggalin'),
            variant: PixelButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(merchantApiProvider).revokeStaff(member.userId);
      if (!mounted) return;
      showPixelToast(
          context, tr(context, en: 'Access revoked.', tl: 'Natanggal na.'));
      await _load();
    } catch (error) {
      if (mounted) {
        showPixelToast(
            context, _staffErrorText(error, 'Could not revoke access.'));
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
        final owner = data != null && _isOwner(data);
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context, en: 'Shop staff', tl: 'Mga staff'),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: _loading && data == null
                      ? const Center(child: PixelLoader(label: 'Loading staff'))
                      : data == null
                          ? Center(
                              child: PixelEmptyState(
                                icon: DesignerArt.navProfile,
                                title: tr(context,
                                    en: 'Staff unavailable',
                                    tl: 'Hindi makuha'),
                                message: _staffErrorText(
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
                                              en: 'Counter cashiers',
                                              tl: 'Mga kahera'),
                                          icon: DesignerArt.navProfile,
                                          colors: PixelText3DColors.cream,
                                          value:
                                              '${data.activeStaffCount}/$_maxActiveStaff',
                                          valueColor: PixelPalette.gold,
                                        ),
                                        SizedBox(height: grid.px(1)),
                                        Text(
                                          tr(context,
                                              en: 'Cashiers can confirm vouchers and Suki scans at your counter.',
                                              tl: 'Puwedeng mag-scan ang mga staff sa counter.'),
                                          style: PixelType.small(context,
                                              color: PixelPalette.cream),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  if (owner) ...[
                                    PixelPanel(
                                      style: PixelBoxStyle.parchment,
                                      padding: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          PixelTextField(
                                            key: const ValueKey(
                                                'merchant_staff_email'),
                                            controller: _emailCtrl,
                                            label: tr(context,
                                                en: 'Cashier verified email',
                                                tl: 'Email ng cashier'),
                                            hint: 'staff@example.com',
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),
                                          SizedBox(height: grid.px(2)),
                                          PixelButton(
                                            key: const ValueKey(
                                                'merchant_staff_add'),
                                            label: tr(context,
                                                en: 'Add cashier',
                                                tl: 'Idagdag'),
                                            loading: _busy,
                                            expand: true,
                                            onPressed: _busy ||
                                                    data.activeStaffCount >=
                                                        _maxActiveStaff
                                                ? null
                                                : _add,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: grid.px(3)),
                                  ],
                                  for (final m in data.items) ...[
                                    PixelPanel(
                                      key: ValueKey(
                                          'merchant_staff_${m.userId}'),
                                      style: PixelBoxStyle.parchment,
                                      padding: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: grid.px(1),
                                            runSpacing: grid.px(1),
                                            children: [
                                              PixelChip(
                                                m.isOwner ? 'OWNER' : 'STAFF',
                                                style: m.isOwner
                                                    ? PixelBoxStyle.gold
                                                    : PixelBoxStyle.slot,
                                              ),
                                              PixelChip(
                                                m.isActive
                                                    ? 'ACTIVE'
                                                    : 'REVOKED',
                                                style: m.isActive
                                                    ? PixelBoxStyle.green
                                                    : PixelBoxStyle.stone,
                                                textColor: PixelPalette.white,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: grid.px(1)),
                                          Text(m.displayName,
                                              style: PixelType.title(context)),
                                          if (m.email != null)
                                            Text(
                                              m.email!,
                                              style: PixelType.small(context,
                                                  color: PixelPalette.slate),
                                            ),
                                          if (owner &&
                                              !m.isOwner &&
                                              m.isActive) ...[
                                            SizedBox(height: grid.px(2)),
                                            PixelButton(
                                              key: ValueKey(
                                                  'merchant_staff_revoke_${m.userId}'),
                                              label: tr(context,
                                                  en: 'Revoke',
                                                  tl: 'Tanggalin'),
                                              variant:
                                                  PixelButtonVariant.danger,
                                              onPressed: _busy
                                                  ? null
                                                  : () => _revoke(m),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
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
}
