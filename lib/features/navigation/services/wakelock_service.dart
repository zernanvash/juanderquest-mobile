import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract class WakelockService {
  Future<void> enable();
  Future<void> disable();
  bool get isEnabled;
}

class AppWakelockService implements WakelockService {
  bool _enabled = false;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> enable() async {
    _enabled = true;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[Wakelock] Note: Could not enable wakelock: $e');
    }
  }

  @override
  Future<void> disable() async {
    _enabled = false;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[Wakelock] Note: Could not disable wakelock: $e');
    }
  }
}

class FakeWakelockService implements WakelockService {
  bool _enabled = false;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> enable() async {
    _enabled = true;
  }

  @override
  Future<void> disable() async {
    _enabled = false;
  }
}

final wakelockServiceProvider = Provider<WakelockService>((ref) {
  return AppWakelockService();
});
