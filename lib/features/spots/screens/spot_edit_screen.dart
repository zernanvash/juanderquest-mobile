import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../quests/builder/builder_models.dart';
import '../../quests/builder/widgets/location_fence_map_picker.dart';
import '../models/spot_model.dart';
import '../utils/relocation_math.dart';

class GpsFixResult {
  final double lat;
  final double lng;
  final double accuracyMeters;

  const GpsFixResult({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
  });
}

typedef GpsFixFetcher = Future<GpsFixResult?> Function(
  void Function(double accuracyMeters) onAccuracyUpdate,
);

const _kSpotCategories = <MapEntry<String, String>>[
  MapEntry('eat_drink', 'Eat & Drink'),
  MapEntry('nature_outdoors', 'Nature & Outdoors'),
  MapEntry('culture_heritage', 'Culture & Heritage'),
  MapEntry('activities_wellness', 'Activities & Wellness'),
  MapEntry('shopping_local', 'Shopping & Local Finds'),
  MapEntry('stay', 'Stay'),
];

const _kGoodForOptions = <MapEntry<String, String>>[
  MapEntry('families', 'Families'),
  MapEntry('solo', 'Solo'),
  MapEntry('couples', 'Couples'),
  MapEntry('groups', 'Groups'),
  MapEntry('seniors_access', 'Seniors & Access'),
];

/// Plan 118: 5-page compact destination editor for the destination's author.
class SpotEditScreen extends ConsumerStatefulWidget {
  final SpotModel spot;
  final GpsFixFetcher? gpsFixFetcher;
  final Future<Map<String, dynamic>> Function(
    String spotId,
    Map<String, dynamic> payload,
  )? patchOverride;

  const SpotEditScreen({
    super.key,
    required this.spot,
    this.gpsFixFetcher,
    this.patchOverride,
  });

  @override
  ConsumerState<SpotEditScreen> createState() => _SpotEditScreenState();
}

class _SpotEditScreenState extends ConsumerState<SpotEditScreen> {
  static const int _totalSteps = 5;

  int _step = 0; // 0..4 => 1/5 .. 5/5
  late final TextEditingController _nameCtrl;
  late final TextEditingController _subcategoryCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _hoursCtrl;

  late String _category;
  late double _lat;
  late double _lng;
  late int? _priceLevel;
  late Set<String> _goodFor;

  double? _gpsAccuracyMeters;
  bool _locatingGps = false;
  bool _saving = false;
  String? _errorMessage;
  int? _pendingRelocationMeters;
  SpotModel? _savedSpot;

  @override
  void initState() {
    super.initState();
    final s = widget.spot;
    _nameCtrl = TextEditingController(text: s.name);
    _subcategoryCtrl = TextEditingController(
      text: s.subcategory.isNotEmpty ? s.subcategory : 'landmark',
    );
    _descCtrl = TextEditingController(text: s.description);
    _addressCtrl = TextEditingController(text: s.address);
    _hoursCtrl = TextEditingController(
      text: s.hours['daily'] ?? (s.hours.isNotEmpty ? s.hours.values.first : ''),
    );
    _category = _kSpotCategories.any((e) => e.key == s.category)
        ? s.category
        : 'nature_outdoors';
    _lat = s.gpsLat;
    _lng = s.gpsLng;
    _priceLevel = s.priceLevel;
    _goodFor = Set<String>.from(s.goodFor);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subcategoryCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  double get _movedMeters => haversineMeters(
        widget.spot.gpsLat,
        widget.spot.gpsLng,
        _lat,
        _lng,
      );

  bool get _coordsInPhBounds =>
      _lat >= 4.5 && _lat <= 21.5 && _lng >= 116.0 && _lng <= 127.0;

  String? _stepValidationError(BuildContext context) {
    switch (_step) {
      case 0:
        if (_nameCtrl.text.trim().length < 3) {
          return tr(
            context,
            en: 'Name needs at least 3 characters.',
            tl: 'Kailangan ng hindi bababa sa 3 letra ang pangalan.',
          );
        }
        return null;
      case 1:
        if (_descCtrl.text.trim().length < 20) {
          return tr(
            context,
            en: 'Description needs at least 20 characters.',
            tl: 'Kailangan ng hindi bababa sa 20 letra ang paglalarawan.',
          );
        }
        return null;
      case 2:
        if (!_coordsInPhBounds) {
          return tr(
            context,
            en: 'Pin must stay inside the Philippines.',
            tl: 'Dapat nasa loob ng Pilipinas ang pin.',
          );
        }
        return null;
      case 3:
        if (_addressCtrl.text.trim().length < 3) {
          return tr(
            context,
            en: 'Address needs at least 3 characters.',
            tl: 'Kailangan ng hindi bababa sa 3 letra ang address.',
          );
        }
        return null;
      default:
        return null;
    }
  }

  Future<GpsFixResult?> _defaultFetchGpsFix(
    void Function(double accuracyMeters) onAccuracyUpdate,
  ) async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }

    final completer = Completer<GpsFixResult?>();
    GpsFixResult? best;
    StreamSubscription<Position>? sub;
    Timer? timer;

    void finish(GpsFixResult? result) {
      if (completer.isCompleted) return;
      timer?.cancel();
      unawaited(sub?.cancel());
      completer.complete(result);
    }

    timer = Timer(const Duration(seconds: 15), () => finish(best));

    try {
      sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(
        (pos) {
          final fix = GpsFixResult(
            lat: pos.latitude,
            lng: pos.longitude,
            accuracyMeters: pos.accuracy,
          );
          onAccuracyUpdate(pos.accuracy);
          if (best == null || fix.accuracyMeters < best!.accuracyMeters) {
            best = fix;
          }
          if (pos.accuracy <= 20.0) {
            finish(fix);
          }
        },
        onError: (_) => finish(best),
      );
    } catch (_) {
      finish(best);
    }

    return completer.future;
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locatingGps = true;
      _errorMessage = null;
    });
    try {
      final fetcher = widget.gpsFixFetcher ?? _defaultFetchGpsFix;
      final fix = await fetcher((acc) {
        if (mounted) setState(() => _gpsAccuracyMeters = acc);
      });
      if (!mounted) return;
      if (fix != null) {
        setState(() {
          _lat = fix.lat;
          _lng = fix.lng;
          _gpsAccuracyMeters = fix.accuracyMeters;
        });
      }
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final hoursText = _hoursCtrl.text.trim();
    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'category': _category,
      'subcategory': _subcategoryCtrl.text.trim().isNotEmpty
          ? _subcategoryCtrl.text.trim()
          : widget.spot.subcategory,
      'description': _descCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'gps_lat': _lat,
      'gps_lng': _lng,
      if (_gpsAccuracyMeters != null) 'accuracy_m': _gpsAccuracyMeters,
      if (_priceLevel != null) 'price_level': _priceLevel,
      'good_for': _goodFor.toList(),
      'hours': hoursText.isNotEmpty ? {'daily': hoursText} : <String, String>{},
    };

    try {
      int statusCode = 200;
      Map<String, dynamic> body;

      if (widget.patchOverride != null) {
        body = await widget.patchOverride!(widget.spot.id, payload);
        statusCode = (body['_status'] as int?) ??
            (body['relocation'] != null ? 202 : 200);
      } else {
        final res = await ref.read(apiClientProvider).dio.patch(
              '/spots/${widget.spot.id}',
              data: payload,
            );
        statusCode = res.statusCode ?? 200;
        body = res.data is Map
            ? Map<String, dynamic>.from(res.data as Map)
            : <String, dynamic>{};
      }

      if (!mounted) return;
      final dataMap = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : null;
      final updatedSpot = dataMap != null
          ? SpotModel.fromJson(dataMap)
          : widget.spot.copyWith(
              name: payload['name'] as String,
              category: payload['category'] as String,
              description: payload['description'] as String,
              address: payload['address'] as String,
              priceLevel: _priceLevel,
              goodFor: _goodFor.toList(),
            );

      final reloc = (body['relocation'] ?? dataMap?['relocation']) as Map?;
      if (statusCode == 202 && reloc != null) {
        final distM =
            (reloc['distance_m'] as num?)?.toInt() ?? _movedMeters.round();
        setState(() {
          _saving = false;
          _savedSpot = updatedSpot;
          _pendingRelocationMeters = distM;
        });
        return;
      }

      showPixelToast(context, tr(context, en: 'Saved', tl: 'Na-save na'));
      Navigator.of(context).pop(updatedSpot);
    } catch (e) {
      if (!mounted) return;
      final failure = ApiFailure.from(
        e,
        fallback: tr(
          context,
          en: 'Could not save changes. Please try again.',
          tl: 'Hindi na-save ang pagbabago. Subukan muli.',
        ),
      );
      setState(() {
        _saving = false;
        _errorMessage = failure.code == 'SPOT_LOCKED_FOR_REVIEW'
            ? tr(
                context,
                en: 'This destination is hidden for review and cannot be edited right now.',
                tl: 'Naka-review pa ang lugar na ito kaya hindi pa maaaring i-edit.',
              )
            : failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final stepError = _stepValidationError(context);

    return Theme(
      data: AppTheme.pixel,
      child: Scaffold(
        backgroundColor: PixelPalette.paper,
        body: DitherBackground(
          top: PixelPalette.paper,
          bottom: PixelPalette.parchment,
          child: SafeArea(
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(
                    context,
                    en: 'EDIT PLACE',
                    tl: 'I-EDIT ANG LUGAR',
                  ),
                  onBack: () => Navigator.of(context).maybePop(_savedSpot),
                  actions: [
                    Padding(
                      padding: EdgeInsets.only(right: grid.px(1)),
                      child: Center(
                        child: Text(
                          '${_step + 1} / $_totalSteps',
                          key: const Key('spot_edit_progress'),
                          style: PixelType.title(
                            context,
                            color: PixelPalette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(grid.px(3)),
                    child: _pendingRelocationMeters != null
                        ? _buildPendingRelocationPanel(context)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_errorMessage != null) ...[
                                PixelPanel(
                                  key: const Key('spot_edit_error_panel'),
                                  style: PixelBoxStyle.parchment,
                                  child: Text(
                                    _errorMessage!,
                                    style: PixelType.body(
                                      context,
                                      color: PixelPalette.red,
                                    ),
                                  ),
                                ),
                                SizedBox(height: grid.px(2)),
                              ],
                              PixelPanel(
                                child: _buildStepBody(context, stepError),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_pendingRelocationMeters == null)
                  _buildBottomBar(context, stepError),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRelocationPanel(BuildContext context) {
    final grid = PixelGrid.of(context);
    final dist = _pendingRelocationMeters ?? 0;
    return PixelPanel(
      key: const Key('relocation_pending_panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'MOVE SENT FOR REVIEW', tl: 'IPINADALA PARA SA REVIEW'),
            colors: PixelText3DColors.gold,
          ),
          SizedBox(height: grid.px(2)),
          Text(
            tr(
              context,
              en: 'Your move of $dist m is waiting for review. The pin stays where it was until then.',
              tl: 'Naghihintay ng review ang paglipat mo ng $dist m. Mananatili muna ang pin sa dati nitong puwesto.',
            ),
            style: PixelType.body(context, color: PixelPalette.ink),
          ),
          SizedBox(height: grid.px(3)),
          PixelButton(
            label: tr(context, en: 'DONE', tl: 'TAPOS'),
            variant: PixelButtonVariant.primary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(_savedSpot),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(BuildContext context, String? stepError) {
    final grid = PixelGrid.of(context);
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'NAME & CATEGORY', tl: 'PANGALAN AT KATEGORYA'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            PixelTextField(
              controller: _nameCtrl,
              label: tr(context, en: 'Destination name', tl: 'Pangalan ng lugar'),
              onChanged: (_) => setState(() {}),
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
            SizedBox(height: grid.px(2)),
            Text(
              tr(context, en: 'Category', tl: 'Kategorya'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _kSpotCategories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.key,
                      child: Text(c.value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            SizedBox(height: grid.px(2)),
            PixelTextField(
              controller: _subcategoryCtrl,
              label: tr(context, en: 'Subcategory', tl: 'Uri ng lugar'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'DESCRIPTION', tl: 'PAGLALARAWAN'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            PixelTextField(
              controller: _descCtrl,
              label: tr(
                context,
                en: 'Tell travelers what makes this place worth visiting',
                tl: 'Ikuwento kung bakit magandang puntahan ang lugar na ito',
              ),
              maxLines: 5,
              onChanged: (_) => setState(() {}),
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case 2:
        final movedM = _movedMeters.round();
        final needsReview = requiresRelocationReview(_movedMeters);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'LOCATION', tl: 'LOKASYON'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(1.5)),
            Text(
              tr(
                context,
                en: 'Drag the map under the pin or use a live GPS fix.',
                tl: 'I-drag ang mapa sa ilalim ng pin o gamitin ang GPS.',
              ),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1.5)),
            LocationFenceMapPicker(
              fence: GeoFence(lat: _lat, lng: _lng, radiusMeters: 100),
              pinLabel: tr(context, en: 'Place pin', tl: 'Pin ng lugar'),
              onChanged: (next) {
                setState(() {
                  _lat = next.lat;
                  _lng = next.lng;
                });
              },
            ),
            SizedBox(height: grid.px(1.5)),
            PixelButton(
              key: const Key('spot_edit_use_gps_btn'),
              label: _locatingGps
                  ? tr(context, en: 'GETTING GPS FIX…', tl: 'KINUKUHA ANG GPS…')
                  : tr(context, en: 'USE MY LOCATION', tl: 'GAMITIN ANG LOKASYON KO'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: _locatingGps ? null : _useMyLocation,
            ),
            SizedBox(height: grid.px(1.5)),
            Wrap(
              spacing: grid.px(1.5),
              runSpacing: grid.px(1),
              children: [
                if (_gpsAccuracyMeters != null)
                  PixelChip(
                    '±${_gpsAccuracyMeters!.round()} m',
                    style: PixelBoxStyle.green,
                    textColor: PixelPalette.white,
                  ),
                PixelChip(
                  movedM == 0
                      ? tr(context, en: 'Pin unchanged', tl: 'Walang paglipat')
                      : needsReview
                          ? tr(
                              context,
                              en: 'Moved $movedM m (review needed)',
                              tl: 'Inilipat $movedM m (for review)',
                            )
                          : tr(
                              context,
                              en: 'Moved $movedM m (saves now)',
                              tl: 'Inilipat $movedM m (diretsong save)',
                            ),
                  style: needsReview ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                  textColor: PixelPalette.ink,
                ),
              ],
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'DETAILS', tl: 'DETALYE'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            PixelTextField(
              controller: _addressCtrl,
              label: tr(context, en: 'Address', tl: 'Address'),
              onChanged: (_) => setState(() {}),
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
            SizedBox(height: grid.px(2)),
            PixelTextField(
              controller: _hoursCtrl,
              label: tr(context, en: 'Hours (e.g. 08:00-18:00)', tl: 'Oras (hal. 08:00-18:00)'),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: grid.px(2)),
            Text(
              tr(context, en: 'Price level', tl: 'Presyo'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final lvl in [0, 1, 2, 3, 4])
                  GestureDetector(
                    onTap: () => setState(() => _priceLevel = lvl),
                    child: PixelChip(
                      lvl == 0 ? 'Free' : '₱' * lvl,
                      style: _priceLevel == lvl
                          ? PixelBoxStyle.wood
                          : PixelBoxStyle.parchment,
                      textColor: _priceLevel == lvl
                          ? PixelPalette.paper
                          : PixelPalette.ink,
                    ),
                  ),
              ],
            ),
            SizedBox(height: grid.px(2)),
            Text(
              tr(context, en: 'Good for', tl: 'Bagay para sa'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final opt in _kGoodForOptions)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_goodFor.contains(opt.key)) {
                        _goodFor.remove(opt.key);
                      } else {
                        _goodFor.add(opt.key);
                      }
                    }),
                    child: PixelChip(
                      opt.value,
                      style: _goodFor.contains(opt.key)
                          ? PixelBoxStyle.green
                          : PixelBoxStyle.parchment,
                      textColor: _goodFor.contains(opt.key)
                          ? PixelPalette.white
                          : PixelPalette.ink,
                    ),
                  ),
              ],
            ),
          ],
        );

      case 4:
      default:
        final movedM = _movedMeters.round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'REVIEW & SAVE', tl: 'SURIIN AT I-SAVE'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            PixelStatRow(
              tr(context, en: 'Name', tl: 'Pangalan'),
              _nameCtrl.text.trim(),
            ),
            SizedBox(height: grid.px(1)),
            PixelStatRow(
              tr(context, en: 'Category', tl: 'Kategorya'),
              _category.replaceAll('_', ' '),
            ),
            SizedBox(height: grid.px(1)),
            PixelStatRow(
              tr(context, en: 'Pin move', tl: 'Lipat ng pin'),
              movedM == 0
                  ? tr(context, en: 'Unchanged', tl: 'Walang pagbabago')
                  : '$movedM m${requiresRelocationReview(_movedMeters) ? ' (review)' : ''}',
            ),
            SizedBox(height: grid.px(1)),
            PixelStatRow(
              tr(context, en: 'Address', tl: 'Address'),
              _addressCtrl.text.trim(),
            ),
          ],
        );
    }
  }

  Widget _buildBottomBar(BuildContext context, String? stepError) {
    final grid = PixelGrid.of(context);
    final isLast = _step == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.all(grid.px(2.5)),
      decoration: const BoxDecoration(
        color: PixelPalette.parchment,
        border: Border(top: BorderSide(color: PixelPalette.ink, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PixelButton(
              key: const Key('spot_edit_back_btn'),
              label: tr(context, en: 'BACK', tl: 'BALIK'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: _saving
                  ? null
                  : () {
                      if (_step == 0) {
                        Navigator.of(context).maybePop();
                      } else {
                        setState(() => _step -= 1);
                      }
                    },
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: PixelButton(
              key: Key(isLast ? 'spot_edit_save_btn' : 'spot_edit_next_btn'),
              label: isLast
                  ? (_saving
                      ? tr(context, en: 'SAVING…', tl: 'SINE-SAVE…')
                      : tr(context, en: 'SAVE', tl: 'I-SAVE'))
                  : tr(context, en: 'NEXT', tl: 'SUNOD'),
              variant: PixelButtonVariant.primary,
              expand: true,
              onPressed: (_saving || (!isLast && stepError != null))
                  ? null
                  : () {
                      if (isLast) {
                        _save();
                      } else {
                        setState(() => _step += 1);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
