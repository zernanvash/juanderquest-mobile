import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plan 84 sample (owner 2026-11-13: "give me sample ... in the pixel lab so
/// we can test it on buttons and other stuff"). Plays the synthesized effects
/// (no music yet: the owner is choosing it). Off by default; the Pixel lab turns it on.
class GameAudio {
  GameAudio._();
  static final GameAudio instance = GameAudio._();

  static const sfxNames = [
    'tap', 'back', 'toggle_on', 'toggle_off', 'tab', 'sheet_open', 'error', //
    'coin', 'stamp', 'unlock', 'quest_complete', 'level_up', //
    'go', 'turn_chime', 'reroute', 'checkin', 'trail_complete', //
    'ar_hit', 'ar_miss', 'ar_countdown', 'ar_win', 'ar_lose', //
    'cheer', 'pin_select',
  ];

  /// When true, every pixel button press plays `tap` (see `pixelTick`).
  /// Follows Settings → Button sounds (on by default since 2026-11-16).
  final buttonSounds = ValueNotifier<bool>(false);

  // Background music (owner 2026-11-16: assets/audio/music/jdq_bgm.mp3,
  // equalized and loudness-normalized for phone speakers).
  static const musicVolume = 0.35;
  bool _musicWanted = false;
  bool _appVisible = true;
  bool _musicPlaying = false;
  AudioPlayer? _music;

  /// Music mixes with whatever the phone already plays (no audio focus), so
  /// it never stops the traveller's own music or navigation voice.
  static final _musicContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.music,
    ),
  );

  static final bool _inTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Called by the app root with the saved settings.
  void configure({required bool music, required bool sounds}) {
    buttonSounds.value = sounds;
    if (_musicWanted == music) return;
    _musicWanted = music;
    _syncMusic();
  }

  /// Called on app lifecycle changes: music pauses in the background.
  void setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    _appVisible = visible;
    _syncMusic();
  }

  Future<void> _syncMusic() async {
    if (_inTest) return;
    final play = _musicWanted && _appVisible;
    if (play == _musicPlaying) return;
    _musicPlaying = play;
    try {
      if (play) {
        final music = _music ??= AudioPlayer();
        await music.setAudioContext(_musicContext);
        await music.setReleaseMode(ReleaseMode.loop);
        await music.setVolume(musicVolume);
        if (music.state == PlayerState.paused) {
          await music.resume();
        } else {
          await music.play(AssetSource('audio/music/jdq_bgm.mp3'));
        }
      } else {
        await _music?.pause();
      }
    } catch (e) {
      // No audio engine: stay silent, and allow a retry on the next change.
      _musicPlaying = false;
      debugPrint('GameAudio music: $e');
    }
  }

  final sfxVolume = ValueNotifier<double>(0.8);

  final _pool = <AudioPlayer>[];
  int _next = 0;
  final _rng = math.Random();
  final _lastPlayed = <String, int>{};

  /// Effects mix with whatever the phone is already playing.
  static final _sfxContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
  );

  Future<void> playSfx(String name, {bool vary = false}) async {
    if (_inTest) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlayed[name] ?? 0) < 60) return;
    _lastPlayed[name] = now;
    try {
      if (_pool.length < 6) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setAudioContext(_sfxContext);
        _pool.add(p);
      }
      final player = _pool[_next++ % _pool.length];
      await player.stop();
      await player.setVolume(sfxVolume.value);
      // ±6% pitch so repeated taps and coins don't sound identical.
      await player
          .setPlaybackRate(vary ? 0.94 + _rng.nextDouble() * 0.12 : 1.0);
      await player.play(AssetSource('audio/sfx/$name.wav'));
    } catch (_) {
      // No audio engine (tests, unsupported device): stay silent.
    }
  }

  Future<void> stopAll() async {
    try {
      for (final p in _pool) {
        await p.stop();
      }
    } catch (_) {}
  }
}
