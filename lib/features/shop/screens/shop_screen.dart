import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../onboarding/page_tutorials.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cosmetics/widgets/passport_preview.dart';
import '../../cosmetics/widgets/profile_banner.dart';
import '../../cosmetics/widgets/cosmetic_avatar.dart';
import '../../merchant/models/merchant_models.dart';
import '../../merchant/providers/merchant_hub_provider.dart';
import '../../merchant/screens/merchant_directory_screen.dart';
import '../../merchant/screens/merchant_page_screen.dart';
import '../../suki/widgets/shop_suki_section.dart';
import '../../wallet/providers/transactions_provider.dart';
import '../../wallet/screens/wallet_connect_screen.dart';
import '../../wallet/widgets/transaction_receipt_sheet.dart';
import '../models/cosmetic_item.dart';
import '../models/shop_teaser.dart';
import '../models/voucher_model.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/shop_nav_provider.dart';
import '../providers/voucher_provider.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  // Plan 93b WP-4: a category-first storefront hub.
  static const _categories = <(int, String, String)>[
    (0, 'Cosmetics', 'Banners, avatar frames, titles & name colours'),
    (1, 'Partner Vouchers', 'Discounts & offers from Pangasinan merchants'),
    (3, 'My Inventory', 'Your look, owned cosmetics & voucher codes'),
    (2, 'Coming Soon', 'Upcoming seasonal & on-chain drops'),
  ];

  static const _filters = <(String, String)>[
    ('banner', 'Banners'),
    ('frame', 'Frames'),
    ('title', 'Titles'),
    ('name_color', 'Colours'),
  ];

  /// null: the category hub. 0 Cosmetics, 1 Vouchers, 2 Coming soon, 3 My items.
  int? get _selectedTab => ref.watch(shopCategoryProvider);
  set _selectedTab(int? value) =>
      ref.read(shopCategoryProvider.notifier).state = value;
  String _filter = 'banner';
  bool _inventoryVouchers = false;
  bool? _liveGrid; // null: follow the system animation setting (Plan 69)

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(voucherProvider.notifier).fetchVouchers();
      ref.read(cosmeticsProvider.notifier).load();
    });
  }

  /// Plan 67: browsing is open to everyone; buying cosmetics needs a linked
  /// wallet. Vouchers do not (owner 2026-11-19).
  Future<bool> _walletReady(String itemTitle) async {
    if (ref.read(authProvider).user?.hasBoundWallet == true) return true;
    return showConnectWalletPromptDialog(context, itemTitle: itemTitle);
  }

  void _showVoucherConfirmationDialog({
    required BuildContext context,
    required VoucherModel voucher,
    required int userPoints,
  }) {
    showPixelDialog<void>(
      context: context,
      title: 'Redeem voucher',
      content: Consumer(
        builder: (dialogContext, ref, _) {
          final isRedeeming = ref.watch(voucherProvider).isRedeeming;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You are about to redeem "${voucher.offerTitle}" from ${voucher.merchantName}.',
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
              SizedBox(height: PixelGrid.of(context).px(2)),
              PixelPanel(
                style: PixelBoxStyle.slot,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: PixelGrid.of(context).px(2),
                  runSpacing: PixelGrid.of(context).px(1),
                  children: [
                    Text('Cost deduction', style: PixelType.body(context)),
                    Text(
                      '-${voucher.costPoints} pts',
                      style: PixelType.numbers(
                        context,
                        color: PixelPalette.redDeep,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: PixelGrid.of(context).px(3)),
              Wrap(
                spacing: PixelGrid.of(context).px(2),
                runSpacing: PixelGrid.of(context).px(2),
                alignment: WrapAlignment.end,
                children: [
                  PixelButton(
                    label: 'Cancel',
                    variant: PixelButtonVariant.secondary,
                    onPressed: isRedeeming
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                  ),
                  PixelButton(
                    key: const ValueKey('shop_voucher_confirm'),
                    label: 'Confirm',
                    loading: isRedeeming,
                    onPressed: isRedeeming
                        ? null
                        : () async {
                            final result = await ref
                                .read(voucherProvider.notifier)
                                .redeemVoucher(voucher);

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (context.mounted) {
                              if (result.success && result.redeemed != null) {
                                _showRedeemedVoucherModal(
                                    context, result.redeemed!);
                              } else {
                                showPixelToast(
                                  context,
                                  result.error ??
                                      ref.read(voucherProvider).error ??
                                      'Redemption failed.',
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRedeemedVoucherModal(
      BuildContext context, RedeemedVoucherModel redeemed) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: PixelPanel(
              style: PixelBoxStyle.parchment,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Voucher Ready to Use!',
                    textAlign: TextAlign.center,
                    style: PixelType.title(modalCtx),
                  ),
                  SizedBox(height: PixelGrid.of(modalCtx).px(1)),
                  Text(
                    redeemed.offerTitle,
                    textAlign: TextAlign.center,
                    style: PixelType.body(modalCtx),
                  ),
                  Text(
                    redeemed.merchantName,
                    textAlign: TextAlign.center,
                    style: PixelType.body(
                      modalCtx,
                      color: PixelPalette.slate,
                    ),
                  ),
                  SizedBox(height: PixelGrid.of(modalCtx).px(3)),
                  PixelPanel(
                    style: PixelBoxStyle.gold,
                    child: Column(
                      children: [
                        Text(
                          'Merchant redemption code',
                          style: PixelType.small(modalCtx),
                        ),
                        SizedBox(height: PixelGrid.of(modalCtx).px(1)),
                        SelectableText(
                          redeemed.code,
                          textAlign: TextAlign.center,
                          style: PixelType.title(modalCtx),
                        ),
                        SizedBox(height: PixelGrid.of(modalCtx).px(1)),
                        GestureDetector(
                          key: const ValueKey('shop_copy_code'),
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: redeemed.code));
                            showPixelToast(
                                context, 'Voucher code copied to clipboard!');
                          },
                          child: Text(
                            'Copy code',
                            style: PixelType.small(
                              modalCtx,
                              color: PixelPalette.greenDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: PixelGrid.of(modalCtx).px(3)),
                  // Plan 107: a real QR the shop's counter scanner confirms.
                  PixelPanel(
                    style: PixelBoxStyle.slot.copyWith(
                      fill: PixelPalette.white,
                    ),
                    child: Column(
                      children: [
                        if (redeemed.usedAt == null)
                          QrImageView(
                            key: const ValueKey('shop_voucher_qr'),
                            data: redeemed.code,
                            size: 180,
                            backgroundColor: Colors.white,
                            semanticsLabel: 'Voucher QR code',
                          ),
                        SizedBox(height: PixelGrid.of(modalCtx).px(1)),
                        Text(
                          redeemed.usedAt == null
                              ? tr(modalCtx,
                                  en:
                                      'Show this QR at the shop counter. Staff scan it once.',
                                  tl:
                                      'Ipakita ang QR sa counter. Isang beses lang i-scan.')
                              : tr(modalCtx,
                                  en: 'The shop already confirmed this voucher.',
                                  tl: 'Nakumpirma na ng tindahan ang voucher.'),
                          textAlign: TextAlign.center,
                          style: PixelType.small(
                            modalCtx,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: PixelGrid.of(modalCtx).px(3)),
                  PixelButton(
                    key: const ValueKey('shop_voucher_receipt'),
                    label: 'View / Share Receipt',
                    variant: PixelButtonVariant.secondary,
                    expand: true,
                    onPressed: () {
                      Navigator.of(modalCtx).pop();
                      showTransactionReceiptSheet(
                        context,
                        TransactionRecord(
                          receiptId: 'JDQ-VCH-${redeemed.code}',
                          title: redeemed.offerTitle,
                          subtitle: redeemed.merchantName,
                          category: TransactionCategory.vouchers,
                          amountLabel: '-${redeemed.costPoints} pts',
                          isCredit: false,
                          timestamp: redeemed.redeemedAt,
                          status: redeemed.usedAt != null ? 'Used' : 'Active',
                          settlement: 'Off-Chain Voucher',
                          voucherCode: redeemed.code,
                          walletAddress:
                              ref.read(authProvider).user?.walletAddress,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: PixelGrid.of(modalCtx).px(2)),
                  PixelButton(
                    label: 'Done',
                    expand: true,
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final points = user?.points ?? user?.demoPoints ?? 1250;
    final voucherState = ref.watch(voucherProvider);
    final cosmeticsState = ref.watch(cosmeticsProvider);
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return PageTutorialHost(
            page: TutorialPage.shop,
            stepsBuilder: (ctx) =>
                buildPageTutorialSteps(ctx, TutorialPage.shop),
            child: Scaffold(
              backgroundColor: PixelPalette.paper,
              body: DitherBackground(
                top: PixelPalette.paper,
                bottom: PixelPalette.parchment,
                child: Column(
                  children: [
                    PixelAppBar(
                      title: 'Traveler Shop',
                      isTab: true,
                      actions: [
                        const TutorialHelpButton(page: TutorialPage.shop),
                        SizedBox(width: grid.px(2)),
                        MjdqChip(
                          points,
                          animateOnIncrease: true,
                        ),
                      ],
                    ),
                  Expanded(
                    child: ListView(
                      key: ValueKey('shop_list_${_selectedTab ?? "hub"}'),
                      padding: EdgeInsets.fromLTRB(
                        grid.gutter,
                        grid.px(3),
                        grid.gutter,
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        if (user?.hasBoundWallet != true) ...[
                          _walletPrompt(context, grid),
                          SizedBox(height: grid.px(3)),
                        ],
                        if (_selectedTab == null)
                          _hub(context, grid, cosmeticsState, voucherState)
                        else ...[
                          _categoryHeader(context, grid),
                          SizedBox(height: grid.px(3)),
                        ],
                        if (_selectedTab == null)
                          const SizedBox.shrink()
                        else if (_selectedTab == 0)
                          _cosmetics(context, grid, cosmeticsState, points)
                        else if (_selectedTab == 1)
                          _vouchers(context, grid, voucherState, points)
                        else if (_selectedTab == 2)
                          _teasers(context, grid, cosmeticsState)
                        else
                          _myItems(context, grid, cosmeticsState, voucherState,
                              user?.displayName ?? 'Traveler', user?.avatarUrl),
                      ],
                    ),
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

  Widget _walletPrompt(BuildContext context, PixelGrid grid) {
    return GestureDetector(
      key: const ValueKey('shop_link_wallet'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/wallet/connect'),
      child: PixelPanel(
        style: PixelBoxStyle.slot.copyWith(shadowPx: 0),
        padding: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: grid.px(2),
            vertical: grid.px(1),
          ),
          child: Text(
            'Link your wallet to buy cosmetics >',
            style: PixelType.small(context),
          ),
        ),
      ),
    );
  }

  Widget _hub(
    BuildContext context,
    PixelGrid grid,
    CosmeticsState cosmetics,
    VoucherState vouchers,
  ) {
    String count(int id) => switch (id) {
          0 => '${cosmetics.items.length} items',
          1 => '${vouchers.vouchers.length} offers',
          2 => '${cosmetics.teasers.length} soon',
          _ => '${cosmetics.owned.length} owned',
        };
    // Owner 2026-11-18: "Move merchant on top and the cosmetics and others
    // below to allow scalability": the merchant hub first, then one
    // full-width row per category, so more categories fit later.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Plan 107: Suki Cards first (my cards + Scan Suki).
        const ShopSukiSection(),
        SizedBox(height: grid.px(2)),
        _merchantHubCard(context, grid),
        for (final category in _categories) ...[
          SizedBox(height: grid.px(2)),
          _categoryCard(context, grid, category, count),
        ],
        SizedBox(height: grid.px(2)),
        _partnerDirectoryCard(context, grid),
        SizedBox(height: grid.px(2)),
        GestureDetector(
          key: const ValueKey('shop_transactions_card'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/transactions'),
          child: PixelPanel(
            style: PixelBoxStyle.parchment.copyWith(corner: 2, shadowPx: 1),
            padding: 2,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transactions & Receipts',
                          style: PixelType.title(context)),
                      SizedBox(height: grid.px(1)),
                      Text(
                        'View invoices, share proof & copy PolygonScan links',
                        style:
                            PixelType.small(context, color: PixelPalette.slate),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: grid.px(2)),
                const PixelChip('OPEN ›', style: PixelBoxStyle.gold),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const _categoryIcons = <int, PixelArt>{
    0: DesignerArt.gem,
    1: DesignerArt.handshake,
    2: DesignerArt.navShop,
    3: DesignerArt.navProfile,
  };

  Widget _categoryCard(
    BuildContext context,
    PixelGrid grid,
    (int, String, String) category,
    String Function(int) count,
  ) {
    return GestureDetector(
      key: ValueKey('shop_tab_${category.$1}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        pixelTick(context);
        setState(() => _selectedTab = category.$1);
      },
      child: PixelPanel(
        style: PixelBoxStyle.parchment.copyWith(corner: 2, shadowPx: 1),
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: FittedBox(
                    child: PixelSprite(_categoryIcons[category.$1]!, scale: 1),
                  ),
                ),
                SizedBox(width: grid.px(1)),
                Flexible(
                  child: Text(
                    count(category.$1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Text(category.$2, style: PixelType.title(context)),
            SizedBox(height: grid.px(1)),
            Text(
              category.$3,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryHeader(BuildContext context, PixelGrid grid) {
    final title = _categories.firstWhere((c) => c.$1 == _selectedTab).$2;
    return Row(
      children: [
        PixelButton(
          key: const ValueKey('shop_back_to_hub'),
          label: '< All',
          variant: PixelButtonVariant.secondary,
          onPressed: () {
            pixelTick(context);
            setState(() => _selectedTab = null);
          },
        ),
        SizedBox(width: grid.px(2)),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.title(context),
          ),
        ),
      ],
    );
  }

  /// Uniform sub-tab / filter pill (Plan 93b WP-10: 40 px tall).
  Widget _pill(
    BuildContext context,
    PixelGrid grid, {
    required Key key,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        pixelTick(context);
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: PixelPanel(
          style: (active ? PixelBoxStyle.gold : PixelBoxStyle.slot)
              .copyWith(corner: 2, shadowPx: 0),
          padding: 1,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: grid.px(2),
              vertical: grid.px(1),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: PixelType.small(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Plan 95: the 5th storefront card opens the merchant journey at the
  /// step this traveler is on.
  Widget _merchantHubCard(BuildContext context, PixelGrid grid) {
    final hub = ref.watch(merchantHubStatusProvider).valueOrNull ??
        MerchantHubStatus.none;
    return GestureDetector(
      key: const ValueKey('shop_merchant_hub_button'),
      onTap: () {
        pixelTick(context);
        context.push(hub.route);
      },
      child: PixelPanel(
        style: PixelBoxStyle.wood.copyWith(corner: 2, shadowPx: 1),
        padding: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(
            horizontal: grid.px(2),
            vertical: grid.px(1),
          ),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: FittedBox(
                  child: PixelSprite(DesignerArt.salakot, scale: 1),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Flexible(
                child: Text(
                  hub.state == MerchantHubState.none ||
                          hub.state == MerchantHubState.rejected
                      ? 'Merchant hub'
                      : hub.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: PixelType.small(context, color: PixelPalette.paper),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partnerDirectoryCard(BuildContext context, PixelGrid grid) {
    return GestureDetector(
      key: const ValueKey('shop_browse_partners_button'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        pixelTick(context);
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.push('/merchants');
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const MerchantDirectoryScreen(),
            ),
          );
        }
      },
      child: PixelPanel(
        style: PixelBoxStyle.parchment.copyWith(corner: 2, shadowPx: 1),
        padding: 2,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: FittedBox(
                child: PixelSprite(DesignerArt.salakot, scale: 1),
              ),
            ),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Browse Partner Shops', style: PixelType.title(context)),
                  Text(
                    'Find Pangasinan merchants, offers & Suki cards',
                    style: PixelType.small(context, color: PixelPalette.slate),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cosmetics(
    BuildContext context,
    PixelGrid grid,
    CosmeticsState state,
    int points,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: PixelLoader(label: 'Loading shop'));
    }
    if (state.error != null && state.items.isEmpty) {
      return _errorPanel(context, grid, state.error!, () {
        ref.read(cosmeticsProvider.notifier).load();
      });
    }
    if (state.items.isEmpty) {
      return const PixelEmptyState(
        key: ValueKey('shop_cosmetics_empty'),
        title: 'No cosmetics yet',
        message: 'Check back soon for new looks.',
      );
    }
    final live = _liveGrid ?? !MediaQuery.of(context).disableAnimations;
    final visibleItems =
        state.items.where((item) => item.kind == _filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final filter in _filters)
              _pill(
                context,
                grid,
                key: ValueKey('shop_filter_${filter.$1}'),
                label: filter.$2,
                active: _filter == filter.$1,
                onTap: () => setState(() => _filter = filter.$1),
              ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        Row(
          children: [
            Expanded(
              child: Text(
                live ? 'Live animations: On' : 'Live animations: Off',
                style: PixelType.body(context),
              ),
            ),
            PixelSwitch(
              key: const ValueKey('shop_live_animations'),
              value: live,
              semanticLabel: 'Live animations',
              onChanged: (on) => setState(() => _liveGrid = on),
            ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PixelSectionTitle(
                _filters.firstWhere((f) => f.$1 == _filter).$2,
                icon: DesignerArt.gem,
                value: '${visibleItems.length}',
                valueColor: PixelPalette.greenDark,
              ),
              SizedBox(height: grid.px(1)),
              for (var i = 0; i < visibleItems.length; i++) ...[
                if (i > 0)
                  Container(height: grid.unit, color: PixelPalette.paperDim),
                _cosmeticCard(context, grid, visibleItems[i], points, live),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _cosmeticCard(
    BuildContext context,
    PixelGrid grid,
    CosmeticItem item,
    int points,
    bool live,
  ) {
    final banner = item.kind == 'banner';
    final details = Padding(
      padding: EdgeInsets.symmetric(vertical: grid.px(2)),
      child: Row(
        children: [
          if (!banner) ...[
            _cosmeticSwatch(context, grid, item),
            SizedBox(width: grid.px(2)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: PixelType.title(context)),
                SizedBox(height: grid.px(1)),
                Row(
                  children: [
                    if (item.rarity != 'common') ...[
                      const SizedBox.square(
                        dimension: 16,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: PixelSprite(DesignerArt.gem, scale: 1),
                        ),
                      ),
                      SizedBox(width: grid.px(1)),
                    ],
                    Expanded(
                      child: Text(
                        '${item.kind.replaceAll('_', ' ')} · ${item.rarity}',
                        style: PixelType.body(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ),
                  ],
                ),
                _priceView(
                  context,
                  item,
                  PixelType.numbers(
                    context,
                    color: item.owned
                        ? PixelPalette.greenDark
                        : PixelPalette.woodMid,
                  ),
                ),
              ],
            ),
          ),
          if (item.equipped)
            const PixelChip('Equipped',
                style: PixelBoxStyle.green, textColor: PixelPalette.white)
          else
            const PixelChip('PREVIEW >', style: PixelBoxStyle.parchment),
        ],
      ),
    );
    return GestureDetector(
      key: ValueKey('shop_cosmetic_${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _showCosmeticPreview(item, points),
      child: banner
          ? Padding(
              padding: EdgeInsets.only(top: grid.px(2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: grid.px(52),
                    child: ClipRect(
                      child: ProfileBanner(
                        asset: item.asset,
                        seed: item.seed,
                        height: grid.px(52),
                        animate: live,
                        forceMotion: _liveGrid == true,
                        child: item.asset['style'] == 'procedural'
                            ? Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(grid.px(1)),
                                  child: Text(
                                    'Procedural · animated',
                                    style: PixelType.small(
                                      context,
                                      color: PixelPalette.white,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  details,
                ],
              ),
            )
          : details,
    );
  }

  /// Small swatch for list rows; frames, titles and name colours use the
  /// traveler's own look.
  Widget _cosmeticSwatch(
      BuildContext context, PixelGrid grid, CosmeticItem item) {
    final user = ref.read(authProvider).user;
    final name = user?.displayName ?? 'Traveler';
    if (item.kind == 'banner') {
      return SizedBox(
        width: grid.px(24),
        height: grid.px(20),
        child: ClipRect(
          child: ProfileBanner(
            asset: item.asset,
            seed: item.seed,
            height: grid.px(20),
            animate: false,
          ),
        ),
      );
    }
    if (item.kind == 'frame') {
      return CosmeticAvatar(
          name: name,
          imageUrl: user?.avatarUrl,
          frame: item.asset,
          size: grid.px(20));
    }
    return SizedBox(
      width: grid.px(40),
      child: PixelPanel(
        style: PixelBoxStyle.slot,
        padding: 1,
        child: item.kind == 'name_color'
            ? Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.body(
                  context,
                  color: _assetColor(item.asset['color']) ?? PixelPalette.ink,
                ),
              )
            : Text(
                item.asset['text']?.toString() ?? 'Title',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: PixelType.small(context),
              ),
      ),
    );
  }

  /// Coin prices show as "<coin> 120" (owner 2026-11-17).
  Widget _priceView(BuildContext context, CosmeticItem item, TextStyle style) {
    if (!item.owned && item.pricePoints != null) {
      return MjdqAmount(item.pricePoints!, style: style);
    }
    return Text(_cosmeticPrice(item), style: style);
  }

  String _cosmeticPrice(CosmeticItem item) {
    if (item.owned) {
      return item.equipped ? 'Equipped' : 'Owned';
    }
    if (item.pricePoints != null) {
      return '${item.pricePoints} mJDQ';
    }
    if (item.priceTjdq != null) {
      return 'tJDQ · Coming soon';
    }
    if (item.unlock != null) {
      return 'Unlock: ${item.unlock!['title'] ?? item.unlock!['achievementId']}';
    }
    return item.lockedReason ?? 'Not for sale';
  }

  Color? _assetColor(dynamic v) {
    try {
      return Color(int.parse(v.toString().replaceFirst('#', '0xff')));
    } catch (_) {
      return null;
    }
  }

  void _showCosmeticPreview(CosmeticItem item, int points) {
    final cosmetics = ref.read(cosmeticsProvider);
    final user = ref.read(authProvider).user;
    final name = user?.displayName ?? 'Traveler';
    final avatar = user?.avatarUrl;
    final equipped = equippedLoadout(cosmetics.loadout,
        [...cosmetics.items, ...cosmetics.owned.map((o) => o.item)]);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Column(
              children: [
                PassportPreview(
                  selected: item,
                  equipped: equipped,
                  name: name,
                  avatarUrl: avatar,
                  actions: [
                    if (item.buyable && item.pricePoints != null) ...[
                      PixelButton(
                        key: const ValueKey('shop_buy_cosmetic'),
                        label: points < item.pricePoints!
                            ? 'Need ${item.pricePoints! - points} more points'
                            : 'Buy for ${item.pricePoints} points',
                        expand: true,
                        onPressed: points < item.pricePoints!
                            ? null
                            : () async {
                                if (!await _walletReady(item.name)) return;
                                final error = await ref
                                    .read(cosmeticsProvider.notifier)
                                    .purchase(item);
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                if (mounted) {
                                  showPixelToast(context,
                                      error ?? '${item.name} purchased.');
                                }
                              },
                      ),
                      SizedBox(height: PixelGrid.of(context).px(2)),
                    ],
                    if (item.owned) ...[
                      PixelButton(
                        key: const ValueKey('shop_equip_cosmetic'),
                        label: item.equipped ? 'Unequip' : 'Equip now',
                        expand: true,
                        onPressed: () async {
                          final error = await ref
                              .read(cosmeticsProvider.notifier)
                              .equip(item, clear: item.equipped);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          if (mounted && error != null) {
                            showPixelToast(context, error);
                          }
                        },
                      ),
                      SizedBox(height: PixelGrid.of(context).px(2)),
                    ],
                    if (!item.owned && !item.buyable) ...[
                      _priceView(
                        context,
                        item,
                        PixelType.body(context, color: PixelPalette.slate),
                      ),
                      SizedBox(height: PixelGrid.of(context).px(2)),
                    ],
                    if (item.owned) ...[
                      GestureDetector(
                        key: const ValueKey('passport_view_profile'),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.go('/profile');
                        },
                        child: Padding(
                          padding: EdgeInsets.all(PixelGrid.of(context).px(2)),
                          child: Text(
                            'View on my profile',
                            style: PixelType.body(
                              context,
                              color: PixelPalette.greenDark,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: PixelGrid.of(context).px(2)),
                    ],
                    PixelButton(
                      label: 'Close preview',
                      variant: PixelButtonVariant.secondary,
                      expand: true,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vouchers(
    BuildContext context,
    PixelGrid grid,
    VoucherState state,
    int points,
  ) {
    if (state.isLoading && state.vouchers.isEmpty) {
      return const Center(child: PixelLoader(label: 'Loading vouchers'));
    }
    if (state.error != null && state.vouchers.isEmpty) {
      return _errorPanel(context, grid, state.error!, () {
        ref.read(voucherProvider.notifier).fetchVouchers();
      });
    }
    if (state.vouchers.isEmpty) {
      return PixelEmptyState(
        key: const ValueKey('shop_vouchers_empty'),
        title: 'No active vouchers',
        message: 'Check back soon for new partner merchant offers.',
        action: PixelButton(
          label: 'Refresh',
          variant: PixelButtonVariant.secondary,
          onPressed: () => ref.read(voucherProvider.notifier).fetchVouchers(),
        ),
      );
    }
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            'Vouchers',
            icon: DesignerArt.handshake,
            value: '${state.vouchers.length}',
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(1)),
          for (var i = 0; i < state.vouchers.length; i++) ...[
            if (i > 0)
              Container(height: grid.unit, color: PixelPalette.paperDim),
            _voucherCard(context, grid, state.vouchers[i], points),
          ],
        ],
      ),
    );
  }

  Widget _voucherCard(
    BuildContext context,
    PixelGrid grid,
    VoucherModel voucher,
    int userPoints,
  ) {
    final canAfford = userPoints >= voucher.costPoints;
    return KeyedSubtree(
      key: ValueKey('shop_voucher_${voucher.id}'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (voucher.availability == 'preview') ...[
              const PixelChip(
                'Sample offer · Partner coming soon',
                style: PixelBoxStyle.gold,
              ),
              SizedBox(height: grid.px(2)),
            ],
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              children: [
                PixelChip(voucher.category.replaceAll('_', ' '),
                    style: PixelBoxStyle.slot),
                MjdqChip(
                  voucher.costPoints,
                  style: canAfford ? PixelBoxStyle.coin : PixelBoxStyle.slot,
                  textColor: canAfford ? PixelPalette.paper : PixelPalette.ink,
                ),
                if (voucher.remainingStock != null)
                  PixelChip(
                    voucher.isOutOfStock
                        ? 'Out of stock'
                        : '${voucher.remainingStock} left',
                    style: voucher.isOutOfStock
                        ? PixelBoxStyle.stone
                        : PixelBoxStyle.parchment,
                    textColor: voucher.isOutOfStock
                        ? PixelPalette.white
                        : PixelPalette.ink,
                  ),
                if (voucher.validDays != null)
                  PixelChip(
                    'Valid ${voucher.validDays}d',
                    style: PixelBoxStyle.slot,
                  ),
              ],
            ),
            SizedBox(height: grid.px(2)),
            Text(voucher.offerTitle, style: PixelType.title(context)),
            SizedBox(height: grid.px(1)),
            // v0.3.10: the shop name opens its public page.
            GestureDetector(
              key: ValueKey('shop_voucher_merchant_${voucher.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: voucher.merchantId.isEmpty
                  ? null
                  : () => openMerchantPage(context, voucher.merchantId),
              child: Text(
                voucher.merchantId.isEmpty
                    ? voucher.merchantName
                    : '${voucher.merchantName} >',
                style: PixelType.body(
                  context,
                  color: voucher.merchantId.isEmpty
                      ? PixelPalette.slate
                      : PixelPalette.greenDark,
                ),
              ),
            ),
            Text(
              voucher.location,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            if (voucher.description.isNotEmpty) ...[
              SizedBox(height: grid.px(2)),
              Text(
                voucher.description,
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
            ],
            SizedBox(height: grid.px(3)),
            if (!voucher.redeemable)
              Text(
                'Planned offer · ${voucher.costPoints} mJDQ · not redeemable yet',
                style: PixelType.body(
                  context,
                  color: PixelPalette.slate,
                ),
              )
            else
              PixelButton(
                key: ValueKey('shop_redeem_${voucher.id}'),
                label: voucher.isOutOfStock
                    ? 'Out of stock'
                    : canAfford
                        ? 'Redeem voucher'
                        : 'Need ${voucher.costPoints - userPoints} more mJDQ',
                expand: true,
                onPressed: canAfford && voucher.redeemable && !voucher.isOutOfStock
                    ? () async {
                        // Owner 2026-11-19: vouchers need no wallet.
                        _showVoucherConfirmationDialog(
                          context: context,
                          voucher: voucher,
                          userPoints: userPoints,
                        );
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _teasers(BuildContext context, PixelGrid grid, CosmeticsState state) {
    if (state.isLoading && state.teasers.isEmpty) {
      return const Center(child: PixelLoader(label: 'Loading teasers'));
    }
    if (state.teasers.isEmpty) {
      return const PixelEmptyState(
        key: ValueKey('shop_teasers_empty'),
        title: 'More is coming',
        message: 'More shop features are coming soon.',
      );
    }
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            'Coming soon',
            icon: DesignerArt.navShop,
            value: '${state.teasers.length}',
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(1)),
          for (var i = 0; i < state.teasers.length; i++) ...[
            if (i > 0)
              Container(height: grid.unit, color: PixelPalette.paperDim),
            _teaserCard(context, grid, state.teasers[i]),
          ],
        ],
      ),
    );
  }

  Widget _teaserCard(BuildContext context, PixelGrid grid, ShopTeaser teaser) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: grid.px(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              const PixelChip('Coming soon', style: PixelBoxStyle.slot),
              if (teaser.etaText != null)
                PixelChip(teaser.etaText!, style: PixelBoxStyle.gold),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(teaser.title, style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(
            teaser.description,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        ],
      ),
    );
  }

  Widget _myItems(
    BuildContext context,
    PixelGrid grid,
    CosmeticsState state,
    VoucherState voucherState,
    String name,
    String? avatar,
  ) {
    if (state.isLoading && state.owned.isEmpty) {
      return const Center(child: PixelLoader(label: 'Loading your items'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            _pill(context, grid,
                key: const ValueKey('shop_inv_look'),
                label: 'My Look',
                active: !_inventoryVouchers,
                onTap: () => setState(() => _inventoryVouchers = false)),
            _pill(context, grid,
                key: const ValueKey('shop_inv_vouchers'),
                label: 'My Vouchers',
                active: _inventoryVouchers,
                onTap: () => setState(() => _inventoryVouchers = true)),
          ],
        ),
        SizedBox(height: grid.px(3)),
        if (!_inventoryVouchers && state.owned.isEmpty)
          const PixelEmptyState(
            key: ValueKey('shop_owned_empty'),
            title: 'No cosmetics owned',
            message: 'Browse the shop to get started.',
          )
        else if (!_inventoryVouchers)
          for (final kind in const [
            'banner',
            'frame',
            'title',
            'name_color'
          ]) ...[
            if (state.owned.any((owned) => owned.item.kind == kind)) ...[
              PixelPanel(
                style: PixelBoxStyle.parchment,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PixelSectionTitle(
                      _kindLabel(kind),
                      icon: DesignerArt.gem,
                      value:
                          '${state.owned.where((o) => o.item.kind == kind).length}',
                      valueColor: PixelPalette.greenDark,
                    ),
                    SizedBox(height: grid.px(1)),
                    for (final entry in state.owned
                        .where((o) => o.item.kind == kind)
                        .toList()
                        .asMap()
                        .entries) ...[
                      if (entry.key > 0)
                        Container(
                          height: grid.unit,
                          color: PixelPalette.paperDim,
                        ),
                      GestureDetector(
                        key: ValueKey('shop_owned_${entry.value.item.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showCosmeticPreview(entry.value.item, 0),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                          child: Row(
                            children: [
                              _cosmeticSwatch(context, grid, entry.value.item),
                              SizedBox(width: grid.px(2)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.value.item.name,
                                        style: PixelType.title(context)),
                                    Text(
                                      entry.value.source == 'achievement'
                                          ? 'Achievement unlock'
                                          : entry.value.source == 'grant'
                                              ? 'Admin grant'
                                              : 'Purchased',
                                      style: PixelType.body(
                                        context,
                                        color: PixelPalette.slate,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: grid.px(1)),
                              PixelButton(
                                key: ValueKey(
                                    'shop_owned_equip_${entry.value.item.id}'),
                                label: entry.value.item.equipped
                                    ? 'Unequip'
                                    : 'Equip',
                                variant: PixelButtonVariant.secondary,
                                onPressed: () async {
                                  final error = await ref
                                      .read(cosmeticsProvider.notifier)
                                      .equip(entry.value.item,
                                          clear: entry.value.item.equipped);
                                  if (error != null && context.mounted) {
                                    showPixelToast(context, error);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: grid.px(2)),
            ],
          ],
        if (!_inventoryVouchers)
          const SizedBox.shrink()
        else if (voucherState.redeemedVouchers.isEmpty)
          PixelEmptyState(
            key: const ValueKey('shop_redeemed_empty'),
            title: 'No redeemed vouchers yet',
            message:
                'Complete quests to earn points and explore rewards from participating local merchants.',
            action: PixelButton(
              label: 'Browse merchant offers',
              variant: PixelButtonVariant.secondary,
              onPressed: () => setState(() => _selectedTab = 1),
            ),
          )
        else
          PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelSectionTitle(
                  'My vouchers',
                  icon: DesignerArt.handshake,
                  value: '${voucherState.redeemedVouchers.length}',
                  valueColor: PixelPalette.greenDark,
                ),
                SizedBox(height: grid.px(1)),
                for (var i = 0;
                    i < voucherState.redeemedVouchers.length;
                    i++) ...[
                  if (i > 0)
                    Container(
                      height: grid.unit,
                      color: PixelPalette.paperDim,
                    ),
                  _redeemedCard(
                      context, grid, voucherState.redeemedVouchers[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _redeemedCard(
      BuildContext context, PixelGrid grid, RedeemedVoucherModel redeemed) {
    return KeyedSubtree(
      key: ValueKey('shop_redeemed_${redeemed.code}'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                redeemed.usedAt == null
                    ? PixelChip(
                        tr(context, en: 'Ready to use', tl: 'Magagamit'),
                        style: PixelBoxStyle.green,
                        textColor: PixelPalette.white)
                    : PixelChip(tr(context, en: 'Used', tl: 'Nagamit na'),
                        style: PixelBoxStyle.stone),
                Text(
                  redeemed.usedAt == null
                      ? tr(context,
                          en: 'Show it at the shop counter',
                          tl: 'Ipakita sa counter ng tindahan')
                      : tr(context,
                          en: 'Confirmed by the shop',
                          tl: 'Kumpirmado ng tindahan'),
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
              ],
            ),
            SizedBox(height: grid.px(2)),
            Text(redeemed.offerTitle, style: PixelType.title(context)),
            Text(
              redeemed.merchantName,
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(2)),
            Wrap(
              spacing: grid.px(2),
              runSpacing: grid.px(2),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PixelChip(
                  redeemed.code,
                  style: PixelBoxStyle.slot,
                ),
                PixelButton(
                  key: ValueKey('shop_show_qr_${redeemed.code}'),
                  label: tr(context, en: 'Show QR', tl: 'Ipakita ang QR'),
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => _showRedeemedVoucherModal(context, redeemed),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPanel(
    BuildContext context,
    PixelGrid grid,
    String message,
    VoidCallback retry,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load the shop',
            style: PixelType.title(context, color: PixelPalette.white),
          ),
          SizedBox(height: grid.px(2)),
          Text(
            message,
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(3)),
          Align(
            alignment: Alignment.centerRight,
            child: PixelButton(
              key: const ValueKey('shop_error_retry'),
              label: 'Retry',
              onPressed: retry,
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
        'banner' => 'Banners',
        'frame' => 'Avatar frames',
        'title' => 'Titles',
        _ => 'Name colours',
      };
}
