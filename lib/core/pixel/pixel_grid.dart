import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class PixelSettings {
  const PixelSettings({
    this.artPx = defaultArtPx,
    this.font = defaultFont,
    this.haptics = true,
  });

  static const double defaultArtPx = 2;
  static const String defaultFont = 'Silkscreen';

  static const artSizes = <double>[2, 2.5, 3, 4];

  static const fonts = <String, String>{
    'Silkscreen': 'Chunky, all caps — default',
    'Monocraft': 'Minecraft-like, uniform, monospaced',
    'PixelifySans': 'Readable pixel sans, proportional',
    'VT323': 'Terminal / Undertale-ish',
    'PressStart2P': '8-bit arcade (NES)',
  };

  final double artPx;
  final String font;
  final bool haptics;

  double fontScale() => switch (font) {
        'PressStart2P' => 0.72,
        'Monocraft' => 1.18,
        'VT323' => 1.55,
        'PixelifySans' => 1.23,
        _ => 1.0,
      };

  PixelSettings copyWith({double? artPx, String? font, bool? haptics}) =>
      PixelSettings(
        artPx: artPx ?? this.artPx,
        font: font ?? this.font,
        haptics: haptics ?? this.haptics,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'artPx': artPx,
        'font': font,
        'haptics': haptics,
      };

  static PixelSettings? fromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final art = (decoded['artPx'] as num?)?.toDouble();
      final font = decoded['font'];
      final haptics = decoded['haptics'];
      return PixelSettings(
        artPx: art != null && artSizes.contains(art) ? art : defaultArtPx,
        font: font is String && fonts.containsKey(font) ? font : defaultFont,
        haptics: haptics is bool ? haptics : true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PixelSettings &&
      other.artPx == artPx &&
      other.font == font &&
      other.haptics == haptics;

  @override
  int get hashCode => Object.hash(artPx, font, haptics);
}

class PixelScope extends InheritedWidget {
  const PixelScope({super.key, required this.settings, required super.child});

  final PixelSettings settings;

  static PixelSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PixelScope>();
    if (scope != null) return scope.settings;
    return ProviderScope.containerOf(context, listen: false)
        .read(pixelSettingsProvider);
  }

  @override
  bool updateShouldNotify(PixelScope oldWidget) =>
      oldWidget.settings != settings;
}

class PixelGrid {
  PixelGrid(this.dpr, double artPx)
      : devicePerArt = (artPx * dpr).round().clamp(1, 64).toInt(),
        unit = (artPx * dpr).round().clamp(1, 64).toInt() / dpr;

  final double dpr;
  final int devicePerArt;
  final double unit;

  static PixelGrid of(BuildContext context) => PixelGrid(
        MediaQuery.devicePixelRatioOf(context),
        PixelScope.of(context).artPx,
      );

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
    if (!kReleaseMode) {
      Future<void>.microtask(_restore);
    }
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
    if (kReleaseMode) return;
    await ref.read(pixelSettingsStoreProvider).write(state);
  }
}
