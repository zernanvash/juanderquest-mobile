import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Minimal socket surface so tests can use a fake channel.
abstract interface class RealtimeChannel {
  Stream<dynamic> get stream;
  void send(String message);
  int? get closeCode;
  Future<void> close();
}

typedef RealtimeConnector = RealtimeChannel Function(Uri uri);

class _WebSocketRealtimeChannel implements RealtimeChannel {
  _WebSocketRealtimeChannel(Uri uri)
      : _channel = WebSocketChannel.connect(uri) {
    // A failed handshake also ends [stream]; keep `ready` from being unhandled.
    unawaited(_channel.ready.catchError((_) {}));
  }

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  int? get closeCode => _channel.closeCode;

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}

RealtimeChannel connectWebSocket(Uri uri) => _WebSocketRealtimeChannel(uri);

/// `https://host/api/v1` -> `wss://host/api/v1/realtime` (http -> ws).
Uri realtimeUriFor(String apiBaseUrl) {
  final base = Uri.parse(apiBaseUrl);
  final path = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '$path/realtime',
    query: null,
  );
}

/// Reconnect delay: 1 s, 2 s, 4 s ... capped at 30 s.
Duration realtimeBackoff(int attempt) =>
    Duration(seconds: math.min(30, 1 << math.min(attempt, 5)));

/// Server close code for a rejected token: wait for a new sign-in instead of retrying.
const int realtimeUnauthorizedCode = 4401;

/// One WebSocket to `/api/v1/realtime` while signed in and in the foreground.
/// Events are refresh hints; [onEvent] receives each decoded JSON object.
class RealtimeService {
  RealtimeService({
    required this.uriBuilder,
    required this.onEvent,
    RealtimeConnector? connector,
  }) : _connector = connector ?? connectWebSocket;

  final Uri Function() uriBuilder;
  final void Function(Map<String, dynamic> event) onEvent;
  final RealtimeConnector _connector;

  RealtimeChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  String? _token;
  bool _paused = false;
  int _attempt = 0;

  bool get isConnected => _channel != null;
  int get attempt => _attempt;
  bool get isRetryScheduled => _retryTimer != null;

  /// Signed in (or token changed): connect with [token].
  void start(String token) {
    if (_token == token && (_channel != null || _retryTimer != null)) return;
    _token = token;
    _attempt = 0;
    _reconnectNow();
  }

  /// Signed out: drop the socket and forget the token.
  void stop() {
    _token = null;
    _teardown();
  }

  /// App backgrounded: close the socket, keep the token.
  void pause() {
    _paused = true;
    _teardown();
  }

  /// App resumed: reconnect immediately.
  void resume() {
    if (!_paused) return;
    _paused = false;
    _attempt = 0;
    _reconnectNow();
  }

  void dispose() => stop();

  void _reconnectNow() {
    _teardown();
    _connect();
  }

  void _connect() {
    final token = _token;
    if (token == null || _paused) return;
    final RealtimeChannel channel;
    try {
      channel = _connector(uriBuilder());
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    if (kDebugMode) debugPrint('[realtime] connecting ${uriBuilder()}');
    _subscription = channel.stream.listen(
      (data) => _handle(channel, data),
      onError: (_) => _onClosed(channel),
      onDone: () => _onClosed(channel),
      cancelOnError: true,
    );
    try {
      channel.send(jsonEncode({'type': 'auth', 'token': token}));
    } catch (_) {
      _onClosed(channel);
    }
  }

  void _handle(RealtimeChannel channel, dynamic data) {
    if (!identical(channel, _channel)) return;
    final Object? decoded;
    try {
      decoded =
          jsonDecode(data is String ? data : utf8.decode(data as List<int>));
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final event = Map<String, dynamic>.from(decoded);
    if (kDebugMode) debugPrint('[realtime] <- ${event['type']}');
    if (event['type'] == 'ready') {
      _attempt = 0;
      return;
    }
    if (event['type'] == 'pong') return;
    onEvent(event);
  }

  void _onClosed(RealtimeChannel channel) {
    if (!identical(channel, _channel)) return;
    final code = channel.closeCode;
    if (kDebugMode) debugPrint('[realtime] closed $code');
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (code == realtimeUnauthorizedCode) {
      _token = null;
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_token == null || _paused) return;
    _retryTimer?.cancel();
    final delay = realtimeBackoff(_attempt);
    _attempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _connect();
    });
  }

  void _teardown() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(channel.close().catchError((_) {}));
  }
}
