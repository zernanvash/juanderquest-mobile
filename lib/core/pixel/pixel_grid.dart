import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PixelTextSize {
  followPhone,
  smaller,
  larger;

  double get multiplier => switch (this) {
        PixelTextSize.followPhone => 1.0,
        PixelTextSize.smaller => 0.9,
        PixelTextSize.larger => 1.15,
      };

  String get label => switch (this) {
        PixelTextSize.followPhone => 'Follow phone',
        PixelTextSize.smaller => 'Smaller',
        PixelTextSize.larger => 'Larger',
      };
}

/// Plan 93b WP-8: app language (English or Tagalog for now).
enum AppLanguage {
  english,
  tagalog;

  String get label => switch (this) {
        AppLanguage.english => 'Pure English',
        AppLanguage.tagalog => 'Tagalog',
      };

  String get shortCode => switch (this) {
        AppLanguage.english => 'EN',
        AppLanguage.tagalog => 'TL',
      };
}

@immutable
class PixelSettings {
  const PixelSettings({
    double? artPx,
    this.font = defaultFont,
    this.haptics = true,
    this.textSize = PixelTextSize.followPhone,
    this.language = AppLanguage.english,
    this.music = true,
    this.sounds = true,
    this.reduceMotion = false,
  }) : _artPx = artPx;

  static const double defaultArtPx = 2;
  // Owner 2026-11-05: Silkscreen is the main font (was Monocraft).
  static const String defaultFont = 'Silkscreen';

  /// Bumped when the default font changes, so a font saved under an
  /// older default moves to the new one.
  static const int fontVersion = 2;

  static const artSizes = <double>[1.5, 2, 2.5, 3, 4];

  static const fonts = <String, String>{
    'Silkscreen': 'Chunky, all caps — default',
    'Monocraft': 'Minecraft-like, uniform',
    'PixelifySans': 'Readable pixel sans, proportional',
    'VT323': 'Terminal / Undertale-ish',
    'PressStart2P': '8-bit arcade (NES)',
  };

  final double? _artPx;
  double get artPx => _artPx ?? defaultArtPx;
  double? get customArtPx => _artPx;

  final String font;
  final bool haptics;
  final PixelTextSize textSize;
  final AppLanguage language;

  /// Owner 2026-11-16: background music and button sounds, on by default.
  final bool music;
  final bool sounds;

  /// Owner 2026-11-17: the app's effects (menu embers, idle loops, party
  /// poppers) play even when the phone's animation scale is off; this
  /// in-app switch turns them off.
  final bool reduceMotion;

  double resolveArtPx([double shortestSide = 400]) {
    final art = _artPx;
    if (art != null && artSizes.contains(art)) return art;
    return shortestSide < 400 ? 1.5 : 2.0;
  }

  double fontScale() => switch (font) {
        'PressStart2P' => 0.61,
        'Silkscreen' => 1.0,
        'VT323' => 1.31,
        'PixelifySans' => 1.04,
        'Monocraft' => 1.0,
        _ => 1.0,
      };

  TextScaler effectiveTextScaler(MediaQueryData media) {
    final phoneScale = media.textScaler.scale(1.0);
    final scaled = phoneScale * textSize.multiplier;
    final clamped = scaled.clamp(0.85, 1.4);
    return TextScaler.linear(clamped);
  }

  PixelSettings copyWith({
    double? artPx,
    String? font,
    bool? haptics,
    PixelTextSize? textSize,
    AppLanguage? language,
    bool? music,
    bool? sounds,
    bool? reduceMotion,
  }) =>
      PixelSettings(
        artPx: artPx ?? _artPx,
        font: font ?? this.font,
        haptics: haptics ?? this.haptics,
        textSize: textSize ?? this.textSize,
        language: language ?? this.language,
        music: music ?? this.music,
        sounds: sounds ?? this.sounds,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'artPx': _artPx,
        'font': font,
        'fontV': fontVersion,
        'haptics': haptics,
        'textSize': textSize.name,
        'language': language.name,
        'music': music,
        'sounds': sounds,
        'reduceMotion': reduceMotion,
      };

  static PixelSettings? fromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final art = (decoded['artPx'] as num?)?.toDouble();
      final font = decoded['font'];
      final haptics = decoded['haptics'];
      final textSizeName = decoded['textSize'];
      PixelTextSize parsedTextSize = PixelTextSize.followPhone;
      if (textSizeName is String) {
        for (final v in PixelTextSize.values) {
          if (v.name == textSizeName) {
            parsedTextSize = v;
            break;
          }
        }
      }
      final languageName = decoded['language'];
      final language = AppLanguage.values.firstWhere(
        (v) => v.name == languageName,
        orElse: () => AppLanguage.english,
      );
      return PixelSettings(
        artPx: art != null && artSizes.contains(art) ? art : null,
        font: font is String &&
                fonts.containsKey(font) &&
                decoded['fontV'] == fontVersion
            ? font
            : defaultFont,
        haptics: haptics is bool ? haptics : true,
        textSize: parsedTextSize,
        language: language,
        music: decoded['music'] is bool ? decoded['music'] as bool : true,
        sounds: decoded['sounds'] is bool ? decoded['sounds'] as bool : true,
        reduceMotion: decoded['reduceMotion'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PixelSettings &&
      other._artPx == _artPx &&
      other.font == font &&
      other.haptics == haptics &&
      other.textSize == textSize &&
      other.language == language &&
      other.music == music &&
      other.sounds == sounds &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(
      _artPx, font, haptics, textSize, language, music, sounds, reduceMotion);
}

class PixelScope extends StatelessWidget {
  const PixelScope({
    super.key,
    required this.settings,
    required this.child,
  });

  final PixelSettings settings;
  final Widget child;

  static PixelSettings of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_InheritedPixelScope>();
    if (inherited != null) return inherited.settings;
    try {
      return ProviderScope.containerOf(context, listen: false)
          .read(pixelSettingsProvider);
    } catch (_) {
      return const PixelSettings();
    }
  }

  static PixelSettings? maybeOf(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_InheritedPixelScope>();
    return inherited?.settings;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final clampedScaler =
        media != null ? settings.effectiveTextScaler(media) : null;

    Widget result = _InheritedPixelScope(
      settings: settings,
      child: child,
    );

    if (media != null && clampedScaler != null) {
      result = MediaQuery(
        // Our own setting decides animations, not the phone's transition
        // scale (owner 2026-11-17: "always play our effects").
        data: media.copyWith(
          textScaler: clampedScaler,
          disableAnimations: settings.reduceMotion,
        ),
        child: result,
      );
    }

    return result;
  }
}

class _InheritedPixelScope extends InheritedWidget {
  const _InheritedPixelScope({
    required this.settings,
    required super.child,
  });

  final PixelSettings settings;

  @override
  bool updateShouldNotify(_InheritedPixelScope oldWidget) =>
      oldWidget.settings != settings;
}

class PixelGrid {
  PixelGrid(this.dpr, double artPx)
      : devicePerArt = (artPx * dpr).round().clamp(1, 64).toInt(),
        unit = (artPx * dpr).round().clamp(1, 64).toInt() / dpr;

  final double dpr;
  final int devicePerArt;
  final double unit;

  static PixelGrid of(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final shortest = media?.size.shortestSide ?? 400.0;
    final dpr = media?.devicePixelRatio ?? 1.0;
    final settings = PixelScope.of(context);
    return PixelGrid(
      dpr,
      settings.resolveArtPx(shortest),
    );
  }

  double snap(double v) => (v * dpr).roundToDouble() / dpr;

  double px(num artPixels) => artPixels * unit;

  /// Side padding for page content. Owner 2026-11-17: panels run nearly
  /// edge to edge; the breathing room is inside them
  /// ([PixelPanel.sectionPadding]).
  double get gutter => px(4);
}

abstract interface class PixelSettingsStore {
  Future<PixelSettings?> read();

  Future<void> write(PixelSettings settings);
}

class SecurePixelSettingsStore implements PixelSettingsStore {
  const SecurePixelSettingsStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'jdq_pixel_settings_v1';

  @override
  Future<PixelSettings?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return PixelSettings.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(PixelSettings settings) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(settings.toJson()));
    } catch (_) {
      return;
    }
  }
}

final pixelSettingsStoreProvider = Provider<PixelSettingsStore>(
  (ref) => const SecurePixelSettingsStore(),
);

final pixelSettingsProvider =
    NotifierProvider<PixelSettingsNotifier, PixelSettings>(
  PixelSettingsNotifier.new,
);

class PixelSettingsNotifier extends Notifier<PixelSettings> {
  @override
  PixelSettings build() {
    Future<void>.microtask(_restore);
    return const PixelSettings();
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(pixelSettingsStoreProvider).read();
      if (stored != null) state = stored;
    } catch (_) {
      return;
    }
  }

  void setArtPx(double value) {
    if (kReleaseMode || !PixelSettings.artSizes.contains(value)) return;
    state = state.copyWith(artPx: value);
    unawaited(_persist());
  }

  void setTextSize(PixelTextSize value) {
    state = state.copyWith(textSize: value);
    unawaited(_persist());
  }

  void setLanguage(AppLanguage value) {
    state = state.copyWith(language: value);
    unawaited(_persist());
  }

  void setHaptics(bool value) {
    if (kReleaseMode) return;
    state = state.copyWith(haptics: value);
    unawaited(_persist());
  }

  void setMusic(bool value) {
    state = state.copyWith(music: value);
    unawaited(_persist());
  }

  void setSounds(bool value) {
    state = state.copyWith(sounds: value);
    unawaited(_persist());
  }

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
    unawaited(_persist());
  }

  void reset() {
    if (kReleaseMode) return;
    state = const PixelSettings();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await ref.read(pixelSettingsStoreProvider).write(state);
  }
}
