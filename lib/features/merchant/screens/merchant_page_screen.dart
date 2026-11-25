import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../suki/screens/suki_card_screen.dart';
import '../models/merchant_page.dart';

/// `GET /merchants/:id` for the public merchant page.
final merchantPageProvider = FutureProvider.autoDispose
    .family<MerchantPageData, String>((ref, id) async {
  final response = await ref
      .read(apiClientProvider)
      .dio
      .get('/merchants/${Uri.encodeComponent(id)}');
  final body = response.data;
  final data = body is Map ? body['data'] : null;
  return MerchantPageData.fromJson(
    data is Map ? Map<String, dynamic>.from(data) : const {},
  );
});

/// Opens a shop's public page over the current screen. A page route (not a
/// shell route), so it opens the same way from Shop, quests or the hub.
Future<void> openMerchantPage(BuildContext context, String merchantId) async {
  if (merchantId.isEmpty) return;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => MerchantPageScreen(merchantId: merchantId),
    ),
  );
}

/// v0.3.10 ("create a merchants page too that show all the detail for that
/// merchant"): cover, logo, details, specialties, products, vouchers, where
/// it is, and the viewer's Suki card at this shop.
class MerchantPageScreen extends ConsumerWidget {
  const MerchantPageScreen({super.key, required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantPageProvider(merchantId));
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
                    title: state.valueOrNull?.name ??
                        tr(context, en: 'Shop', tl: 'Tindahan'),
                    onBack: Navigator.of(context).canPop()
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: state.when(
                      loading: () => Center(
                        child: PixelLoader(
                          label: tr(
                            context,
                            en: 'Loading shop',
                            tl: 'Kinukuha ang tindahan',
                          ),
                        ),
                      ),
                      error: (error, _) => Center(
                        child: PixelEmptyState(
                          key: const ValueKey('merchant_page_error'),
                          icon: DesignerArt.salakot,
                          title: _notFound(error)
                              ? tr(
                                  context,
                                  en: 'Shop not found',
                                  tl: 'Walang nahanap na tindahan',
                                )
                              : tr(
                                  context,
                                  en: 'Shop unavailable',
                                  tl: 'Hindi makuha ang tindahan',
                                ),
                          message: _notFound(error)
                              ? tr(
                                  context,
                                  en: 'This shop is not open on JuanderQuest.',
                                  tl: 'Wala sa JuanderQuest ang tindahang ito.',
                                )
                              : tr(
                                  context,
                                  en: 'Check your connection and try again.',
                                  tl: 'Suriin ang koneksyon at subukang muli.',
                                ),
                          action: _notFound(error)
                              ? null
                              : PixelButton(
                                  key: const ValueKey('merchant_page_retry'),
                                  label: tr(
                                    context,
                                    en: 'Retry',
                                    tl: 'Subukang muli',
                                  ),
                                  onPressed: () => ref.invalidate(
                                    merchantPageProvider(merchantId),
                                  ),
                                ),
                        ),
                      ),
                      data: (page) => RefreshIndicator(
                        color: PixelPalette.green,
                        backgroundColor: PixelPalette.parchment,
                        onRefresh: () async {
                          ref.invalidate(merchantPageProvider(merchantId));
                          try {
                            await ref.read(
                              merchantPageProvider(merchantId).future,
                            );
                          } catch (_) {
                            // The error state shows it.
                          }
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            grid.gutter,
                            grid.px(3),
                            grid.gutter,
                            grid.px(8) + MediaQuery.paddingOf(context).bottom,
                          ),
                          children: _sections(context, ref, grid, page),
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

  static bool _notFound(Object error) =>
      error is DioException && error.response?.statusCode == 404;

  List<Widget> _sections(
    BuildContext context,
    WidgetRef ref,
    PixelGrid grid,
    MerchantPageData page,
  ) {
    final gap = SizedBox(height: grid.px(3));
    return [
      if (page.bannerUrl != null) ...[_cover(grid, page.bannerUrl!), gap],
      _identity(context, grid, page),
      if (page.linkedSpot != null) ...[
        gap,
        _linkedSpotPanel(context, grid, page.linkedSpot!),
      ],
      gap,
      _suki(context, ref, grid, page),
      if (page.specialties.isNotEmpty) ...[
        gap,
        _productsPanel(
          context,
          grid,
          key: const ValueKey('merchant_page_specialties'),
          title: tr(context, en: 'Specialties', tl: 'Espesyalidad'),
          icon: DesignerArt.gem,
          items: page.specialties,
        ),
      ],
      if (page.products.isNotEmpty) ...[
        gap,
        _productsPanel(
          context,
          grid,
          key: const ValueKey('merchant_page_products'),
          title: tr(context, en: 'Products', tl: 'Mga produkto'),
          icon: DesignerArt.navShop,
          items: page.products,
        ),
      ],
      if (page.vouchers.isNotEmpty) ...[gap, _vouchers(context, grid, page)],
    ];
  }

  Widget _linkedSpotPanel(
    BuildContext context,
    PixelGrid grid,
    MerchantPageLinkedSpot spot,
  ) {
    return PixelPanel(
      key: const ValueKey('merchant_page_linked_spot'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LINKED DESTINATION',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(0.5)),
          Text(
            spot.name,
            style: PixelType.body(
              context,
              color: PixelPalette.ink,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          if (spot.municipality.isNotEmpty)
            Text(
              spot.municipality,
              style: PixelType.small(context, color: PixelPalette.woodDeep),
            ),
          SizedBox(height: grid.px(1.5)),
          Wrap(
            spacing: grid.px(1.5),
            runSpacing: grid.px(1.5),
            children: [
              PixelButton(
                key: const ValueKey('merchant_linked_view_map_btn'),
                label: 'VIEW ON MAP',
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/map?spot=${spot.slug}'),
              ),
              PixelButton(
                key: const ValueKey('merchant_linked_navigate_btn'),
                label: 'NAVIGATE',
                variant: PixelButtonVariant.primary,
                onPressed: () => context.push(
                  Uri(
                    path: '/navigate',
                    queryParameters: {
                      'lat': spot.gpsLat.toString(),
                      'lng': spot.gpsLng.toString(),
                      'name': spot.name,
                      if (spot.municipality.isNotEmpty)
                        'town': spot.municipality,
                    },
                  ).toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cover(PixelGrid grid, String url) => PixelPanel(
        key: const ValueKey('merchant_page_cover'),
        style: PixelBoxStyle.slot,
        padding: 1,
        child: SizedBox(
          height: 150,
          width: double.infinity,
          child: Image.network(
            SpotModel.resolveImageUrl(url),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: PixelPalette.paperDim,
              child: Center(child: PixelSprite(DesignerArt.navShop, scale: 3)),
            ),
          ),
        ),
      );

  Widget _identity(BuildContext context, PixelGrid grid, MerchantPageData p) {
    final line = [
      if (p.municipality != null) p.municipality!,
      if (p.category != null) p.category!,
    ].join(' · ');
    Widget fact(String label, String value) => Padding(
          padding: EdgeInsets.only(top: grid.px(1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              SelectableText(value, style: PixelType.body(context)),
            ],
          ),
        );
    return PixelPanel(
      key: const ValueKey('merchant_page_identity'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.logoUrl != null) ...[
                PixelPanel(
                  style: PixelBoxStyle.slot.copyWith(fill: PixelPalette.white),
                  padding: 1,
                  child: SizedBox.square(
                    dimension: 48,
                    child: Image.network(
                      SpotModel.resolveImageUrl(p.logoUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const FittedBox(
                        child: PixelSprite(DesignerArt.salakot, scale: 1),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: grid.px(2)),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: PixelType.title(context)),
                    if (line.isNotEmpty)
                      Text(
                        line,
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
          if (!p.isPublished) ...[
            SizedBox(height: grid.px(2)),
            PixelChip(
              tr(
                context,
                en: 'DRAFT: only your team sees this page',
                tl: 'DRAFT: kayo lang ang nakakakita',
              ),
              key: const ValueKey('merchant_page_draft'),
              style: PixelBoxStyle.stone,
              textColor: PixelPalette.white,
            ),
          ],
          if (p.description.isNotEmpty) ...[
            SizedBox(height: grid.px(2)),
            Text(p.description, style: PixelType.body(context)),
          ],
          if (p.location != null)
            fact(tr(context, en: 'WHERE', tl: 'SAAN'), p.location!),
          if (p.contactPhone != null)
            fact(tr(context, en: 'PHONE', tl: 'TELEPONO'), p.contactPhone!),
          if (p.contactEmail != null)
            fact(tr(context, en: 'EMAIL', tl: 'EMAIL'), p.contactEmail!),
          if (p.hasLocation) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('merchant_page_directions'),
              label: tr(context, en: 'Directions', tl: 'Direksyon'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: () {
                final router = GoRouter.maybeOf(context);
                router?.push(
                  Uri(
                    path: '/navigate',
                    queryParameters: {
                      'lat': '${p.lat}',
                      'lng': '${p.lng}',
                      'name': p.name,
                    },
                  ).toString(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _suki(
    BuildContext context,
    WidgetRef ref,
    PixelGrid grid,
    MerchantPageData p,
  ) {
    final s = p.suki;
    final String message;
    String? button;
    if (!s.enabled) {
      message = tr(
        context,
        en: 'Suki Cards are coming soon.',
        tl: 'Malapit na ang Suki Cards.',
      );
    } else if (!s.hasProgram) {
      message = tr(
        context,
        en: 'This shop has no Suki Card yet.',
        tl: 'Wala pang Suki Card ang tindahang ito.',
      );
    } else if (p.isMember) {
      message = tr(
        context,
        en: 'This is your shop\'s Suki Card: ${s.visitsRequired} visits for ${s.rewardText ?? 'a reward'}.',
        tl: 'Suki Card ng tindahan mo: ${s.visitsRequired} bisita para sa ${s.rewardText ?? 'reward'}.',
      );
    } else if (s.hasCard) {
      message = tr(
        context,
        en: 'Your card: ${s.visits} of ${s.required} visits for ${s.rewardText ?? 'the reward'}.',
        tl: 'Card mo: ${s.visits} sa ${s.required} bisita para sa ${s.rewardText ?? 'reward'}.',
      );
      button = tr(context, en: 'Open my card', tl: 'Buksan ang card');
    } else {
      message = tr(
        context,
        en: 'Get a Suki card: ${s.visitsRequired} visits for ${s.rewardText ?? 'a reward'}.',
        tl: 'Kumuha ng Suki card: ${s.visitsRequired} bisita para sa ${s.rewardText ?? 'reward'}.',
      );
      button = tr(context, en: 'Get a Suki card', tl: 'Kumuha ng Suki card');
    }
    final required = s.required ?? 0;
    return PixelPanel(
      key: const ValueKey('merchant_page_suki'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'Suki Card', tl: 'Suki Card'),
            icon: DesignerArt.handshake,
            value: s.rewardTag,
            valueColor: PixelPalette.greenDark,
          ),
          SizedBox(height: grid.px(1)),
          Text(
            message,
            key: const ValueKey('merchant_page_suki_status'),
            style: PixelType.body(context),
          ),
          if (s.hasCard && required > 0) ...[
            SizedBox(height: grid.px(1)),
            PixelProgressBar(value: (s.visits ?? 0) / required),
          ],
          if (button != null) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('merchant_page_suki_open'),
              label: button,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SukiCardScreen(programId: s.programId!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _productsPanel(
    BuildContext context,
    PixelGrid grid, {
    required Key key,
    required String title,
    required PixelArt icon,
    required List<MerchantPageProduct> items,
  }) {
    return PixelPanel(
      key: key,
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            title,
            icon: icon,
            value: '${items.length}',
            valueColor: PixelPalette.greenDark,
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(height: grid.unit, color: PixelPalette.paperDim),
            Padding(
              key: ValueKey('merchant_page_product_${items[i].id}'),
              padding: EdgeInsets.symmetric(vertical: grid.px(2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(items[i].name, style: PixelType.body(context)),
                  if (items[i].isSpecialty || items[i].priceLabel != null) ...[
                    SizedBox(height: grid.px(1)),
                    Wrap(
                      spacing: grid.px(2),
                      runSpacing: grid.px(1),
                      children: [
                        if (items[i].isSpecialty)
                          PixelChip(
                            tr(context, en: 'SPECIALTY', tl: 'ESPESYAL'),
                            style: PixelBoxStyle.gold,
                          ),
                        if (items[i].priceLabel != null)
                          PixelChip(
                            items[i].priceLabel!,
                            style: PixelBoxStyle.parchment,
                          ),
                      ],
                    ),
                  ],
                  if (items[i].description.isNotEmpty) ...[
                    SizedBox(height: grid.px(1)),
                    Text(
                      items[i].description,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.slate,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vouchers(BuildContext context, PixelGrid grid, MerchantPageData p) {
    return PixelPanel(
      key: const ValueKey('merchant_page_vouchers'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'Vouchers', tl: 'Mga voucher'),
            icon: DesignerArt.handshake,
            value: '${p.vouchers.length}',
            valueColor: PixelPalette.greenDark,
          ),
          for (final v in p.vouchers)
            Padding(
              padding: EdgeInsets.symmetric(vertical: grid.px(1)),
              child: Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(1),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(v.title, style: PixelType.body(context)),
                  PixelChip('${v.costPoints} pts', style: PixelBoxStyle.gold),
                ],
              ),
            ),
          SizedBox(height: grid.px(1)),
          Text(
            tr(
              context,
              en: 'Redeem them in Shop > Partner Vouchers, then show the code at the counter.',
              tl: 'I-redeem sa Shop > Partner Vouchers at ipakita ang code sa counter.',
            ),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
      ),
    );
  }
}
