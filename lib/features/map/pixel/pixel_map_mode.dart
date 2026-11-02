import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Available map display modes.
enum PixelMapMode {
  /// Native vector map platform view (MapLibre) or raster fallback.
  real,

  /// Retro pixelated raster tile map with FragmentShader quantization.
  pixel,
}

/// Abstract contract for reading and saving map mode preference.
abstract interface class PixelMapModeStore {
  Future<PixelMapMode> read();
  Future<void> write(PixelMapMode mode);
}

/// Persistent storage for the map mode using [FlutterSecureStorage].
class SecurePixelMapModeStore implements PixelMapModeStore {
  const SecurePixelMapModeStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'pixel_map_mode_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<PixelMapMode> read() async {
    try {
      final value = await _storage.read(key: key);
      if (value == 'pixel') return PixelMapMode.pixel;
      return PixelMapMode.real;
    } catch (_) {
      return PixelMapMode.real;
    }
  }

  @override
  Future<void> write(PixelMapMode mode) async {
    try {
      await _storage.write(
        key: key,
        value: mode == PixelMapMode.pixel ? 'pixel' : 'real',
      );
    } catch (_) {
      // Storage failure is non-fatal.
    }
  }
}

/// Provider for the storage layer.
final pixelMapModeStoreProvider =
    Provider<PixelMapModeStore>((ref) => const SecurePixelMapModeStore());

/// Injectable provider for checking whether shader filters are supported on the device.
/// Defaults to platform support, easily overridden in widget tests.
final shaderFilterSupportedProvider =
    Provider<bool>((ref) => ui.ImageFilter.isShaderFilterSupported);

/// State notifier managing the active map mode with asynchronous persistence.
class PixelMapModeNotifier extends StateNotifier<PixelMapMode> {
  PixelMapModeNotifier(this._store) : super(PixelMapMode.real) {
    _load();
  }

  final PixelMapModeStore _store;

  Future<void> _load() async {
    final saved = await _store.read();
    if (mounted) state = saved;
  }

  Future<void> setMode(PixelMapMode mode) async {
    if (state == mode) return;
    state = mode;
    await _store.write(mode);
  }

  Future<void> toggle() async {
    final next = state == PixelMapMode.real ? PixelMapMode.pixel : PixelMapMode.real;
    await setMode(next);
  }
}

/// Provider for the active map display mode.
final pixelMapModeProvider =
    StateNotifierProvider<PixelMapModeNotifier, PixelMapMode>((ref) {
  final store = ref.watch(pixelMapModeStoreProvider);
  return PixelMapModeNotifier(store);
});
