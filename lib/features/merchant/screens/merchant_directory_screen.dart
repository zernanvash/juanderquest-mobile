import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../spots/models/spot_model.dart';
import '../models/merchant_models.dart';
import '../providers/merchant_hub_provider.dart';
import 'merchant_page_screen.dart';

/// Overridable location lookup for [MerchantDirectoryScreen] (used on "Near me").
final merchantDirectoryLocationProvider =
    Provider<Future<({double lat, double lng})?> Function()>((ref) {
  return () async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 6),
        );
        return (lat: p.latitude, lng: p.longitude);
      }
    } catch (_) {
      // Fall back cleanly when location is denied or unavailable.
    }
    return null;
  };
});

/// Plan 110b: Public partner directory (`GET /merchants`).
class MerchantDirectoryScreen extends ConsumerStatefulWidget {
  const MerchantDirectoryScreen({super.key});

  @override
  ConsumerState<MerchantDirectoryScreen> createState() =>
      _MerchantDirectoryScreenState();
}

class _MerchantDirectoryScreenState
    extends ConsumerState<MerchantDirectoryScreen> {
  static const _categories = <(String, String)>[
    ('', 'All'),
    ('dining', 'Dining'),
    ('cafe', 'Cafe'),
    ('pasalubong', 'Pasalubong'),
    ('crafts', 'Crafts'),
    ('hotel', 'Hotel'),
    ('tour', 'Tour'),
  ];

  final _searchCtrl = TextEditingController();
  final List<PublicMerchantItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  String _category = '';
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final targetPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await ref.read(merchantApiProvider).publicMerchants(
            q: _searchCtrl.text.trim(),
            category: _category.isEmpty ? null : _category,
            lat: _lat,
            lng: _lng,
            page: targetPage,
            limit: 20,
          );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = result.page;
        _total = result.total;
        _hasMore = result.hasMore;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _toggleNearMe() async {
    if (_lat != null && _lng != null) {
      setState(() {
        _lat = null;
        _lng = null;
      });
      await _load(reset: true);
      return;
    }
    final coords = await ref.read(merchantDirectoryLocationProvider)();
    if (!mounted) return;
    if (coords == null) {
      showPixelToast(
          context,
          tr(context,
              en: 'Location unavailable. Showing alphabetical order.',
              tl: 'Walang GPS. Nakalista nang alpabetikal.'));
      return;
    }
    setState(() {
      _lat = coords.lat;
      _lng = coords.lng;
    });
    await _load(reset: true);
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _category = '';
      _lat = null;
      _lng = null;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final nearMeActive = _lat != null && _lng != null;
    final hasFilter =
        _searchCtrl.text.trim().isNotEmpty || _category.isNotEmpty || nearMeActive;
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context, en: 'Partner shops', tl: 'Mga tindahan'),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: PixelPalette.green,
                    backgroundColor: PixelPalette.parchment,
                    onRefresh: () => _load(reset: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          grid.gutter,
                          grid.px(3),
                          grid.gutter,
                          grid.px(8) + MediaQuery.paddingOf(context).bottom),
                      children: [
                        PixelPanel(
                          style: PixelBoxStyle.parchment,
                          padding: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PixelTextField(
                                key: const ValueKey('directory_search_input'),
                                controller: _searchCtrl,
                                label: tr(context,
                                    en: 'Search partner shops',
                                    tl: 'Maghanap ng tindahan'),
                                hint: 'Bangus, coffee, Dagupan',
                                textInputAction: TextInputAction.search,
                              ),
                              SizedBox(height: grid.px(2)),
                              Wrap(
                                spacing: grid.px(2),
                                runSpacing: grid.px(1),
                                children: [
                                  PixelButton(
                                    key: const ValueKey(
                                        'directory_search_submit'),
                                    label: tr(context,
                                        en: 'Search', tl: 'Hanapin'),
                                    onPressed: _loading
                                        ? null
                                        : () => _load(reset: true),
                                  ),
                                  PixelButton(
                                    key: const ValueKey('directory_near_me'),
                                    label: nearMeActive
                                        ? tr(context,
                                            en: 'Near me (ON)',
                                            tl: 'Malapit (ON)')
                                        : tr(context,
                                            en: 'Near me', tl: 'Malapit'),
                                    variant: nearMeActive
                                        ? PixelButtonVariant.primary
                                        : PixelButtonVariant.secondary,
                                    onPressed: _loading ? null : _toggleNearMe,
                                  ),
                                  if (hasFilter)
                                    PixelButton(
                                      key: const ValueKey('directory_clear'),
                                      label: tr(context,
                                          en: 'Clear', tl: 'I-clear'),
                                      variant: PixelButtonVariant.ghost,
                                      onPressed: _clearFilters,
                                    ),
                                ],
                              ),
                              SizedBox(height: grid.px(2)),
                              Wrap(
                                spacing: grid.px(1),
                                runSpacing: grid.px(1),
                                children: [
                                  for (final cat in _categories)
                                    GestureDetector(
                                      key: ValueKey(
                                          'directory_cat_${cat.$1.isEmpty ? 'all' : cat.$1}'),
                                      onTap: () {
                                        setState(() => _category = cat.$1);
                                        _load(reset: true);
                                      },
                                      child: PixelChip(
                                        cat.$2,
                                        style: _category == cat.$1
                                            ? PixelBoxStyle.gold
                                            : PixelBoxStyle.slot,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
                        if (_loading && _items.isEmpty)
                          const Center(
                              child: PixelLoader(label: 'Finding shops'))
                        else if (_error != null && _items.isEmpty)
                          PixelEmptyState(
                            icon: DesignerArt.salakot,
                            title: tr(context,
                                en: 'Directory unavailable',
                                tl: 'Hindi makuha'),
                            message: tr(context,
                                en: 'Check your connection and try again.',
                                tl: 'Suriin ang koneksyon at subukang muli.'),
                            action: PixelButton(
                              label: tr(context,
                                  en: 'Retry', tl: 'Subukang muli'),
                              onPressed: () => _load(reset: true),
                            ),
                          )
                        else if (_items.isEmpty)
                          PixelEmptyState(
                            key: const ValueKey('directory_empty'),
                            icon: DesignerArt.salakot,
                            title: tr(context,
                                en: 'No matching shops',
                                tl: 'Walang nahanap na tindahan'),
                            message: tr(context,
                                en: 'Try clearing your filters or searching another town.',
                                tl: 'Subukang palitan ang filter.'),
                          )
                        else ...[
                          Text(
                            tr(context,
                                en: '$_total partner shops',
                                tl: '$_total na partner shop'),
                            style: PixelType.small(context,
                                color: PixelPalette.slate),
                          ),
                          SizedBox(height: grid.px(2)),
                          for (final item in _items) ...[
                            _merchantCard(context, grid, item),
                            SizedBox(height: grid.px(2)),
                          ],
                          if (_hasMore)
                            PixelButton(
                              key: const ValueKey('directory_load_more'),
                              label: tr(context,
                                  en: 'Load more', tl: 'Mag-load pa'),
                              variant: PixelButtonVariant.secondary,
                              loading: _loadingMore,
                              expand: true,
                              onPressed:
                                  _loadingMore ? null : () => _load(reset: false),
                            ),
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

  Widget _merchantCard(
    BuildContext context,
    PixelGrid grid,
    PublicMerchantItem item,
  ) {
    final subtitle = [
      if (item.municipality != null) item.municipality!,
      if (item.category != null) item.category!,
    ].join(' · ');
    return GestureDetector(
      key: ValueKey('directory_merchant_${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openMerchantPage(context, item.id),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelPanel(
                  style: PixelBoxStyle.slot.copyWith(fill: PixelPalette.white),
                  padding: 1,
                  child: SizedBox.square(
                    dimension: 40,
                    child: item.logoUrl != null
                        ? Image.network(
                            SpotModel.resolveImageUrl(item.logoUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const FittedBox(
                                child: PixelSprite(DesignerArt.salakot,
                                    scale: 1)),
                          )
                        : const FittedBox(
                            child: PixelSprite(DesignerArt.salakot, scale: 1)),
                  ),
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: PixelType.title(context)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: PixelType.small(context,
                                color: PixelPalette.slate)),
                    ],
                  ),
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              SizedBox(height: grid.px(1)),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
            ],
            if (item.distanceLabel != null ||
                item.activeVoucherCount > 0 ||
                item.hasActiveSuki) ...[
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(1),
                runSpacing: grid.px(1),
                children: [
                  if (item.distanceLabel != null)
                    PixelChip(item.distanceLabel!, style: PixelBoxStyle.slot),
                  if (item.activeVoucherCount > 0)
                    PixelChip('${item.activeVoucherCount} offers',
                        style: PixelBoxStyle.gold),
                  if (item.hasActiveSuki)
                    const PixelChip(
                      'Suki Card',
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
