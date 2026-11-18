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
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../quests/widgets/sponsorship_conditions_widgets.dart';
import '../models/merchant_models.dart';
import '../providers/merchant_hub_provider.dart';
import '../suki/merchant_loyalty_tab.dart';
import '../suki/suki_badge_art.dart';
import '../widgets/merchant_pixel_art.dart';

const merchantTabNames = [
  'overview',
  'profile',
  'catalog',
  'sponsorships',
  'loyalty',
];

String _errorText(Object error, String fallback) {
  if (error is DioException) {
    final body = error.response?.data;
    final message = body is Map && body['error'] is Map
        ? body['error']['message']?.toString()
        : null;
    if (message != null && message.isNotEmpty) return message;
  }
  return fallback;
}

String _errorCode(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['error'] is Map) {
      return body['error']['code']?.toString() ?? '';
    }
  }
  return '';
}

/// Plan 95 stage 3: the approved merchant's workspace.
class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key, this.initialTab = 'overview'});

  final String initialTab;

  @override
  ConsumerState<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState
    extends ConsumerState<MerchantDashboardScreen> {
  late int _tab = merchantTabNames.indexOf(widget.initialTab).clamp(0, 4);
  MerchantDashboardData? _data;
  Object? _error;
  bool _loading = true;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(merchantApiProvider).dashboard();
      if (mounted) setState(() => (_data = data, _error = null));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePublish() async {
    final data = _data;
    if (data == null) return;
    setState(() => _publishing = true);
    try {
      await ref.read(merchantApiProvider).setPublished(!data.isPublished);
      ref.invalidate(merchantHubStatusProvider);
      await _load();
    } catch (error) {
      if (!mounted) return;
      showPixelToast(
        context,
        _errorText(error, 'Could not change publication.'),
      );
      if (_errorCode(error) == 'INCOMPLETE_PROFILE') setState(() => _tab = 1);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _openChecklistItem(String id) {
    switch (id) {
      case 'catalog_item':
        setState(() => _tab = 2);
      case 'publish_profile':
        _togglePublish();
      default:
        setState(() => _tab = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final data = _data;
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Merchant hub',
                    onBack: Navigator.of(context).canPop()
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: _loading && data == null
                        ? const Center(
                            child: PixelLoader(label: 'Loading workspace'),
                          )
                        : data == null
                            ? PixelEmptyState(
                                icon: DesignerArt.salakot,
                                title: 'Workspace unavailable',
                                message: _errorText(
                                  _error ?? '',
                                  'Check your connection and try again.',
                                ),
                                action: PixelButton(
                                  key: const ValueKey('merchant_retry'),
                                  label: 'Retry',
                                  onPressed: _load,
                                ),
                              )
                            : ListView(
                                padding: EdgeInsets.fromLTRB(
                                  grid.gutter,
                                  grid.px(4),
                                  grid.gutter,
                                  grid.px(8) +
                                      MediaQuery.paddingOf(context).bottom,
                                ),
                                children: [
                                  _identity(context, grid, data),
                                  SizedBox(height: grid.px(4)),
                                  MerchantTabbedPanel(
                                    selected: _tab,
                                    onSelect: (i) {
                                      pixelTick(context);
                                      setState(() => _tab = i);
                                    },
                                    tabs: [
                                      const MerchantTab(
                                        key: ValueKey('merchant_tab_overview'),
                                        icon: DesignerArt.navShop,
                                        label: 'Overview',
                                      ),
                                      const MerchantTab(
                                        key: ValueKey('merchant_tab_profile'),
                                        icon: DesignerArt.navProfile,
                                        label: 'Profile',
                                      ),
                                      MerchantTab(
                                        key: const ValueKey(
                                            'merchant_tab_catalog'),
                                        icon: merchantCatalogList,
                                        label: 'Catalog',
                                        badge: data.activeProducts > 0
                                            ? '${data.activeProducts}'
                                            : null,
                                      ),
                                      const MerchantTab(
                                        key: ValueKey(
                                            'merchant_tab_sponsorships'),
                                        icon: DesignerArt.handshake,
                                        label: 'Sponsorships & Points',
                                      ),
                                      // Plan 107: Suki Card setup + counter.
                                      const MerchantTab(
                                        key: ValueKey('merchant_tab_loyalty'),
                                        icon: SukiBadgeArt.sukiCard,
                                        label: 'Loyalty',
                                      ),
                                    ],
                                    child: switch (_tab) {
                                      1 => _ProfileTab(onSaved: _load),
                                      2 => _CatalogTab(onChanged: _load),
                                      3 => const _SponsorshipsTab(),
                                      4 => const MerchantLoyaltyTab(),
                                      _ => _overview(context, grid, data),
                                    },
                                  ),
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

  Widget _identity(
    BuildContext context,
    PixelGrid grid,
    MerchantDashboardData data,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelSectionTitle(
            data.name,
            icon: DesignerArt.salakot,
            colors: PixelText3DColors.cream,
          ),
          Text(
            [
              data.municipality,
              data.category,
            ].where((v) => v.isNotEmpty).join(' · '),
            style: PixelType.small(context, color: PixelPalette.cream),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelChip(
                data.isPublished ? 'PUBLISHED' : 'DRAFT',
                key: const ValueKey('merchant_publish_state'),
                style: data.isPublished
                    ? PixelBoxStyle.green
                    : PixelBoxStyle.stone,
                textColor: PixelPalette.white,
              ),
              PixelButton(
                key: const ValueKey('merchant_publish_toggle'),
                label: data.isPublished ? 'Unpublish' : 'Publish profile',
                variant: data.isPublished
                    ? PixelButtonVariant.secondary
                    : PixelButtonVariant.primary,
                loading: _publishing,
                onPressed: _publishing ? null : _togglePublish,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overview(
    BuildContext context,
    PixelGrid grid,
    MerchantDashboardData data,
  ) {
    Widget metric(String label, String value) => Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: grid.px(1)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
                Text(
                  value,
                  style:
                      PixelType.numbers(context, color: PixelPalette.greenDark),
                ),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PixelSectionTitle(
          'Storefront status',
          icon: DesignerArt.navShop,
        ),
        SizedBox(height: grid.px(2)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            metric('ACTIVE ITEMS', '${data.activeProducts}'),
            SizedBox(width: grid.px(2)),
            metric(
              'SETUP',
              '${data.completedCount} / ${data.checklist.length}',
            ),
          ],
        ),
        Container(height: grid.unit, color: PixelPalette.paperDim),
        SizedBox(height: grid.px(2)),
        Text(
          'SETUP CHECKLIST',
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(1)),
        for (var i = 0; i < data.checklist.length; i++) ...[
          if (i > 0) Container(height: grid.unit, color: PixelPalette.paperDim),
          Padding(
            padding: EdgeInsets.symmetric(vertical: grid.px(2)),
            child: Row(
              children: [
                PixelChip(
                  data.checklist[i].completed ? 'DONE' : 'TODO',
                  style: data.checklist[i].completed
                      ? PixelBoxStyle.green
                      : PixelBoxStyle.parchment,
                  textColor: data.checklist[i].completed
                      ? PixelPalette.white
                      : PixelPalette.ink,
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Text(data.checklist[i].title,
                      style: PixelType.body(context)),
                ),
                if (!data.checklist[i].completed)
                  PixelButton(
                    key: ValueKey('merchant_checklist_${data.checklist[i].id}'),
                    label: 'Do it',
                    variant: PixelButtonVariant.ghost,
                    onPressed: () => _openChecklistItem(data.checklist[i].id),
                  ),
              ],
            ),
          ),
        ],
        if (data.notice.isNotEmpty) ...[
          Container(height: grid.unit, color: PixelPalette.paperDim),
          SizedBox(height: grid.px(2)),
          Text(
            data.notice,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
      ],
    );
  }
}

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab({required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  static const _fields = [
    ('name', 'Establishment name', 1),
    ('location', 'Locality & landmark', 1),
    ('municipality', 'Municipality', 1),
    ('contact_email', 'Public inquiries email', 1),
    ('contact_phone', 'Public contact phone', 1),
    ('logo_url', 'Logo URL (optional)', 1),
    ('banner_url', 'Banner URL (optional)', 1),
    ('description', 'Description & visitor story', 4),
  ];
  final _controllers = {for (final f in _fields) f.$1: TextEditingController()};
  Map<String, dynamic> _original = const {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(merchantApiProvider).profile();
      if (!mounted) return;
      _original = profile;
      for (final entry in _controllers.entries) {
        entry.value.text = profile[entry.key]?.toString() ?? '';
      }
    } catch (_) {
      if (mounted) showPixelToast(context, 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    // Only send what changed: the API rejects an empty email or phone.
    final changes = <String, dynamic>{
      for (final entry in _controllers.entries)
        if (entry.value.text.trim() != (_original[entry.key]?.toString() ?? ''))
          entry.key: entry.value.text.trim(),
    };
    if (changes.isEmpty) {
      showPixelToast(context, 'Nothing to save.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(merchantApiProvider).saveProfile(changes);
      _original = {..._original, ...changes};
      if (!mounted) return;
      showPixelToast(context, 'Profile saved.');
      widget.onSaved();
    } catch (error) {
      if (mounted) {
        showPixelToast(context, _errorText(error, 'Could not save profile.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    if (_loading) return const PixelLoader(label: 'Loading profile');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PixelSectionTitle(
          'Profile · Showcase details',
          icon: DesignerArt.navProfile,
        ),
        SizedBox(height: grid.px(2)),
        for (final f in _fields) ...[
          PixelTextField(
            key: ValueKey('merchant_profile_${f.$1}'),
            controller: _controllers[f.$1],
            label: f.$2,
            maxLines: f.$3,
          ),
          SizedBox(height: grid.px(2)),
        ],
        PixelButton(
          key: const ValueKey('merchant_profile_save'),
          label: 'Save profile details',
          expand: true,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

class _CatalogTab extends ConsumerStatefulWidget {
  const _CatalogTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  List<MerchantProductItem>? _items;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(merchantApiProvider).products();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  Future<void> _edit(MerchantProductItem? item) async {
    final name = TextEditingController(text: item?.name ?? '');
    final price = TextEditingController(
      text: item?.price == null ? '' : item!.price!.toStringAsFixed(2),
    );
    final description = TextEditingController(text: item?.description ?? '');
    final saved = await showPixelDialog<bool>(
      context: context,
      title: item == null ? 'Add product' : 'Edit product',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelTextField(
              key: const ValueKey('merchant_product_name'),
              controller: name,
              label: 'Product / specialty name *',
            ),
            const SizedBox(height: 8),
            PixelTextField(
              key: const ValueKey('merchant_product_price'),
              controller: price,
              label: 'Price in PHP (optional)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 8),
            PixelTextField(
              controller: description,
              label: 'Description (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (dialogContext) => PixelButton(
                key: const ValueKey('merchant_product_save'),
                label: 'Save item',
                expand: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    final fields = {
      'name': name.text.trim(),
      'price': double.tryParse(price.text.trim()),
      'description': description.text.trim(),
      'currency': 'PHP',
    };
    name.dispose();
    price.dispose();
    description.dispose();
    if (saved != true || !mounted) return;
    if ((fields['name'] as String).length < 2) {
      showPixelToast(context, 'Enter a product name (2+ characters).');
      return;
    }
    try {
      await ref.read(merchantApiProvider).saveProduct(item?.id, fields);
      await _load();
      widget.onChanged();
    } catch (error) {
      if (mounted) {
        showPixelToast(context, _errorText(error, 'Could not save the item.'));
      }
    }
  }

  Future<void> _archive(MerchantProductItem item) async {
    try {
      await ref.read(merchantApiProvider).archiveProduct(item.id);
      await _load();
      widget.onChanged();
    } catch (error) {
      if (mounted) {
        showPixelToast(
          context,
          _errorText(error, 'Could not remove the item.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final items = _items;
    if (items == null) return const PixelLoader(label: 'Loading catalog');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: grid.px(2),
          runSpacing: grid.px(1),
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PixelSectionTitle(
              'Catalog',
              icon: merchantCatalogList,
              value: '${items.length}',
              valueColor: PixelPalette.greenDark,
            ),
            PixelButton(
              key: const ValueKey('merchant_add_product'),
              label: '+ Add product',
              onPressed: () => _edit(null),
            ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        if (items.isEmpty)
          Text(
            'No items yet. Add your first product or specialty.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Container(height: grid.unit, color: PixelPalette.paperDim),
          KeyedSubtree(
            key: ValueKey('merchant_product_${items[i].id}'),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: grid.px(2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(items[i].name, style: PixelType.title(context)),
                  SizedBox(height: grid.px(1)),
                  PixelChip(items[i].priceLabel),
                  if (items[i].description.isNotEmpty) ...[
                    SizedBox(height: grid.px(1)),
                    Text(items[i].description, style: PixelType.body(context)),
                  ],
                  SizedBox(height: grid.px(1)),
                  Wrap(
                    spacing: grid.px(2),
                    runSpacing: grid.px(1),
                    children: [
                      PixelButton(
                        key: ValueKey('merchant_edit_${items[i].id}'),
                        label: 'Edit',
                        variant: PixelButtonVariant.secondary,
                        onPressed: () => _edit(items[i]),
                      ),
                      PixelButton(
                        key: ValueKey('merchant_remove_${items[i].id}'),
                        label: 'Remove',
                        variant: PixelButtonVariant.danger,
                        onPressed: () => _archive(items[i]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SponsorshipsTab extends ConsumerStatefulWidget {
  const _SponsorshipsTab();

  @override
  ConsumerState<_SponsorshipsTab> createState() => _SponsorshipsTabState();
}

class _SponsorshipsTabState extends ConsumerState<_SponsorshipsTab> {
  static const _packages = [500, 1000, 2500, 5000];
  MerchantPointSummary? _points;
  List<MerchantSponsorshipItem>? _items;
  String? _pointsError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final api = ref.read(merchantApiProvider);
    try {
      final points = await api.points();
      if (mounted) setState(() => (_points = points, _pointsError = null));
    } catch (error) {
      if (mounted) {
        setState(
          () => _pointsError = _errorText(
            error,
            'Merchant points are unavailable.',
          ),
        );
      }
    }
    try {
      final items = await api.sponsorships();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showPixelToast(context, done);
      await _load();
    } catch (error) {
      if (mounted) {
        showPixelToast(context, _errorText(error, 'That did not go through.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setConditions(MerchantSponsorshipItem item) async {
    final api = ref.read(merchantApiProvider);
    final selected =
        await showSetConditionsSheet(context, initial: item.conditions);
    if (selected == null || !mounted) return;
    await _run(
      () => api.setConditions(item, selected),
      tr(
        context,
        en: 'Deal conditions updated.',
        tl: 'Na-update ang mga kondisyon.',
      ),
    );
  }

  Future<void> _accept(MerchantSponsorshipItem item) async {
    final api = ref.read(merchantApiProvider);
    final unmet = item.conditions.where((c) => !c.isMet).toList();
    if (unmet.isNotEmpty) {
      final confirmed = await _confirmOverride(unmet);
      if (confirmed != true || !mounted) return;
      await _run(
        () => api.accept(item, acknowledgeUnmet: true),
        'Sponsorship accepted.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await api.accept(item);
      if (mounted) showPixelToast(context, 'Sponsorship accepted.');
      await _load();
    } on DioException catch (error) {
      if (!mounted) return;
      final body = error.response?.data;
      if (_errorCode(error) == 'CONDITIONS_NOT_MET') {
        final rawConds = body is Map && body['data'] is Map
            ? body['data']['conditions']
            : null;
        final serverUnmet = [
          if (rawConds is List)
            for (final c in rawConds)
              if (c is Map)
                SponsorshipConditionData.fromJson(Map<String, dynamic>.from(c)),
        ].where((c) => !c.isMet).toList();
        setState(() => _busy = false);
        final confirmed = await _confirmOverride(
          serverUnmet.isNotEmpty ? serverUnmet : item.conditions,
        );
        if (confirmed != true || !mounted) return;
        await _run(
          () => api.accept(item, acknowledgeUnmet: true),
          'Sponsorship accepted.',
        );
        return;
      }
      showPixelToast(context, _errorText(error, 'That did not go through.'));
    } catch (error) {
      if (mounted) {
        showPixelToast(context, _errorText(error, 'That did not go through.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmOverride(List<SponsorshipConditionData> unmet) {
    return showPixelDialog<bool>(
      context: context,
      title: tr(
        context,
        en: 'Deal requirements not met yet',
        tl: 'Hindi pa natutupad ang mga kondisyon',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unmet.isNotEmpty) SponsorshipConditionsList(conditions: unmet),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              en: 'You can still accept. The quest will show your shop as a sponsor now.',
              tl: 'Puwede mo pa ring tanggapin. Ipapakita na ng quest ang shop mo bilang sponsor.',
            ),
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        ],
      ),
      actions: [
        PixelButton(
          key: const ValueKey('merchant_override_cancel'),
          label: tr(context, en: 'CANCEL', tl: 'KANSELAHIN'),
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PixelButton(
          key: const ValueKey('merchant_override_confirm'),
          label: tr(context, en: 'ACCEPT ANYWAY', tl: 'TANGGAPIN PA RIN'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Future<void> _counter(MerchantSponsorshipItem item) async {
    final api = ref.read(merchantApiProvider);
    List<MerchantVoucherOption> vouchers = const [];
    try {
      vouchers = await api.vouchers();
    } catch (_) {}
    if (!mounted) return;
    final points = TextEditingController(text: '${item.points}');
    final qty = TextEditingController(text: '${item.voucherQty}');
    final message = TextEditingController();
    String? voucherId;
    var promo = item.promo;
    List<Map<String, dynamic>>? nextConditions;
    var conditionCount = item.conditions.length;
    final send = await showPixelDialog<bool>(
      context: context,
      title: 'Counter-offer',
      content: StatefulBuilder(
        builder: (dialogContext, setLocal) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PixelTextField(
                key: const ValueKey('merchant_counter_points'),
                controller: points,
                label: 'Points',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              for (final v in vouchers)
                PixelRadio(
                  selected: voucherId == v.id,
                  label: v.title,
                  onChanged: () => setLocal(
                    () => voucherId = voucherId == v.id ? null : v.id,
                  ),
                ),
              if (voucherId != null) ...[
                const SizedBox(height: 8),
                PixelTextField(
                  controller: qty,
                  label: 'Voucher quantity',
                  keyboardType: TextInputType.number,
                ),
              ],
              PixelCheckbox(
                value: promo,
                label: 'Promote the quest at my store',
                onChanged: (value) => setLocal(() => promo = value),
              ),
              const SizedBox(height: 8),
              PixelButton(
                key: const ValueKey('merchant_counter_conditions'),
                label: conditionCount > 0
                    ? 'SET CONDITIONS ($conditionCount)'
                    : 'SET CONDITIONS',
                variant: PixelButtonVariant.secondary,
                expand: true,
                onPressed: () async {
                  final initial = nextConditions != null
                      ? [
                          for (final c in nextConditions!)
                            SponsorshipConditionData.fromJson(c),
                        ]
                      : item.conditions;
                  final picked = await showSetConditionsSheet(
                    dialogContext,
                    initial: initial,
                  );
                  if (picked != null && dialogContext.mounted) {
                    setLocal(() {
                      nextConditions = picked;
                      conditionCount = picked.length;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              PixelTextField(
                controller: message,
                label: 'Message (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              PixelButton(
                key: const ValueKey('merchant_counter_send'),
                label: 'Send counter-offer',
                expand: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    final terms = (
      int.tryParse(points.text.trim()) ?? 0,
      int.tryParse(qty.text.trim()) ?? 0,
      message.text.trim(),
    );
    points.dispose();
    qty.dispose();
    message.dispose();
    if (send != true || !mounted) return;
    await _run(
      () => api.counter(
        item,
        points: terms.$1,
        voucherId: voucherId,
        voucherQty: terms.$2,
        promo: promo,
        message: terms.$3,
        conditions: nextConditions,
      ),
      'Counter-offer sent.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final api = ref.read(merchantApiProvider);
    final points = _points;
    final items = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelSectionTitle(
          'Sponsorships & points',
          icon: DesignerArt.handshake,
          value: points != null ? '${points.balance}' : null,
          valueColor: PixelPalette.greenDark,
        ),
        SizedBox(height: grid.px(2)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              points == null
                  ? (_pointsError ?? 'Loading points')
                  : '${points.balance} PTS',
              key: const ValueKey('merchant_points_balance'),
              style: PixelType.numbers(context, color: PixelPalette.greenDark),
            ),
            Text(
              'Simulated prototype credits — no real money is charged.',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            if (points != null) ...[
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(1),
                children: [
                  for (final p in _packages)
                    PixelButton(
                      key: ValueKey('merchant_buy_$p'),
                      label: '+$p',
                      variant: PixelButtonVariant.secondary,
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => api.buyPoints(p),
                                'Added $p simulated points.',
                              ),
                    ),
                ],
              ),
              SizedBox(height: grid.px(1)),
              for (final credit in points.history.take(5))
                Text(
                  '+${credit.points} · ${credit.source}',
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
            ],
          ],
        ),
        SizedBox(height: grid.px(2)),
        Container(height: grid.unit, color: PixelPalette.paperDim),
        SizedBox(height: grid.px(2)),
        Text(
          'QUEST SPONSORSHIP REQUESTS',
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(1)),
        if (items == null)
          const PixelLoader(label: 'Loading requests')
        else if (items.isEmpty)
          Text(
            'No sponsorship requests yet.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        for (var i = 0;
            i < (items ?? const <MerchantSponsorshipItem>[]).length;
            i++) ...[
          if (i > 0) Container(height: grid.unit, color: PixelPalette.paperDim),
          Builder(builder: (context) {
            final item = items![i];
            return KeyedSubtree(
              key: ValueKey('merchant_sponsorship_${item.id}'),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.questTitle, style: PixelType.title(context)),
                    if (item.spotName.isNotEmpty)
                      Text(
                        item.spotName,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    SizedBox(height: grid.px(1)),
                    Wrap(
                      spacing: grid.px(1),
                      runSpacing: grid.px(1),
                      children: [
                        PixelChip(
                          item.status.toUpperCase(),
                          style: PixelBoxStyle.parchment,
                        ),
                        if (item.points > 0) PixelChip('${item.points} PTS'),
                        if (item.voucherQty > 0)
                          PixelChip('${item.voucherQty} VOUCHERS'),
                        if (item.promo) const PixelChip('PROMO'),
                      ],
                    ),
                    if (item.conditions.isNotEmpty ||
                        item.status == 'requested' ||
                        item.status == 'countered') ...[
                      SizedBox(height: grid.px(1.5)),
                      Text(
                        tr(
                          context,
                          en: 'DEAL CONDITIONS',
                          tl: 'MGA KONDISYON',
                        ),
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: grid.px(0.5)),
                      if (item.conditions.isNotEmpty)
                        SponsorshipConditionsList(conditions: item.conditions)
                      else
                        Text(
                          tr(
                            context,
                            en: 'No deal conditions set.',
                            tl: 'Walang kondisyon.',
                          ),
                          style: PixelType.small(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                    ],
                    if (item.status == 'requested' ||
                        item.status == 'countered') ...[
                      SizedBox(height: grid.px(1)),
                      Wrap(
                        spacing: grid.px(2),
                        runSpacing: grid.px(1),
                        children: [
                          PixelButton(
                            key: ValueKey('merchant_set_conditions_${item.id}'),
                            label: tr(context,
                                en: 'SET CONDITIONS',
                                tl: 'ITAKDA ANG KONDISYON'),
                            variant: PixelButtonVariant.secondary,
                            onPressed:
                                _busy ? null : () => _setConditions(item),
                          ),
                          if (item.status == 'requested') ...[
                            PixelButton(
                              key: ValueKey('merchant_accept_${item.id}'),
                              label: 'Accept',
                              onPressed: _busy ? null : () => _accept(item),
                            ),
                            PixelButton(
                              key: ValueKey('merchant_decline_${item.id}'),
                              label: 'Decline',
                              variant: PixelButtonVariant.danger,
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                        () => api.decline(item),
                                        'Sponsorship declined.',
                                      ),
                            ),
                            PixelButton(
                              key: ValueKey('merchant_counter_${item.id}'),
                              label: 'Counter',
                              variant: PixelButtonVariant.secondary,
                              onPressed: _busy ? null : () => _counter(item),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (item.status == 'accepted' &&
                        item.planStatus == 'active' &&
                        item.planId.isNotEmpty) ...[
                      SizedBox(height: grid.px(1)),
                      PixelButton(
                        key: ValueKey('merchant_topup_${item.id}'),
                        label: 'Top up active round (+500)',
                        variant: PixelButtonVariant.secondary,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => api.topUp(item.planId, 500),
                                  'Added 500 points to the round.',
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
