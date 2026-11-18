import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/merchant_models.dart';

/// Plan 95: one read decides where every merchant entry point goes
/// (Shop card, Settings row, Home MERCHANTS tile via `/affiliate`).
final merchantHubStatusProvider = FutureProvider.autoDispose<MerchantHubStatus>(
  (ref) async {
    if (ref.watch(authProvider.select((s) => s.user == null))) {
      return MerchantHubStatus.none;
    }
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/affiliate/applications/me');
      return MerchantHubStatus.fromResponse(response.data);
    } catch (_) {
      return MerchantHubStatus.none;
    }
  },
);

final merchantApiProvider = Provider<MerchantApi>(
  (ref) => MerchantApi(ref.watch(apiClientProvider)),
);

/// Calls for the approved-merchant workspace (`/merchant`).
class MerchantApi {
  MerchantApi(this._api);

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

  Future<MerchantDashboardData> dashboard() async =>
      MerchantDashboardData.fromJson(
        _data((await _api.dio.get('/merchant/dashboard')).data),
      );

  Future<Map<String, dynamic>> profile() async =>
      _data((await _api.dio.get('/merchant/profile')).data);

  Future<void> saveProfile(Map<String, dynamic> fields) =>
      _api.dio.patch('/merchant/profile', data: fields);

  Future<void> setPublished(bool published) => _api.dio.post(
        published ? '/merchant/profile/publish' : '/merchant/profile/unpublish',
      );

  Future<List<MerchantProductItem>> products() async {
    final body = (await _api.dio.get('/merchant/products')).data;
    return _rows(
      body is Map ? body['data'] : null,
    ).map(MerchantProductItem.fromJson).toList();
  }

  Future<void> saveProduct(String? id, Map<String, dynamic> fields) =>
      id == null
          ? _api.dio.post('/merchant/products', data: fields)
          : _api.dio.patch('/merchant/products/$id', data: fields);

  Future<void> archiveProduct(String id) =>
      _api.dio.delete('/merchant/products/$id');

  Future<MerchantPointSummary> points() async => MerchantPointSummary.fromJson(
        _data((await _api.dio.get('/merchant/points')).data),
      );

  Future<void> buyPoints(int package) => _api.dio.post(
        '/merchant/points/purchase',
        data: {'package': package, 'idempotency_key': _uuid.v4()},
      );

  Future<List<MerchantSponsorshipItem>> sponsorships() async => _rows(
        _data((await _api.dio.get('/merchant/sponsorships')).data)['items'],
      ).map(MerchantSponsorshipItem.fromJson).toList();

  Future<List<MerchantVoucherOption>> vouchers() async => [
        for (final row in _rows(
          _data((await _api.dio.get('/merchant/vouchers')).data)['items'],
        ))
          MerchantVoucherOption(
            id: '${row['id']}',
            title: '${row['title'] ?? 'Voucher'}',
          ),
      ];

  Future<void> setConditions(
    MerchantSponsorshipItem item,
    List<Map<String, dynamic>> conditions,
  ) =>
      _api.dio.put(
        '/sponsorships/${item.id}/conditions',
        data: {'conditions': conditions},
      );

  Future<void> accept(
    MerchantSponsorshipItem item, {
    bool acknowledgeUnmet = false,
  }) =>
      _api.dio.post(
        '/sponsorships/${item.id}/accept',
        data: {
          'terms_version': item.termsVersion,
          'idempotency_key': _uuid.v4(),
          if (acknowledgeUnmet) 'acknowledge_unmet': true,
        },
      );

  Future<void> decline(MerchantSponsorshipItem item) => _api.dio.post(
        '/sponsorships/${item.id}/decline',
        data: {'idempotency_key': _uuid.v4()},
      );

  Future<void> counter(
    MerchantSponsorshipItem item, {
    required int points,
    required String? voucherId,
    required int voucherQty,
    required bool promo,
    required String message,
    List<Map<String, dynamic>>? conditions,
  }) =>
      _api.dio.post(
        '/sponsorships/${item.id}/counter',
        data: {
          'points': points,
          'voucher_id': voucherId,
          'voucher_qty': voucherId == null ? 0 : voucherQty,
          'promo': promo,
          if (message.isNotEmpty) 'message': message,
          if (conditions != null) 'conditions': conditions,
          'terms_version': item.termsVersion,
          'idempotency_key': _uuid.v4(),
        },
      );

  Future<void> topUp(String planId, int points) => _api.dio.post(
        '/funding-plans/$planId/merchant-top-up',
        data: {'points': points, 'idempotency_key': _uuid.v4()},
      );
}
