import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] Initialized successfully with options');
  } catch (e) {
    debugPrint('[Firebase] Initialization note (continuing safely): $e');
  }

  runApp(
    const ProviderScope(
      child: JuanderQuestApp(),
    ),
  );
}

