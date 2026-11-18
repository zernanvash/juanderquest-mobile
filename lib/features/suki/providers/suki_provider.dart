import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/suki_models.dart';

/// Plan 107 — the customer's Suki Card calls (plan §6.4).
class SukiApi {
  SukiApi(this._api);

  final ApiClient _api;
  static const _uuid = Uuid();

  Map<String, dynamic> _data(Object? body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  List<Map<String, dynamic>> _rows(Object? value) => [
        for (final row in (value is List ? value : const []))
          if (row is Map) Map<String, dynamic>.from(row),
      ];

  Future<List<SukiCard>> myCards() async => _rows(
        _data((await _api.dio.get('/me/suki-cards')).data)['cards'],
      ).map(SukiCard.fromJson).toList();

  Future<List<SukiProgram>> nearby({double? lat, double? lng}) async => _rows(
        _data((await _api.dio.get('/suki/programs', queryParameters: {
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'limit': 30,
        }))
            .data)['programs'],
      ).map(SukiProgram.fromJson).toList();

  Future<SukiProgramDetail> program(String id) async =>
      SukiProgramDetail.fromJson(_data(
          (await _api.dio.get('/suki/programs/${Uri.encodeComponent(id)}'))
              .data));

  Future<SukiVisitResult> recordVisit({
    required String standee,
    required double lat,
    required double lng,
    required double accuracyM,
  }) async =>
      SukiVisitResult.fromJson(
          _data((await _api.dio.post('/suki/visits', data: {
        'standee': standee,
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracyM,
        'idempotency_key': _uuid.v4(),
      }))
              .data));

  Future<({String pass, DateTime? expiresAt})> pass(String programId) async {
    final data = _data(
      (await _api.dio.post('/suki/pass', data: {'program_id': programId})).data,
    );
    return (
      pass: '${data['pass'] ?? ''}',
      expiresAt: DateTime.tryParse('${data['expires_at']}'),
    );
  }

  /// What the pass sheet polls: has staff recorded today's visit yet?
  Future<({bool visitedToday, SukiCardProgress? card})> passStatus(
      String programId) async {
    final data = _data((await _api.dio.get('/suki/pass/status',
            queryParameters: {'program_id': programId}))
        .data);
    final card = data['card'];
    return (
      visitedToday: data['visited_today'] == true,
      card: card is Map
          ? SukiCardProgress.fromJson(Map<String, dynamic>.from(card))
          : null,
    );
  }

  Future<List<SukiRedemption>> myRedemptions() async {
    final data = _data((await _api.dio.get('/me/redemptions')).data);
    return _rows(data['items'] ?? data['redemptions'])
        .map(SukiRedemption.fromJson)
        .toList();
  }
}

final sukiApiProvider =
    Provider<SukiApi>((ref) => SukiApi(ref.watch(apiClientProvider)));

/// The signed-in traveler's Suki cards (empty when signed out).
final mySukiCardsProvider =
    FutureProvider.autoDispose<List<SukiCard>>((ref) async {
  if (ref.watch(authProvider.select((s) => s.user == null))) return const [];
  return ref.read(sukiApiProvider).myCards();
});

/// Active Suki programs, nearest first when a point is given.
final nearbySukiProgramsProvider = FutureProvider.autoDispose
    .family<List<SukiProgram>, ({double? lat, double? lng})>(
        (ref, at) => ref.read(sukiApiProvider).nearby(lat: at.lat, lng: at.lng));

/// One program page (`/suki/:programId`).
final sukiProgramProvider = FutureProvider.autoDispose
    .family<SukiProgramDetail, String>(
        (ref, id) => ref.read(sukiApiProvider).program(id));

/// The server's error code (`error.code`), or ''.
String sukiErrorCode(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['error'] is Map) {
      return '${(body['error'] as Map)['code'] ?? ''}';
    }
  }
  return '';
}

/// `suki_enabled` is off on the server (503 SUKI_DISABLED).
bool isSukiDisabled(Object error) => sukiErrorCode(error) == 'SUKI_DISABLED';

String sukiComingSoonText(BuildContext context) => tr(context,
    en: 'Suki Cards are coming soon.', tl: 'Malapit na ang Suki Cards.');

/// Plain-language text for a Suki error (plan §7.3).
String sukiErrorText(BuildContext context, Object error) {
  switch (sukiErrorCode(error)) {
    case 'ALREADY_VISITED_TODAY':
      return tr(context,
          en: 'You already visited today. Come back tomorrow!',
          tl: 'Nakabisita ka na ngayon. Balik bukas!');
    case 'OUT_OF_RANGE':
      return tr(context,
          en: 'You need to be at the shop to collect a visit.',
          tl: 'Kailangang nasa tindahan ka para makakuha ng bisita.');
    case 'LOCATION_ACCURACY_TOO_LOW':
      return tr(context,
          en: 'Your GPS is weak. Step outside or wait a moment and try again.',
          tl: 'Mahina ang GPS. Subukang muli.');
    case 'STANDEE_REPLACED':
      return tr(context,
          en: 'This QR was replaced. Ask the shop for the new one.',
          tl: 'Napalitan na ang QR na ito.');
    case 'STANDEE_INVALID':
      return tr(context,
          en: 'That is not a Suki Card QR.',
          tl: 'Hindi ito Suki Card QR.');
    case 'SUKI_STAFF_SCAN_ONLY':
      return tr(context,
          en: 'This shop scans your pass. Tap Show my Suki pass.',
          tl: 'Ipakita ang Suki pass mo sa staff.');
    case 'EMAIL_NOT_VERIFIED':
      return tr(context,
          en: 'Verify your email to collect Suki visits.',
          tl: 'I-verify ang email mo.');
    case 'SELF_VISIT_FORBIDDEN':
      return tr(context,
          en: 'Shop members cannot collect visits on their own card.',
          tl: 'Hindi puwedeng mag-visit sa sariling tindahan.');
    case 'SHOP_LOCATION_MISSING':
      return tr(context,
          en: 'This shop has not pinned its location yet.',
          tl: 'Wala pang naka-pin na lokasyon ang tindahan.');
    case 'SUKI_NOT_ACTIVE':
    case 'SUKI_NOT_FOUND':
      return tr(context,
          en: 'This Suki Card is not active right now.',
          tl: 'Hindi aktibo ang Suki Card na ito ngayon.');
    case 'SUKI_DISABLED':
      return sukiComingSoonText(context);
  }
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['error'] is Map) {
      final message = (body['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
  }
  return tr(context,
      en: 'Could not reach JuanderQuest. Check your connection and retry.',
      tl: 'Hindi maabot ang JuanderQuest. Subukang muli.');
}
