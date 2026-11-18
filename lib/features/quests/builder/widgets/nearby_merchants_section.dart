import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_language.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_box.dart';
import '../../../../core/pixel/pixel_controls.dart';
import '../../../../core/pixel/pixel_feedback.dart';
import '../../../../core/pixel/pixel_grid.dart';
import '../../../../core/pixel/pixel_text.dart';
import '../../../../core/pixel/pixel_text_3d.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../pixel/pixel_tag.dart';
import '../../screens/quest_funding_screen.dart';
import '../../screens/sponsor_request_screen.dart';

/// A shop the creator already asked to sponsor this quest (from the funding
/// round's sponsorships), shown on the builder's review card.
class NearbySponsorInvite {
  const NearbySponsorInvite({
    required this.merchantId,
    required this.name,
    required this.status,
  });

  final String merchantId;
  final String name;
  final String status;
}

/// Shops within this distance of the quest pin (or in the quest's town)
/// count as "nearby".
const int kNearbyMerchantMeters = 5000;

String formatMerchantDistance(int meters) {
  if (meters < 1000) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Quest builder "Merchants nearby": partner shops near the quest pin, each
/// with an invite that opens the Plan 108 sponsorship request flow.
class NearbyMerchantsSection extends ConsumerStatefulWidget {
  const NearbyMerchantsSection({
    super.key,
    required this.questId,
    required this.pinLat,
    required this.pinLng,
    this.onInvitesChanged,
  });

  /// Null while the quest is not saved yet.
  final String? questId;
  final double pinLat;
  final double pinLng;
  final ValueChanged<List<NearbySponsorInvite>>? onInvitesChanged;

  @override
  ConsumerState<NearbyMerchantsSection> createState() =>
      _NearbyMerchantsSectionState();
}

class _NearbyMerchantsSectionState
    extends ConsumerState<NearbyMerchantsSection> {
  List<SponsorDirectoryMerchant> _nearby = const [];
  Map<String, String> _inviteStatus = const {};
  String? _planId;
  String _planStatus = '';
  bool _loading = false;
  bool _unavailable = false;
  String? _error;

  String? get _questId {
    final id = widget.questId;
    return id == null || id.isEmpty ? null : id;
  }

  @override
  void initState() {
    super.initState();
    if (_questId != null) _load();
  }

  @override
  void didUpdateWidget(covariant NearbyMerchantsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_questId != null &&
        (oldWidget.pinLat != widget.pinLat ||
            oldWidget.pinLng != widget.pinLng ||
            oldWidget.questId != widget.questId)) {
      _load();
    }
  }

  Future<void> _load() async {
    final questId = _questId;
    if (questId == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _unavailable = false;
    });
    final dio = ref.read(apiClientProvider).dio;
    try {
      final response = await dio.get(
        '/sponsor-directory',
        queryParameters: {
          'quest_id': questId,
          'lat': widget.pinLat,
          'lng': widget.pinLng,
          'page': 1,
        },
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final rawItems = data is Map ? data['items'] : null;
      final nearby = <SponsorDirectoryMerchant>[
        if (rawItems is List)
          for (final row in rawItems)
            if (row is Map)
              SponsorDirectoryMerchant.fromJson(Map<String, dynamic>.from(row)),
      ].where((m) {
        final d = m.distanceMeters;
        return m.sameMunicipality || (d != null && d <= kNearbyMerchantMeters);
      }).toList()
        ..sort((a, b) {
          final da = a.distanceMeters, db = b.distanceMeters;
          if (da == null && db == null) return a.name.compareTo(b.name);
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      await _loadPlan(dio, questId);
      if (mounted) setState(() => _nearby = nearby);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        setState(() => _unavailable = true);
      } else {
        setState(
          () => _error = tr(
            context,
            en: 'Could not load nearby merchants.',
            tl: 'Hindi makuha ang mga tindahan sa malapit.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPlan(Dio dio, String questId) async {
    Map? plan;
    try {
      final response =
          await dio.get('/quests/${Uri.encodeComponent(questId)}/funding-plan');
      final data = response.data is Map ? response.data['data'] : null;
      plan = data is Map && data['plan'] is Map ? data['plan'] as Map : null;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }
    final invites = <NearbySponsorInvite>[];
    final statusById = <String, String>{};
    for (final s in (plan?['sponsorships'] as List? ?? const [])) {
      if (s is! Map) continue;
      final id = s['merchant_id']?.toString() ?? '';
      final status = s['status']?.toString() ?? 'requested';
      if (id.isEmpty || ['declined', 'withdrawn', 'expired'].contains(status)) {
        continue;
      }
      statusById[id] = status;
      invites.add(NearbySponsorInvite(
        merchantId: id,
        name: s['merchant_name']?.toString() ?? 'Shop',
        status: status,
      ));
    }
    _planId = plan?['id']?.toString();
    _planStatus = plan?['status']?.toString() ?? '';
    _inviteStatus = statusById;
    widget.onInvitesChanged?.call(invites);
  }

  Future<void> _invite(SponsorDirectoryMerchant merchant) async {
    final questId = _questId!;
    final planId = _planId;
    final accepting = ['pending_sponsors', 'active'].contains(_planStatus);
    if (planId == null || planId.isEmpty || !accepting) {
      showPixelToast(
        context,
        tr(
          context,
          en: 'Submit a funding round first, then invite shops.',
          tl: 'Mag-submit muna ng funding round, saka mag-imbita.',
        ),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => QuestFundingScreen(questId: questId),
        ),
      );
    } else {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SponsorRequestScreen(
            questId: questId,
            planId: planId,
            initialMerchant: merchant,
          ),
        ),
      );
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      key: const ValueKey('builder_nearby_merchants'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSectionTitle(
            tr(context, en: 'Merchants nearby', tl: 'Mga tindahan sa malapit'),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            tr(
              context,
              en: 'Partner shops near your quest pin. Invite one to sponsor it.',
              tl: 'Mga tindahan malapit sa quest. Imbitahin silang mag-sponsor.',
            ),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          ..._body(context, grid),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, PixelGrid grid) {
    Widget note(String text, {Key? key}) => Text(
          text,
          key: key,
          style: PixelType.small(context, color: PixelPalette.slate),
        );
    if (_questId == null) {
      return [
        note(
          tr(
            context,
            en: 'Save the draft first to see merchants nearby.',
            tl: 'I-save muna ang draft para makita ang mga tindahan.',
          ),
          key: const ValueKey('nearby_merchants_save_first'),
        ),
      ];
    }
    if (_loading) {
      return const [Center(child: PixelLoader(label: 'Loading merchants'))];
    }
    if (_unavailable) {
      return [
        note(
          tr(
            context,
            en: 'Shop sponsorship is not turned on yet.',
            tl: 'Hindi pa bukas ang sponsorship ng tindahan.',
          ),
          key: const ValueKey('nearby_merchants_unavailable'),
        ),
      ];
    }
    if (_error != null) {
      return [
        note(_error!),
        SizedBox(height: grid.px(1)),
        Align(
          alignment: Alignment.centerLeft,
          child: PixelButton(
            label: tr(context, en: 'RETRY', tl: 'SUBUKAN ULIT'),
            variant: PixelButtonVariant.secondary,
            onPressed: _load,
          ),
        ),
      ];
    }
    if (_nearby.isEmpty) {
      return [
        note(
          tr(
            context,
            en: 'No partner shops near this quest yet.',
            tl: 'Wala pang partner na tindahan malapit sa quest na ito.',
          ),
          key: const ValueKey('nearby_merchants_empty'),
        ),
      ];
    }
    return [
      for (final m in _nearby)
        Padding(
          padding: EdgeInsets.only(bottom: grid.px(2)),
          child: _row(context, grid, m),
        ),
    ];
  }

  Widget _row(
      BuildContext context, PixelGrid grid, SponsorDirectoryMerchant m) {
    final status = _inviteStatus[m.id];
    final distance = m.distanceMeters;
    return PixelPanel(
      key: ValueKey('nearby_merchant_${m.id}'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.name, style: PixelType.body(context)),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              PixelTag(
                distance != null
                    ? formatMerchantDistance(distance)
                    : tr(context, en: 'IN TOWN', tl: 'SA BAYAN'),
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
              ),
              if (m.category.isNotEmpty) PixelTag(m.category),
              if (m.municipality.isNotEmpty) PixelTag(m.municipality),
            ],
          ),
          SizedBox(height: grid.px(1.5)),
          if (status != null)
            PixelTag(
              status.toUpperCase(),
              key: ValueKey('nearby_invited_${m.id}'),
              style: PixelBoxStyle.green,
              textColor: PixelPalette.cream,
            )
          else
            PixelButton(
              key: ValueKey('nearby_invite_${m.id}'),
              label: tr(context, en: 'INVITE TO SPONSOR', tl: 'IMBITAHIN'),
              variant: PixelButtonVariant.secondary,
              onPressed: () => _invite(m),
            ),
        ],
      ),
    );
  }
}
