import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/base_tile_layer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';

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
  LatLng _mapCenter = const LatLng(12.8797, 121.774);
  double _mapZoom = 6;
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

  @override
  Widget build(BuildContext context) {
    final status = _existing?['status']?.toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Affiliate')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('Partner with local tourism',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: AppColors.woodBrown)),
                  const SizedBox(height: 8),
                  const Text(
                      'Local businesses can apply to participate in destination quests, vouchers, map discovery, and seasonal events. Applications are reviewed by the team.'),
                  if (status != null) ...[
                    const SizedBox(height: 12),
                    Card(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('Application status'),
                            subtitle: Text(status.replaceAll('_', ' '))),
                        if (_existing?['applicant_feedback'] != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              'Reviewer Note: ${_existing!['applicant_feedback']}',
                              style: const TextStyle(
                                  color: Colors.deepOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    )),
                  ],
                  const SizedBox(height: 18),
                  _field(_business, 'Business name'),
                  DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _category,
                      decoration:
                          const InputDecoration(labelText: 'Business category'),
                      items: _affiliateCategories
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category)),
                  _field(_municipality, 'Municipality / city'),
                  _field(_province, 'Province / region'),
                  const SizedBox(height: 4),
                  Text('Business location',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _placeSearch,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchPlaces(),
                    decoration: const InputDecoration(
                      labelText: 'Search a Philippine city or landmark',
                      border: OutlineInputBorder(
                          borderRadius: AppSpacing.roundedMd),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _searching ? null : _searchPlaces,
                        icon: const Icon(Icons.search),
                        label: Text(_searching ? 'Searching...' : 'Search map'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use my location'),
                      ),
                    ],
                  ),
                  if (_places.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._places.map((place) => ListTile(
                          dense: true,
                          title: Text(place['name']?.toString() ?? 'Place'),
                          subtitle: Text(place['subtitle']?.toString() ?? '',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            final lat = (place['lat'] as num?)?.toDouble();
                            final lng = (place['lng'] as num?)?.toDouble();
                            if (lat == null || lng == null) return;
                            setState(() {
                              _pin =
                                  null; // Search navigates; it does not claim the business is at the result center.
                              _places = const [];
                              if (place['type'] == 'city' ||
                                  place['type'] == 'municipality') {
                                _municipality.text =
                                    place['name']?.toString() ??
                                        _municipality.text;
                              }
                              if (place['type'] == 'province') {
                                _province.text =
                                    place['name']?.toString() ?? _province.text;
                              }
                            });
                            _moveMap(LatLng(lat, lng), 12);
                          },
                        )),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: AppSpacing.roundedMd,
                    child: SizedBox(
                      height: 240,
                      child: Stack(children: [
                        FlutterMap(
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
                                  width: 44,
                                  height: 44,
                                  child: const Icon(Icons.location_pin,
                                      size: 42, color: AppColors.primary),
                                )
                              ]),
                          ],
                        ),
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: ColoredBox(
                            color: Colors.white,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text('© OpenStreetMap contributors',
                                  style: TextStyle(fontSize: 10)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pin == null
                        ? 'Pan or zoom, then tap to place your business pin.'
                        : 'Pin: ${_pin!.latitude.toStringAsFixed(6)}, ${_pin!.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _field(_contact, 'Contact person'),
                  _field(_email, 'Contact email',
                      type: TextInputType.emailAddress),
                  _field(_phone, 'Contact phone', type: TextInputType.phone),
                  const SizedBox(height: 12),
                  Text('How would you like to participate?',
                      style: Theme.of(context).textTheme.titleMedium),
                  ..._affiliateGoals.entries.map((entry) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        value: _goals.contains(entry.key),
                        onChanged: (selected) => setState(() => selected == true
                            ? _goals.add(entry.key)
                            : _goals.remove(entry.key)),
                      )),
                  _field(_details, 'Proposal details (optional)',
                      required: false, maxLines: 4),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  if (_success != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_success!,
                            style: const TextStyle(color: AppColors.primary))),
                  const SizedBox(height: 8),
                  PrimaryButton(
                      label: _submitting
                          ? 'Submitting…'
                          : status == 'received' || status == 'in_review'
                              ? 'Application Under Review'
                              : 'Submit Application',
                      onPressed: _submitting ||
                              status == 'received' ||
                              status == 'in_review'
                          ? null
                          : _submit),
                  const SizedBox(height: 12),
                  Text(
                      'Submitting an application does not guarantee approval. Voucher offers and merchant spending remain subject to separate review.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label,
          {TextInputType? type, bool required = true, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label,
              border:
                  const OutlineInputBorder(borderRadius: AppSpacing.roundedMd)),
          validator: !required
              ? null
              : (value) => value == null || value.trim().length < 2
                  ? 'Enter $label'
                  : null,
        ),
      );
}
