import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/merchant_models.dart';
import '../suki/merchant_suki_models.dart';

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

  /// v0.3.10: pin (or unpin) a published product as the shop's specialty.
  Future<void> setSpecialty(String id, bool pinned) => _api.dio.put(
        '/merchant/products/${Uri.encodeComponent(id)}/specialty',
        data: {'pinned': pinned},
      );

  /// v0.3.10: uploads a photo through the shared `/spot-media` pipeline and
  /// returns its URL (root-relative for local storage).
  Future<String> uploadPhoto(List<int> bytes, String filename) async {
    final response = await _api.dio.post(
      '/spot-media',
      data: FormData.fromMap({
        'media': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    final url = _data(response.data)['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('The upload did not return a URL.');
    }
    return url;
  }

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

  // Plan 107 §6.5: Suki Card (merchant side).
  Future<MerchantSukiView> suki() async => MerchantSukiView.fromJson(
        _data((await _api.dio.get('/merchant/suki')).data),
      );

  Future<MerchantSukiView> saveSuki(Map<String, dynamic> fields) async =>
      MerchantSukiView.fromJson(
        _data((await _api.dio.put('/merchant/suki', data: fields)).data),
      );

  Future<MerchantSukiView> pinSukiLocation({
    required double lat,
    required double lng,
    required double accuracyM,
  }) async =>
      MerchantSukiView.fromJson(_data((await _api.dio.put(
        '/merchant/suki/location',
        data: {'lat': lat, 'lng': lng, 'accuracy_m': accuracyM},
      ))
          .data));

  Future<MerchantSukiView> activateSuki() async => MerchantSukiView.fromJson(
        _data((await _api.dio.post('/merchant/suki/activate')).data),
      );

  Future<MerchantSukiView> pauseSuki() async => MerchantSukiView.fromJson(
        _data((await _api.dio.post('/merchant/suki/pause')).data),
      );

  Future<MerchantSukiStandee> sukiStandee() async =>
      MerchantSukiStandee.fromJson(
        _data((await _api.dio.get('/merchant/suki/standee')).data),
      );

  Future<MerchantSukiStandee> rotateSukiStandee() async =>
      MerchantSukiStandee.fromJson(
        _data((await _api.dio.post('/merchant/suki/standee/rotate')).data),
      );

  Future<MerchantSukiScanResult> sukiScan(String code) async =>
      MerchantSukiScanResult.fromJson(_data((await _api.dio.post(
        '/merchant/suki/scan',
        data: {'code': code},
      ))
          .data));

  Future<MerchantSukiStats> sukiStats({int days = 30}) async =>
      MerchantSukiStats.fromJson(_data((await _api.dio.get(
        '/merchant/suki/stats',
        queryParameters: {'days': days},
      ))
          .data));

  // Plan 110b: Workspace bridges (voucher CRUD, staff, history, analytics, directory).
  Future<MerchantManagedVoucherList> manageVouchers() async =>
      MerchantManagedVoucherList.fromJson(
        _data((await _api.dio.get('/merchant/vouchers/manage')).data),
      );

  Future<MerchantManagedVoucher> createVoucher({
    required String title,
    required String description,
    required int costPoints,
    int? stockLimit,
    int? validDays,
    String? iconKey,
  }) async =>
      MerchantManagedVoucher.fromJson(_data((await _api.dio.post(
        '/merchant/vouchers',
        data: {
          'title': title.trim(),
          'description': description.trim(),
          'cost_points': costPoints,
          if (stockLimit != null) 'stock_limit': stockLimit,
          if (validDays != null) 'valid_days': validDays,
          if (iconKey != null) 'icon_key': iconKey,
        },
      ))
          .data));

  Future<MerchantManagedVoucher> updateVoucher(
    String id,
    Map<String, dynamic> fields,
  ) async =>
      MerchantManagedVoucher.fromJson(_data((await _api.dio.patch(
        '/merchant/vouchers/${Uri.encodeComponent(id)}',
        data: fields,
      ))
          .data));

  Future<void> archiveVoucher(String id) =>
      _api.dio.delete('/merchant/vouchers/${Uri.encodeComponent(id)}');

  Future<MerchantStaffList> staff() async => MerchantStaffList.fromJson(
        _data((await _api.dio.get('/merchant/staff')).data),
      );

  Future<MerchantStaffMember> addStaff(String email) async =>
      MerchantStaffMember.fromJson(_data((await _api.dio.post(
        '/merchant/staff',
        data: {'email': email.trim()},
      ))
          .data));

  Future<void> revokeStaff(String userId) =>
      _api.dio.delete('/merchant/staff/${Uri.encodeComponent(userId)}');

  Future<List<MerchantCounterEvent>> counterHistory({int limit = 50}) async {
    final data = _data((await _api.dio.get(
      '/merchant/counter/history',
      queryParameters: {'limit': limit},
    ))
        .data);
    return _rows(data['items']).map(MerchantCounterEvent.fromJson).toList();
  }

  Future<MerchantAnalyticsData> analytics({int days = 30}) async =>
      MerchantAnalyticsData.fromJson(_data((await _api.dio.get(
        '/merchant/analytics',
        queryParameters: {'days': days},
      ))
          .data));

  Future<PublicMerchantPage> publicMerchants({
    String? q,
    String? municipality,
    String? category,
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (municipality != null && municipality.trim().isNotEmpty)
        'municipality': municipality.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
    };
    return PublicMerchantPage.fromJson(_data((await _api.dio.get(
      '/merchants',
      queryParameters: params,
    ))
        .data));
  }
}
