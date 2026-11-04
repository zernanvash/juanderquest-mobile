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

@immutable
class PixelSettings {
  const PixelSettings({
    double? artPx,
    this.font = defaultFont,
    this.haptics = true,
    this.textSize = PixelTextSize.followPhone,
  }) : _artPx = artPx;

  static const double defaultArtPx = 2;
  static const String defaultFont = 'Monocraft';

  static const artSizes = <double>[1.5, 2, 2.5, 3, 4];

  static const fonts = <String, String>{
    'Monocraft': 'Minecraft-like, uniform — default',
    'Silkscreen': 'Chunky, all caps',
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

  double resolveArtPx([double shortestSide = 400]) {
    final art = _artPx;
    if (art != null && artSizes.contains(art)) return art;
    return shortestSide < 400 ? 1.5 : 2.0;
  }

  double fontScale() => switch (font) {
        'PressStart2P' => 0.61,
        'Silkscreen' => 0.85,
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
  }) =>
      PixelSettings(
        artPx: artPx ?? _artPx,
        font: font ?? this.font,
        haptics: haptics ?? this.haptics,
        textSize: textSize ?? this.textSize,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'artPx': _artPx,
        'font': font,
        'haptics': haptics,
        'textSize': textSize.name,
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
      return PixelSettings(
        artPx: art != null && artSizes.contains(art) ? art : null,
        font: font is String && fonts.containsKey(font) ? font : defaultFont,
        haptics: haptics is bool ? haptics : true,
        textSize: parsedTextSize,
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
      other.textSize == textSize;

  @override
  int get hashCode => Object.hash(_artPx, font, haptics, textSize);
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
        data: media.copyWith(textScaler: clampedScaler),
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

  void setFont(String value) {
    if (kReleaseMode || !PixelSettings.fonts.containsKey(value)) return;
    state = state.copyWith(font: value);
    unawaited(_persist());
  }

  void setHaptics(bool value) {
    if (kReleaseMode) return;
    state = state.copyWith(haptics: value);
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
