import 'package:flutter/material.dart';

import 'features/ar_lab/ar_lab_screen.dart';

/// Entry point of the separate "JDQ AR Lab" test app (owner 2026-11-02).
/// Build: flutter build apk --debug -t lib/main_ar_lab.dart --android-project-arg=jdqArLab=true
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'JDQ AR Lab',
    debugShowCheckedModeBanner: false,
    home: ArLabScreen(),
  ));
}
