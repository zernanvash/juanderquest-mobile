import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';

DioException _dioError({
  DioExceptionType type = DioExceptionType.badResponse,
  Response<dynamic>? response,
}) {
  final options = RequestOptions(path: '/spots');
  return DioException(
    requestOptions: options,
    type: type,
    response: response ?? Response<dynamic>(requestOptions: options),
  );
}

Response<dynamic> _response(int status, {Object? data, Map<String, List<String>>? headers}) {
  final options = RequestOptions(path: '/spots');
  return Response<dynamic>(
    requestOptions: options,
    statusCode: status,
    data: data,
    headers: Headers.fromMap(headers ?? const {}),
  );
}

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
      // Plan 40 §A3 splits this case: a device-level outage is OFFLINE while
      // an online device that cannot reach the server is SERVER_UNREACHABLE.
      final offline = ApiFailure.from(
        DioException(
            requestOptions: RequestOptions(path: '/spots'),
            type: DioExceptionType.connectionError),
        deviceOnline: false,
      );
      expect(offline.code, 'OFFLINE');
      expect(offline.message, contains('offline'));

      final unreachable = ApiFailure.from(DioException(
          requestOptions: RequestOptions(path: '/spots'),
          type: DioExceptionType.connectionError));
      expect(unreachable.code, 'SERVER_UNREACHABLE');
      expect(unreachable.message, contains('JuanDerQuest'));
    });

    test('turns timeouts into a retryable message', () {
      final failure = ApiFailure.from(DioException(
          requestOptions: RequestOptions(path: '/wallet'),
          type: DioExceptionType.receiveTimeout));
      expect(failure.code, 'TIMEOUT');
      expect(failure.message, contains('Try again'));
    });
  });

  group('ApiFailure classification (Plan 40 A3)', () {
    test('connection errors split into OFFLINE vs SERVER_UNREACHABLE', () {
      final offline = ApiFailure.from(
        _dioError(type: DioExceptionType.connectionError),
        deviceOnline: false,
      );
      expect(offline.code, ApiFailureCodes.offline);

      final unreachable = ApiFailure.from(_dioError(type: DioExceptionType.connectionError));
      expect(unreachable.code, ApiFailureCodes.serverUnreachable);
    });

    test('timeouts map to TIMEOUT with clear copy', () {
      final failure = ApiFailure.from(_dioError(type: DioExceptionType.connectionTimeout));
      expect(failure.code, ApiFailureCodes.timeout);
      expect(failure.message, contains('longer than expected'));
    });

    test('Cloudflare HTML on 530 is SERVER_UNAVAILABLE, not a generic error', () {
      final failure = ApiFailure.from(
        _dioError(response: _response(530, data: '<!DOCTYPE html><html>error code: 530</html>')),
      );
      expect(failure.code, ApiFailureCodes.serverUnavailable);
      expect(failure.message, contains('briefly unavailable'));
    });

    test('HTML body on any 5xx is SERVER_UNAVAILABLE even without a gateway status', () {
      final failure = ApiFailure.from(
        _dioError(response: _response(500, data: '<html>oops</html>')),
      );
      expect(failure.code, ApiFailureCodes.serverUnavailable);
    });

    test('503 MAINTENANCE keeps its envelope and reads Retry-After', () {
      final failure = ApiFailure.from(
        _dioError(
          response: _response(
            503,
            data: {
              'success': false,
              'error': {'code': 'MAINTENANCE', 'message': 'JuanDerQuest is starting up'},
            },
            headers: {
              'retry-after': ['7'],
            },
          ),
        ),
      );
      expect(failure.code, ApiFailureCodes.maintenance);
      expect(failure.message, 'JuanDerQuest is starting up');
      expect(failure.retryAfterSeconds, 7);
      expect(failure.isRetryable, isTrue);
    });

    test('426 maps to UPGRADE_REQUIRED', () {
      final failure = ApiFailure.from(
        _dioError(
          response: _response(426, data: {
            'success': false,
            'error': {'code': 'UPGRADE_REQUIRED', 'message': 'Update required'},
          }),
        ),
      );
      expect(failure.code, ApiFailureCodes.upgradeRequired);
    });

    test('401 maps to UNAUTHORIZED with the session copy', () {
      final failure = ApiFailure.from(_dioError(response: _response(401)));
      expect(failure.code, ApiFailureCodes.unauthorized);
      expect(failure.message, contains('session ended'));
    });

    test('429 maps to RATE_LIMITED and reads Retry-After', () {
      final failure = ApiFailure.from(
        _dioError(
          response: _response(429, headers: {
            'retry-after': ['12'],
          }),
        ),
      );
      expect(failure.code, ApiFailureCodes.rateLimited);
      expect(failure.retryAfterSeconds, 12);
    });

    test('server error envelopes pass their code/message through', () {
      final failure = ApiFailure.from(
        _dioError(
          response: _response(409, data: {
            'success': false,
            'error': {'code': 'ACTIVE_APPLICATION_EXISTS', 'message': 'Already under review.'},
          }),
        ),
      );
      expect(failure.code, 'ACTIVE_APPLICATION_EXISTS');
      expect(failure.message, 'Already under review.');
    });

    test('never leaks raw exception text for unknown errors', () {
      final failure = ApiFailure.from(Exception('socket exploded at 0x1234'));
      expect(failure.code, ApiFailureCodes.unknown);
      expect(failure.message, isNot(contains('0x1234')));
      expect(failure.message, contains('Something went wrong'));
    });

    test('cancel maps to CANCELLED and is not retryable', () {
      final failure = ApiFailure.from(_dioError(type: DioExceptionType.cancel));
      expect(failure.code, ApiFailureCodes.cancelled);
      expect(failure.isRetryable, isFalse);
    });
  });
}
