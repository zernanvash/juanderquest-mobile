import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_hub_provider.dart';
import 'merchant_suki_codes.dart';
import 'merchant_suki_models.dart';
import 'suki_badge_art.dart';

/// Plan 107 J1 (`/merchant/suki/standee`): the counter standee to print,
/// laid out like the quest QR placards (QrSheetScreen) and exported as a PNG
/// the same way the Recap share does.
class SukiStandeeScreen extends ConsumerStatefulWidget {
  const SukiStandeeScreen({super.key});

  @override
  ConsumerState<SukiStandeeScreen> createState() => _SukiStandeeScreenState();
}

class _SukiStandeeScreenState extends ConsumerState<SukiStandeeScreen> {
  late Future<MerchantSukiStandee> _future;
  final _placardKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(merchantApiProvider).sukiStandee();
  }

  void _reload() =>
      setState(() => _future = ref.read(merchantApiProvider).sukiStandee());

  Future<void> _share(MerchantSukiStandee data) async {
    final boundary = _placardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/suki-standee-v${data.version}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${data.shopName} Suki Card',
      ));
    } catch (_) {
      if (mounted) {
        showPixelToast(
            context,
            tr(context,
                en: 'Could not export the standee.',
                tl: 'Hindi ma-export ang standee.'));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    title: tr(context, en: 'Suki standee', tl: 'Suki standee'),
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: FutureBuilder<MerchantSukiStandee>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: PixelLoader(label: 'Loading standee'),
                          );
                        }
                        final padding = EdgeInsets.fromLTRB(
                          grid.gutter,
                          grid.px(3),
                          grid.gutter,
                          grid.px(8) + MediaQuery.paddingOf(context).bottom,
                        );
                        if (snapshot.hasError) {
                          return ListView(
                            padding: padding,
                            children: [
                              PixelPanel(
                                key: const ValueKey('suki_standee_error'),
                                style: PixelBoxStyle.parchment,
                                padding: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      merchantSukiErrorText(
                                          context, snapshot.error),
                                      style: PixelType.body(context),
                                    ),
                                    if (!isSukiDisabled(snapshot.error)) ...[
                                      SizedBox(height: grid.px(2)),
                                      PixelButton(
                                        label: tr(context,
                                            en: 'Retry', tl: 'Subukang muli'),
                                        variant: PixelButtonVariant.secondary,
                                        onPressed: _reload,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        final data = snapshot.data!;
                        return ListView(
                          padding: padding,
                          children: [
                            RepaintBoundary(
                              key: _placardKey,
                              child: _placard(context, grid, data),
                            ),
                            SizedBox(height: grid.px(3)),
                            PixelButton(
                              key: const ValueKey('suki_standee_share'),
                              label: tr(context,
                                  en: 'Save or share image',
                                  tl: 'I-save o ibahagi ang larawan'),
                              expand: true,
                              loading: _sharing,
                              onPressed: () => _share(data),
                            ),
                            SizedBox(height: grid.px(2)),
                            PixelButton(
                              key: const ValueKey('suki_standee_copy'),
                              label: tr(context,
                                  en: 'Copy link', tl: 'Kopyahin ang link'),
                              variant: PixelButtonVariant.secondary,
                              expand: true,
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: data.url));
                                showPixelToast(
                                    context,
                                    tr(context,
                                        en: 'Standee link copied.',
                                        tl: 'Nakopya ang link.'));
                              },
                            ),
                            SizedBox(height: grid.px(2)),
                            Text(
                              tr(context,
                                  en: 'Print it and stand it at your counter. Replacing the QR in the Loyalty tab stops old prints from working.',
                                  tl: 'I-print at ilagay sa counter. Kapag pinalitan ang QR, hindi na gagana ang lumang print.'),
                              textAlign: TextAlign.center,
                              style: PixelType.small(context,
                                  color: PixelPalette.slate),
                            ),
                          ],
                        );
                      },
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

  Widget _placard(
      BuildContext context, PixelGrid grid, MerchantSukiStandee data) {
    final visits = data.visitsRequired;
    return ColoredBox(
      color: PixelPalette.paper,
      child: Padding(
        padding: EdgeInsets.all(grid.px(2)),
        child: Column(
          children: [
            PixelPanel(
              style: PixelBoxStyle.wood,
              padding: 3,
              child: Column(
                children: [
                  const PixelSprite(SukiBadgeArt.sukiCard, scale: 3),
                  SizedBox(height: grid.px(1)),
                  Text(
                    'JUANDERQUEST SUKI CARD',
                    textAlign: TextAlign.center,
                    style: PixelType.small(context, color: PixelPalette.sun),
                  ),
                  SizedBox(height: grid.px(1)),
                  Text(
                    data.shopName,
                    key: const ValueKey('suki_standee_shop'),
                    textAlign: TextAlign.center,
                    style: PixelType.title(context, color: PixelPalette.paper),
                  ),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: PixelType.body(context, color: PixelPalette.cream),
                  ),
                ],
              ),
            ),
            SizedBox(height: grid.px(3)),
            LayoutBuilder(
              builder: (context, box) => Container(
                color: PixelPalette.white,
                padding: EdgeInsets.all(grid.px(2)),
                child: QrImageView(
                  key: const ValueKey('suki_standee_qr'),
                  data: data.url,
                  version: QrVersions.auto,
                  size: (box.maxWidth - grid.px(4)).clamp(120.0, 260.0),
                  backgroundColor: PixelPalette.white,
                  semanticsLabel: 'Suki Card standee QR code',
                ),
              ),
            ),
            SizedBox(height: grid.px(3)),
            PixelPanel(
              style: PixelBoxStyle.gold,
              padding: 2,
              child: Text(
                visits == null
                    ? data.rewardText
                    : tr(context,
                        en: 'Visit $visits times: ${data.rewardText}',
                        tl: 'Bumisita nang $visits beses: ${data.rewardText}'),
                key: const ValueKey('suki_standee_reward'),
                textAlign: TextAlign.center,
                style: PixelType.title(context),
              ),
            ),
            SizedBox(height: grid.px(2)),
            Text(
              tr(context,
                  en: 'Open JuanderQuest and tap Scan Suki. No app yet? Scan with your camera to get it.',
                  tl: 'Buksan ang JuanderQuest at i-tap ang Scan Suki. Wala pang app? I-scan gamit ang camera.'),
              textAlign: TextAlign.center,
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              'QR v${data.version}',
              style: PixelType.small(context, color: PixelPalette.stone),
            ),
          ],
        ),
      ),
    );
  }
}
