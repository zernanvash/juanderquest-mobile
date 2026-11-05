import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/map_config.dart';
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
import '../../../core/widgets/base_tile_layer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/pixel/map_marker_art.dart';

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

class AffiliateApplicationScreen extends ConsumerStatefulWidget {
  const AffiliateApplicationScreen({super.key});

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
  final _mapController = MapController();
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
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _existing;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadApplication);
  }

  @override
  void dispose() {
    _business.dispose();
    _municipality.dispose();
    _province.dispose();
    _placeSearch.dispose();
    _mapController.dispose();
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
          }
          _contact.text = data['contact_name']?.toString() ?? '';
          _email.text = data['contact_email']?.toString() ?? '';
          _phone.text = data['contact_phone']?.toString() ?? '';
          _details.text = data['proposal_details']?.toString() ?? '';
          _goals.addAll((data['sponsorship_goals'] as List? ?? const [])
              .whereType<String>());
        });
      }
    } catch (_) {
      // The application form remains useful if the optional status read fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pin == null) {
      setState(() => _error =
          'Choose your business location on the map or use your current location.');
      return;
    }
    if (_goals.isEmpty) {
      setState(() =>
          _error = 'Choose at least one way you would like to participate.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final isNeedsChanges = _existing?['status'] == 'needs_changes';
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
            'Current location is unavailable. Search or tap the map instead.');
      }
    }
  }

  void _moveMap(LatLng center, double zoom) {
    _mapCenter = center;
    _mapZoom = zoom;
    // The map may not be mounted yet inside the scrolling form.
    try {
      _mapController.move(center, zoom);
    } catch (_) {
      // The stored center is used when the map enters the viewport.
    }
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
                    title: 'Merchant Affiliate',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: PixelLoader(label: 'Loading application'))
                        : Form(
                            key: _formKey,
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                grid.px(4),
                                grid.px(4),
                                grid.px(4),
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
                                PixelTextField(
                                  controller: _business,
                                  label: 'Business name',
                                  validator: _required('Business name'),
                                ),
                                SizedBox(height: grid.px(2)),
                                _categoryField(context, grid),
                                SizedBox(height: grid.px(2)),
                                PixelTextField(
                                  controller: _municipality,
                                  label: 'Municipality / city',
                                  validator: _required('Municipality / city'),
                                ),
                                SizedBox(height: grid.px(2)),
                                PixelTextField(
                                  controller: _province,
                                  label: 'Province / region',
                                  validator: _required('Province / region'),
                                ),
                                SizedBox(height: grid.px(3)),
                                _location(context, grid),
                                SizedBox(height: grid.px(3)),
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
                                ),
                                SizedBox(height: grid.px(3)),
                                Text('How would you like to participate?',
                                    style: PixelType.title(context)),
                                SizedBox(height: grid.px(1)),
                                for (final entry in _affiliateGoals.entries)
                                  PixelCheckbox(
                                    key: ValueKey(
                                        'affiliate_goal_${entry.key}'),
                                    value: _goals.contains(entry.key),
                                    label: entry.value,
                                    onChanged: (selected) => setState(
                                        () => selected == true
                                            ? _goals.add(entry.key)
                                            : _goals.remove(entry.key)),
                                  ),
                                SizedBox(height: grid.px(2)),
                                PixelTextField(
                                  controller: _details,
                                  label: 'Proposal details (optional)',
                                  maxLines: 4,
                                ),
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
                                              status == 'in_review'
                                          ? 'Application Under Review'
                                          : 'Submit Application',
                                  expand: true,
                                  loading: _submitting,
                                  onPressed: _submitting ||
                                          status == 'received' ||
                                          status == 'in_review'
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

  Widget _intro(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Partner with local tourism',
            style: PixelType.title(context, color: PixelPalette.paper),
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
              Expanded(
                child: Text('Application status',
                    style: PixelType.title(context)),
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
              child: PixelPanel(
                style: PixelBoxStyle.parchment,
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
            SizedBox(height: grid.px(2)),
          ],
        ],
        SizedBox(height: grid.px(2)),
        SizedBox(
          height: grid.px(120),
          child: Stack(
            children: [
              ClipRect(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: _mapZoom,
                    minZoom: 5,
                    maxZoom: 19,
                    onTap: (_, point) => setState(() {
                      _pin = point;
                      _error = null;
                    }),
                  ),
                  children: [
                    buildBaseTileLayer(),
                    if (_pin != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _pin!,
                          width: grid.px(24),
                          height: grid.px(24),
                          child: const Center(
                            child: PixelSprite(
                              DesignerArt.questMarker,
                              scale: 3,
                            ),
                          ),
                        )
                      ]),
                  ],
                ),
              ),
              const Positioned.fill(
                child: PixelCrosshairReticle(),
              ),
              Positioned(
                right: grid.px(1),
                bottom: grid.px(1),
                child: PixelPanel(
                  style: PixelBoxStyle.parchment.copyWith(shadowPx: 0),
                  padding: 1,
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: PixelType.small(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(2)),
        Text(
          _pin == null
              ? 'Pan or zoom, then tap to place your business pin.'
              : 'Pin: ${_pin!.latitude.toStringAsFixed(6)}, ${_pin!.longitude.toStringAsFixed(6)}',
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
      ],
    );
  }

  String? Function(String?) _required(String label) {
    return (value) => value == null || value.trim().length < 2
        ? 'Enter $label'
        : null;
  }
}
