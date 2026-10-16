import 'dart:math';

import 'package:dio/dio.dart';

import 'api_failure.dart';

typedef FailureReporter = void Function(ApiFailure failure);
typedef OfflineCheck = bool Function();

/// Retries idempotent requests on transport/gateway failures with a bounded
/// backoff + jitter. Non-idempotent calls without an idempotency key are never
/// retried, so submissions cannot duplicate.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.onFailure,
    required this.isOffline,
    this.maxAttempts = 3,
    int? seed,
    this.delayOverride,
  }) : _random = Random(seed);

  /// The client's Dio, injected after construction so retries can re-fetch.
  late Dio dio;

  final FailureReporter onFailure;
  final OfflineCheck isOffline;
  final int maxAttempts;
  final Random _random;

  /// Test hook: replaces the computed backoff (receives the raw delay).
  final Future<void> Function(Duration delay)? delayOverride;

  static const List<int> _baseDelaysMs = [500, 1500, 4000];
  static const int _maxRetryAfterMs = 30000;

  /// GET/HEAD, or any request that carries an Idempotency-Key header or an
  /// `idempotency_key` body field (submissions, vouchers, quest steps).
  static bool isIdempotent(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD') return true;
    if (options.headers.keys.any((key) => key.toLowerCase() == 'idempotency-key')) return true;
    final data = options.data;
    if (data is Map && data['idempotency_key'] != null) return true;
    return false;
  }

  bool _shouldRetry(DioException error, ApiFailure failure) {
    if (!isIdempotent(error.requestOptions)) return false;
    if (!failure.isRetryable) return false;
    if (failure.code == ApiFailureCodes.timeout &&
        error.type != DioExceptionType.connectionTimeout) {
      return false;
    }
    return true;
  }

  Duration _delayFor(int attempt, int? retryAfterSeconds) {
    if (retryAfterSeconds != null) {
      return Duration(milliseconds: min(retryAfterSeconds * 1000, _maxRetryAfterMs));
    }
    final base = _baseDelaysMs[(attempt - 1).clamp(0, _baseDelaysMs.length - 1)];
    final jitter = 0.7 + _random.nextDouble() * 0.6; // ±30%
    return Duration(milliseconds: (base * jitter).round());
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _handle(err, handler);
  }

  Future<void> _handle(DioException err, ErrorInterceptorHandler handler) async {
    final failure = ApiFailure.from(err, deviceOnline: !isOffline());
    final attempt = (err.requestOptions.extra['retry_attempt'] as int? ?? 0) + 1;

    if (_shouldRetry(err, failure) && attempt <= maxAttempts && !isOffline()) {
      final delay = _delayFor(attempt, failure.retryAfterSeconds);
      if (delayOverride != null) {
        await delayOverride!(delay);
      } else {
        await Future<void>.delayed(delay);
      }

      if (err.requestOptions.cancelToken?.isCancelled ?? false) {
        onFailure(failure);
        handler.next(err);
        return;
      }
      if (isOffline()) {
        onFailure(failure);
        handler.next(err);
        return;
      }

      err.requestOptions.extra['retry_attempt'] = attempt;
      try {
        final response = await dio.fetch<dynamic>(err.requestOptions);
        handler.resolve(response);
        return;
      } on DioException catch (retryError) {
        // The nested fetch already ran this interceptor's policy end-to-end
        // (and reported the final failure exactly once); forward as-is.
        handler.next(retryError);
        return;
      }
    }

    onFailure(failure);
    handler.next(err);
  }
}
