import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';

void main() {
  group('ApiFailure', () {
    test('preserves structured API error details', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/spots'),
        response: Response(
          requestOptions: RequestOptions(path: '/spots'),
          statusCode: 409,
          data: {
            'error': {
              'code': 'DUPLICATE_SPOT',
              'message': 'A similar spot already exists.'
            },
          },
        ),
      );

      final failure = ApiFailure.from(error);
      expect(failure.code, 'DUPLICATE_SPOT');
      expect(failure.message, 'A similar spot already exists.');
      expect(failure.statusCode, 409);
    });

    test('turns connection failures into truthful offline guidance', () {
      final failure = ApiFailure.from(DioException(
          requestOptions: RequestOptions(path: '/spots'),
          type: DioExceptionType.connectionError));
      expect(failure.code, 'OFFLINE');
      expect(failure.message, contains('unreachable'));
    });

    test('turns timeouts into a retryable message', () {
      final failure = ApiFailure.from(DioException(
          requestOptions: RequestOptions(path: '/wallet'),
          type: DioExceptionType.receiveTimeout));
      expect(failure.code, 'TIMEOUT');
      expect(failure.message, contains('Try again'));
    });
  });
}
