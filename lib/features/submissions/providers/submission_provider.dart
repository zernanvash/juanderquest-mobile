import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/submission_model.dart';

class SubmissionState {
  final List<SubmissionModel> submissions;
  final bool isSubmitting;
  final bool isLoading;
  final String? error;
  final String? errorCode;

  SubmissionState({
    this.submissions = const [],
    this.isSubmitting = false,
    this.isLoading = false,
    this.error,
    this.errorCode,
  });
}

class SubmissionNotifier extends StateNotifier<SubmissionState> {
  final ApiClient _apiClient;
  final _uuid = const Uuid();

  Future<void>? _inFlightFetch;
  DateTime? _lastFetchTime;
  static const Duration minAutoRefetchInterval = Duration(seconds: 30);

  SubmissionNotifier(this._apiClient) : super(SubmissionState());

  Future<bool> submitProof({
    required String questId,
    required double capturedLat,
    required double capturedLng,
    required double accuracy,
  }) async {
    state = SubmissionState(submissions: state.submissions, isSubmitting: true);
    try {
      // The server-issued single-use challenge token is the only proof path the
      // backend accepts; never fall back to a raw marker code.
      final String challengeToken;
      try {
        final chalRes = await _apiClient.dio.post('/quests/$questId/challenge');
        if (chalRes.statusCode != 200 || chalRes.data['success'] != true) {
          final msg = chalRes.data['error']?['message'] ?? 'Quest challenge unavailable.';
          final errCode = chalRes.data['error']?['code'] ?? 'CHALLENGE_UNAVAILABLE';
          state = SubmissionState(submissions: state.submissions, error: msg, errorCode: errCode);
          return false;
        }
        challengeToken = chalRes.data['data']['challenge_token'] as String;
      } on DioException catch (e) {
        final msg = e.response?.data['error']?['message'] ??
            'Could not obtain a quest challenge. Check your connection and retry.';
        final errCode = e.response?.data['error']?['code'] ?? 'CHALLENGE_UNAVAILABLE';
        state = SubmissionState(submissions: state.submissions, error: msg, errorCode: errCode);
        return false;
      }

      final idempotencyKey = _uuid.v4();
      final body = <String, dynamic>{
        'idempotency_key': idempotencyKey,
        'quest_id': questId,
        'challenge_token': challengeToken,
        'captured_lat': capturedLat,
        'captured_lng': capturedLng,
        'captured_accuracy': accuracy,
      };

      final response = await _apiClient.dio.post(
        '/submissions',
        data: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchSubmissions(force: true);
        return true;
      } else {
        final msg = response.data['error']?['message'] ?? 'Submission rejected.';
        final errCode = response.data['error']?['code'] ?? 'REJECTED';
        state = SubmissionState(submissions: state.submissions, error: msg, errorCode: errCode);
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?['message'] ?? 'Network error: ${e.message}';
      final errCode = e.response?.data['error']?['code'] ?? 'NETWORK_ERROR';
      state = SubmissionState(submissions: state.submissions, error: msg, errorCode: errCode);
      return false;
    } catch (e) {
      state = SubmissionState(submissions: state.submissions, error: 'Unexpected error during submission.', errorCode: 'UNKNOWN');
      return false;
    }
  }

  /// Fetches the user's submissions.
  ///
  /// Deduplicates concurrent in-flight requests.
  /// Throttles automatic triggers (e.g. app lifecycle resume, screen mount)
  /// with a 30-second cooldown unless [force] is true (e.g. pull-to-refresh or post-submit).
  Future<void> fetchSubmissions({bool force = false}) {
    if (_inFlightFetch != null) {
      return _inFlightFetch!;
    }

    final now = DateTime.now();
    if (!force && _lastFetchTime != null && now.difference(_lastFetchTime!) < minAutoRefetchInterval) {
      return Future.value();
    }

    final future = _executeFetch();
    _inFlightFetch = future;
    return future.whenComplete(() {
      _inFlightFetch = null;
    });
  }

  Future<void> _executeFetch() async {
    state = SubmissionState(submissions: state.submissions, isLoading: true);
    try {
      final response = await _apiClient.dio.get('/submissions');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = (response.data['data'] as List)
            .map((s) => SubmissionModel.fromJson(s))
            .toList();
        _lastFetchTime = DateTime.now();
        state = SubmissionState(submissions: list);
      }
    } catch (e) {
      state = SubmissionState(submissions: state.submissions, error: 'Failed to fetch submissions.');
    }
  }
}

final submissionProvider = StateNotifierProvider<SubmissionNotifier, SubmissionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SubmissionNotifier(apiClient);
});
