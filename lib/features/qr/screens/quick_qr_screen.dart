import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../onboarding/page_tutorials.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shop/models/voucher_model.dart';
import '../../shop/providers/voucher_provider.dart';
import '../../suki/providers/suki_provider.dart';
import '../../suki/suki_scan_flow.dart';
import '../../suki/widgets/suki_pass_sheet.dart';
import '../qr_payload_parser.dart';

/// Unified Quick QR Hub (`/qr`):
/// - **Scan QR**: auto-detects Suki standees, JuanDerQuest links, quest
///   checkpoints, and EVM wallet addresses.
/// - **My QR**: shows the traveler's Passport QR plus 1-tap access to active
///   redeemed voucher QRs and Suki counter passes.
class QuickQrScreen extends ConsumerStatefulWidget {
  const QuickQrScreen({
    super.key,
    this.initialTab = 'scan',
    this.enableCamera = true,
  });

  final String initialTab;

  /// Set to false in widget/overflow tests where the native camera plugin is
  /// unavailable.
  final bool enableCamera;

  @override
  ConsumerState<QuickQrScreen> createState() => _QuickQrScreenState();
}

class _QuickQrScreenState extends ConsumerState<QuickQrScreen> {
  late String _tab;
  MobileScannerController? _controller;
  bool _handlingScan = false;
  bool _torchOn = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == 'my' ? 'my' : 'scan';
    if (widget.enableCamera) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voucherProvider.notifier).fetchVouchers();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _switchTab(String next) {
    if (_tab == next) return;
    setState(() {
      _tab = next;
      _statusMessage = null;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingScan || !mounted || _tab != 'scan') return;
    for (final barcode in capture.barcodes) {
      final parsed = parseQuickQrPayload(barcode.rawValue);
      if (parsed != null) {
        await _handleParsedQr(parsed);
        return;
      }
    }
    if (mounted) {
      setState(() {
        _statusMessage = tr(
          context,
          en: 'Unrecognized QR code. Try a Suki standee, quest, or traveler QR.',
          tl: 'Hindi kilalang QR code. Subukan ang Suki, quest, o traveler QR.',
        );
      });
    }
  }

  Future<void> _handleParsedQr(QuickQrResult parsed) async {
    setState(() {
      _handlingScan = true;
      _statusMessage = null;
    });
    try {
      switch (parsed) {
        case SukiStandeeQr(:final standeeUrl):
          await _handleSukiStandee(standeeUrl);
        case SpotLinkQr(:final slug):
          if (mounted) context.push('/explore/$slug');
        case QuestLinkQr(:final questId):
          if (mounted) context.push('/quests/$questId');
        case ProfileLinkQr(:final handle):
          if (mounted) context.push('/profile/$handle');
        case WalletAddressQr(:final address):
          if (mounted) await _showWalletAddressSheet(address);
        case CheckpointCodeQr(:final code):
          if (mounted) await _showCheckpointSheet(code);
      }
    } finally {
      if (mounted) {
        setState(() => _handlingScan = false);
      }
    }
  }

  Future<void> _handleSukiStandee(String standeeUrl) async {
    setState(() {
      _statusMessage = tr(
        context,
        en: 'Checking location for Suki visit…',
        tl: 'Sinusuri ang lokasyon para sa Suki visit…',
      );
    });
    final pos = await sukiPosition();
    if (!mounted) return;
    if (pos == null) {
      await showSukiMessage(
        context,
        title: tr(context, en: 'Location needed', tl: 'Kailangan ang lokasyon'),
        message: tr(
          context,
          en: 'Turn on location: Suki visits are collected at the shop.',
          tl: 'I-on ang lokasyon: sa tindahan kinukuha ang Suki visit.',
        ),
      );
      return;
    }
    try {
      final result = await ref.read(sukiApiProvider).recordVisit(
            standee: standeeUrl,
            lat: pos.latitude,
            lng: pos.longitude,
            accuracyM: pos.accuracy,
          );
      ref.invalidate(mySukiCardsProvider);
      ref.invalidate(sukiProgramProvider(result.program.id));
      if (mounted) {
        await celebrateSukiVisit(context, result);
      }
    } catch (error) {
      if (mounted) {
        await showSukiMessage(
          context,
          title: tr(context, en: 'Suki scan', tl: 'Suki scan'),
          message: sukiErrorText(context, error),
        );
      }
    }
  }

  Future<void> _showWalletAddressSheet(String address) async {
    final scanUrl = 'https://amoy.polygonscan.com/address/$address';
    await showPixelDialog<void>(
      context: context,
      title: 'Wallet Address',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 2,
            child: SelectableText(
              address,
              style: PixelType.small(context, color: PixelPalette.ink),
            ),
          ),
          const SizedBox(height: 10),
          PixelButton(
            label: 'Copy address',
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              showPixelToast(context, 'Wallet address copied.');
            },
          ),
          const SizedBox(height: 8),
          PixelButton(
            label: 'Open on PolygonScan',
            expand: true,
            onPressed: () async {
              final uri = Uri.parse(scanUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      actions: [
        PixelButton(
          label: 'Done',
          variant: PixelButtonVariant.ghost,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  Future<void> _showCheckpointSheet(String code) async {
    await showPixelDialog<void>(
      context: context,
      title: 'QR Code Detected',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Checkpoint / reference code:',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          const SizedBox(height: 6),
          PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 2,
            child: SelectableText(
              code,
              style: PixelType.body(context, color: PixelPalette.ink),
            ),
          ),
          const SizedBox(height: 10),
          PixelButton(
            label: 'Copy code',
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              showPixelToast(context, 'Code copied.');
            },
          ),
          const SizedBox(height: 8),
          PixelButton(
            label: 'Open Quests',
            expand: true,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.go('/quests');
            },
          ),
        ],
      ),
      actions: [
        PixelButton(
          label: 'Close',
          variant: PixelButtonVariant.ghost,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  void _showVoucherQrModal(RedeemedVoucherModel voucher) {
    showPixelDialog<void>(
      context: context,
      title: voucher.offerTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            voucher.merchantName,
            textAlign: TextAlign.center,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          const SizedBox(height: 10),
          PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 2,
            child: QrImageView(
              data: voucher.code,
              size: 200,
              backgroundColor: Colors.white,
              semanticsLabel: 'Voucher QR code',
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            voucher.code,
            textAlign: TextAlign.center,
            style: PixelType.title(context, color: PixelPalette.ink),
          ),
          const SizedBox(height: 8),
          PixelButton(
            label: 'Copy code',
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: voucher.code));
              showPixelToast(context, 'Voucher code copied.');
            },
          ),
        ],
      ),
      actions: [
        PixelButton(
          label: 'Close',
          variant: PixelButtonVariant.ghost,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return PageTutorialHost(
            page: TutorialPage.quickQr,
            stepsBuilder: (ctx) =>
                buildPageTutorialSteps(ctx, TutorialPage.quickQr),
            child: Scaffold(
              backgroundColor: PixelPalette.paper,
              body: DitherBackground(
                top: PixelPalette.paper,
                bottom: PixelPalette.parchment,
                child: Column(
                  children: [
                    PixelAppBar(
                      title: tr(context, en: 'QR Hub', tl: 'QR Hub'),
                      onBack:
                          canPop ? () => Navigator.of(context).maybePop() : null,
                      actions: const [
                        TutorialHelpButton(page: TutorialPage.quickQr),
                      ],
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      grid.gutter,
                      grid.px(2),
                      grid.gutter,
                      grid.px(2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: PixelButton(
                            key: const ValueKey('quick_qr_tab_scan'),
                            label: tr(context, en: 'Scan QR', tl: 'I-scan'),
                            expand: true,
                            variant: _tab == 'scan'
                                ? PixelButtonVariant.primary
                                : PixelButtonVariant.secondary,
                            onPressed: () => _switchTab('scan'),
                          ),
                        ),
                        SizedBox(width: grid.px(2)),
                        Expanded(
                          child: PixelButton(
                            key: const ValueKey('quick_qr_tab_my'),
                            label: tr(context, en: 'My QR', tl: 'QR Ko'),
                            expand: true,
                            variant: _tab == 'my'
                                ? PixelButtonVariant.primary
                                : PixelButtonVariant.secondary,
                            onPressed: () => _switchTab('my'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _tab == 'scan'
                        ? _buildScanTab(context, grid)
                        : _buildMyQrTab(context, grid),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanTab(BuildContext context, PixelGrid grid) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        grid.gutter,
        grid.px(1),
        grid.gutter,
        grid.px(8) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PixelPanel(
          style: PixelBoxStyle.wood,
          padding: 1,
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_controller != null)
                    MobileScanner(
                      controller: _controller!,
                      onDetect: _onDetect,
                    )
                  else
                    Container(
                      color: PixelPalette.ink,
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(grid.px(4)),
                      child: Text(
                        'Camera preview',
                        style: PixelType.body(context, color: PixelPalette.cream),
                      ),
                    ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: PixelPalette.sun,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_handlingScan)
                    Container(
                      color: PixelPalette.ink.withValues(alpha: 0.65),
                      alignment: Alignment.center,
                      child: const PixelLoader(label: 'Processing QR…'),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: grid.px(3)),
        if (_statusMessage != null) ...[
          PixelPanel(
            style: PixelBoxStyle.gold,
            padding: 2,
            child: Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: PixelType.small(context, color: PixelPalette.ink),
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
        PixelPanel(
          style: PixelBoxStyle.parchment,
          padding: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  en: 'Point your camera at a Suki shop standee, quest checkpoint, traveler passport QR, or wallet address.',
                  tl: 'Itutok ang camera sa Suki standee, quest checkpoint, traveler QR, o wallet address.',
                ),
                style: PixelType.small(context, color: PixelPalette.slate),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: grid.px(3)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(2),
                alignment: WrapAlignment.center,
                children: [
                  if (_controller != null)
                    PixelButton(
                      key: const ValueKey('quick_qr_torch'),
                      label: _torchOn ? 'Flashlight: ON' : 'Flashlight',
                      variant: PixelButtonVariant.secondary,
                      onPressed: () async {
                        await _controller?.toggleTorch();
                        if (mounted) setState(() => _torchOn = !_torchOn);
                      },
                    ),
                  PixelButton(
                    key: const ValueKey('quick_qr_switch_my'),
                    label: 'Show My QR',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => _switchTab('my'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyQrTab(BuildContext context, PixelGrid grid) {
    final user = ref.watch(authProvider).user;
    final voucherState = ref.watch(voucherProvider);
    final sukiCardsAsync = ref.watch(mySukiCardsProvider);

    final handle = user?.publicHandle;
    final cleanHandle = handle?.replaceFirst(RegExp(r'^@+'), '');
    final passportUrl = cleanHandle != null && cleanHandle.isNotEmpty
        ? 'https://juanderquest.app/profile/$cleanHandle'
        : 'juanderquest://profile/${user?.id ?? 'traveler'}';
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Traveler';
    final wallet = user?.walletAddress?.trim() ?? '';
    final activeVouchers = voucherState.redeemedVouchers
        .where((v) => v.usedAt == null)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        grid.gutter,
        grid.px(1),
        grid.gutter,
        grid.px(8) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PixelPanel(
          key: const ValueKey('quick_qr_passport_card'),
          style: PixelBoxStyle.parchment,
          padding: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                tr(context, en: 'TRAVELER PASSPORT QR', tl: 'TRAVELER PASSPORT QR'),
                style: PixelType.title(context, color: PixelPalette.ink),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: grid.px(1)),
              Text(
                handle != null && handle.isNotEmpty
                    ? '$displayName · $handle'
                    : displayName,
                style: PixelType.body(context, color: PixelPalette.slate),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: grid.px(3)),
              PixelPanel(
                style: PixelBoxStyle.slot,
                padding: 2,
                child: QrImageView(
                  key: const ValueKey('quick_qr_passport_image'),
                  data: passportUrl,
                  size: 196,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Traveler passport QR code',
                ),
              ),
              if (wallet.isNotEmpty) ...[
                SizedBox(height: grid.px(2)),
                PixelChip(
                  'Wallet: ${wallet.length > 14 ? '${wallet.substring(0, 6)}…${wallet.substring(wallet.length - 4)}' : wallet}',
                  style: PixelBoxStyle.green,
                  textColor: PixelPalette.white,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: wallet));
                    showPixelToast(context, 'Wallet address copied.');
                  },
                ),
              ],
              SizedBox(height: grid.px(3)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(2),
                alignment: WrapAlignment.center,
                children: [
                  PixelButton(
                    key: const ValueKey('quick_qr_copy_link'),
                    label: 'Copy Link',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: passportUrl));
                      showPixelToast(context, 'Profile link copied.');
                    },
                  ),
                  PixelButton(
                    key: const ValueKey('quick_qr_share_link'),
                    label: 'Share',
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Connect with me on JuanDerQuest: $passportUrl',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          padding: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, en: 'ACTIVE VOUCHER QRS', tl: 'ACTIVE VOUCHER QRS'),
                style: PixelType.title(context, color: PixelPalette.ink),
              ),
              SizedBox(height: grid.px(1)),
              if (activeVouchers.isEmpty)
                Text(
                  tr(
                    context,
                    en: 'No active voucher codes yet. Redeem one in the Shop to show its QR here.',
                    tl: 'Wala pang active voucher. Mag-redeem sa Shop para makita ang QR dito.',
                  ),
                  style: PixelType.small(context, color: PixelPalette.slate),
                )
              else
                for (final v in activeVouchers) ...[
                  SizedBox(height: grid.px(2)),
                  GestureDetector(
                    onTap: () => _showVoucherQrModal(v),
                    child: PixelPanel(
                      style: PixelBoxStyle.slot,
                      padding: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.offerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PixelType.body(context,
                                      color: PixelPalette.ink),
                                ),
                                Text(
                                  '${v.merchantName} · ${v.code}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PixelType.small(context,
                                      color: PixelPalette.slate),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: grid.px(2)),
                          const PixelChip(
                            'QR ›',
                            style: PixelBoxStyle.gold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          padding: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, en: 'SUKI COUNTER PASSES', tl: 'SUKI COUNTER PASSES'),
                style: PixelType.title(context, color: PixelPalette.ink),
              ),
              SizedBox(height: grid.px(1)),
              sukiCardsAsync.when(
                loading: () => const PixelLoader(label: 'Loading Suki cards…'),
                error: (_, __) => Text(
                  'Open Suki Cards to view your shop passes.',
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
                data: (cards) {
                  if (cards.isEmpty) {
                    return Text(
                      tr(
                        context,
                        en: 'Scan a partner shop standee to start a Suki Card and show your pass here.',
                        tl: 'I-scan ang standee ng tindahan para makakuha ng Suki Card.',
                      ),
                      style: PixelType.small(context, color: PixelPalette.slate),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in cards.take(5)) ...[
                        SizedBox(height: grid.px(2)),
                        GestureDetector(
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: PixelPalette.parchment,
                            builder: (_) => Theme(
                              data: AppTheme.pixel,
                              child: SukiPassSheet(
                                programId: c.program.id,
                                shopName: c.program.merchant.name,
                              ),
                            ),
                          ),
                          child: PixelPanel(
                            style: PixelBoxStyle.slot,
                            padding: 2,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.program.merchant.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: PixelType.body(context,
                                            color: PixelPalette.ink),
                                      ),
                                      Text(
                                        '${c.progress.visits}/${c.progress.required} visits',
                                        style: PixelType.small(context,
                                            color: PixelPalette.slate),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: grid.px(2)),
                                const PixelChip(
                                  'PASS ›',
                                  style: PixelBoxStyle.green,
                                  textColor: PixelPalette.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
