import '../../../core/pixel/pixel_art.dart';

/// Hand-crafted pixel sprites for the Home command deck and calendar.
/// Keys map to [PixelPalette.byKey]; `.` is transparent.
abstract final class HomePixelArt {
  /// 16x16 pixel calendar icon with sun-gold header and green date pip.
  static const calendar = PixelArt('homeCalendar', [
    '...00......00...',
    '..0hh0....0hh0..',
    '.00000000000000.',
    '0hhhhhhhhhhhhhh0',
    '0gggggggggggggg0',
    '0000000000000000',
    '0666666666666660',
    '0622622622622660',
    '0622622622622660',
    '0666666666666660',
    '06226aa6226hh660',
    '06226aa6226hh660',
    '0666666666666660',
    '0622622622666660',
    '0555555555555550',
    '.00000000000000.',
  ]);

  /// 8x8 pixel flame/sun stamp checkmark pip for claimed streak days.
  static const stampCheck = PixelArt('homeStampCheck', [
    '..0000..',
    '.0gggg0.',
    '0ghhhhg0',
    '0gh66hg0',
    '0ghh6hg0',
    '0g6hhhg0',
    '.0gggg0.',
    '..0000..',
  ]);

  /// 16x16 pixel QR code icon (3 finder squares + data modules).
  static const qrCode = PixelArt('homeQrCode', [
    '0000000..0000000',
    '0666660..0666660',
    '0600060..0600060',
    '0600060..0600060',
    '0600060..0600060',
    '0666660..0666660',
    '0000000..0000000',
    '.........0..0...',
    '00..00.00.00..00',
    '0000000..0..00.0',
    '0666660..00.0.00',
    '0600060..0..00..',
    '0600060..000..00',
    '0600060..0..00.0',
    '0666660..00.0..0',
    '0000000..0..0000',
  ]);
}
