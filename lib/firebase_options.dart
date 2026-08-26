// File generated for JuanDerQuest Mobile
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions have not been configured for web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBTM5ls89n8_oaIlGzbd6WSSbovY440qU8',
    appId: '1:195492156420:android:20386ac70e19b2c2209151',
    messagingSenderId: '195492156420',
    projectId: 'juanderquest',
    storageBucket: 'juanderquest.firebasestorage.app',
  );
}
