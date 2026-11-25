import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_theme.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../auth/providers/auth_provider.dart';

class MerchantLinkedSpot {
  final String id;
  final String slug;
  final String name;
  final String municipality;
  final double gpsLat;
  final double gpsLng;
  final String? imageUrl;

  const MerchantLinkedSpot({
    required this.id,
    required this.slug,
    required this.name,
    required this.municipality,
    required this.gpsLat,
    required this.gpsLng,
    this.imageUrl,
  });

  factory MerchantLinkedSpot.fromJson(Map<String, dynamic> j) =>
      MerchantLinkedSpot(
        id: j['id']?.toString() ?? '',
        slug: j['slug']?.toString() ?? j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        municipality: j['municipality']?.toString() ?? '',
        gpsLat: (j['gps_lat'] as num?)?.toDouble() ?? 0.0,
        gpsLng: (j['gps_lng'] as num?)?.toDouble() ?? 0.0,
        imageUrl: j['image_url']?.toString(),
      );
}

class MerchantPendingClaim {
  final String id;
  final String spotId;
  final String spotName;
  final String status;
  final String createdAt;

  const MerchantPendingClaim({
    required this.id,
    required this.spotId,
    required this.spotName,
    required this.status,
    required this.createdAt,
  });

  factory MerchantPendingClaim.fromJson(Map<String, dynamic> j) =>
      MerchantPendingClaim(
        id: j['id']?.toString() ?? '',
        spotId: j['spot_id']?.toString() ?? '',
        spotName: j['spot_name']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pending',
        createdAt: j['created_at']?.toString() ?? '',
      );
}

class MerchantLocationCandidates {
  final List<MerchantLinkedSpot> authoredSpots;
  final MerchantLinkedSpot? linkedSpot;
  final MerchantPendingClaim? pendingClaim;

  const MerchantLocationCandidates({
    required this.authoredSpots,
    this.linkedSpot,
    this.pendingClaim,
  });

  factory MerchantLocationCandidates.fromJson(Map<String, dynamic> j) {
    final rawSpots = j['authored_spots'];
    final authored = rawSpots is List
        ? [
            for (final item in rawSpots)
              if (item is Map)
                MerchantLinkedSpot.fromJson(Map<String, dynamic>.from(item)),
          ]
        : const <MerchantLinkedSpot>[];
    return MerchantLocationCandidates(
      authoredSpots: authored,
      linkedSpot: j['linked_spot'] is Map
          ? MerchantLinkedSpot.fromJson(
              Map<String, dynamic>.from(j['linked_spot'] as Map),
            )
          : null,
      pendingClaim: j['pending_claim'] is Map
          ? MerchantPendingClaim.fromJson(
              Map<String, dynamic>.from(j['pending_claim'] as Map),
            )
          : null,
    );
  }
}

class ClaimSpotHit {
  final String id;
  final String slug;
  final String name;
  final String municipality;

  const ClaimSpotHit({
    required this.id,
    required this.slug,
    required this.name,
    required this.municipality,
  });

  factory ClaimSpotHit.fromJson(Map<String, dynamic> j) => ClaimSpotHit(
        id: j['id']?.toString() ?? '',
        slug: j['slug']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        municipality: j['municipality']?.toString() ?? '',
      );
}

abstract class MerchantLocationApi {
  Future<MerchantLocationCandidates> fetchCandidates();
  Future<MerchantLinkedSpot> linkAuthoredSpot(String spotId);
  Future<void> unlinkLocation();
  Future<List<ClaimSpotHit>> searchSpots(String query);
  Future<MerchantPendingClaim> submitClaim({
    required String spotId,
    required String note,
    String? proofUrl,
  });
  Future<void> cancelClaim(String claimId);
}

class DioMerchantLocationApi implements MerchantLocationApi {
  DioMerchantLocationApi(this._dio);
  final Dio _dio;

  @override
  Future<MerchantLocationCandidates> fetchCandidates() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/merchant/location/candidates',
    );
    final data = res.data?['data'];
    if (data is Map) {
      return MerchantLocationCandidates.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return const MerchantLocationCandidates(authoredSpots: []);
  }

  @override
  Future<MerchantLinkedSpot> linkAuthoredSpot(String spotId) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/merchant/location',
      data: {'spot_id': spotId},
    );
    final data = res.data?['data'];
    if (data is Map && data['linked_spot'] is Map) {
      return MerchantLinkedSpot.fromJson(
        Map<String, dynamic>.from(data['linked_spot'] as Map),
      );
    }
    throw StateError('Unexpected link response');
  }

  @override
  Future<void> unlinkLocation() async {
    await _dio.delete<Map<String, dynamic>>('/merchant/location');
  }

  @override
  Future<List<ClaimSpotHit>> searchSpots(String query) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/spots/search',
      queryParameters: {'q': query, 'limit': 8},
    );
    final data = res.data?['data'];
    if (data is List) {
      return [
        for (final item in data)
          if (item is Map)
            ClaimSpotHit.fromJson(Map<String, dynamic>.from(item)),
      ];
    }
    return const [];
  }

  @override
  Future<MerchantPendingClaim> submitClaim({
    required String spotId,
    required String note,
    String? proofUrl,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/merchant/location/claim',
      data: {
        'spot_id': spotId,
        'note': note,
        if (proofUrl != null && proofUrl.trim().isNotEmpty)
          'proof_url': proofUrl.trim(),
      },
    );
    final data = res.data?['data'];
    if (data is Map) {
      return MerchantPendingClaim.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Unexpected claim response');
  }

  @override
  Future<void> cancelClaim(String claimId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/merchant/location/claim/$claimId',
    );
  }
}

final merchantLocationApiProvider = Provider<MerchantLocationApi>(
  (ref) => DioMerchantLocationApi(ref.watch(apiClientProvider).dio),
);

/// Plan 122a: Merchant Hub → Store Location screen (`/merchant/location`).
class MerchantLocationScreen extends ConsumerStatefulWidget {
  const MerchantLocationScreen({super.key});

  @override
  ConsumerState<MerchantLocationScreen> createState() =>
      _MerchantLocationScreenState();
}

class _MerchantLocationScreenState
    extends ConsumerState<MerchantLocationScreen> {
  MerchantLocationCandidates? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _proofCtrl = TextEditingController();
  List<ClaimSpotHit> _searchHits = const [];
  bool _searching = false;
  ClaimSpotHit? _selectedClaimSpot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _proofCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(merchantLocationApiProvider).fetchCandidates();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map && body['error'] is Map) {
        final msg = body['error']['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return 'Could not complete store location request.';
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? PixelPalette.red : PixelPalette.woodDeep,
      ),
    );
  }

  Future<void> _linkSpot(MerchantLinkedSpot spot) async {
    setState(() => _busy = true);
    try {
      await ref.read(merchantLocationApiProvider).linkAuthoredSpot(spot.id);
      _toast('Linked "${spot.name}" as your Store Location.');
      await _load();
    } catch (e) {
      _toast(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    setState(() => _busy = true);
    try {
      await ref.read(merchantLocationApiProvider).unlinkLocation();
      _toast('Store Location unlinked.');
      await _load();
    } catch (e) {
      _toast(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelClaim(String claimId) async {
    setState(() => _busy = true);
    try {
      await ref.read(merchantLocationApiProvider).cancelClaim(claimId);
      _toast('Location claim cancelled.');
      await _load();
    } catch (e) {
      _toast(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _searchHits = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final hits = await ref.read(merchantLocationApiProvider).searchSpots(q);
      if (!mounted) return;
      setState(() {
        _searchHits = hits;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      _toast(_friendlyError(e), error: true);
    }
  }

  Future<void> _submitClaim() async {
    final spot = _selectedClaimSpot;
    final note = _noteCtrl.text.trim();
    if (spot == null) {
      _toast('Select a destination to claim first.', error: true);
      return;
    }
    if (note.length < 10) {
      _toast('Enter an ownership note (at least 10 characters).', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(merchantLocationApiProvider).submitClaim(
            spotId: spot.id,
            note: note,
            proofUrl:
                _proofCtrl.text.trim().isEmpty ? null : _proofCtrl.text.trim(),
          );
      _noteCtrl.clear();
      _proofCtrl.clear();
      setState(() {
        _selectedClaimSpot = null;
        _searchHits = const [];
      });
      _toast('Location claim submitted for admin review.');
      await _load();
    } catch (e) {
      _toast(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Theme(
      data: PixelTheme.build(),
      child: JdqScaffold(
        padding: EdgeInsets.zero,
        appBar: AppBar(
          backgroundColor: PixelPalette.paper,
          foregroundColor: PixelPalette.ink,
          elevation: 0,
          title: Text(
            'Store Location',
            style: PixelType.title(context, color: PixelPalette.ink),
          ),
        ),
        body: _loading
            ? const Center(child: PixelLoader(label: 'LOADING LOCATION'))
            : _error != null
                ? Center(
                    child: PixelPanel(
                      style: PixelBoxStyle.parchment,
                      padding: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: PixelType.body(context)),
                          SizedBox(height: grid.px(2)),
                          PixelButton(
                            label: 'RETRY',
                            variant: PixelButtonVariant.primary,
                            onPressed: _load,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(grid.px(2)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCurrentStatus(context, grid),
                        SizedBox(height: grid.px(2)),
                        _buildAuthoredSection(context, grid),
                        SizedBox(height: grid.px(2)),
                        _buildClaimSection(context, grid),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCurrentStatus(BuildContext context, PixelGrid grid) {
    final linked = _data?.linkedSpot;
    final pending = _data?.pendingClaim;
    return PixelPanel(
      key: const ValueKey('merchant_location_status_panel'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CURRENT LINKED DESTINATION',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          if (linked != null) ...[
            Text(
              linked.name,
              style: PixelType.title(context, color: PixelPalette.ink),
            ),
            if (linked.municipality.isNotEmpty)
              Text(
                linked.municipality,
                style: PixelType.small(context, color: PixelPalette.woodDeep),
              ),
            SizedBox(height: grid.px(1.5)),
            Wrap(
              spacing: grid.px(1.5),
              runSpacing: grid.px(1.5),
              children: [
                PixelButton(
                  key: const ValueKey('merchant_location_view_map_btn'),
                  label: 'VIEW ON MAP',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => context.push('/map?spot=${linked.slug}'),
                ),
                PixelButton(
                  key: const ValueKey('merchant_location_unlink_btn'),
                  label: 'UNLINK',
                  variant: PixelButtonVariant.danger,
                  onPressed: _busy ? null : _unlink,
                ),
              ],
            ),
          ] else if (pending != null) ...[
            PixelPanel(
              key: const ValueKey('merchant_location_pending_banner'),
              style: PixelBoxStyle.gold,
              padding: 1,
              child: Text(
                'PENDING ADMIN REVIEW',
                style: PixelType.small(
                  context,
                  color: PixelPalette.ink,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              pending.spotName,
              style: PixelType.body(
                context,
                color: PixelPalette.ink,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: grid.px(1.5)),
            Align(
              alignment: Alignment.centerLeft,
              child: PixelButton(
                key: const ValueKey('merchant_location_cancel_claim_btn'),
                label: 'CANCEL CLAIM',
                variant: PixelButtonVariant.danger,
                onPressed: _busy ? null : () => _cancelClaim(pending.id),
              ),
            ),
          ] else
            Text(
              'No destination linked yet. Link one of your published spots below or submit a claim for an existing place.',
              style: PixelType.small(context, color: PixelPalette.woodDeep),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthoredSection(BuildContext context, PixelGrid grid) {
    final spots = _data?.authoredSpots ?? const [];
    final linkedId = _data?.linkedSpot?.id;
    return PixelPanel(
      key: const ValueKey('merchant_location_authored_panel'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MY PUBLISHED DESTINATIONS (INSTANT LINK)',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          if (spots.isEmpty) ...[
            Text(
              'You have no published destinations available to link instantly.',
              style: PixelType.small(context, color: PixelPalette.woodDeep),
            ),
            SizedBox(height: grid.px(1.5)),
            Align(
              alignment: Alignment.centerLeft,
              child: PixelButton(
                key: const ValueKey('merchant_location_create_spot_btn'),
                label: 'CREATE NEW DESTINATION',
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/map'),
              ),
            ),
          ] else ...[
            for (final spot in spots)
              Padding(
                padding: EdgeInsets.only(bottom: grid.px(1.5)),
                child: PixelPanel(
                  style: PixelBoxStyle.slot,
                  padding: 2,
                  child: Wrap(
                    spacing: grid.px(1.5),
                    runSpacing: grid.px(1),
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              style: PixelType.small(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                        ],
                      ),
                      if (linkedId == spot.id)
                        PixelPanel(
                          style: PixelBoxStyle.green,
                          padding: 1,
                          child: Text(
                            'LINKED',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.white,
                            ),
                          ),
                        )
                      else
                        PixelButton(
                          key: ValueKey('merchant_link_spot_${spot.id}'),
                          label: 'SET AS LOCATION',
                          variant: PixelButtonVariant.primary,
                          onPressed: _busy ? null : () => _linkSpot(spot),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildClaimSection(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      key: const ValueKey('merchant_location_claim_panel'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CLAIM AN EXISTING PLACE (ADMIN REVIEW)',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelTextField(
            key: const ValueKey('merchant_claim_search_input'),
            controller: _searchCtrl,
            hint: 'Search published destination...',
          ),
          SizedBox(height: grid.px(1)),
          Align(
            alignment: Alignment.centerLeft,
            child: PixelButton(
              key: const ValueKey('merchant_claim_search_btn'),
              label: _searching ? 'SEARCHING...' : 'SEARCH PLACES',
              variant: PixelButtonVariant.secondary,
              onPressed: _searching ? null : _runSearch,
            ),
          ),
          if (_searchHits.isNotEmpty) ...[
            SizedBox(height: grid.px(1.5)),
            for (final hit in _searchHits)
              Padding(
                padding: EdgeInsets.only(bottom: grid.px(1)),
                child: InkWell(
                  key: ValueKey('merchant_claim_hit_${hit.id}'),
                  onTap: () => setState(() => _selectedClaimSpot = hit),
                  child: PixelPanel(
                    style: _selectedClaimSpot?.id == hit.id
                        ? PixelBoxStyle.gold
                        : PixelBoxStyle.slot,
                    padding: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hit.name,
                          style: PixelType.body(
                            context,
                            color: PixelPalette.ink,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (hit.municipality.isNotEmpty)
                          Text(
                            hit.municipality,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.woodDeep,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          if (_selectedClaimSpot != null) ...[
            SizedBox(height: grid.px(1.5)),
            Text(
              'Selected: ${_selectedClaimSpot!.name}',
              style: PixelType.body(
                context,
                color: PixelPalette.ink,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          SizedBox(height: grid.px(1.5)),
          PixelTextField(
            key: const ValueKey('merchant_claim_note_input'),
            controller: _noteCtrl,
            hint:
                'Explain your business ownership at this place (10-500 chars)',
            maxLines: 3,
          ),
          SizedBox(height: grid.px(1)),
          PixelTextField(
            key: const ValueKey('merchant_claim_proof_input'),
            controller: _proofCtrl,
            hint: 'Optional proof URL (https://...)',
          ),
          SizedBox(height: grid.px(1.5)),
          PixelButton(
            key: const ValueKey('merchant_claim_submit_btn'),
            label: 'SUBMIT CLAIM',
            variant: PixelButtonVariant.primary,
            onPressed: _busy ? null : _submitClaim,
          ),
        ],
      ),
    );
  }
}
