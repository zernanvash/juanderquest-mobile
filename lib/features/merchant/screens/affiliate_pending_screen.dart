import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/merchant_models.dart';
import '../providers/merchant_hub_provider.dart';

/// Plan 95 stage 2: read-only review status for a submitted application.
class AffiliatePendingScreen extends ConsumerWidget {
  const AffiliatePendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(merchantHubStatusProvider);
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Application',
                    onBack: Navigator.of(context).canPop()
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    actions: [
                      PixelButton(
                        key: const ValueKey('affiliate_pending_refresh'),
                        label: 'Refresh',
                        variant: PixelButtonVariant.ghost,
                        onPressed: () =>
                            ref.invalidate(merchantHubStatusProvider),
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(merchantHubStatusProvider.future),
                      child: status.when(
                        loading: () => const Center(
                          child: PixelLoader(label: 'Loading status'),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (hub) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            grid.gutter,
                            grid.px(4),
                            grid.gutter,
                            grid.px(8) + MediaQuery.paddingOf(context).bottom,
                          ),
                          children: _body(context, ref, grid, hub),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    PixelGrid grid,
    MerchantHubStatus hub,
  ) {
    final app = hub.application ?? const <String, dynamic>{};
    final gap = SizedBox(height: grid.px(3));
    if (hub.state == MerchantHubState.none) {
      return [
        PixelEmptyState(
          icon: DesignerArt.salakot,
          title: 'No application yet',
          message: 'Apply to partner with local tourism.',
          action: PixelButton(
            label: 'Start application',
            onPressed: () => context.pushReplacement('/affiliate'),
          ),
        ),
      ];
    }
    return [
      _header(context, grid, hub, app),
      gap,
      if (hub.state == MerchantHubState.approvedMerchant)
        _approved(context, grid)
      else ...[
        Text(
          'APPLICATION PROGRESS',
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(1)),
        _timeline(context, grid, app),
        if (hub.state == MerchantHubState.needsChanges ||
            hub.state == MerchantHubState.rejected) ...[
          gap,
          _feedback(context, ref, grid, hub, app),
        ],
      ],
      gap,
      Text(
        'SUBMITTED DOSSIER (READ-ONLY)',
        style: PixelType.small(context, color: PixelPalette.slate),
      ),
      SizedBox(height: grid.px(1)),
      _dossier(context, grid, app),
      gap,
      PixelButton(
        key: const ValueKey('affiliate_pending_back_shop'),
        label: 'Back to Traveler Shop',
        variant: PixelButtonVariant.secondary,
        expand: true,
        onPressed: () => context.go('/shop'),
      ),
    ];
  }

  Widget _header(
    BuildContext context,
    PixelGrid grid,
    MerchantHubStatus hub,
    Map<String, dynamic> app,
  ) {
    final (title, chip) = switch (hub.state) {
      MerchantHubState.needsChanges => ('Changes requested', 'ACTION NEEDED'),
      MerchantHubState.rejected => ('Not approved', 'CLOSED'),
      MerchantHubState.approvedMerchant => ('Approved', 'APPROVED'),
      _ when app['status'] == 'appealed' => (
          tr(context, en: 'Appeal under review', tl: 'Sinusuri ang apela'),
          tr(context, en: 'APPEALED', tl: 'INAPELA'),
        ),
      _ when hub.reapplicationsUsed > 0 && app['status'] == 'received' => (
          tr(context,
              en: 'Resubmitted for review', tl: 'Ipinasa muli para suriin'),
          tr(context, en: 'RESUBMITTED', tl: 'IPINASA MULI'),
        ),
      _ => (
          'In review by tourism team',
          app['status'] == 'in_review' ? 'IN REVIEW' : 'RECEIVED',
        ),
    };
    final place = [
      app['municipality'],
      app['business_province'],
    ].where((v) => (v?.toString() ?? '').isNotEmpty).join(', ');
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelSectionTitle(
            title,
            icon: DesignerArt.salakot,
            colors: PixelText3DColors.cream,
          ),
          SizedBox(height: grid.px(1)),
          Text(
            hub.merchantName ?? '${app['business_name'] ?? ''}',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          if (place.isNotEmpty)
            Text(
              '$place · ${app['category'] ?? ''}',
              style: PixelType.small(context, color: PixelPalette.cream),
            ),
          SizedBox(height: grid.px(1)),
          PixelChip(chip, key: const ValueKey('affiliate_pending_chip')),
        ],
      ),
    );
  }

  Widget _timeline(
    BuildContext context,
    PixelGrid grid,
    Map<String, dynamic> app,
  ) {
    final steps = [
      ('Application submitted', 'Ref ${app['id'] ?? ''}'.trim(), true),
      ('Tourism team review', 'Checking your pin and details', false),
      ('Merchant hub unlocked', 'Publish your storefront and catalog', false),
    ];
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PixelSectionTitle(
            'Review progress',
            icon: DesignerArt.questMarker,
          ),
          SizedBox(height: grid.px(1)),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Container(height: grid.unit, color: PixelPalette.paperDim),
            Padding(
              padding: EdgeInsets.symmetric(vertical: grid.px(2)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelChip(
                    steps[i].$3 ? 'DONE' : (i == 1 ? 'NOW' : 'NEXT'),
                    style: steps[i].$3
                        ? PixelBoxStyle.green
                        : (i == 1 ? PixelBoxStyle.gold : PixelBoxStyle.stone),
                    textColor: steps[i].$3 || i != 1
                        ? PixelPalette.white
                        : PixelPalette.ink,
                  ),
                  SizedBox(width: grid.px(2)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${steps[i].$1}',
                          style: PixelType.body(context),
                        ),
                        Text(
                          steps[i].$2,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedback(
    BuildContext context,
    WidgetRef ref,
    PixelGrid grid,
    MerchantHubStatus hub,
    Map<String, dynamic> app,
  ) {
    final note = (app['applicant_feedback'] ?? '').toString();
    final rejected = hub.state == MerchantHubState.rejected;
    return PixelPanel(
      key: const ValueKey('affiliate_pending_feedback'),
      style: rejected ? PixelBoxStyle.red : PixelBoxStyle.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            rejected ? 'Reviewer note' : 'Reviewer feedback',
            icon: DesignerArt.notifBell,
            colors: rejected ? PixelText3DColors.cream : PixelText3DColors.gold,
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(
              note,
              style: PixelType.body(
                context,
                color: rejected ? PixelPalette.white : PixelPalette.ink,
              ),
            ),
          ],
          SizedBox(height: grid.px(2)),
          if (rejected && !hub.canReapply)
            Text(
              tr(
                context,
                en: 'This application was already resubmitted or appealed '
                    '${MerchantHubStatus.maxReapplications} times.',
                tl: 'Naipasa muli o naiapela na ang aplikasyong ito nang '
                    '${MerchantHubStatus.maxReapplications} beses.',
              ),
              key: const ValueKey('affiliate_pending_limit'),
              style: PixelType.body(context, color: PixelPalette.white),
            )
          else
            PixelButton(
              key: const ValueKey('affiliate_pending_edit'),
              label: rejected
                  ? tr(context,
                      en: 'Edit and resubmit', tl: 'I-edit at ipasa muli')
                  : 'Edit & resubmit',
              expand: true,
              onPressed: () => context.push('/affiliate?edit=1'),
            ),
          if (rejected && hub.canReapply) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('affiliate_pending_appeal'),
              label: tr(context, en: 'Appeal', tl: 'Umapela'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: () => _appeal(context, ref, '${app['id'] ?? ''}'),
            ),
          ],
        ],
      ),
    );
  }

  /// Owner 2026-11-18: appeal a rejection with a message; the same
  /// application goes back to the review queue as `appealed`.
  Future<void> _appeal(BuildContext context, WidgetRef ref, String id) async {
    final controller = TextEditingController();
    final message = await showPixelDialog<String>(
      context: context,
      title: tr(context, en: 'Appeal the decision', tl: 'Umapela sa desisyon'),
      message: tr(
        context,
        en: 'Tell the tourism team why they should look again (at least 10 characters).',
        tl: 'Sabihin sa tourism team kung bakit dapat nila itong suriin muli (hindi bababa sa 10 titik).',
      ),
      content: PixelTextField(
        key: const ValueKey('affiliate_appeal_message'),
        controller: controller,
        label: tr(context, en: 'Your appeal', tl: 'Ang iyong apela'),
        maxLines: 4,
      ),
      actions: [
        Builder(
          builder: (dialogContext) => PixelButton(
            label: tr(context, en: 'Cancel', tl: 'Kanselahin'),
            variant: PixelButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        Builder(
          builder: (dialogContext) => PixelButton(
            key: const ValueKey('affiliate_appeal_send'),
            label: tr(context, en: 'Send appeal', tl: 'Ipadala ang apela'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ),
      ],
    );
    controller.dispose();
    if (message == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (message.length < 10) {
      showPixelToastOn(
        messenger,
        tr(context,
            en: 'Write at least 10 characters.',
            tl: 'Sumulat ng hindi bababa sa 10 titik.'),
      );
      return;
    }
    final sent = tr(context,
        en: 'Appeal sent to the tourism team.',
        tl: 'Naipadala ang apela sa tourism team.');
    final failed = tr(context,
        en: 'Could not send the appeal. Try again.',
        tl: 'Hindi naipadala ang apela. Subukan muli.');
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/affiliate/applications/$id/appeal', data: {
        'message': message,
      });
      ref.invalidate(merchantHubStatusProvider);
      showPixelToastOn(messenger, sent);
    } on DioException catch (error) {
      final body = error.response?.data;
      final serverMessage = body is Map && body['error'] is Map
          ? body['error']['message']?.toString()
          : null;
      showPixelToastOn(messenger, serverMessage ?? failed);
    }
  }

  Widget _approved(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PixelSectionTitle(
            'Your merchant workspace is ready!',
            icon: DesignerArt.salakot,
            colors: PixelText3DColors.cream,
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('affiliate_pending_open_merchant'),
            label: 'Open merchant dashboard',
            expand: true,
            variant: PixelButtonVariant.secondary,
            onPressed: () => context.pushReplacement('/merchant'),
          ),
        ],
      ),
    );
  }

  Widget _dossier(
    BuildContext context,
    PixelGrid grid,
    Map<String, dynamic> app,
  ) {
    final lat = (app['gps_lat'] as num?)?.toStringAsFixed(6);
    final lng = (app['gps_lng'] as num?)?.toStringAsFixed(6);
    final goals = (app['sponsorship_goals'] as List? ?? const [])
        .map((g) => g.toString().replaceAll('_', ' '))
        .join(', ');
    final rows = [
      (
        'Contact',
        '${app['contact_name'] ?? ''} (${app['contact_email'] ?? ''} · ${app['contact_phone'] ?? ''})',
      ),
      if (lat != null && lng != null) ('Map pin', '$lat, $lng'),
      if (goals.isNotEmpty) ('Goals', goals),
    ];
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PixelSectionTitle(
            'Application details',
            icon: DesignerArt.handshake,
          ),
          SizedBox(height: grid.px(1)),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(height: grid.unit, color: PixelPalette.paperDim),
            Padding(
              padding: EdgeInsets.symmetric(vertical: grid.px(2)),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${rows[i].$1}: ',
                      style: PixelType.small(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                    TextSpan(text: rows[i].$2, style: PixelType.body(context)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
