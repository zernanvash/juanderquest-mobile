import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
import '../../../core/search/fuzzy_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../pixel/pixel_tag.dart';

class SponsorDirectoryMerchant {
  const SponsorDirectoryMerchant({
    required this.id,
    required this.name,
    required this.municipality,
    required this.category,
    required this.description,
    required this.sameMunicipality,
    required this.vouchers,
    this.distanceMeters,
  });

  final String id;
  final String name;
  final String municipality;
  final String category;
  final String description;
  final bool sameMunicipality;
  final List<SponsorDirectoryVoucher> vouchers;

  /// Metres from the quest pin; null when the shop has no GPS.
  final int? distanceMeters;

  factory SponsorDirectoryMerchant.fromJson(Map<String, dynamic> json) {
    final rawVouchers = json['vouchers'];
    final voucherList = <SponsorDirectoryVoucher>[];
    if (rawVouchers is List) {
      for (final v in rawVouchers) {
        if (v is Map) {
          voucherList.add(
            SponsorDirectoryVoucher.fromJson(Map<String, dynamic>.from(v)),
          );
        }
      }
    }
    return SponsorDirectoryMerchant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sameMunicipality: json['same_municipality'] == true,
      vouchers: voucherList,
      distanceMeters: _intOrNull(json['distance_m']),
    );
  }
}

int? _intOrNull(Object? value) {
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round();
  return null;
}

class SponsorDirectoryVoucher {
  const SponsorDirectoryVoucher({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  factory SponsorDirectoryVoucher.fromJson(Map<String, dynamic> json) =>
      SponsorDirectoryVoucher(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Voucher',
        description: json['description']?.toString() ?? '',
      );
}

class SponsorRequestScreen extends ConsumerStatefulWidget {
  const SponsorRequestScreen({
    super.key,
    required this.questId,
    required this.planId,
    this.initialMerchant,
  });

  final String questId;
  final String planId;

  /// Opens straight on the request form for this merchant (from the quest
  /// builder's "Merchants nearby"); back then closes the screen.
  final SponsorDirectoryMerchant? initialMerchant;

  @override
  ConsumerState<SponsorRequestScreen> createState() =>
      _SponsorRequestScreenState();
}

class _SponsorRequestScreenState extends ConsumerState<SponsorRequestScreen> {
  final _searchController = TextEditingController();
  final _pointsController = TextEditingController(text: '100');
  final _voucherQtyController = TextEditingController(text: '1');
  final _messageController = TextEditingController();

  List<SponsorDirectoryMerchant> _merchants = const [];
  SponsorDirectoryMerchant? _selected;
  String? _selectedVoucherId;
  bool _promo = true;
  String _query = '';
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMerchant;
    if (_selected == null) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pointsController.dispose();
    _voucherQtyController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.get(
        '/sponsor-directory',
        queryParameters: {'quest_id': widget.questId, 'page': 1},
      );
      if (response.data['success'] != true) {
        throw Exception('Could not load local merchants.');
      }
      final rawItems = response.data['data']?['items'];
      final items = <SponsorDirectoryMerchant>[];
      if (rawItems is List) {
        for (final row in rawItems) {
          if (row is Map) {
            items.add(
              SponsorDirectoryMerchant.fromJson(Map<String, dynamic>.from(row)),
            );
          }
        }
      }
      if (mounted) setState(() => _merchants = items);
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map && data['error'] is Map
          ? data['error']['message']?.toString()
          : null;
      if (mounted) {
        setState(
          () => _error = msg ??
              tr(
                context,
                en: 'Could not load merchants right now.',
                tl: 'Hindi makuha ang listahan ng mga tindahan.',
              ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            context,
            en: 'Could not load merchants right now.',
            tl: 'Hindi makuha ang listahan ng mga tindahan.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SponsorDirectoryMerchant> get _filteredMerchants {
    final q = _query.trim();
    if (q.isEmpty) return _merchants;
    final scored = <(double score, SponsorDirectoryMerchant m)>[];
    for (final m in _merchants) {
      final score = FuzzySearch.score(q, [
        m.name,
        m.category,
        m.municipality,
        m.description,
      ]);
      if (score != null) {
        scored.add((score, m));
      }
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final entry in scored) entry.$2];
  }

  Future<void> _sendRequest() async {
    final merchant = _selected;
    if (merchant == null) return;
    final pts = int.tryParse(_pointsController.text.trim()) ?? 0;
    final hasVoucher =
        _selectedVoucherId != null && _selectedVoucherId!.isNotEmpty;
    final qty =
        hasVoucher ? (int.tryParse(_voucherQtyController.text.trim()) ?? 0) : 0;
    final msg = _messageController.text.trim();

    if (pts < 0 ||
        (hasVoucher && qty < 1) ||
        (pts == 0 && !hasVoucher && !_promo)) {
      setState(
        () => _error = tr(
          context,
          en: 'Enter points, choose a voucher, or enable shop promotion.',
          tl: 'Maglagay ng puntos, pumili ng voucher, o i-on ang promosyon.',
        ),
      );
      return;
    }
    if (msg.length > 500) {
      setState(
        () => _error = tr(
          context,
          en: 'Message must be 500 characters or fewer.',
          tl: 'Ang mensahe ay hanggang 500 letra lamang.',
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    final idempotencyKey = const Uuid().v4();
    try {
      final response = await ref.read(apiClientProvider).dio.post(
            '/funding-plans/${Uri.encodeComponent(widget.planId)}/sponsorships',
            data: {
              'merchant_id': merchant.id,
              'points': pts,
              'voucher_id': hasVoucher ? _selectedVoucherId : null,
              'voucher_qty': qty,
              'promo': _promo,
              if (msg.isNotEmpty) 'message': msg,
              'idempotency_key': idempotencyKey,
            },
            options: Options(headers: {'x-idempotency-key': idempotencyKey}),
          );
      if (response.data['success'] != true) {
        throw Exception(
          response.data['error']?['message']?.toString() ??
              'Could not send request.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              en: 'Request sent to ${merchant.name}',
              tl: 'Naipadala ang hiling kay ${merchant.name}',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final data = e.response?.data;
      final serverMsg = data is Map && data['error'] is Map
          ? data['error']['message']?.toString()
          : null;
      if (mounted) {
        setState(
          () => _error = serverMsg ??
              tr(
                context,
                en: 'Could not send request. Please try again.',
                tl: 'Hindi naipadala ang hiling. Subukan ulit.',
              ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final selected = _selected;
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: selected == null
                        ? tr(context,
                            en: 'Ask a merchant', tl: 'Hilingin sa tindahan')
                        : selected.name,
                    onBack: () {
                      if (selected != null && widget.initialMerchant == null) {
                        setState(() {
                          _selected = null;
                          _selectedVoucherId = null;
                          _error = null;
                        });
                      } else {
                        Navigator.of(context).maybePop(false);
                      }
                    },
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: PixelLoader(label: 'Loading merchants'),
                          )
                        : selected == null
                            ? _buildDirectory(context, grid)
                            : _buildForm(context, grid, selected),
                  ),
                  if (selected != null)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          grid.gutter,
                          grid.px(1.5),
                          grid.gutter,
                          grid.px(2),
                        ),
                        child: PixelButton(
                          key: const ValueKey('sponsor_request_send'),
                          label: _sending
                              ? tr(context, en: 'SENDING', tl: 'IPINAPADALA')
                              : tr(context,
                                  en: 'SEND REQUEST', tl: 'IPADALA ANG HILING'),
                          expand: true,
                          loading: _sending,
                          onPressed: _sending ? null : _sendRequest,
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

  Widget _buildDirectory(BuildContext context, PixelGrid grid) {
    final items = _filteredMerchants;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        grid.gutter,
        grid.px(3),
        grid.gutter,
        grid.px(6) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PixelTextField(
          key: const ValueKey('sponsor_search_field'),
          controller: _searchController,
          label: tr(
            context,
            en: 'Search local merchants',
            tl: 'Maghanap ng tindahan',
          ),
          hint: tr(
            context,
            en: 'Shop name, town, or category',
            tl: 'Pangalan, bayan, o kategorya',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        SizedBox(height: grid.px(2)),
        if (_error != null) ...[
          PixelPanel(
            style: PixelBoxStyle.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: PixelType.body(context, color: PixelPalette.white),
                ),
                SizedBox(height: grid.px(1.5)),
                PixelButton(
                  label: tr(context, en: 'RETRY', tl: 'SUBUKAN ULIT'),
                  variant: PixelButtonVariant.secondary,
                  onPressed: _load,
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
        if (items.isEmpty)
          PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Text(
              tr(
                context,
                en: 'No matching active merchants found.',
                tl: 'Walang nahanap na aktibong tindahan.',
              ),
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
          ),
        for (final merchant in items)
          Padding(
            padding: EdgeInsets.only(bottom: grid.px(2)),
            child: InkWell(
              key: ValueKey('sponsor_merchant_${merchant.id}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() {
                _selected = merchant;
                _selectedVoucherId = null;
                _error = null;
              }),
              child: PixelPanel(
                style: PixelBoxStyle.parchment,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox.square(
                          dimension: 20,
                          child: FittedBox(
                            child: PixelSprite(DesignerArt.handshake, scale: 1),
                          ),
                        ),
                        SizedBox(width: grid.px(1.5)),
                        Expanded(
                          child: Text(
                            merchant.name,
                            style: PixelType.title(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: grid.px(1)),
                    Wrap(
                      spacing: grid.px(1),
                      runSpacing: grid.px(1),
                      children: [
                        if (merchant.municipality.isNotEmpty)
                          PixelTag(merchant.municipality),
                        if (merchant.category.isNotEmpty)
                          PixelTag(merchant.category),
                        if (merchant.sameMunicipality)
                          PixelTag(
                            tr(context, en: 'SAME TOWN', tl: 'PAREHONG BAYAN'),
                            style: PixelBoxStyle.green,
                            textColor: PixelPalette.cream,
                          ),
                      ],
                    ),
                    if (merchant.description.isNotEmpty) ...[
                      SizedBox(height: grid.px(1)),
                      Text(
                        merchant.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            PixelType.small(context, color: PixelPalette.slate),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    PixelGrid grid,
    SponsorDirectoryMerchant merchant,
  ) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        grid.gutter,
        grid.px(3),
        grid.gutter,
        grid.px(4),
      ),
      children: [
        if (_error != null) ...[
          PixelPanel(
            style: PixelBoxStyle.red,
            child: Text(
              _error!,
              style: PixelType.body(context, color: PixelPalette.white),
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, en: 'REQUEST TERMS', tl: 'MGA DETALYE NG HILING'),
                style: PixelType.title(context),
              ),
              SizedBox(height: grid.px(2)),
              PixelTextField(
                key: const ValueKey('sponsor_request_points'),
                controller: _pointsController,
                label: tr(context,
                    en: 'Points requested', tl: 'Hinihinging puntos'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: grid.px(2)),
              if (merchant.vouchers.isNotEmpty) ...[
                Text(
                  tr(context, en: 'VOUCHER PERK', tl: 'VOUCHER PERK'),
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(1)),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('sponsor_request_voucher'),
                  value: _selectedVoucherId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: PixelPalette.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: grid.px(2),
                      vertical: grid.px(1.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        tr(context, en: 'No voucher', tl: 'Walang voucher'),
                      ),
                    ),
                    for (final v in merchant.vouchers)
                      DropdownMenuItem<String?>(
                        value: v.id,
                        child: Text(
                          v.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedVoucherId = value),
                ),
                if (_selectedVoucherId != null) ...[
                  SizedBox(height: grid.px(2)),
                  PixelTextField(
                    key: const ValueKey('sponsor_request_voucher_qty'),
                    controller: _voucherQtyController,
                    label: tr(
                      context,
                      en: 'Voucher quantity',
                      tl: 'Bilang ng voucher',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                SizedBox(height: grid.px(2)),
              ],
              PixelCheckbox(
                key: const ValueKey('sponsor_request_promo'),
                value: _promo,
                label: tr(
                  context,
                  en: 'Promote my shop on this quest',
                  tl: 'Ipakita ang tindahan ko sa quest',
                ),
                onChanged: (v) => setState(() => _promo = v),
              ),
              SizedBox(height: grid.px(2)),
              PixelTextField(
                key: const ValueKey('sponsor_request_message'),
                controller: _messageController,
                label: tr(
                  context,
                  en: 'Message to merchant (max 500 chars)',
                  tl: 'Mensahe sa tindahan (hanggang 500 letra)',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
