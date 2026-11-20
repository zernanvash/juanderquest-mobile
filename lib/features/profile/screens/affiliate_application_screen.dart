import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/map_config.dart';
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
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/engine/jdq_map.dart';
import '../../map/engine/jdq_map_canvas.dart';
import '../../map/engine/maplibre_jdq_map.dart';
import '../../map/pixel/map_marker_art.dart';
import '../../merchant/models/merchant_models.dart';
import '../../merchant/providers/merchant_hub_provider.dart';

const _affiliateCategories = <String>[
  'dining',
  'pasalubong',
  'lodging',
  'adventure',
  'heritage',
  'retail'
];
const _affiliateGoals = <String, String>{
  'quest_stop': 'Co-sponsor a tourism quest stop',
  'voucher_perk': 'Offer voucher perks or discounts',
  'map_pin': 'Request a business map feature',
  'event_sponsor': 'Support a festival or seasonal event',
};
const _contactMethods = <String, String>{
  'email': 'EMAIL',
  'phone': 'PHONE',
  'sms': 'SMS',
};

class AffiliateApplicationScreen extends ConsumerStatefulWidget {
  const AffiliateApplicationScreen({super.key, this.edit = false});

  /// Plan 95: `?edit=1` keeps the form open for a `needs_changes` or
  /// `rejected` application instead of forwarding to the status screen.
  final bool edit;

  @override
  ConsumerState<AffiliateApplicationScreen> createState() =>
      _AffiliateApplicationScreenState();
}

class _AffiliateApplicationScreenState
    extends ConsumerState<AffiliateApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _municipality = TextEditingController();
  final _province = TextEditingController();
  final _placeSearch = TextEditingController();
  late final JdqMap _map;
  late final Future<String> _style;
  LatLng _mapCenter =
      const LatLng(MapConfig.pangasinanLat, MapConfig.pangasinanLng);
  double _mapZoom = MapConfig.defaultZoom;
  LatLng? _pin;
  List<Map<String, dynamic>> _places = const [];
  bool _searching = false;
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _details = TextEditingController();
  String _category = _affiliateCategories.first;
  final Set<String> _goals = {};
  String _contactMethod = 'email';
  bool _declared = false;
  // Plan 95: collapsible sections; identity and location start open.
  final Set<int> _open = {1, 2};
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _existing;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _map = ref.read(jdqMapFactoryProvider)();
    _style = ref.read(mapStyleProvider.future);
    _map.onCameraIdle = () {
      final c = _map.camera.center;
      if (mounted) {
        setState(() {
          _mapCenter = c;
          _pin = c;
          _error = null;
        });
      }
    };
    _map.onTapEmpty = (point) =>
        unawaited(_map.easeTo(point, _map.camera.zoom, reducedMotion: true));
    unawaited(_map.easeTo(_mapCenter, _mapZoom, reducedMotion: true));
    Future.microtask(_loadApplication);
  }

  @override
  void dispose() {
    _business.dispose();
    _municipality.dispose();
    _province.dispose();
    _placeSearch.dispose();
    _map.dispose();
    _contact.dispose();
    _email.dispose();
    _phone.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _loadApplication() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/affiliate/applications/me');
      final hub = MerchantHubStatus.fromResponse(response.data);
      if (!widget.edit &&
          hub.route != '/affiliate' &&
          mounted &&
          GoRouter.maybeOf(context) != null) {
        context.pushReplacement(hub.route);
        return;
      }
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map<String, dynamic> && mounted) {
        setState(() {
          _existing = data;
          _business.text = data['business_name']?.toString() ?? '';
          _category = _affiliateCategories.contains(data['category'])
              ? data['category'] as String
              : _category;
          _municipality.text =
              data['municipality']?.toString() ?? _municipality.text;
          _province.text =
              data['business_province']?.toString() ?? 'Pangasinan';
          final lat = (data['gps_lat'] as num?)?.toDouble();
          final lng = (data['gps_lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _pin = LatLng(lat, lng);
            _mapCenter = _pin!;
            _mapZoom = 15;
            unawaited(_map.easeTo(_mapCenter, _mapZoom, reducedMotion: true));
          }
          _contact.text = data['contact_name']?.toString() ?? '';
          _email.text = data['contact_email']?.toString() ?? '';
          _phone.text = data['contact_phone']?.toString() ?? '';
          _details.text = data['proposal_details']?.toString() ?? '';
          _goals.addAll((data['sponsorship_goals'] as List? ?? const [])
              .whereType<String>());
          if (_contactMethods.containsKey(data['preferred_contact_method'])) {
            _contactMethod = data['preferred_contact_method'] as String;
          }
        });
      }
    } catch (_) {
      // The application form remains useful if the optional status read fails.
    } finally {
      if (mounted) {
        final user = ref.read(authProvider).user;
        if (_contact.text.isEmpty) _contact.text = user?.displayName ?? '';
        if (_email.text.isEmpty) _email.text = user?.email ?? '';
        setState(() => _loading = false);
      }
    }
  }

  bool _filled(TextEditingController c) => c.text.trim().length >= 2;

  bool get _identityDone =>
      _filled(_business) && _filled(_municipality) && _filled(_province);

  bool get _contactDone =>
      _filled(_contact) &&
      _filled(_email) &&
      _filled(_phone) &&
      _goals.isNotEmpty;

  bool _sectionDone(int section) => switch (section) {
        1 => _identityDone,
        2 => _pin != null,
        3 => _contactDone,
        _ => _declared,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _open.addAll([
            for (final section in [1, 3])
              if (!_sectionDone(section)) section,
          ]));
      return;
    }
    if (_pin == null) {
      setState(() {
        _open.add(2);
        _error =
            'Choose your business location on the map or use your current location.';
      });
      return;
    }
    if (_goals.isEmpty) {
      setState(() {
        _open.add(3);
        _error = 'Choose at least one way you would like to participate.';
      });
      return;
    }
    if (!_declared) {
      setState(() {
        _open.add(4);
        _error = 'Confirm the declaration before submitting.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      // Needs-changes and rejected applications are edited in place.
      final isNeedsChanges = _existing?['status'] == 'needs_changes' ||
          _existing?['status'] == 'rejected';
      final appId = _existing?['id']?.toString();

      final payload = {
        'business_name': _business.text.trim(),
        'category': _category,
        'municipality': _municipality.text.trim(),
        'business_province': _province.text.trim(),
        'gps_lat': _pin!.latitude,
        'gps_lng': _pin!.longitude,
        'contact_name': _contact.text.trim(),
        'contact_email': _email.text.trim(),
        'contact_phone': _phone.text.trim(),
        'preferred_contact_method': _contactMethod,
        'sponsorship_goals': _goals.toList(),
        'proposal_details': _details.text.trim(),
      };

      final response = isNeedsChanges && appId != null
          ? await ref
              .read(apiClientProvider)
              .dio
              .post('/affiliate/applications/$appId/resubmit', data: payload)
          : await ref
              .read(apiClientProvider)
              .dio
              .post('/affiliate/applications', data: payload);

      ref.invalidate(merchantHubStatusProvider);
      if (mounted && GoRouter.maybeOf(context) != null) {
        if (widget.edit && context.canPop()) {
          context.pop();
        } else {
          context.pushReplacement('/affiliate/pending');
        }
        return;
      }
      if (mounted) {
        setState(() {
          _existing = response.data['data'] is Map
              ? Map<String, dynamic>.from(response.data['data'] as Map)
              : _existing;
          _success = isNeedsChanges
              ? 'Your revised application was resubmitted for review.'
              : 'Your application was submitted for review.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Could not submit the application. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _searchPlaces() async {
    final query = _placeSearch.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Enter at least two characters to search.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _places = const [];
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/affiliate/places', queryParameters: {'q': query});
      final data = response.data is Map ? response.data['data'] : null;
      if (!mounted) return;
      setState(() {
        _places = data is List
            ? data
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : const [];
        if (_places.isEmpty) {
          _error = 'No matching places. Try another city or landmark.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Place search is unavailable. You can still pan the map and place a pin.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are off.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _pin = point;
        _error = null;
      });
      _moveMap(point, 16);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Current location is unavailable. Search or drag the map instead.');
      }
    }
  }

  void _moveMap(LatLng center, double zoom) {
    _mapCenter = center;
    _mapZoom = zoom;
    unawaited(_map.easeTo(center, zoom, reducedMotion: true));
  }

  Future<void> _chooseCategory(PixelGrid grid) async {
    await showPixelDialog<void>(
      context: context,
      title: 'Business category',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final value in _affiliateCategories) ...[
              PixelButton(
                label: value,
                variant: value == _category
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                onPressed: () {
                  setState(() => _category = value);
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(height: grid.px(2)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _existing?['status']?.toString();
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Be a partner',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: PixelLoader(label: 'Loading application'))
                        : Form(
                            key: _formKey,
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                grid.gutter,
                                grid.px(4),
                                grid.gutter,
                                grid.px(8) +
                                    MediaQuery.paddingOf(context).bottom,
                              ),
                              children: [
                                _intro(context, grid),
                                if (status != null) ...[
                                  SizedBox(height: grid.px(3)),
                                  _statusCard(context, grid, status),
                                ],
                                SizedBox(height: grid.px(3)),
                                _section(
                                    context, grid, 1, 'Business identity', [
                                  PixelTextField(
                                    controller: _business,
                                    label: 'Business name',
                                    validator: _required('Business name'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  SizedBox(height: grid.px(2)),
                                  _categoryField(context, grid),
                                  SizedBox(height: grid.px(2)),
                                  PixelTextField(
                                    controller: _municipality,
                                    label: 'Municipality / city',
                                    validator: _required('Municipality / city'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  SizedBox(height: grid.px(2)),
                                  PixelTextField(
                                    controller: _province,
                                    label: 'Province / region',
                                    validator: _required('Province / region'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ]),
                                _section(
                                    context, grid, 2, 'Location & map pin', [
                                  _location(context, grid),
                                ]),
                                _section(context, grid, 3,
                                    'Contact & participation', [
                                  PixelTextField(
                                    controller: _contact,
                                    label: 'Contact person',
                                    validator: _required('Contact person'),
                                  ),
                                  SizedBox(height: grid.px(2)),
                                  PixelTextField(
                                    controller: _email,
                                    label: 'Contact email',
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _required('Contact email'),
                                  ),
                                  SizedBox(height: grid.px(2)),
                                  PixelTextField(
                                    controller: _phone,
                                    label: 'Contact phone',
                                    keyboardType: TextInputType.phone,
                                    validator: _required('Contact phone'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  SizedBox(height: grid.px(2)),
                                  Text('PREFERRED CONTACT METHOD',
                                      style: PixelType.small(context,
                                          color: PixelPalette.slate)),
                                  SizedBox(height: grid.px(1)),
                                  Wrap(
                                    spacing: grid.px(2),
                                    runSpacing: grid.px(1),
                                    children: [
                                      for (final m in _contactMethods.entries)
                                        PixelChip(
                                          m.value,
                                          key: ValueKey(
                                              'affiliate_contact_${m.key}'),
                                          style: _contactMethod == m.key
                                              ? PixelBoxStyle.green
                                              : PixelBoxStyle.parchment,
                                          textColor: _contactMethod == m.key
                                              ? PixelPalette.white
                                              : PixelPalette.ink,
                                          onTap: () => setState(
                                              () => _contactMethod = m.key),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: grid.px(3)),
                                  const PixelSectionTitle(
                                    'How would you like to participate?',
                                    icon: DesignerArt.handshake,
                                  ),
                                  SizedBox(height: grid.px(1)),
                                  for (final entry in _affiliateGoals.entries)
                                    PixelCheckbox(
                                      key: ValueKey(
                                          'affiliate_goal_${entry.key}'),
                                      value: _goals.contains(entry.key),
                                      label: entry.value,
                                      onChanged: (selected) => setState(() =>
                                          selected == true
                                              ? _goals.add(entry.key)
                                              : _goals.remove(entry.key)),
                                    ),
                                  SizedBox(height: grid.px(2)),
                                  PixelTextField(
                                    controller: _details,
                                    label: 'Proposal details (optional)',
                                    maxLines: 4,
                                  ),
                                ]),
                                _section(
                                    context, grid, 4, 'Declaration & submit', [
                                  PixelCheckbox(
                                    key: const ValueKey(
                                        'affiliate_declaration_checkbox'),
                                    value: _declared,
                                    label:
                                        'I confirm I am authorized to represent this business and that the location and details are accurate.',
                                    onChanged: (value) =>
                                        setState(() => _declared = value),
                                  ),
                                ]),
                                if (_error != null) ...[
                                  SizedBox(height: grid.px(2)),
                                  PixelPanel(
                                    style: PixelBoxStyle.red,
                                    child: Text(
                                      _error!,
                                      style: PixelType.body(
                                        context,
                                        color: PixelPalette.white,
                                      ),
                                    ),
                                  ),
                                ],
                                if (_success != null) ...[
                                  SizedBox(height: grid.px(2)),
                                  PixelPanel(
                                    style: PixelBoxStyle.green,
                                    child: Text(
                                      _success!,
                                      style: PixelType.body(
                                        context,
                                        color: PixelPalette.white,
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: grid.px(3)),
                                PixelButton(
                                  key: const ValueKey('affiliate_submit'),
                                  label: _submitting
                                      ? 'Submitting'
                                      : status == 'received' ||
                                              status == 'in_review' ||
                                              status == 'appealed'
                                          ? 'Application Under Review'
                                          : status == 'needs_changes'
                                              ? 'Resubmit Revised Application'
                                              : status == 'rejected'
                                                  ? tr(context,
                                                      en: 'Resubmit Application',
                                                      tl: 'Ipasa Muli ang Aplikasyon')
                                                  : 'Submit Application',
                                  expand: true,
                                  loading: _submitting,
                                  onPressed: _submitting ||
                                          status == 'received' ||
                                          status == 'in_review' ||
                                          status == 'appealed'
                                      ? null
                                      : _submit,
                                ),
                                SizedBox(height: grid.px(2)),
                                Text(
                                  'Submitting an application does not guarantee approval. Voucher offers and merchant spending remain subject to separate review.',
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.slate,
                                  ),
                                ),
                              ],
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

  Widget _section(BuildContext context, PixelGrid grid, int number,
      String title, List<Widget> children) {
    final open = _open.contains(number);
    final done = _sectionDone(number);
    return Padding(
      padding: EdgeInsets.only(bottom: grid.px(2)),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: GestureDetector(
                key: ValueKey('affiliate_section_$number'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                    () => open ? _open.remove(number) : _open.add(number)),
                child: Row(
                  children: [
                    Expanded(
                      child: PixelSectionTitle('$number. $title'),
                    ),
                    PixelChip(
                      done ? 'DONE' : 'OPEN',
                      style: done ? PixelBoxStyle.green : PixelBoxStyle.gold,
                      textColor: done ? PixelPalette.white : PixelPalette.ink,
                    ),
                    SizedBox(width: grid.px(1)),
                    Text(open ? '-' : '+', style: PixelType.title(context)),
                  ],
                ),
              ),
            ),
            Visibility(
              visible: open,
              maintainState: true,
              child: Padding(
                padding: EdgeInsets.only(top: grid.px(2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PixelSectionTitle(
            'Partner with local tourism',
            icon: DesignerArt.salakot,
            colors: PixelText3DColors.cream,
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Local businesses can apply to participate in destination quests, vouchers, map discovery, and seasonal events. Applications are reviewed by the team.',
            style: PixelType.body(context, color: PixelPalette.cream),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context, PixelGrid grid, String status) {
    final note = _existing?['applicant_feedback'];
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PixelSectionTitle(
                  'Application status',
                  icon: DesignerArt.handshake,
                ),
              ),
              PixelChip(status.replaceAll('_', ' ').toUpperCase()),
            ],
          ),
          if (note != null) ...[
            SizedBox(height: grid.px(2)),
            Text(
              'Reviewer note: $note',
              style: PixelType.body(context, color: PixelPalette.redDeep),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryField(BuildContext context, PixelGrid grid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUSINESS CATEGORY',
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(1)),
        GestureDetector(
          key: const ValueKey('affiliate_category'),
          onTap: () => _chooseCategory(grid),
          child: PixelPanel(
            style: PixelBoxStyle.slot,
            sunken: true,
            padding: 2,
            child: Row(
              children: [
                Expanded(
                  child: Text(_category, style: PixelType.body(context)),
                ),
                Text('CHANGE',
                    style: PixelType.small(
                      context,
                      color: PixelPalette.greenDark,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _location(BuildContext context, PixelGrid grid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business location', style: PixelType.title(context)),
        SizedBox(height: grid.px(2)),
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              _searchPlaces();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: PixelTextField(
            controller: _placeSearch,
            label: 'Search a Philippine city or landmark',
            textInputAction: TextInputAction.search,
          ),
        ),
        SizedBox(height: grid.px(2)),
        Wrap(
          spacing: grid.px(2),
          runSpacing: grid.px(2),
          children: [
            PixelButton(
              key: const ValueKey('affiliate_search_map'),
              label: _searching ? 'Searching' : 'Search map',
              variant: PixelButtonVariant.secondary,
              loading: _searching,
              onPressed: _searching ? null : _searchPlaces,
            ),
            PixelButton(
              key: const ValueKey('affiliate_use_location'),
              label: 'Use my location',
              variant: PixelButtonVariant.secondary,
              onPressed: _useCurrentLocation,
            ),
          ],
        ),
        if (_places.isNotEmpty) ...[
          SizedBox(height: grid.px(2)),
          for (final place in _places) ...[
            GestureDetector(
              onTap: () {
                final lat = (place['lat'] as num?)?.toDouble();
                final lng = (place['lng'] as num?)?.toDouble();
                if (lat == null || lng == null) return;
                setState(() {
                  _pin = null;
                  _places = const [];
                  if (place['type'] == 'city' ||
                      place['type'] == 'municipality') {
                    _municipality.text =
                        place['name']?.toString() ?? _municipality.text;
                  }
                  if (place['type'] == 'province') {
                    _province.text =
                        place['name']?.toString() ?? _province.text;
                  }
                });
                _moveMap(LatLng(lat, lng), 12);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place['name']?.toString() ?? 'Place',
                      style: PixelType.title(context),
                    ),
                    if ((place['subtitle']?.toString() ?? '').isNotEmpty) ...[
                      SizedBox(height: grid.px(1)),
                      Text(
                        place['subtitle'].toString(),
                        style: PixelType.body(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(height: grid.unit, color: PixelPalette.paperDim),
          ],
        ],
        SizedBox(height: grid.px(2)),
        SizedBox(
          height: grid.px(120),
          child: Stack(
            children: [
              ClipRect(
                child: JdqMapCanvas(
                  map: _map,
                  style: _style,
                  fallback: const ColoredBox(color: PixelPalette.paperDim),
                  onFallback: () {},
                ),
              ),
              const Positioned.fill(
                child: PixelCrosshairReticle(),
              ),
              const IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 30),
                    child: SizedBox.square(
                      dimension: 36,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: PixelSprite(DesignerArt.spotMarker, scale: 1),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: PixelButton(
                  key: const ValueKey('affiliate_confirm_location'),
                  label: 'Use this location',
                  style: PixelBoxStyle.wood,
                  textColor: PixelPalette.white,
                  onPressed: () {
                    final c = _map.camera.center;
                    setState(() {
                      _mapCenter = c;
                      _pin = c;
                      _error = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(2)),
        Text(
          _pin == null
              ? 'Drag or zoom the map to place the pin at your business.'
              : 'Pin: ${_pin!.latitude.toStringAsFixed(6)}, ${_pin!.longitude.toStringAsFixed(6)}',
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
      ],
    );
  }

  String? Function(String?) _required(String label) {
    return (value) =>
        value == null || value.trim().length < 2 ? 'Enter $label' : null;
  }
}
