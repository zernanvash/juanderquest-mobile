import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/features/juanchoice/data/juanchoice_repository.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';

class RetryRepository extends ChoiceRepository {
  RetryRepository() : super(Dio());
  final keys = <String>[];
  int attempts = 0;
  @override
  String newIdempotencyKey() => 'key-${keys.length + 1}';
  @override
  Future<ChoiceBallot> vote(String campaignId, String candidateId,
      int expectedVersion, String idempotencyKey) async {
    keys.add(idempotencyKey);
    attempts++;
    if (attempts == 1) {
      throw DioException(requestOptions: RequestOptions(path: '/ballot'),
        type: DioExceptionType.connectionTimeout);
    }
    return const ChoiceBallot(candidateId: 'candidate', version: 1);
  }
}

void main() {
  test('spotlight expires locally and preserves winner spot identity', () {
    final active = ChoiceSpotlight.fromJson({
      'campaign_id': 'campaign', 'theme': 'Coastal gems',
      'expires_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'winners': [{'spot_id': 'spot-1'}],
    });
    expect(active.isActive, isTrue);
    expect(active.winnerSpotIds, {'spot-1'});
    final expired = ChoiceSpotlight.fromJson({
      'campaign_id': 'campaign', 'theme': 'Coastal gems',
      'expires_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'winners': [{'spot_id': 'spot-1'}],
    });
    expect(expired.isActive, isFalse);
    final plan = planChoiceSpotlight(['spot-1', 'spot-2'], (id) => id, active);
    expect(plan.winners, ['spot-1']);
    expect(plan.ordinary, ['spot-2']);
  });

  test('uncertain ballot retry keeps the same idempotency key', () async {
    final repository = RetryRepository();
    final container = ProviderContainer(overrides: [
      choiceRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(choiceVoteProvider, (previous, next) {});
    addTearDown(subscription.close);
    final notifier = container.read(choiceVoteProvider.notifier);
    await notifier.submit('campaign', 'candidate', 0);
    expect(container.read(choiceVoteProvider).error, contains('Network error'));
    await notifier.submit('campaign', 'candidate', 0);
    expect(repository.keys, ['key-1', 'key-1']);
    expect(container.read(choiceVoteProvider).receipt?.version, 1);
  });
}
