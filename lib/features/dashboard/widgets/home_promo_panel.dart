import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../app_update/models/app_version_info.dart';
import '../../app_update/providers/app_update_provider.dart';

typedef PromoUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLaunchPromoUrl(Uri uri) async {
  if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
    return true;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

final homePromoUrlLauncherProvider = Provider<PromoUrlLauncher>(
  (_) => _defaultLaunchPromoUrl,
);

const _promoCardStyle = PixelBoxStyle(
  fill: PixelPalette.cream,
  highlight: PixelPalette.sunLight,
  shade: PixelPalette.amber,
  outline: PixelPalette.woodDeep,
);

/// Highlighted admin-controlled feedback/promotion form card on Home.
class HomePromoPanel extends ConsumerWidget {
  const HomePromoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promo = ref.watch(activeHomePromoProvider);
    if (promo == null) {
      return const SizedBox.shrink();
    }

    final grid = PixelGrid.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: grid.px(5)),
      child: _HomePromoCard(
        promo: promo,
        onDismiss: () => ref
            .read(homePromoDismissProvider.notifier)
            .dismiss(promo.campaignId),
        onOpen: () => _openPromo(context, ref, promo),
      ),
    );
  }

  Future<void> _openPromo(
    BuildContext context,
    WidgetRef ref,
    HomePromoPanelConfig promo,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = Uri.tryParse(promo.url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      if (messenger != null) {
        showPixelToastOn(messenger, 'Unable to open form link right now.');
      }
      return;
    }
    try {
      final launcher = ref.read(homePromoUrlLauncherProvider);
      final opened = await launcher(uri);
      if (!opened && messenger != null) {
        showPixelToastOn(messenger, 'Unable to open form link right now.');
      }
    } catch (_) {
      if (messenger != null) {
        showPixelToastOn(messenger, 'Unable to open form link right now.');
      }
    }
  }
}

class _HomePromoCard extends StatelessWidget {
  const _HomePromoCard({
    required this.promo,
    required this.onDismiss,
    required this.onOpen,
  });

  final HomePromoPanelConfig promo;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const ValueKey('home_promo_panel'),
      style: _promoCardStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 20,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: PixelSprite(DesignerArt.juanChoice, scale: 2),
                ),
              ),
              SizedBox(width: grid.px(2)),
              const Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PixelChip(
                      'FEEDBACK',
                      style: PixelBoxStyle.gold,
                      textColor: PixelPalette.ink,
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Dismiss promotion',
                child: InkWell(
                  key: const ValueKey('home_promo_dismiss'),
                  onTap: onDismiss,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: PixelPalette.woodDeep,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            promo.title,
            key: const ValueKey('home_promo_title'),
            softWrap: true,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: PixelType.body(context, color: PixelPalette.ink)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          if (promo.body.isNotEmpty) ...[
            SizedBox(height: grid.px(1.5)),
            Text(
              promo.body,
              key: const ValueKey('home_promo_body'),
              softWrap: true,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
          SizedBox(height: grid.px(3)),
          PixelButton(
            key: const ValueKey('home_promo_cta'),
            label: promo.ctaLabel.toUpperCase(),
            expand: true,
            variant: PixelButtonVariant.primary,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
