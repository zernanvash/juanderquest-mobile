import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../providers/merchant_hub_provider.dart';
import '../screens/merchant_counter_history_screen.dart';
import '../suki/merchant_loyalty_tab.dart' show merchantSukiScannerProvider;
import '../suki/merchant_suki_codes.dart';
import '../suki/merchant_suki_widgets.dart';

/// v0.3.10: asks staff to type a code from the customer's screen.
/// Returns an accepted counter code, or null when cancelled.
Future<String?> promptCounterCode(BuildContext context) async {
  final controller = TextEditingController();
  String? problem;
  final code = await showPixelDialog<String>(
    context: context,
    title: tr(context, en: 'Enter the code', tl: 'I-type ang code'),
    content: StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelTextField(
            key: const ValueKey('merchant_counter_code'),
            controller: controller,
            label: tr(ctx, en: 'Voucher or reward code', tl: 'Code'),
            hint: 'JDQ-XXXXXX-XXXXXX',
          ),
          if (problem != null) ...[
            const SizedBox(height: 8),
            Text(problem!,
                key: const ValueKey('merchant_counter_code_error'),
                style: PixelType.small(ctx, color: PixelPalette.redDeep)),
          ],
          const SizedBox(height: 8),
          PixelButton(
            key: const ValueKey('merchant_counter_code_confirm'),
            label: tr(ctx, en: 'Confirm', tl: 'Kumpirmahin'),
            expand: true,
            onPressed: () {
              final accepted = extractCounterCode(controller.text);
              if (accepted == null) {
                setState(() => problem = tr(ctx,
                    en: 'Type the code as shown, e.g. JDQ-AB12CD-EF34GH.',
                    tl: 'I-type ang code gaya ng nakikita.'));
                return;
              }
              Navigator.of(ctx).pop(accepted);
            },
          ),
          const SizedBox(height: 8),
          PixelButton(
            label: tr(ctx, en: 'Cancel', tl: 'Kanselahin'),
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
    actions: const [],
  );
  controller.dispose();
  return code;
}

/// v0.3.10: the counter loop. Scans (or asks for) a code, confirms it with
/// `POST /merchant/suki/scan`, shows the result, and repeats on "Scan next".
/// Voucher codes work even while Suki Cards are switched off.
Future<void> runMerchantCounter(
  BuildContext context,
  WidgetRef ref, {
  bool manual = false,
}) async {
  final api = ref.read(merchantApiProvider);
  final scan = ref.read(merchantSukiScannerProvider);
  var again = true;
  while (again) {
    again = false;
    if (!context.mounted) return;
    final code =
        manual ? await promptCounterCode(context) : await scan(context);
    if (code == null || !context.mounted) return;
    try {
      final result = await api.sukiScan(code);
      if (!context.mounted) return;
      again = await showSukiScanResult(context, result);
    } catch (error) {
      if (!context.mounted) return;
      final next = await showPixelDialog<bool>(
        context: context,
        title: tr(context, en: 'Not accepted', tl: 'Hindi tinanggap'),
        message: merchantSukiErrorText(context, error),
        actions: [
          Builder(
            builder: (ctx) => PixelButton(
              key: const ValueKey('loyalty_scan_retry'),
              label: manual
                  ? tr(ctx, en: 'Try again', tl: 'Subukang muli')
                  : tr(ctx, en: 'Scan next', tl: 'Susunod'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
          Builder(
            builder: (ctx) => PixelButton(
              key: const ValueKey('loyalty_scan_stop'),
              label: tr(ctx, en: 'Done', tl: 'Tapos'),
              variant: PixelButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ),
        ],
      );
      again = next == true;
    }
  }
}

/// v0.3.10 ("users still cant use voucher"): the merchant hub's always-on
/// counter. Staff confirm a traveler's Shop voucher by scanning its QR or
/// typing its code, whether or not Suki Cards are switched on.
class MerchantCounterPanel extends ConsumerWidget {
  const MerchantCounterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const ValueKey('merchant_counter_panel'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'Counter', tl: 'Counter'),
            icon: DesignerArt.handshake,
          ),
          SizedBox(height: grid.px(1)),
          Text(
            tr(context,
                en: 'Confirm a traveler\'s voucher: scan the QR on their phone, or type the code.',
                tl: 'Kumpirmahin ang voucher: i-scan ang QR o i-type ang code.'),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              PixelButton(
                key: const ValueKey('merchant_counter_scan'),
                label: tr(context, en: 'Scan voucher', tl: 'I-scan'),
                onPressed: () => runMerchantCounter(context, ref),
              ),
              PixelButton(
                key: const ValueKey('merchant_counter_enter'),
                label: tr(context, en: 'Enter code', tl: 'I-type ang code'),
                variant: PixelButtonVariant.secondary,
                onPressed: () => runMerchantCounter(context, ref, manual: true),
              ),
              PixelButton(
                key: const ValueKey('merchant_counter_history_btn'),
                label: tr(context, en: 'History', tl: 'Kasaysayan'),
                variant: PixelButtonVariant.secondary,
                onPressed: () {
                  final router = GoRouter.maybeOf(context);
                  if (router != null) {
                    router.push('/merchant/counter-history');
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MerchantCounterHistoryScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
