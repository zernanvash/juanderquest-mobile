import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/governance_proposal_model.dart';
import '../models/governance_config_model.dart';

class GovernanceState {
  final List<GovernanceProposalModel> proposals;
  final GovernanceConfigModel? config;
  final bool isLoading;
  final String? error;
  final Map<String, String> userVotes; // proposalId -> choice ('yes' | 'no')

  GovernanceState({
    this.proposals = const [],
    this.config,
    this.isLoading = false,
    this.error,
    this.userVotes = const {},
  });

  GovernanceState copyWith({
    List<GovernanceProposalModel>? proposals,
    GovernanceConfigModel? config,
    bool? isLoading,
    String? error,
    Map<String, String>? userVotes,
  }) {
    return GovernanceState(
      proposals: proposals ?? this.proposals,
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userVotes: userVotes ?? this.userVotes,
    );
  }
}

class GovernanceNotifier extends StateNotifier<GovernanceState> {
  final Ref _ref;

  GovernanceNotifier(this._ref) : super(GovernanceState()) {
    loadGovernanceData();
  }

  Future<void> loadGovernanceData() async {
    state = state.copyWith(isLoading: true, error: null);
    final apiClient = _ref.read(apiClientProvider);

    try {
      final configRes = await apiClient.dio.get('/proposals/config');
      GovernanceConfigModel? config;
      if (configRes.statusCode == 200 && configRes.data['success'] == true) {
        config = GovernanceConfigModel.fromJson(configRes.data['data']);
      }

      final proposalsRes = await apiClient.dio.get('/proposals');
      List<GovernanceProposalModel> proposals = [];
      if (proposalsRes.statusCode == 200 && proposalsRes.data['success'] == true) {
        final list = proposalsRes.data['data'] as List;
        proposals = list.map((item) => GovernanceProposalModel.fromJson(item)).toList();
      }

      state = state.copyWith(
        proposals: proposals,
        config: config ?? GovernanceConfigModel(
          voteFeeMjdq: 10,
          burnBps: 2000,
          escrowBps: 8000,
          organizerBondMjdq: 25000,
          quorumBps: 1500,
        ),
        isLoading: false,
      );
    } catch (e) {
      print('Governance API error: $e');
      state = state.copyWith(
        isLoading: false,
        config: GovernanceConfigModel(
          voteFeeMjdq: 10,
          burnBps: 2000,
          escrowBps: 8000,
          organizerBondMjdq: 25000,
          quorumBps: 1500,
        ),
      );
    }
  }

  Future<bool> castVote({
    required String proposalId,
    required String choice,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    final idempotencyKey = 'vote_${proposalId}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await apiClient.dio.post(
        '/proposals/$proposalId/votes',
        data: {
          'choice': choice,
          'idempotency_key': idempotencyKey,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final newBalance = data['balance_mjdq'] as int?;

        if (newBalance != null) {
          _ref.read(walletProvider.notifier).updateBalanceLocally(newBalance);
        } else {
          _ref.read(walletProvider.notifier).fetchWallet();
        }

        final updatedVotes = Map<String, String>.from(state.userVotes);
        updatedVotes[proposalId] = choice;

        state = state.copyWith(userVotes: updatedVotes);
        await loadGovernanceData();
        return true;
      } else {
        final err = response.data['error']?['message'] ?? 'Failed to cast vote.';
        state = state.copyWith(error: err);
        return false;
      }
    } on DioException catch (e) {
      final err = e.response?.data['error']?['message'] ?? 'Network error (${e.message}).';
      state = state.copyWith(error: err);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to submit vote.');
      return false;
    }
  }

  Future<bool> createAndSubmitProposal({
    required String title,
    required String locationName,
    required String category,
    required String description,
  }) async {
    final apiClient = _ref.read(apiClientProvider);

    try {
      final createRes = await apiClient.dio.post(
        '/proposals',
        data: {
          'title': title,
          'location_name': locationName,
          'category': category.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_'),
          'description': description,
        },
      );

      if (createRes.statusCode != 201 || createRes.data['success'] != true) {
        state = state.copyWith(error: createRes.data['error']?['message'] ?? 'Failed to create proposal.');
        return false;
      }

      final newPropId = createRes.data['data']['id'] as String;

      final submitRes = await apiClient.dio.post('/proposals/$newPropId/submit');
      if (submitRes.statusCode == 200 && submitRes.data['success'] == true) {
        await loadGovernanceData();
        return true;
      } else {
        state = state.copyWith(error: submitRes.data['error']?['message'] ?? 'Failed to submit proposal for screening.');
        return false;
      }
    } on DioException catch (e) {
      state = state.copyWith(error: e.response?.data['error']?['message'] ?? 'Network error while submitting proposal.');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Error creating location proposal.');
      return false;
    }
  }
}

final governanceProvider = StateNotifierProvider<GovernanceNotifier, GovernanceState>((ref) {
  return GovernanceNotifier(ref);
});
