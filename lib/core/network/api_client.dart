import 'package:dio/dio.dart';

class ApiClient {
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.juanderquest.app/api/v1',
  );

  /// Normalizes API base URL, ensuring trailing slashes are removed
  /// and the canonical /api/v1 prefix is preserved whether pointing to
  /// https://api.juanderquest.app or https://juanderquest.app.
  static String normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.endsWith('/api/v1')) {
      trimmed = '$trimmed/api/v1';
    }
    return trimmed;
  }

  static final String apiBaseUrl = normalizeBaseUrl(_rawApiBaseUrl);

  late final Dio dio;
  String? _authToken;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'JuanDerQuest-Mobile/1.0 (+https://juanderquest.app)',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          print('[API Error] ${e.message} on ${e.requestOptions.path}');
          return handler.next(e);
        },
      ),
    );
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  bool get isAuthenticated => _authToken != null;
}
