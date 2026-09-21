import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/juanchoice_models.dart';

final choiceRepositoryProvider = Provider<ChoiceRepository>((ref) =>
    ChoiceRepository(ref.read(apiClientProvider).dio));

class ChoiceRepository {
  ChoiceRepository(this._dio);
  final Dio _dio;
  static const _uuid = Uuid();

  Future<List<ChoiceCampaign>> campaigns() async {
    final response = await _dio.get('/juanchoice/campaigns');
    final items = response.data['data']['items'] as List<dynamic>;
    return items.map((item) => ChoiceCampaign.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChoiceSpotlight?> spotlight() async {
    final response = await _dio.get('/juanchoice/spotlight');
    final raw = response.data['data'];
    if (raw == null) return null;
    final spotlight = ChoiceSpotlight.fromJson(raw as Map<String, dynamic>);
    return spotlight.isActive ? spotlight : null;
  }

  Future<ChoiceSupporterQuest?> supporterQuest() async {
    final response=await _dio.get('/juanchoice/supporter-quest');
    final raw=response.data['data'];
    return raw==null?null:ChoiceSupporterQuest.fromJson(raw as Map<String,dynamic>);
  }

  Future<void> claimSupporterQuest(String campaignId) async {
    await _dio.post('/juanchoice/supporter-quest/$campaignId/claim');
  }

  Future<ChoiceEngagementSummary> engagement() async {
    final response = await _dio.get('/me/engagement');
    return ChoiceEngagementSummary.fromJson((response.data['data'] as Map).cast<String, dynamic>());
  }

  Future<void> setAchievementSharing(bool enabled) async {
    await _dio.put('/me/engagement/preferences', data: {'share_achievements': enabled});
  }

  Future<ChoiceDetail> detail(String id, {required bool authenticated}) async {
    final response = await _dio.get('/juanchoice/campaigns/$id');
    final data = response.data['data'] as Map<String, dynamic>;
    ChoiceBallot? ballot;
    if (authenticated) {
      final owner = await _dio.get('/juanchoice/campaigns/$id/me');
      final raw = owner.data['data']['ballot'];
      if (raw != null) ballot = ChoiceBallot.fromJson(raw as Map<String, dynamic>);
    }
    return ChoiceDetail(
      campaign: ChoiceCampaign.fromJson(data['campaign'] as Map<String, dynamic>),
      standings: (data['standings'] as List<dynamic>)
          .map((item) => ChoiceStanding.fromJson(item as Map<String, dynamic>)).toList(),
      ballot: ballot);
  }

  Future<ChoiceBallot> vote(String campaignId, String candidateId,
      int expectedVersion, String idempotencyKey) async {
    final response = await _dio.put('/juanchoice/campaigns/$campaignId/ballot',
      data: {'candidate_id': candidateId, 'expected_version': expectedVersion},
      options: Options(headers: {'Idempotency-Key': idempotencyKey},
          sendTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));
    return ChoiceBallot.fromJson(response.data['data']['ballot'] as Map<String, dynamic>);
  }

  String newIdempotencyKey() => _uuid.v4();
}
