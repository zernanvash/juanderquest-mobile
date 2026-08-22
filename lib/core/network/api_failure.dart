import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ApiFailure(
      {required this.code, required this.message, this.statusCode});

  factory ApiFailure.from(Object error,
      {String fallback = 'Something went wrong. Please try again.'}) {
    if (error is DioException) {
      final data = error.response?.data;
      final apiError = data is Map<String, dynamic> ? data['error'] : null;
      final code = apiError is Map ? apiError['code']?.toString() : null;
      final message = apiError is Map ? apiError['message']?.toString() : null;
      return ApiFailure(
        code: code ?? _networkCode(error.type),
        message: message ?? _networkMessage(error.type, fallback),
        statusCode: error.response?.statusCode,
      );
    }
    return ApiFailure(code: 'UNKNOWN', message: fallback);
  }

  static String _networkCode(DioExceptionType type) => switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'TIMEOUT',
        DioExceptionType.connectionError => 'OFFLINE',
        DioExceptionType.cancel => 'CANCELLED',
        _ => 'NETWORK_ERROR',
      };

  static String _networkMessage(DioExceptionType type, String fallback) =>
      switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'The server is taking longer than expected. Try again.',
        DioExceptionType.connectionError =>
          'JuanderQuest is unreachable. Check your connection and try again.',
        DioExceptionType.cancel => 'Request cancelled.',
        _ => fallback,
      };
}
