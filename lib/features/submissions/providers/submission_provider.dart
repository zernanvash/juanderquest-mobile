import 'dart:math' as math;

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
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  Future<void>? _inFlightFetch;
  DateTime? _lastFetchTime;
  int _consecutiveFailures = 0;
  bool _unauthorizedLocked = false;
  String? _lastSeenToken;
  static const Duration minAutoRefetchInterval = Duration(seconds: 30);
  static const Duration maxBackoffInterval = Duration(minutes: 5);

  SubmissionNotifier(
    this._apiClient, {
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _lastSeenToken = _apiClient.authToken,
        super(SubmissionState());

  Duration get _currentBackoff {
    if (_consecutiveFailures <= 1) return minAutoRefetchInterval;
    final seconds = math.min(
      maxBackoffInterval.inSeconds,
      minAutoRefetchInterval.inSeconds * (1 << (_consecutiveFailures - 1)),
    );
    return Duration(seconds: seconds);
  }

  /// Syncs auth token changes: clears locked 401 state when a new token arrives,
  /// and resets/clears submissions on sign-out.
  void onAuthTokenChanged(String? token) {
    final normalized = (token == null || token.isEmpty) ? null : token;
    if (normalized == _lastSeenToken) return;
    _lastSeenToken = normalized;
    if (normalized == null) {
      _inFlightFetch = null;
      if (_unauthorizedLocked || state.errorCode == 'UNAUTHORIZED') {
        // Keep the single 401 error state on token drop until re-authentication.
        return;
      }
      _consecutiveFailures = 0;
      _lastFetchTime = null;
      state = SubmissionState();
      return;
    }
    _unauthorizedLocked = false;
    _consecutiveFailures = 0;
    _lastFetchTime = null;
    if (state.error != null) {
      state = SubmissionState(submissions: state.submissions);
    }
  }

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
  /// Throttles automatic triggers with exponential backoff (30 s, 60 s, 120 s,
  /// capped at 5 min) on failures, blocks requests when signed out, and stops
  /// retrying after 401 until the auth token changes.
  Future<void> fetchSubmissions({bool force = false}) {
    final currentToken = _apiClient.authToken;
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        currentToken != _lastSeenToken) {
      onAuthTokenChanged(currentToken);
    }

    if (currentToken == null || currentToken.isEmpty) {
      _lastSeenToken = null;
      return Future.value();
    }

    if (_unauthorizedLocked) {
      return Future.value();
    }

    if (_inFlightFetch != null) {
      return _inFlightFetch!;
    }

    if (force) {
      _consecutiveFailures = 0;
    }

    final now = _clock();
    if (!force &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < _currentBackoff) {
      return Future.value();
    }

    final future = _executeFetch(now);
    _inFlightFetch = future;
    return future.whenComplete(() {
      _inFlightFetch = null;
    });
  }

  Future<void> _executeFetch(DateTime startedAt) async {
    _lastFetchTime = startedAt;
    state = SubmissionState(submissions: state.submissions, isLoading: true);
    try {
      final response = await _apiClient.dio.get('/submissions');
      _lastFetchTime = _clock();
      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = (response.data['data'] as List)
            .map((s) => SubmissionModel.fromJson(s))
            .toList();
        _consecutiveFailures = 0;
        _unauthorizedLocked = false;
        state = SubmissionState(submissions: list);
      } else {
        _recordFailure(statusCode: response.statusCode);
      }
    } on DioException catch (e) {
      _lastFetchTime = _clock();
      _recordFailure(statusCode: e.response?.statusCode);
    } catch (_) {
      _lastFetchTime = _clock();
      _recordFailure();
    }
  }

  void _recordFailure({int? statusCode}) {
    _consecutiveFailures += 1;
    if (statusCode == 401) {
      _unauthorizedLocked = true;
      state = SubmissionState(
        submissions: state.submissions,
        error: 'Session expired. Please sign in again.',
        errorCode: 'UNAUTHORIZED',
      );
      return;
    }
    state = SubmissionState(
      submissions: state.submissions,
      error: 'Failed to fetch submissions.',
      errorCode: 'FETCH_FAILED',
    );
  }
}

final submissionProvider = StateNotifierProvider<SubmissionNotifier, SubmissionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notifier = SubmissionNotifier(apiClient);
  final currentToken = ref.read(authProvider).token ?? apiClient.authToken;
  notifier.onAuthTokenChanged(currentToken);
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (prev?.token != next.token) {
      notifier.onAuthTokenChanged(next.token);
    }
  });
  return notifier;
});
