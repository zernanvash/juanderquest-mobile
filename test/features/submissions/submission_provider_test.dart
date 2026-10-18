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
  });
}
