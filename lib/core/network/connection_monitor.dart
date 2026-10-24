import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_base_url.dart';
import 'api_failure.dart';

enum ConnectionStatus { online, offline, serverUnreachable, serverRestarting, degraded }

enum ServerProbeResult { ready, startingUp, unreachable }

typedef ServerProbe = Future<ServerProbeResult> Function();

/// Tracks device connectivity plus server reachability so screens never show
/// dead ends. Probes on start/resume/regain/API failures with a 2→30 s backoff,
/// stops while backgrounded, and reports `degraded` when probes succeed but
/// the API stays slow.
class ConnectionMonitor extends StateNotifier<ConnectionStatus> {
  ConnectionMonitor({
    required ServerProbe probe,
    Stream<List<ConnectivityResult>>? connectivityStream,
    this.recoverProbeDelays = const [2, 4, 8, 15, 30],
    this.slowCallThreshold = const Duration(seconds: 4),
    this.slowCallsForDegraded = 3,
  })  : _probe = probe,
        _connectivityStream = connectivityStream,
        super(ConnectionStatus.online);

  final ServerProbe _probe;
  Stream<List<ConnectivityResult>>? _connectivityStream;
  final List<int> recoverProbeDelays;
  final Duration slowCallThreshold;
  final int slowCallsForDegraded;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  int _attempt = 0;
  int _consecutiveSlowCalls = 0;
  bool _backgrounded = false;
  bool _disposed = false;
  DateTime? _nextProbeAt;

  final StreamController<void> _recoveredController = StreamController<void>.broadcast();

  /// Emits whenever the connection returns to [ConnectionStatus.online] after
  /// being offline/unreachable so visible screens can refetch.
  Stream<void> get onRecovered => _recoveredController.stream;

  /// Seconds until the next automatic probe, for the banner countdown.
  int? get secondsUntilRetry {
    final next = _nextProbeAt;
    if (next == null) return null;
    final remaining = next.difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  void start() {
    try {
      final stream = _connectivityStream ??= Connectivity().onConnectivityChanged;
      _connectivitySubscription = stream.listen(
        _handleConnectivityChange,
        onError: (_) {
          // Connectivity plugins are unavailable on some platforms/tests;
          // probing still works, so a stream error only means "unknown".
        },
      );
    } catch (_) {
      // Keep the monitor usable without device connectivity events.
    }
    if (!_backgrounded) {
      unawaited(probeNow());
    }
  }

  void setBackgrounded(bool value) {
    _backgrounded = value;
    if (value) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _nextProbeAt = null;
    } else {
      unawaited(probeNow());
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final connected = results.any((result) => result != ConnectivityResult.none);
    if (!connected) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _nextProbeAt = null;
      _setStatus(ConnectionStatus.offline);
      return;
    }
    if (state != ConnectionStatus.online) {
      unawaited(probeNow());
    }
  }

  Future<void> probeNow() async {
    if (_disposed || _backgrounded) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _nextProbeAt = null;

    ServerProbeResult result;
    try {
      result = await _probe();
    } catch (_) {
      result = ServerProbeResult.unreachable;
    }
    if (_disposed) return;

    switch (result) {
      case ServerProbeResult.ready:
        _completeRecovery();
      case ServerProbeResult.startingUp:
        _setStatus(ConnectionStatus.serverRestarting);
        _scheduleProbe();
      case ServerProbeResult.unreachable:
        _setStatus(ConnectionStatus.serverUnreachable);
        _scheduleProbe();
    }
  }

  /// Called by the API layer for every failed request.
  void reportApiFailure(ApiFailure failure) {
    if (_disposed || _backgrounded) return;
    switch (failure.code) {
      case ApiFailureCodes.offline:
        _setStatus(ConnectionStatus.offline);
      case ApiFailureCodes.maintenance:
        _setStatus(ConnectionStatus.serverRestarting);
        _scheduleProbe();
      case ApiFailureCodes.serverUnreachable:
      case ApiFailureCodes.serverUnavailable:
        _setStatus(ConnectionStatus.serverUnreachable);
        _scheduleProbe();
      default:
        break;
    }
  }

  /// Called by the API layer after every successful response.
  void reportApiSuccess(Duration elapsed) {
    if (_disposed || _backgrounded) return;
    if (elapsed > slowCallThreshold) {
      _consecutiveSlowCalls += 1;
      if (_consecutiveSlowCalls >= slowCallsForDegraded && state == ConnectionStatus.online) {
        _setStatus(ConnectionStatus.degraded);
      }
    } else {
      _consecutiveSlowCalls = 0;
    }
    if (state == ConnectionStatus.offline ||
        state == ConnectionStatus.serverRestarting ||
        state == ConnectionStatus.serverUnreachable) {
      _completeRecovery();
    }
  }

  /// Manual retry from the banner.
  void retryNow() {
    _attempt = 0;
    unawaited(probeNow());
  }

  void _scheduleProbe() {
    _retryTimer?.cancel();
    final delaySeconds = recoverProbeDelays[_attempt.clamp(0, recoverProbeDelays.length - 1)];
    _attempt += 1;
    _nextProbeAt = DateTime.now().add(Duration(seconds: delaySeconds));
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(probeNow());
    });
  }

  void _completeRecovery() {
    _attempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    _nextProbeAt = null;
    if (state != ConnectionStatus.online) {
      _setStatus(ConnectionStatus.online);
      if (!_recoveredController.isClosed) {
        _recoveredController.add(null);
      }
    }
  }

  void _setStatus(ConnectionStatus next) {
    if (state != next) state = next;
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _recoveredController.close();
    super.dispose();
  }
}

Future<ServerProbeResult> defaultServerProbe() async {
  final probeDio = Dio(
    BaseOptions(
      baseUrl: normalizeApiBaseUrl(_rawProbeBaseUrl),
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      headers: {'Accept': 'application/json'},
    ),
  );
  try {
    final response = await probeDio.get<dynamic>('/health/ready');
    final data = response.data;
    if (data is Map && data['ready'] == true) return ServerProbeResult.ready;
    if (data is Map) return ServerProbeResult.startingUp;
    if (response.statusCode == 503) return ServerProbeResult.startingUp;
    return ServerProbeResult.unreachable;
  } on DioException catch (error) {
    final status = error.response?.statusCode;
    if (status == 503) return ServerProbeResult.startingUp;
    return ServerProbeResult.unreachable;
  } catch (_) {
    return ServerProbeResult.unreachable;
  }
}

final String _rawProbeBaseUrl = defaultApiBaseUrl();

final connectionMonitorProvider =
    StateNotifierProvider<ConnectionMonitor, ConnectionStatus>((ref) {
  // Widget tests must not spawn network probes, plugin channels or timers;
  // the monitor is trivially online there so screens render unchanged.
  final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
  final monitor = isFlutterTest
      ? ConnectionMonitor(
          probe: () async => ServerProbeResult.ready,
          connectivityStream: const Stream.empty(),
        )
      : ConnectionMonitor(probe: defaultServerProbe);
  if (!isFlutterTest) {
    monitor.start();
  }
  // Riverpod disposes the StateNotifier (and thus the monitor's timers and
  // streams) when the provider container tears down; no extra hook needed.
  return monitor;
});
