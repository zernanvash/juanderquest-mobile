import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_base_url.dart';
import 'api_failure.dart';
import 'retry_interceptor.dart';
import 'server_override.dart';

/// A single in-memory request log entry for "Report a problem" debugging.
/// Never contains bodies or tokens.
class RequestLogEntry {
  final DateTime time;
  final String method;
  final String path;
  final int? status;
  final int elapsedMs;
  final String? code;

  const RequestLogEntry({
    required this.time,
    required this.method,
    required this.path,
    required this.elapsedMs,
    this.status,
    this.code,
  });

  @override
  String toString() =>
      '${time.toIso8601String()} ${method.toUpperCase()} $path -> ${status ?? 'ERR'} ${elapsedMs}ms${code != null ? ' ($code)' : ''}';
}

/// Observer so the app layer can forward API health to the ConnectionMonitor.
abstract class ApiObserver {
  void onFailure(ApiFailure failure);
  void onSuccess(Duration elapsed);
}

class ApiClient {
  static final String _rawApiBaseUrl = defaultApiBaseUrl();

  /// Normalizes API base URL, ensuring trailing slashes are removed
  /// and the canonical /api/v1 prefix is preserved whether pointing to
  /// https://api.juanderquest.app or https://juanderquest.app.
  static String normalizeBaseUrl(String url) => normalizeApiBaseUrl(url);

  static String _activeBaseUrl = normalizeApiBaseUrl(_rawApiBaseUrl);
  static String get apiBaseUrl => _activeBaseUrl;

  static const int _logCapacity = 200;
  static const Duration uploadSendTimeout = Duration(seconds: 90);
  static const Duration uploadReceiveTimeout = Duration(seconds: 30);

  static String _appVersionHeader = '1.0';
  static int _appBuildNumber = 1;
  static bool _appInfoLoaded = false;

  /// Reads app/build identifiers once at startup for the request headers.
  static Future<void> initAppInfo() async {
    if (_appInfoLoaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersionHeader = info.version.isEmpty ? '1.0' : info.version;
      _appBuildNumber = int.tryParse(info.buildNumber) ?? 1;
      _appInfoLoaded = true;
    } catch (_) {
      // Desktop/tests do not provide package info; defaults are fine.
    }
  }

  /// Redirects the API base URL from the debug-only Settings override.
  /// No-op in release builds.
  static Future<void> applyStoredServerOverride() async {
    if (kReleaseMode) return;
    final override = await ServerOverrideStore.read();
    if (override != null && override.isNotEmpty) {
      _activeBaseUrl = normalizeApiBaseUrl(override);
    }
  }

  late final Dio dio;
  String? _authToken;
  ApiObserver? observer;

  /// Wired by the app layer to the ConnectionMonitor so retries abort while
  /// the device is offline.
  bool Function()? isOffline;
  bool _sessionExpiredEmitted = false;

  final Queue<RequestLogEntry> requestLog = Queue<RequestLogEntry>();
  final StreamController<void> _sessionExpiredController = StreamController<void>.broadcast();

  /// Emits once when an authenticated request is rejected with 401.
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  ApiClient({bool enableRetries = true}) {
    dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final retryInterceptor = RetryInterceptor(
      onFailure: (failure) {
        observer?.onFailure(failure);
        if (kDebugMode) {
          debugPrint('[API] ${failure.code} ${failure.statusCode ?? ''} — ${failure.message}');
        }
      },
      isOffline: () => isOffline?.call() ?? false,
    );
    retryInterceptor.dio = dio;
    if (enableRetries) dio.interceptors.add(retryInterceptor);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['started_at_us'] ??= DateTime.now().microsecondsSinceEpoch;
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          options.headers['User-Agent'] = 'JuanDerQuest-Mobile/$_appVersionHeader+$_appBuildNumber';
          options.headers['X-App-Build'] = '$_appBuildNumber';
          options.headers['X-App-Platform'] = 'android';
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final elapsed = _elapsedFor(response.requestOptions);
          _log(
            method: response.requestOptions.method,
            path: response.requestOptions.path,
            status: response.statusCode,
            elapsedMs: elapsed.inMilliseconds,
          );
          observer?.onSuccess(elapsed);
          return handler.next(response);
        },
        onError: (error, handler) {
          final elapsed = _elapsedFor(error.requestOptions);
          final failure = ApiFailure.from(error);
          _log(
            method: error.requestOptions.method,
            path: error.requestOptions.path,
            status: error.response?.statusCode,
            elapsedMs: elapsed.inMilliseconds,
            code: failure.code,
          );

          final requestAuth = error.requestOptions.headers['Authorization'];
          final failedToken = requestAuth is String && requestAuth.startsWith('Bearer ')
              ? requestAuth.substring(7)
              : null;
          final isCurrentSessionFailed = _authToken != null && failedToken == _authToken;

          if (failure.code == ApiFailureCodes.unauthorized && isCurrentSessionFailed && !_sessionExpiredEmitted) {
            _sessionExpiredEmitted = true;
            _authToken = null;
            if (!_sessionExpiredController.isClosed) {
              _sessionExpiredController.add(null);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Duration _elapsedFor(RequestOptions options) {
    final startedAt = options.extra['started_at_us'];
    if (startedAt is! int) return Duration.zero;
    return Duration(microseconds: DateTime.now().microsecondsSinceEpoch - startedAt);
  }

  void _log({
    required String method,
    required String path,
    required int elapsedMs,
    int? status,
    String? code,
  }) {
    requestLog.addLast(RequestLogEntry(
      time: DateTime.now(),
      method: method,
      path: path,
      status: status,
      elapsedMs: elapsedMs,
      code: code,
    ));
    while (requestLog.length > _logCapacity) {
      requestLog.removeFirst();
    }
  }

  /// Per-request options for media uploads (long send, moderate receive).
  Options uploadOptions() => Options(
        sendTimeout: uploadSendTimeout,
        receiveTimeout: uploadReceiveTimeout,
      );

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      _sessionExpiredEmitted = false;
    }
  }

  bool get isAuthenticated => _authToken != null;
}
