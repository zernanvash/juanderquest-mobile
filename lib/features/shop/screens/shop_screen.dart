import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cosmetics/widgets/passport_preview.dart';
import '../../cosmetics/widgets/profile_banner.dart';
import '../../cosmetics/widgets/cosmetic_avatar.dart';
import '../../wallet/screens/wallet_connect_screen.dart';
import '../models/cosmetic_item.dart';
import '../models/shop_teaser.dart';
import '../models/voucher_model.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/voucher_provider.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  static const _tabs = <(int, String)>[
    (0, 'Cosmetics'),
    (1, 'Vouchers'),
    (2, 'Coming soon'),
    (3, 'My items'),
  ];

  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('banner', 'Banners'),
    ('frame', 'Frames'),
    ('title', 'Titles'),
    ('name_color', 'Name colours'),
  ];

  int _selectedTab = 0; // Cosmetics, Vouchers, Coming soon, My items
  String _filter = 'all';
  bool? _liveGrid; // null: follow the system animation setting (Plan 69)

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(voucherProvider.notifier).fetchVouchers();
      ref.read(cosmeticsProvider.notifier).load();
    });
  }

  /// Plan 67: browsing is open to everyone; buying needs a linked wallet.
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
                    Text('Cost deduction',
                        style: PixelType.body(context)),
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
                  UiSpecContainer(
                    spec: const UiSpec(
                      title: 'In-Person Store Cashier Barcode & QR Box',
                      figmaLayer: '#Voucher_QR_Redemption_Box',
                      dimensions: 'Width: 100%, Height: ~80dp, Padding: 12dp',
                      dataBinding: 'redeemedVoucher.code / expirationTimestamp',
                      stateNotes:
                          'Displays 1D barcode stripes & QR scan box for retail cashier terminal',
                      uxNotes:
                          'Ensure screen backlight brightness is sufficient for optical scanners.',
                      deferred: true,
                    ),
                    child: PixelPanel(
                      style: PixelBoxStyle.slot.copyWith(
                        fill: PixelPalette.white,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              24,
                              (index) => Container(
                                width: index % 3 == 0
                                    ? 3
                                    : (index % 2 == 0 ? 2 : 1),
                                height: 38,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1.5),
                                color: PixelPalette.ink,
                              ),
                            ),
                          ),
                          SizedBox(height: PixelGrid.of(modalCtx).px(1)),
                          Text(
                            'Present this barcode/code to the store cashier',
                            textAlign: TextAlign.center,
                            style: PixelType.small(
                              modalCtx,
                              color: PixelPalette.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: PixelGrid.of(modalCtx).px(3)),
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
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Traveler Shop',
                    onBack: null,
                    actions: [
                      PixelChip('$points mJDQ', style: PixelBoxStyle.gold),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _header(context, grid, points),
                        SizedBox(height: grid.px(3)),
                        _tabRow(context, grid),
                        SizedBox(height: grid.px(3)),
                        if (_selectedTab == 0)
                          _cosmetics(context, grid, cosmeticsState, points)
                        else if (_selectedTab == 1)
                          _vouchers(context, grid, voucherState, points)
                        else if (_selectedTab == 2)
                          _teasers(context, grid, cosmeticsState)
                        else
                          _myItems(context, grid, cosmeticsState,
                              voucherState, user?.displayName ?? 'Traveler',
                              user?.avatarUrl),
                      ],
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

  Widget _header(BuildContext context, PixelGrid grid, int points) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make your profile yours',
            style: PixelType.small(context, color: PixelPalette.sun),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Traveler shop',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'Collect Pangasinan-inspired cosmetics, partner offers, and upcoming experiences.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelChip('$points points', style: PixelBoxStyle.gold),
              if (ref.watch(authProvider).user?.hasBoundWallet != true)
                const PixelChip('No wallet',
                    style: PixelBoxStyle.parchment),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabRow(BuildContext context, PixelGrid grid) {
    return Wrap(
      spacing: grid.px(2),
      runSpacing: grid.px(2),
      children: [
        for (final tab in _tabs)
          GestureDetector(
            key: ValueKey('shop_tab_${tab.$1}'),
            onTap: () {
              pixelTick(context);
              setState(() => _selectedTab = tab.$1);
            },
            child: PixelPanel(
              style: (_selectedTab == tab.$1
                      ? PixelBoxStyle.green
                      : PixelBoxStyle.parchment)
                  .copyWith(corner: 1, shadowPx: 1),
              padding: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: grid.px(2),
                  vertical: grid.px(1),
                ),
                child: Text(
                  tab.$2,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: PixelType.small(
                    context,
                    color: _selectedTab == tab.$1
                        ? PixelPalette.white
                        : PixelPalette.ink,
                  ),
                ),
              ),
            ),
          ),
      ],
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
    final visibleItems = state.items
        .where((item) => _filter == 'all' || item.kind == _filter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final filter in _filters)
              GestureDetector(
                key: ValueKey('shop_filter_${filter.$1}'),
                onTap: () {
                  pixelTick(context);
                  setState(() => _filter = filter.$1);
                },
                child: PixelPanel(
                  style: (_filter == filter.$1
                          ? PixelBoxStyle.gold
                          : PixelBoxStyle.slot)
                      .copyWith(corner: 1, shadowPx: 0),
                  padding: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: grid.px(2),
                      vertical: grid.px(1),
                    ),
                    child: Text(
                      filter.$2,
                      style: PixelType.small(context),
                    ),
                  ),
                ),
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
        for (var i = 0; i < visibleItems.length; i++) ...[
          if (i > 0) SizedBox(height: grid.px(2)),
          _cosmeticCard(context, grid, visibleItems[i], points, live),
        ],
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
      padding: EdgeInsets.all(grid.px(2)),
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
                Text(
                  '${item.kind.replaceAll('_', ' ')} · ${item.rarity}',
                  style: PixelType.body(
                    context,
                    color: PixelPalette.slate,
                  ),
                ),
                Text(
                  _cosmeticPrice(item),
                  style: PixelType.numbers(
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
            const PixelChip('Equipped', style: PixelBoxStyle.green,
                textColor: PixelPalette.white),
        ],
      ),
    );
    return GestureDetector(
      key: ValueKey('shop_cosmetic_${item.id}'),
      onTap: () => _showCosmeticPreview(item, points),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: banner
            ? Column(
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
              )
            : details,
      ),
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

  String _cosmeticPrice(CosmeticItem item) {
    if (item.owned) {
      return item.equipped ? 'Equipped' : 'Owned';
    }
    if (item.pricePoints != null) {
      return '${item.pricePoints} points';
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
                      Text(
                        _cosmeticPrice(item),
                        style: PixelType.body(
                          context,
                          color: PixelPalette.slate,
                        ),
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
                          padding: EdgeInsets.all(
                              PixelGrid.of(context).px(2)),
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
          onPressed: () =>
              ref.read(voucherProvider.notifier).fetchVouchers(),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < state.vouchers.length; i++) ...[
          if (i > 0) SizedBox(height: grid.px(2)),
          _voucherCard(context, grid, state.vouchers[i], points),
        ],
      ],
    );
  }

  Widget _voucherCard(
    BuildContext context,
    PixelGrid grid,
    VoucherModel voucher,
    int userPoints,
  ) {
    final canAfford = userPoints >= voucher.costPoints;
    return PixelPanel(
      key: ValueKey('shop_voucher_${voucher.id}'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (voucher.availability == 'preview') ...[
            PixelPanel(
              style: PixelBoxStyle.gold.copyWith(shadowPx: 0),
              padding: 1,
              child: Text(
                'Sample offer · Partner coming soon',
                textAlign: TextAlign.center,
                style: PixelType.small(context),
              ),
            ),
            SizedBox(height: grid.px(2)),
          ],
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelChip(voucher.category.replaceAll('_', ' '),
                  style: PixelBoxStyle.slot),
              PixelChip(
                '${voucher.costPoints} pts',
                style: canAfford
                    ? PixelBoxStyle.gold
                    : PixelBoxStyle.slot,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(voucher.offerTitle, style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          Text(
            voucher.merchantName,
            style: PixelType.body(context, color: PixelPalette.slate),
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
              'Planned offer · ${voucher.costPoints} points · not redeemable yet',
              style: PixelType.body(
                context,
                color: PixelPalette.slate,
              ),
            )
          else
            PixelButton(
              key: ValueKey('shop_redeem_${voucher.id}'),
              label: canAfford
                  ? 'Redeem voucher'
                  : 'Need ${voucher.costPoints - userPoints} more points',
              expand: true,
              onPressed: canAfford && voucher.redeemable
                  ? () async {
                      if (!await _walletReady(voucher.offerTitle) ||
                          !context.mounted) {
                        return;
                      }
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
    );
  }

  Widget _teasers(
      BuildContext context, PixelGrid grid, CosmeticsState state) {
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
    return Column(
      children: [
        for (var i = 0; i < state.teasers.length; i++) ...[
          if (i > 0) SizedBox(height: grid.px(2)),
          _teaserCard(context, grid, state.teasers[i]),
        ],
      ],
    );
  }

  Widget _teaserCard(BuildContext context, PixelGrid grid, ShopTeaser teaser) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelChip(teaser.etaText ?? 'Coming soon',
              style: PixelBoxStyle.gold),
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
        if (state.owned.isEmpty)
          const PixelEmptyState(
            key: ValueKey('shop_owned_empty'),
            title: 'No cosmetics owned',
            message: 'Browse the shop to get started.',
          )
        else
          for (final kind in const [
            'banner',
            'frame',
            'title',
            'name_color'
          ]) ...[
            if (state.owned.any((owned) => owned.item.kind == kind)) ...[
              Text(
                _kindLabel(kind),
                style: PixelType.title(context),
              ),
              SizedBox(height: grid.px(2)),
              for (final owned
                  in state.owned.where((o) => o.item.kind == kind)) ...[
                GestureDetector(
                  key: ValueKey('shop_owned_${owned.item.id}'),
                  onTap: () => _showCosmeticPreview(owned.item, 0),
                  child: PixelPanel(
                    style: PixelBoxStyle.parchment,
                    child: Row(
                      children: [
                        _cosmeticSwatch(context, grid, owned.item),
                        SizedBox(width: grid.px(2)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(owned.item.name,
                                  style: PixelType.title(context)),
                              Text(
                                owned.source == 'achievement'
                                    ? 'Achievement unlock'
                                    : owned.source == 'grant'
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
                              'shop_owned_equip_${owned.item.id}'),
                          label: owned.item.equipped ? 'Unequip' : 'Equip',
                          variant: PixelButtonVariant.secondary,
                          onPressed: () async {
                            final error = await ref
                                .read(cosmeticsProvider.notifier)
                                .equip(owned.item,
                                    clear: owned.item.equipped);
                            if (error != null && context.mounted) {
                              showPixelToast(context, error);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: grid.px(2)),
              ],
            ],
          ],
        SizedBox(height: grid.px(3)),
        Text('Redeemed vouchers', style: PixelType.title(context)),
        SizedBox(height: grid.px(2)),
        if (voucherState.redeemedVouchers.isEmpty)
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
          for (final redeemed in voucherState.redeemedVouchers) ...[
            _redeemedCard(context, grid, redeemed),
            SizedBox(height: grid.px(2)),
          ],
      ],
    );
  }

  Widget _redeemedCard(
      BuildContext context, PixelGrid grid, RedeemedVoucherModel redeemed) {
    return PixelPanel(
      key: ValueKey('shop_redeemed_${redeemed.code}'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PixelChip('Active voucher', style: PixelBoxStyle.green,
                  textColor: PixelPalette.white),
              Text(
                'Expires in 30 days',
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
              PixelPanel(
                style: PixelBoxStyle.slot,
                padding: 1,
                child: Text(
                  redeemed.code,
                  style: PixelType.numbers(context),
                ),
              ),
              PixelButton(
                key: ValueKey('shop_show_barcode_${redeemed.code}'),
                label: 'Show Barcode',
                variant: PixelButtonVariant.secondary,
                onPressed: () =>
                    _showRedeemedVoucherModal(context, redeemed),
              ),
            ],
          ),
        ],
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
