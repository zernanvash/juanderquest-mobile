import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> payload, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('SubmissionNotifier challenge-only proof flow', () {
    test('requests a server challenge and submits it instead of a marker code', () async {
      final requests = <RequestOptions>[];
      final client = ApiClient();
      client.setAuthToken('test-token');
      client.dio.httpClientAdapter = _FakeAdapter((options) async {
        requests.add(options);
        if (options.path == '/quests/q1/challenge') {
          return _json({
            'success': true,
            'data': {'challenge_token': 'CHAL_TOKEN'},
          }, 200);
        }
        if (options.method == 'POST' && options.path == '/submissions') {
          return _json({
            'success': true,
            'data': {'id': 's1', 'quest_id': 'q1', 'status': 'pending'},
          }, 201);
        }
        if (options.method == 'GET' && options.path == '/submissions') {
          return _json({'success': true, 'data': []}, 200);
        }
        return _json({
          'success': false,
          'error': {'code': 'NOT_FOUND', 'message': 'Unexpected request'},
        }, 404);
      });

      final notifier = SubmissionNotifier(client);
      final ok = await notifier.submitProof(
        questId: 'q1',
        capturedLat: 16.2,
        capturedLng: 119.9,
        accuracy: 5,
      );

      expect(ok, isTrue);
      final challengeRequest =
          requests.where((r) => r.path == '/quests/q1/challenge').toList();
      expect(challengeRequest, hasLength(1));

      final submitRequest = requests
          .firstWhere((r) => r.method == 'POST' && r.path == '/submissions');
      final body = submitRequest.data as Map<String, dynamic>;
      expect(body['challenge_token'], 'CHAL_TOKEN');
      expect(body.containsKey('scanned_marker_code'), isFalse);
    });

    test('fails truthfully without submitting when the challenge endpoint is unavailable', () async {
      final requests = <RequestOptions>[];
      final client = ApiClient();
      client.setAuthToken('test-token');
      client.dio.httpClientAdapter = _FakeAdapter((options) async {
        requests.add(options);
        if (options.path == '/quests/q1/challenge') {
          return _json({
            'success': false,
            'error': {'code': 'CHALLENGE_UNAVAILABLE', 'message': 'Quest challenge unavailable.'},
          }, 503);
        }
        return _json({
          'success': true,
          'data': {'id': 's1', 'status': 'pending'},
        }, 201);
      });

      final notifier = SubmissionNotifier(client);
      final ok = await notifier.submitProof(
        questId: 'q1',
        capturedLat: 16.2,
        capturedLng: 119.9,
        accuracy: 5,
      );

      expect(ok, isFalse);
      expect(notifier.state.errorCode, 'CHALLENGE_UNAVAILABLE');
      expect(
        requests.where((r) => r.method == 'POST' && r.path == '/submissions'),
        isEmpty,
      );
    });
  });

  group('SubmissionNotifier fetchSubmissions deduplication and throttling', () {
    test('concurrent fetchSubmissions calls deduplicate to exactly 1 network request', () async {
      int requestCount = 0;
      final client = ApiClient();
      client.setAuthToken('test-token');
      client.dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.method == 'GET' && options.path == '/submissions') {
          requestCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return _json({'success': true, 'data': []}, 200);
        }
        return _json({'success': false}, 404);
      });

      final notifier = SubmissionNotifier(client);
      // Fire 5 concurrent calls
      await Future.wait([
        notifier.fetchSubmissions(),
        notifier.fetchSubmissions(),
        notifier.fetchSubmissions(),
        notifier.fetchSubmissions(),
        notifier.fetchSubmissions(),
      ]);

      expect(requestCount, equals(1));
    });

    test('automatic repeated calls within 30s throttle to 1 request, while force=true bypasses throttle', () async {
      int requestCount = 0;
      final client = ApiClient();
      client.setAuthToken('test-token');
      client.dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.method == 'GET' && options.path == '/submissions') {
          requestCount++;
          return _json({'success': true, 'data': []}, 200);
        }
        return _json({'success': false}, 404);
      });

      final notifier = SubmissionNotifier(client);
      await notifier.fetchSubmissions();
      expect(requestCount, equals(1));

      // Immediate second automatic fetch (e.g. repeated resume/re-render)
      await notifier.fetchSubmissions();
      expect(requestCount, equals(1), reason: 'Throttled within 30s interval');

      // Manual or post-submit force=true fetch
      await notifier.fetchSubmissions(force: true);
      expect(requestCount, equals(2), reason: 'force=true bypasses cooldown');
    });

    test('401 stops the loop: <=1 request for 10 calls, 0 while signed out, 1 after new token', () async {
      int requestCount = 0;
      bool returnUnauthorized = true;
      final client = ApiClient(enableRetries: false);
      client.setAuthToken('expired-token');
      client.dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.method == 'GET' && options.path == '/submissions') {
          requestCount++;
          if (returnUnauthorized) {
            return _json({
              'success': false,
              'error': {'code': 'UNAUTHORIZED', 'message': 'Expired token'},
            }, 401);
          }
          return _json({'success': true, 'data': []}, 200);
        }
        return _json({'success': false}, 404);
      });

      final notifier = SubmissionNotifier(client);

      for (var i = 0; i < 10; i++) {
        await notifier.fetchSubmissions();
      }
      expect(requestCount, 1);
      expect(notifier.state.errorCode, 'UNAUTHORIZED');

      // While signed out / no token, even force: true sends nothing.
      client.setAuthToken(null);
      notifier.onAuthTokenChanged(null);
      await notifier.fetchSubmissions();
      await notifier.fetchSubmissions(force: true);
      expect(requestCount, 1);

      // Setting a new token allows exactly one fetch.
      returnUnauthorized = false;
      client.setAuthToken('fresh-token');
      notifier.onAuthTokenChanged('fresh-token');
      await notifier.fetchSubmissions();
      expect(requestCount, 2);
      expect(notifier.state.error, isNull);
    });

    test('consecutive server errors back off 30s -> 60s -> 120s -> 300s and reset on force or success', () async {
      int requestCount = 0;
      bool fail = true;
      var now = DateTime(2026, 11, 23, 12, 0, 0);
      final client = ApiClient(enableRetries: false);
      client.setAuthToken('valid-token');
      client.dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.method == 'GET' && options.path == '/submissions') {
          requestCount++;
          if (fail) {
            return _json({
              'success': false,
              'error': {'code': 'SERVER_ERROR', 'message': 'Temporary outage'},
            }, 500);
          }
          return _json({'success': true, 'data': []}, 200);
        }
        return _json({'success': false}, 404);
      });

      final notifier = SubmissionNotifier(client, clock: () => now);

      // Failure #1 -> backoff 30s
      await notifier.fetchSubmissions();
      expect(requestCount, 1);
      now = now.add(const Duration(seconds: 29));
      await notifier.fetchSubmissions();
      expect(requestCount, 1);

      // At +30s -> Failure #2 -> backoff 60s
      now = now.add(const Duration(seconds: 1));
      await notifier.fetchSubmissions();
      expect(requestCount, 2);
      now = now.add(const Duration(seconds: 59));
      await notifier.fetchSubmissions();
      expect(requestCount, 2);

      // At +60s -> Failure #3 -> backoff 120s
      now = now.add(const Duration(seconds: 1));
      await notifier.fetchSubmissions();
      expect(requestCount, 3);
      now = now.add(const Duration(seconds: 119));
      await notifier.fetchSubmissions();
      expect(requestCount, 3);

      // At +120s -> Failure #4 -> backoff 240s
      now = now.add(const Duration(seconds: 1));
      await notifier.fetchSubmissions();
      expect(requestCount, 4);
      now = now.add(const Duration(seconds: 239));
      await notifier.fetchSubmissions();
      expect(requestCount, 4);

      // At +240s -> Failure #5 -> backoff capped at 300s
      now = now.add(const Duration(seconds: 1));
      await notifier.fetchSubmissions();
      expect(requestCount, 5);
      now = now.add(const Duration(seconds: 299));
      await notifier.fetchSubmissions();
      expect(requestCount, 5);

      // force=true succeeds and resets backoff to 30s
      fail = false;
      await notifier.fetchSubmissions(force: true);
      expect(requestCount, 6);
      now = now.add(const Duration(seconds: 30));
      await notifier.fetchSubmissions();
      expect(requestCount, 7);
    });
  });
}
