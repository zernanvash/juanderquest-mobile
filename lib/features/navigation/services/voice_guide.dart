import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech voice guidance abstraction for live navigation.
abstract class VoiceGuide {
  bool get isMuted;
  Future<void> init();
  Future<void> setMuted(bool muted);
  Future<void> speak(String phrase);
  Future<void> stop();
}

/// Real device TTS implementation backed by [FlutterTts] and persisted mute
/// preference in [FlutterSecureStorage]. Fails silently if no TTS engine is
/// installed on the device.
class TtsVoiceGuide implements VoiceGuide {
  static const _muteKey = 'nav_voice_muted';

  final FlutterTts _tts;
  final FlutterSecureStorage _storage;
  bool _isMuted = false;
  bool _initialized = false;

  TtsVoiceGuide({
    FlutterTts? tts,
    FlutterSecureStorage? storage,
  })  : _tts = tts ?? FlutterTts(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  bool get isMuted => _isMuted;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final raw = await _storage.read(key: _muteKey);
      _isMuted = raw == 'true';
    } catch (_) {
      _isMuted = false;
    }
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
    } catch (_) {
      // Silent fail if TTS engine is unavailable.
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    try {
      await _storage.write(key: _muteKey, value: muted ? 'true' : 'false');
    } catch (_) {
      // Ignore storage write errors on unsupported platforms/tests.
    }
    if (muted) {
      await stop();
    }
  }

  @override
  Future<void> speak(String phrase) async {
    if (_isMuted || phrase.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(phrase);
    } catch (_) {
      // Silent fail when TTS engine is missing.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore.
    }
  }
}

/// Test fake recording spoken phrases in memory.
class FakeVoiceGuide implements VoiceGuide {
  final List<String> spoken = [];
  bool _isMuted;

  FakeVoiceGuide({bool initialMuted = false}) : _isMuted = initialMuted;

  @override
  bool get isMuted => _isMuted;

  @override
  Future<void> init() async {}

  @override
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
  }

  @override
  Future<void> speak(String phrase) async {
    if (_isMuted || phrase.trim().isEmpty) return;
    spoken.add(phrase);
  }

  @override
  Future<void> stop() async {}
}

final voiceGuideProvider = Provider<VoiceGuide>((ref) => TtsVoiceGuide());
