import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/network/retry_interceptor.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions options, int callIndex) respond;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return respond(options, calls++);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object data, int status) =>
    ResponseBody.fromString(
      data is String ? data : jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Dio _buildDio({
  required _ScriptedAdapter adapter,
  required RetryInterceptor interceptor,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  interceptor.dio = dio;
  dio.interceptors.add(interceptor);
  return dio;
}

void main() {
  group('RetryInterceptor', () {
    test('retries idempotent GET on connection errors up to max attempts', () async {
      final delays = <Duration>[];
      final failures = <ApiFailure>[];
      final adapter = _ScriptedAdapter((options, index) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'offline',
        );
      });
      final interceptor = RetryInterceptor(
        maxAttempts: 3,
        seed: 1,
        onFailure: failures.add,
        isOffline: () => false,
        delayOverride: (delay) async => delays.add(delay),
      );
      final dio = _buildDio(adapter: adapter, interceptor: interceptor);

      await expectLater(dio.get<dynamic>('/spots'), throwsA(isA<DioException>()));
      expect(adapter.calls, 4, reason: 'initial + 3 retries');
      expect(delays, hasLength(3));
      expect(failures, hasLength(1));
      expect(failures.single.code, ApiFailureCodes.serverUnreachable);
    });

    test('does not retry non-idempotent POST without an idempotency key', () async {
      final failures = <ApiFailure>[];
      final adapter = _ScriptedAdapter((options, index) {
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final interceptor = RetryInterceptor(
        onFailure: failures.add,
        isOffline: () => false,
        delayOverride: (_) async {},
      );
      final dio = _buildDio(adapter: adapter, interceptor: interceptor);

      await expectLater(dio.post<dynamic>('/spots', data: {'name': 'x'}), throwsA(isA<DioException>()));
      expect(adapter.calls, 1);
      expect(failures, hasLength(1));
    });

    test('retries POST that carries an idempotency key', () async {
      var calls = 0;
      final adapter = _ScriptedAdapter((options, index) {
        calls += 1;
        if (calls == 1) {
          throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
        }
        return _jsonBody({'success': true}, 201);
      });
      final interceptor = RetryInterceptor(
        onFailure: (_) {},
        isOffline: () => false,
        delayOverride: (_) async {},
      );
      final dio = _buildDio(adapter: adapter, interceptor: interceptor);

      final response = await dio.post<dynamic>(
        '/submissions',
        data: {'idempotency_key': 'abc-123'},
      );
      expect(response.statusCode, 201);
      expect(calls, 2);
    });

    test('honors Retry-After for 429 responses', () async {
      final delays = <Duration>[];
      var calls = 0;
      final adapter = _ScriptedAdapter((options, index) {
        calls += 1;
        if (calls == 1) {
          return ResponseBody.fromString(
            jsonEncode({'success': false, 'error': {'code': 'RATE_LIMITED'}}),
            429,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
              'retry-after': ['9'],
            },
          );
        }
        return _jsonBody({'success': true}, 200);
      });
      final interceptor = RetryInterceptor(
        onFailure: (_) {},
        isOffline: () => false,
        delayOverride: (delay) async => delays.add(delay),
      );
      final dio = _buildDio(adapter: adapter, interceptor: interceptor);

      final response = await dio.get<dynamic>('/spots');
      expect(response.statusCode, 200);
      expect(delays, [const Duration(seconds: 9)]);
    });

    test('does not retry while the monitor reports offline', () async {
      var calls = 0;
      final adapter = _ScriptedAdapter((options, index) {
        calls += 1;
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final interceptor = RetryInterceptor(
        onFailure: (_) {},
        isOffline: () => true,
        delayOverride: (_) async {},
      );
      final dio = _buildDio(adapter: adapter, interceptor: interceptor);

      await expectLater(dio.get<dynamic>('/spots'), throwsA(isA<DioException>()));
      expect(calls, 1);
    });

    test('cancelled requests are not retried', () async {
      var calls = 0;
      final adapter = _ScriptedAdapter((options, index) {
        calls += 1;
        throw DioException(requestOptions: options, type: DioExceptionType.cancel);
      });
      final interceptor = RetryInterceptor(
        onFailure: (_) {},
        isOffline: () => false,
        delayOverride: (_) async {},
      );
      final dio = _buildDio(adapter: adapter, interceptor: interceptor);

      await expectLater(dio.get<dynamic>('/spots'), throwsA(isA<DioException>()));
      expect(calls, 1);
    });

    test('receive timeouts are not retried (connect timeouts are)', () async {
      var receiveCalls = 0;
      final receiveAdapter = _ScriptedAdapter((options, index) {
        receiveCalls += 1;
        throw DioException(requestOptions: options, type: DioExceptionType.receiveTimeout);
      });
      final receiveInterceptor = RetryInterceptor(
        onFailure: (_) {},
        isOffline: () => false,
        delayOverride: (_) async {},
      );
      final receiveDio = _buildDio(adapter: receiveAdapter, interceptor: receiveInterceptor);
      await expectLater(receiveDio.get<dynamic>('/spots'), throwsA(isA<DioException>()));
      expect(receiveCalls, 1);

      var connectCalls = 0;
      final connectAdapter = _ScriptedAdapter((options, index) {
        connectCalls += 1;
        if (connectCalls == 1) {
          throw DioException(requestOptions: options, type: DioExceptionType.connectionTimeout);
        }
        return _jsonBody({'success': true}, 200);
      });
      final connectInterceptor = RetryInterceptor(
        onFailure: (_) {},
        isOffline: () => false,
        delayOverride: (_) async {},
      );
      final connectDio = _buildDio(adapter: connectAdapter, interceptor: connectInterceptor);
      final response = await connectDio.get<dynamic>('/spots');
      expect(response.statusCode, 200);
      expect(connectCalls, 2);
    });
  });
}

