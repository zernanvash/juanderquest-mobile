import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/services/push_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 200 * 1024 * 1024,
  );

  // Catch any unhandled synchronous Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  // Catch any unhandled asynchronous platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher Error] $error\n$stack');
    return true; // Handled, prevent app termination
  };

  await ApiClient.initAppInfo();
  await ApiClient.applyStoredServerOverride();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] Initialized successfully with options');
  } catch (e) {
    debugPrint('[Firebase] Initialization note (continuing safely): $e');
  }

  // Push notifications background listener registration
  try {
    final container = ProviderContainer();
    await container.read(pushServiceProvider).init();
  } catch (e) {
    debugPrint('[Push] Startup init note: $e');
  }

  runApp(
    const ProviderScope(
      child: JuanderQuestApp(),
    ),
  );
}

