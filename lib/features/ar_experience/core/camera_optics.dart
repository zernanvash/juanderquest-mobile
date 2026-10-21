import 'dart:math' as math;
import 'dart:ui';

/// Physical optics of the back camera (from Camera2 characteristics).
class CameraOptics {
  final double focalLengthMm;

  /// Active sensor size; width is the sensor's long (landscape) side.
  final double sensorWidthMm;
  final double sensorHeightMm;

  /// True when these numbers came from the device, false for the default.
  final bool measured;

  const CameraOptics({
    required this.focalLengthMm,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    this.measured = true,
  });

  /// Typical phone main camera: 4:3 sensor, ~66° along the long side.
  static const fallback = CameraOptics(
    focalLengthMm: 4.25,
    sensorWidthMm: 5.52,
    sensorHeightMm: 4.14,
    measured: false,
  );

  static CameraOptics? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    final f = (map['focalLengthMm'] as num?)?.toDouble();
    final w = (map['sensorWidthMm'] as num?)?.toDouble();
    final h = (map['sensorHeightMm'] as num?)?.toDouble();
    if (f == null || w == null || h == null || f <= 0 || w <= 0 || h <= 0) {
      return null;
    }
    final long = math.max(w, h);
    final short = math.min(w, h);
    return CameraOptics(
        focalLengthMm: f, sensorWidthMm: long, sensorHeightMm: short);
  }

  double get sensorAspect => sensorWidthMm / sensorHeightMm;

  double get longFovDeg =>
      2 * math.atan(sensorWidthMm / (2 * focalLengthMm)) * 180 / math.pi;

  double get shortFovDeg =>
      2 * math.atan(sensorHeightMm / (2 * focalLengthMm)) * 180 / math.pi;

  /// Focal length in logical pixels for a portrait [screen] that shows the
  /// camera preview scaled with `BoxFit.cover`.
  ///
  /// [previewAspect] is the stream's width / height in landscape (> 1), e.g.
  /// `CameraController.value.aspectRatio`. A stream wider than the sensor is
  /// cropped top/bottom of the sensor (short side), otherwise the long side is
  /// cropped; the uncropped side keeps the full field of view.
  double focalPixels({required Size screen, required double previewAspect}) {
    final ar = previewAspect >= 1 ? previewAspect : 1 / previewAspect;
    // Portrait: preview width = sensor short side, preview height = long side.
    final boxW = screen.width;
    final boxH = screen.width * ar;
    final scale = math.max(screen.width / boxW, screen.height / boxH);
    final shownLong = boxH * scale; // vertical on screen
    final shownShort = boxW * scale; // horizontal on screen
    if (ar >= sensorAspect) {
      // Full long side visible in the stream.
      return (shownLong / 2) / (sensorWidthMm / (2 * focalLengthMm));
    }
    // Full short side visible in the stream.
    return (shownShort / 2) / (sensorHeightMm / (2 * focalLengthMm));
  }
}
