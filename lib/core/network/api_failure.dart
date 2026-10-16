import 'package:dio/dio.dart';

/// Canonical failure codes the app distinguishes for user-facing copy.
abstract final class ApiFailureCodes {
  static const offline = 'OFFLINE';
  static const serverUnreachable = 'SERVER_UNREACHABLE';
  static const timeout = 'TIMEOUT';
  static const serverUnavailable = 'SERVER_UNAVAILABLE';
  static const maintenance = 'MAINTENANCE';
  static const upgradeRequired = 'UPGRADE_REQUIRED';
  static const unauthorized = 'UNAUTHORIZED';
  static const rateLimited = 'RATE_LIMITED';
  static const cancelled = 'CANCELLED';
  static const networkError = 'NETWORK_ERROR';
  static const unknown = 'UNKNOWN';
}

class ApiFailure implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  /// Server-provided Retry-After (404/503/429), when present and sane.
  final int? retryAfterSeconds;

  const ApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.retryAfterSeconds,
  });

  /// Classifies a thrown error before reading the JSON envelope, so gateway
  /// HTML pages and transport failures get their own honest copy instead of a
  /// generic "Something went wrong". Raw exception text is never shown to
  /// users; only the server's own message envelopes are surfaced.
  factory ApiFailure.from(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
    bool deviceOnline = true,
  }) {
    if (error is ApiFailure) return error;
    if (error is! DioException) {
      return const ApiFailure(code: ApiFailureCodes.unknown, message: 'Something went wrong. Please try again.');
    }

    final status = error.response?.statusCode;
    final retryAfter = _parseRetryAfter(error.response?.headers.value('retry-after'));
    final data = error.response?.data;
    final envelope = data is Map ? data['error'] : null;
    final envelopeCode = envelope is Map ? envelope['code']?.toString() : null;
    final envelopeMessage = envelope is Map ? envelope['message']?.toString() : null;

    if (status == null) {
      switch (error.type) {
        case DioExceptionType.connectionError:
          if (!deviceOnline) {
            return const ApiFailure(
              code: ApiFailureCodes.offline,
              message: "You're offline. Check your connection and try again.",
            );
          }
          return const ApiFailure(
            code: ApiFailureCodes.serverUnreachable,
            message: "Can't reach JuanDerQuest right now. We'll keep retrying.",
          );
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return const ApiFailure(
            code: ApiFailureCodes.timeout,
            message: 'The server is taking longer than expected. Try again in a moment.',
          );
        case DioExceptionType.cancel:
          return const ApiFailure(code: ApiFailureCodes.cancelled, message: 'Request cancelled.');
        case DioExceptionType.badCertificate:
        case DioExceptionType.badResponse:
        case DioExceptionType.transformTimeout:
        case DioExceptionType.unknown:
          break;
      }
      return ApiFailure(code: ApiFailureCodes.networkError, message: fallback);
    }

    if (status == 503 && envelopeCode == 'MAINTENANCE') {
      return ApiFailure(
        code: ApiFailureCodes.maintenance,
        message: envelopeMessage ?? 'JuanDerQuest is restarting. Reconnecting…',
        statusCode: status,
        retryAfterSeconds: retryAfter ?? 5,
      );
    }

    if (_gatewayStatuses.contains(status) || (status >= 500 && _isHtmlBody(data))) {
      return ApiFailure(
        code: ApiFailureCodes.serverUnavailable,
        message: 'JuanDerQuest is briefly unavailable. We\'ll keep retrying.',
        statusCode: status,
        retryAfterSeconds: retryAfter,
      );
    }

    if (status == 426) {
      return ApiFailure(
        code: ApiFailureCodes.upgradeRequired,
        message: envelopeMessage ?? 'This app version is no longer supported. Please update to continue.',
        statusCode: status,
      );
    }

    if (status == 401) {
      return ApiFailure(
        code: ApiFailureCodes.unauthorized,
        message: envelopeMessage ?? 'Your session ended. Sign in again to continue.',
        statusCode: status,
      );
    }

    if (status == 429) {
      return ApiFailure(
        code: ApiFailureCodes.rateLimited,
        message: envelopeMessage ?? 'Too many requests — give it a few seconds.',
        statusCode: status,
        retryAfterSeconds: retryAfter,
      );
    }

    if (envelopeCode != null) {
      return ApiFailure(
        code: envelopeCode,
        message: envelopeMessage ?? fallback,
        statusCode: status,
        retryAfterSeconds: retryAfter,
      );
    }

    return ApiFailure(code: ApiFailureCodes.unknown, message: fallback, statusCode: status);
  }

  static const Set<int> _gatewayStatuses = {
    502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 527, 530,
  };

  static bool _isHtmlBody(Object? data) {
    if (data is! String) return false;
    return data.trimLeft().startsWith('<');
  }

  static int? _parseRetryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    if (seconds == null) return null;
    if (seconds < 0 || seconds > 600) return null;
    return seconds;
  }

  bool get isRetryable => const {
        ApiFailureCodes.serverUnreachable,
        ApiFailureCodes.timeout,
        ApiFailureCodes.serverUnavailable,
        ApiFailureCodes.maintenance,
        ApiFailureCodes.rateLimited,
      }.contains(code);

  @override
  String toString() => 'ApiFailure($code${statusCode != null ? ' $statusCode' : ''}): $message';
}
