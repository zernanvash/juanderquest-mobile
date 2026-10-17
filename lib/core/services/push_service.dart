import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Push] Background init note: $e');
  }
}

class PushService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  PushService(this._apiClient, [FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _askedKey = 'push_permission_asked';

  Future<void> init() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      // Listen for incoming foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[Push] Foreground message: ${message.notification?.title}');
      });

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _syncToken(token);
      });
    } catch (e) {
      debugPrint('[Push] Init note: $e');
    }
  }

  Future<bool> hasAskedPermission() async {
    try {
      final val = await _storage.read(key: _askedKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissionAndRegister() async {
    try {
      await _storage.write(key: _askedKey, value: 'true');

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _syncToken(token);
        }
      }
      return granted;
    } catch (e) {
      debugPrint('[Push] Permission/registration error: $e');
      return false;
    }
  }

  Future<void> _syncToken(String token) async {
    try {
      await _apiClient.dio.put('/me/devices', data: {
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'app_build': '1.0.0+1',
      });
      debugPrint('[Push] Device token registered successfully');
    } catch (e) {
      debugPrint('[Push] Failed to register device token: $e');
    }
  }

  Future<void> unregisterDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _apiClient.dio.delete('/me/devices', data: {'token': token});
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[Push] Unregister note: $e');
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final api = ref.watch(apiClientProvider);
  return PushService(api);
});
