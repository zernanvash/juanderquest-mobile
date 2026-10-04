import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/juanchoice_repository.dart';
import '../models/juanchoice_models.dart';

final choiceCampaignsProvider = FutureProvider<List<ChoiceCampaign>>((ref) =>
    ref.read(choiceRepositoryProvider).campaigns());

final choiceOverviewProvider = FutureProvider<ChoiceOverview>((ref) =>
    ref.read(choiceRepositoryProvider).overview());

final choiceSpotlightProvider = FutureProvider<ChoiceSpotlight?>((ref) async {
  final spotlight = await ref.read(choiceRepositoryProvider).spotlight();
  if (spotlight != null) {
    final remaining = spotlight.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return null;
    final timer = Timer(remaining, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return spotlight;
});

final choiceSupporterQuestProvider = FutureProvider<ChoiceSupporterQuest?>((ref) =>
    ref.read(choiceRepositoryProvider).supporterQuest());

final choiceEngagementProvider = FutureProvider<ChoiceEngagementSummary>((ref) =>
    ref.read(choiceRepositoryProvider).engagement());

class ChoiceSupporterClaimNotifier extends StateNotifier<AsyncValue<void>> {
  ChoiceSupporterClaimNotifier(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<void> claim(String campaignId) async {
    state = const AsyncLoading();
    try {
      await _ref.read(choiceRepositoryProvider).claimSupporterQuest(campaignId);
      state = const AsyncData(null);
      _ref.invalidate(choiceSupporterQuestProvider);
    } on DioException catch (error) {
      final body = error.response?.data;
      final code = body is Map && body['error'] is Map ? body['error']['code'] : null;
      state = AsyncError(
        code == 'VERIFIED_VISIT_REQUIRED'
            ? 'Complete the destination quest during the spotlight period first.'
            : 'Unable to claim the visit reward.',
        StackTrace.current,
      );
    }
  }
}

final choiceSupporterClaimProvider = StateNotifierProvider.autoDispose<
    ChoiceSupporterClaimNotifier, AsyncValue<void>>(
  (ref) => ChoiceSupporterClaimNotifier(ref),
);

final choiceDetailProvider = FutureProvider.family<ChoiceDetail, String>((ref, id) =>
    ref.read(choiceRepositoryProvider).detail(id,
      authenticated: ref.watch(authProvider).isAuthenticated));

class ChoiceVoteState {
  const ChoiceVoteState({this.pending = false, this.error, this.receipt});
  final bool pending;
  final String? error;
  final ChoiceBallot? receipt;
}

class ChoiceVoteNotifier extends StateNotifier<ChoiceVoteState> {
  ChoiceVoteNotifier(this._ref) : super(const ChoiceVoteState());
  final Ref _ref;
  String? _key;
  String? _payload;

  Future<void> submit(String campaignId, String candidateId, int expectedVersion) async {
    if (state.pending) return;
    final payload = '$campaignId:$candidateId:$expectedVersion';
    if (_payload != payload) {
      _payload = payload;
      _key = _ref.read(choiceRepositoryProvider).newIdempotencyKey();
    }
    state = const ChoiceVoteState(pending: true);
    try {
      final ballot = await _ref.read(choiceRepositoryProvider)
          .vote(campaignId, candidateId, expectedVersion, _key!);
      if (!mounted) return;
      _key = null;
      _payload = null;
      state = ChoiceVoteState(receipt: ballot);
      _ref.invalidate(choiceDetailProvider(campaignId));
    } on DioException catch (error) {
      final body = error.response?.data;
      final code = body is Map && body['error'] is Map ? body['error']['code'] : null;
      if (!mounted) return;
      if (error.response != null && (error.response!.statusCode ?? 500) < 500) {
        _key = null;
        _payload = null;
      }
      state = ChoiceVoteState(error: code?.toString() ?? 'Network error. Retry uses the same ballot request.');
      if (code == 'VERSION_CONFLICT' || code == 'ROUND_CLOSED') {
        _ref.invalidate(choiceDetailProvider(campaignId));
      }
    } catch (_) {
      if (!mounted) return;
      state = const ChoiceVoteState(error: 'Unable to submit. Please retry.');
    }
  }
}

final choiceVoteProvider = StateNotifierProvider.autoDispose<ChoiceVoteNotifier, ChoiceVoteState>(
    (ref) => ChoiceVoteNotifier(ref));
